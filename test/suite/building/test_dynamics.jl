module TestOCPDynamics

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_partial_dynamics()

    # Sample full dynamics function for comparison
    function full_dynamics!(r, t, x, u, v)
        r[1] = t + x[1]
        r[2] = u[1] + x[2]
        r[3] = v[1] + x[3]
        return r
    end

    # Partial dynamics function examples (simple for testing)
    partial_dyn_1!(r, t, x, u, v) = (r[1] = t + x[1])
    partial_dyn_2!(r, t, x, u, v) = (r[1] = u[1] + x[2])
    partial_dyn_3!(r, t, x, u, v) = (r[1] = v[1] + x[3])

    partial_dyn_12!(r, t, x, u, v) = (r[1]=t + x[1]; r[2]=u[1] + x[2])
    partial_dyn_23!(r, t, x, u, v) = (r[1]=u[1] + x[2]; r[2]=v[1] + x[3])

    ######
    # 1. Setup common parameters and helper for test evaluations
    ######
    n_states = 3
    ocp = Building.PreModel()
    Building.time!(ocp; t0=0.0, tf=1.0)
    Building.state!(ocp, n_states)
    Building.control!(ocp, 1)
    Building.variable!(ocp, 1)

    # Dummy variables for evaluating dynamics
    r = zeros(n_states)
    t = 10
    x = 20*ones(n_states)
    u = 100*ones(1)
    v = 1000*ones(1)

    ######
    # 2. Add index-by-index in order, then evaluate vs full function
    ######
    ocp1 = deepcopy(ocp)
    Building.dynamics!(ocp1, 1:1, partial_dyn_1!)
    Building.dynamics!(ocp1, 2:2, partial_dyn_2!)
    Building.dynamics!(ocp1, 3:3, partial_dyn_3!)
    Test.@test length(ocp1.dynamics) == n_states

    # Evaluate partial dynamics and collect result vector
    r_partial = zeros(n_states)
    for (rg, f) in ocp1.dynamics
        f((@view r_partial[rg]), t, x, u, v)
    end

    # Evaluate full dynamics and compare
    r_full = zeros(n_states)
    full_dynamics!(r_full, t, x, u, v)
    Test.@test r_partial == r_full

    # Evaluate after building
    f_from_parts! = Building.__build_dynamics_from_parts(ocp1.dynamics)
    r_partial = zeros(n_states)
    f_from_parts!(r_partial, t, x, u, v)
    Test.@test r_partial == r_full

    ######
    # 3. Add index-by-index out of order, then evaluate vs full function
    ######
    ocp2 = deepcopy(ocp)
    Building.dynamics!(ocp2, 3:3, partial_dyn_3!)
    Building.dynamics!(ocp2, 1:1, partial_dyn_1!)
    Building.dynamics!(ocp2, 2:2, partial_dyn_2!)
    Test.@test length(ocp2.dynamics) == n_states

    r_partial = zeros(n_states)
    for (rg, f) in ocp2.dynamics
        f((@view r_partial[rg]), t, x, u, v)
    end

    r_full = zeros(n_states)
    full_dynamics!(r_full, t, x, u, v)
    Test.@test r_partial == r_full

    f_from_parts! = Building.__build_dynamics_from_parts(ocp2.dynamics)
    r_partial = zeros(n_states)
    f_from_parts!(r_partial, t, x, u, v)
    Test.@test r_partial == r_full

    ######
    # 4. Add by ranges in order, evaluate vs full function
    ######
    ocp3 = deepcopy(ocp)
    Building.dynamics!(ocp3, 1:2, partial_dyn_12!)
    Building.dynamics!(ocp3, 3:3, partial_dyn_3!)
    Test.@test length(ocp3.dynamics) == 2

    r_partial = zeros(n_states)
    for (rg, f) in ocp3.dynamics
        f((@view r_partial[rg]), t, x, u, v)
    end

    r_full = zeros(n_states)
    full_dynamics!(r_full, t, x, u, v)
    Test.@test r_partial == r_full

    f_from_parts! = Building.__build_dynamics_from_parts(ocp3.dynamics)
    r_partial = zeros(n_states)
    f_from_parts!(r_partial, t, x, u, v)
    Test.@test r_partial == r_full

    ######
    # 5. Add by ranges out of order, evaluate vs full function
    ######
    ocp4 = deepcopy(ocp)
    Building.dynamics!(ocp4, 2:3, partial_dyn_23!)
    Building.dynamics!(ocp4, 1:1, partial_dyn_1!)
    Test.@test length(ocp4.dynamics) == 2

    r_partial = zeros(n_states)
    for (rg, f) in ocp4.dynamics
        f((@view r_partial[rg]), t, x, u, v)
    end

    r_full = zeros(n_states)
    full_dynamics!(r_full, t, x, u, v)
    Test.@test r_partial == r_full

    f_from_parts! = Building.__build_dynamics_from_parts(ocp4.dynamics)
    r_partial = zeros(n_states)
    f_from_parts!(r_partial, t, x, u, v)
    Test.@test r_partial == r_full

    ######
    # 6. Error: start with adding index or range then add full dynamics function -> error
    ######
    ocp5 = deepcopy(ocp)
    Building.dynamics!(ocp5, 1:1, partial_dyn_1!)
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(ocp5, full_dynamics!)

    ocp6 = deepcopy(ocp)
    Building.dynamics!(ocp6, 1:2, (r, t, x, u, v)->(r[1]=0; r[2]=0))
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(ocp6, full_dynamics!)

    ######
    # 7. Error: add index out of range (< 1 or > n_states)
    ######
    ocp7 = deepcopy(ocp)
    Test.@test_throws Exceptions.IncorrectArgument Building.dynamics!(
        ocp7, 0:0, partial_dyn_1!
    )
    Test.@test_throws Exceptions.IncorrectArgument Building.dynamics!(
        ocp7, -1:-1, partial_dyn_1!
    )
    Test.@test_throws Exceptions.IncorrectArgument Building.dynamics!(
        ocp7, (n_states + 1):(n_states + 1), partial_dyn_1!
    )

    ######
    # 8. Error: add range with at least one index out of range
    ######
    ocp8 = deepcopy(ocp)
    Test.@test_throws Exceptions.IncorrectArgument Building.dynamics!(
        ocp8, (n_states):(n_states + 1), partial_dyn_1!
    )

    ######
    # 9. Error: add twice the same index in one range
    ######
    ocp9 = deepcopy(ocp)
    Building.dynamics!(ocp9, 2:2, partial_dyn_1!)
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(
        ocp9, 1:2, partial_dyn_1!
    )

    ######
    # 10. Error: add twice the same index in two different ranges
    ######
    ocp10 = deepcopy(ocp)
    Building.dynamics!(ocp10, 1:2, (r, t, x, u, v) -> (r[1]=t; r[2]=u[1]))
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(
        ocp10, 2:3, (r, t, x, u, v) -> (r[2]=0; r[3]=0)
    )

    ######
    # 11. Error: prerequisite checks for partial dynamics (missing state, control, times)
    ######
    ocp_missing = Building.PreModel()
    Building.time!(ocp_missing; t0=0.0, tf=10.0)
    Building.control!(ocp_missing, 1)
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(
        ocp_missing, 1:1, partial_dyn_1!
    )

    # Control is now optional, so this should NOT throw an error
    ocp_missing = Building.PreModel()
    Building.time!(ocp_missing; t0=0.0, tf=10.0)
    Building.state!(ocp_missing, 1)
    Building.dynamics!(ocp_missing, 1:1, partial_dyn_1!)
    Test.@test Building.__is_dynamics_set(ocp_missing)

    ocp_missing = Building.PreModel()
    Building.state!(ocp_missing, 1)
    Building.control!(ocp_missing, 1)
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(
        ocp_missing, 1:1, partial_dyn_1!
    )

    # variable must NOT be set after dynamics
    ocp_variable = Building.PreModel()
    Building.time!(ocp_variable; t0=0.0, tf=10.0)
    Building.state!(ocp_variable, 3)
    Building.control!(ocp_variable, 1)
    Building.dynamics!(ocp_variable, 1:3, full_dynamics!)
    Test.@test_throws Exceptions.PreconditionError Building.variable!(ocp_variable, 1)
end

function test_full_dynamics()

    # Sample full dynamics function
    dynamics!(r, t, x, u, v) = r .= t .+ x .+ u .+ v

    ######
    # 1. Success case: full dynamics set properly
    ######
    ocp = Building.PreModel()
    Building.time!(ocp; t0=0.0, tf=10.0)
    Building.state!(ocp, 1)
    Building.control!(ocp, 1)
    Building.variable!(ocp, 1)
    Building.dynamics!(ocp, dynamics!)
    Test.@test ocp.dynamics == dynamics!

    ######
    # 2. Error: set full dynamics twice not allowed
    ######
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(ocp, dynamics!)

    ######
    # 3. Error: state must be set before dynamics
    ######
    ocp2 = Building.PreModel()
    Building.time!(ocp2; t0=0.0, tf=10.0)
    Building.control!(ocp2, 1)
    Building.variable!(ocp2, 1)
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(ocp2, dynamics!)

    ######
    # 4. Control is now optional - this should succeed
    ######
    ocp3 = Building.PreModel()
    Building.time!(ocp3; t0=0.0, tf=10.0)
    Building.state!(ocp3, 1)
    Building.variable!(ocp3, 1)
    Building.dynamics!(ocp3, dynamics!)
    Test.@test Building.__is_dynamics_set(ocp3)

    ######
    # 5. Error: time must be set before dynamics
    ######
    ocp4 = Building.PreModel()
    Building.state!(ocp4, 1)
    Building.control!(ocp4, 1)
    Building.variable!(ocp4, 1)
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(ocp4, dynamics!)

    ######
    # 6. Error: variable must NOT be set after dynamics
    ######
    ocp5 = Building.PreModel()
    Building.time!(ocp5; t0=0.0, tf=10.0)
    Building.state!(ocp5, 1)
    Building.control!(ocp5, 1)
    Building.dynamics!(ocp5, dynamics!)
    Test.@test_throws Exceptions.PreconditionError Building.variable!(ocp5, 1)

    ######
    # 7. Error: mixing full dynamics and partial dynamics not allowed
    ######
    ocp6 = Building.PreModel()
    Building.time!(ocp6; t0=0.0, tf=10.0)
    Building.state!(ocp6, 2)
    Building.control!(ocp6, 1)
    Building.variable!(ocp6, 1)
    Building.dynamics!(ocp6, dynamics!)

    # Attempt to add partial dynamics after full dynamics -> error
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(
        ocp6, 1:1, (r, t, x, u, v)->(r[1]=0)
    )

    # New ocp for partial dynamics first, then full -> error
    ocp7 = Building.PreModel()
    Building.time!(ocp7; t0=0.0, tf=10.0)
    Building.state!(ocp7, 2)
    Building.control!(ocp7, 1)
    Building.variable!(ocp7, 1)
    Building.dynamics!(ocp7, 1:1, (r, t, x, u, v)->(r[1]=0))
    Test.@test_throws Exceptions.PreconditionError Building.dynamics!(ocp7, dynamics!)
end

function test_dynamics()
    Test.@testset "Dynamics Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Full Dynamics
        # ====================================================================

        Test.@testset "Full dynamics" begin
            test_full_dynamics()
        end

        # ====================================================================
        # UNIT TESTS - Partial Dynamics
        # ====================================================================

        Test.@testset "Partial dynamics" begin
            test_partial_dynamics()
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_dynamics() = TestOCPDynamics.test_dynamics()
