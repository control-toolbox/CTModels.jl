module TestOCPConstraints

using Test: Test
import CTBase.Exceptions
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

"""
    test_constraints()

Test constraint handling in OCP models.

# Note
Some tests in this file intentionally generate warnings to verify that the system
correctly warns users about overwriting bounds. If you see warnings like
"Overwriting bound for component X", they are expected and part of the test assertions.
"""
function test_constraints()
    Test.@testset "Constraints Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for constraints functionality
        end

        # ====================================================================
        # UNIT TESTS - Constraint Handling
        # ====================================================================
        ∅ = Vector{Float64}()

        # From PreModel
        ocp_set = CTModels.PreModel()
        CTModels.time!(ocp_set; t0=0.0, tf=10.0)
        CTModels.state!(ocp_set, 2)
        CTModels.control!(ocp_set, 1)
        CTModels.variable!(ocp_set, 1)

        # state not set
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.constraint!(ocp, :dummy)

        # control not set
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.constraint!(ocp, :dummy)

        # times not set
        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        CTModels.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.constraint!(ocp, :dummy)

        # variable not set and try to add a :variable constraint
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        CTModels.state!(ocp, 1)
        CTModels.control!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.constraint!(ocp, :variable)

        # lb and ub cannot be both nothing
        Test.@test_throws Exceptions.PreconditionError CTModels.constraint!(ocp_set, :state)

        # twice the same label for two constraints
        CTModels.constraint!(ocp_set, :state; lb=[0, 1], label=:cons)
        Test.@test_throws Exceptions.PreconditionError CTModels.constraint!(
            ocp_set, :control, lb=[0, 1], label=:cons
        )

        # lb and ub must have the same length
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :state, lb=[0, 1], ub=[0, 1, 2]
        )

        # x(1) == [0, 0, 1] must raise an error if x is of dimension 2
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :boundary, lb=[0, 0, 1], ub=[0, 1, 2], codim_f=2
        )

        # if no range nor function is provided, lb and ub must have the right length:
        # depending on state, control, or variable
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :state, lb=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :control, lb=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :variable, lb=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :state, ub=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :control, ub=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :variable, ub=[0, 1, 2]
        )

        # if no range nor function is provided, the only possible constraints are 
        # :state, :control, and :variable
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :dummy, lb=[0], ub=[1]
        )

        # if a range is provided, lb and ub must have the same length as the range
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :state, rg=1:2, lb=[0], ub=[1]
        )

        # if a range is provided, it must be consistent with the dimensions of the model
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :state, rg=3:4, lb=[0, 1], ub=[1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :control, rg=2:3, lb=[0, 1], ub=[1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :variable, rg=2:3, lb=[0, 1], ub=[1, 2]
        )

        # if a range is provided, the only possible constraints are :state, :control, and :variable
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :dummy, rg=1:2, lb=[0, 1], ub=[1, 2]
        )

        # if a function is provided, the only possible constraints are :path, :boundary and :variable
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :dummy, f=(x, y) -> x + y, lb=[0, 1], ub=[1, 2]
        )

        # we cannot provide a function and a range
        Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
            ocp_set, :variable, f=(x, y) -> x + y, rg=1:2, lb=[0, 1], ub=[1, 2]
        )

        # test with :path constraint
        f_path(r, t, x, u, v) = r .= x .+ u .+ v .+ t
        CTModels.constraint!(ocp_set, :path; f=f_path, lb=[0, 1], ub=[1, 2], label=:path)
        Test.@test ocp_set.constraints[:path] == (:path, f_path, [0, 1], [1, 2])

        # test with :boundary constraint
        f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)
        CTModels.constraint!(
            ocp_set, :boundary; f=f_boundary, lb=[0, 1], ub=[1, 2], label=:boundary
        )
        Test.@test ocp_set.constraints[:boundary] == (:boundary, f_boundary, [0, 1], [1, 2])

        # test with :state constraint and range
        CTModels.constraint!(ocp_set, :state; rg=1:2, lb=[0, 1], ub=[1, 2], label=:state_rg)
        Test.@test ocp_set.constraints[:state_rg] == (:state, 1:2, [0, 1], [1, 2])

        # test with :control constraint and range
        CTModels.constraint!(ocp_set, :control; rg=1:1, lb=[1], ub=[1], label=:control_rg)
        Test.@test ocp_set.constraints[:control_rg] == (:control, 1:1, [1], [1])

        # test with :variable constraint and range
        CTModels.constraint!(ocp_set, :variable; rg=1:1, lb=[1], ub=[1], label=:variable_rg)
        Test.@test ocp_set.constraints[:variable_rg] == (:variable, 1:1, [1], [1])

        # -----------------------------------------------------------------------
        # Test duplicate constraint warning (Issue #105)
        # When multiple constraints are declared on the same component index,
        # a warning should be emitted during model build.
        # Applies to: state, control, and variable constraints.
        #
        # NOTE: The warnings displayed during these tests are INTENTIONAL and EXPECTED.
        # They verify that the system correctly warns users about overwriting bounds.
        # These warnings are part of the test assertions using Test.@test_warn.
        # -----------------------------------------------------------------------
        Test.@testset "duplicate constraint warning" begin
            # --- State constraints ---
            Test.@testset "state" begin
                ocp_dup = CTModels.PreModel()
                CTModels.time!(ocp_dup; t0=0.0, tf=1.0)
                CTModels.state!(ocp_dup, 2)
                CTModels.control!(ocp_dup, 1)
                dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
                CTModels.dynamics!(ocp_dup, dynamics!)
                CTModels.objective!(ocp_dup, :min; mayer=(x0, xf, v) -> xf[1])
                CTModels.definition!(ocp_dup, quote end)
                CTModels.time_dependence!(ocp_dup; autonomous=false)

                # Add constraints on state component 1
                CTModels.constraint!(ocp_dup, :state; rg=1:1, lb=[0.0], ub=[1.0], label=:s1)
                CTModels.constraint!(ocp_dup, :state; rg=1:1, lb=[0.5], ub=[1.5], label=:s2)

                Test.@test_warn "Overwriting bound for component 1" CTModels.build(ocp_dup)
            end

            # --- Control constraints ---
            Test.@testset "control" begin
                ocp_dup = CTModels.PreModel()
                CTModels.time!(ocp_dup; t0=0.0, tf=1.0)
                CTModels.state!(ocp_dup, 2)
                CTModels.control!(ocp_dup, 2)  # 2 controls to allow duplicate on component 1
                dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
                CTModels.dynamics!(ocp_dup, dynamics!)
                CTModels.objective!(ocp_dup, :min; mayer=(x0, xf, v) -> xf[1])
                CTModels.definition!(ocp_dup, quote end)
                CTModels.time_dependence!(ocp_dup; autonomous=false)

                # Add constraints on control component 1
                CTModels.constraint!(
                    ocp_dup, :control; rg=1:1, lb=[0.0], ub=[1.0], label=:c1
                )
                CTModels.constraint!(
                    ocp_dup, :control; rg=1:1, lb=[0.5], ub=[1.5], label=:c2
                )

                Test.@test_warn "Overwriting bound for component 1" CTModels.build(ocp_dup)
            end

            # --- Variable constraints ---
            Test.@testset "variable" begin
                ocp_dup = CTModels.PreModel()
                CTModels.time!(ocp_dup; t0=0.0, tf=1.0)
                CTModels.state!(ocp_dup, 2)
                CTModels.control!(ocp_dup, 1)
                CTModels.variable!(ocp_dup, 2)  # 2 variables to allow duplicate on component 1
                dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
                CTModels.dynamics!(ocp_dup, dynamics!)
                CTModels.objective!(ocp_dup, :min; mayer=(x0, xf, v) -> xf[1])
                CTModels.definition!(ocp_dup, quote end)
                CTModels.time_dependence!(ocp_dup; autonomous=false)

                # Add constraints on variable component 1
                CTModels.constraint!(
                    ocp_dup, :variable; rg=1:1, lb=[0.0], ub=[1.0], label=:v1
                )
                CTModels.constraint!(
                    ocp_dup, :variable; rg=1:1, lb=[0.5], ub=[1.5], label=:v2
                )

                Test.@test_warn "Overwriting bound for component 1" CTModels.build(ocp_dup)
            end
        end

        # NEW: lb ≤ ub validation tests
        Test.@testset "constraints! - Bounds validation" begin
            # lb > ub for state constraints
            Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
                ocp_set, :state, lb=[1.0, 2.0], ub=[0.5, 1.0], label=:invalid_state
            )

            # lb > ub for control constraints
            Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
                ocp_set, :control, lb=[2.0], ub=[1.0], label=:invalid_control
            )

            # lb > ub for variable constraints
            Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
                ocp_set, :variable, lb=[1.5], ub=[0.5], label=:invalid_variable
            )

            # lb > ub for boundary constraints
            f_boundary(r, x0, xf, v) = r .= x0 .+ v
            Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
                ocp_set,
                :boundary;
                f=f_boundary,
                lb=[1.0, 2.0],
                ub=[0.5, 1.0],
                label=:invalid_boundary,
            )

            # lb > ub for path constraints
            f_path(r, t, x, u, v) = r .= x .+ u .+ v
            Test.@test_throws Exceptions.IncorrectArgument CTModels.constraint!(
                ocp_set, :path; f=f_path, lb=[2.0], ub=[1.0], label=:invalid_path
            )

            # Valid bounds (lb ≤ ub)
            Test.@test_nowarn CTModels.constraint!(
                ocp_set, :state, lb=[0.0, 1.0], ub=[1.0, 2.0], label=:valid_state
            )
            Test.@test_nowarn CTModels.constraint!(
                ocp_set, :control, lb=[0.0], ub=[1.0], label=:valid_control
            )
            Test.@test_nowarn CTModels.constraint!(
                ocp_set, :variable, lb=[-1.0], ub=[1.0], label=:valid_variable
            )

            # Edge case: lb == ub (equality constraints)
            Test.@test_nowarn CTModels.constraint!(
                ocp_set, :state, lb=[0.5, 1.5], ub=[0.5, 1.5], label=:equality_state
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_constraints() = TestOCPConstraints.test_constraints()
