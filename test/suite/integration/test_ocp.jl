module TestOCP

import Test: Test
import CTBase: CTBase
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_ocp()
    Test.@testset "OCP Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - OCP Functionality
        # ====================================================================

        #
        ∅ = Vector{Float64}()

        #
        Test.@test isconcretetype(Building.PreModel)

        # dimensions
        n = 2 # state dimension
        m = 2 # control dimension
        q = 2 # variable dimension

        # functions
        mayer_user(x0, xf, v) = sum(xf .- x0 .- v)
        lagrange_user(t, x, u, v) = sum(x .+ u .+ v .+ t)
        dynamics_user!(r, t, x, u, v) = r .= x .+ u .+ v .+ t

        # points
        x0 = [1.0, 2.0]
        xf = [3.0, 4.0]
        v = [5.0, 6.0]
        t = 7.0
        x = [8.0, 9.0]
        u = [10.0, 11.0]

        # models
        times = Components.TimesModel(
            Components.FreeTimeModel(1, "t₀"), Components.FreeTimeModel(2, "t_f"), "t"
        )
        state = Components.StateModel("y", ["y₁", "y₂"])
        control = Components.ControlModel("u", ["u₁", "u₂"])
        variable = Components.VariableModel("v", ["v₁", "v₂"])
        dynamics = dynamics_user!
        objective = Components.MayerObjectiveModel(mayer_user, :min)
        pre_constraints = Components.ConstraintsDictType()

        # add some constraints:
        # - path constraint: one of dimension 2, and another of dimension 1
        # - boundary constraint: one of dimension 2, and another of dimension 1
        # - variable nonlinear (function) constraint: one of dimension 2, and another of dimension 1
        # - state box constraint: one of dimension 2, and another of dimension 1
        # - control box constraint: one of dimension 2, and another of dimension 1
        # - variable box constraint: one of dimension 2, and another of dimension 1

        # path constraint
        f_path_a(r, t, x, u, v) = r .= x .+ u .+ v .+ t
        Building.__constraint!(
            pre_constraints, :path, n, m, q; f=f_path_a, lb=[0, 1], ub=[1, 2]
        )
        f_path_b(r, t, x, u, v) = r .= x[1] + u[1] + v[1] + t
        Building.__constraint!(
            pre_constraints, :path, n, m, q; f=f_path_b, lb=[3], ub=[3]
        )

        # boundary constraint
        f_boundary_a(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)
        Building.__constraint!(
            pre_constraints, :boundary, n, m, q; f=f_boundary_a, lb=[0, 1], ub=[1, 2]
        )
        f_boundary_b(r, x0, xf, v) = r .= x0[1] - 1.0 + v[1] * (xf[1] - x0[1])
        Building.__constraint!(
            pre_constraints, :boundary, n, m, q; f=f_boundary_b, lb=[3], ub=[3]
        )

        # state/control/variable box constraints:
        # declare full-range bounds on components 1..2, then a tighter bound on
        # component 2 that is consistent with the first declaration (so the
        # per-component intersection is non-empty). After dedup:
        #   comp 1 → lb=0, ub=1     (from first declaration)
        #   comp 2 → lb=1, ub=1.5   (intersection: max(1, 1)=1, min(2, 1.5)=1.5)

        # state box
        Building.__constraint!(pre_constraints, :state, n, m, q; lb=[0, 1], ub=[1, 2])
        Building.__constraint!(
            pre_constraints, :state, n, m, q; rg=2:2, lb=[1], ub=[1.5]
        )

        # control box
        Building.__constraint!(pre_constraints, :control, n, m, q; lb=[0, 1], ub=[1, 2])
        Building.__constraint!(
            pre_constraints, :control, n, m, q; rg=2:2, lb=[1], ub=[1.5]
        )

        # variable box
        Building.__constraint!(
            pre_constraints, :variable, n, m, q; lb=[0, 1], ub=[1, 2]
        )
        Building.__constraint!(
            pre_constraints, :variable, n, m, q; rg=2:2, lb=[1], ub=[1.5]
        )

        # build constraints (the duplicate-on-component-2 declarations above
        # emit one warning each, which we silence via stderr redirection).
        constraints = redirect_stderr(devnull) do
            return Building.build(pre_constraints)
        end

        # Model definition
        definition = Components.Definition(quote
            t ∈ [0, 1], time
            x ∈ R², state
            u ∈ R, control
            x(0) == [-1, 0]
            x(1) == [0, 0]
            ẋ(t) == [x₂(t), u(t)]
            ∫(0.5u(t)^2) → min
        end)

        build_examodel = nothing

        # concrete ocp
        ocp = Models.Model{Components.NonAutonomous}(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )

        # print (captured, no terminal output)
        io = IOBuffer()
        show(io, MIME"text/plain"(), ocp)

        # tests on times
        Test.@test Components.initial_time(ocp, [0.0, 10.0]) == 0.0
        Test.@test Components.final_time(ocp, [0.0, 10.0]) == 10.0
        Test.@test Components.time_name(ocp) == "t"
        Test.@test Components.initial_time_name(ocp) == "t₀"
        Test.@test Components.final_time_name(ocp) == "t_f"
        Test.@test Components.has_fixed_initial_time(ocp) == false
        Test.@test Components.has_fixed_final_time(ocp) == false
        Test.@test Components.has_free_initial_time(ocp) == true
        Test.@test Components.has_free_final_time(ocp) == true

        # tests on state
        Test.@test Models.state_dimension(ocp) == 2
        Test.@test Models.state_name(ocp) == "y"
        Test.@test Models.state_components(ocp) == ["y₁", "y₂"]

        # tests on control
        Test.@test Models.control_dimension(ocp) == 2
        Test.@test Models.control_name(ocp) == "u"
        Test.@test Models.control_components(ocp) == ["u₁", "u₂"]

        # tests on variable
        Test.@test Models.variable_dimension(ocp) == 2
        Test.@test Models.variable_name(ocp) == "v"
        Test.@test Models.variable_components(ocp) == ["v₁", "v₂"]

        # tests on dynamics
        r = zeros(Float64, 2)
        r_user = zeros(Float64, 2)
        dynamics! = Models.dynamics(ocp)
        dynamics!(r, t, x, u, v)
        dynamics_user!(r_user, t, x, u, v)
        Test.@test r == r_user

        # tests on objective
        Test.@test Models.objective(ocp) == objective
        Test.@test Components.criterion(ocp) == :min
        Test.@test Components.has_mayer_cost(ocp) == true
        Test.@test Components.has_lagrange_cost(ocp) == false

        # tests on mayer
        mayer = Components.mayer(ocp)
        Test.@test mayer(x0, xf, v) == mayer_user(x0, xf, v)

        # tests on constraints
        # dimensions: path, boundary, variable (nonlinear), state, control, variable (box)
        Test.@test Components.dim_path_constraints_nl(ocp) == 3
        Test.@test Components.dim_boundary_constraints_nl(ocp) == 3
        Test.@test Components.dim_state_constraints_box(ocp) == 2
        Test.@test Components.dim_control_constraints_box(ocp) == 2
        Test.@test Components.dim_variable_constraints_box(ocp) == 2

        # Get all constraints and test. Be careful, the order is not guaranteed.
        # We will check up to permutations by sorting the results.
        (path_cons_nl_lb, path_cons_nl!, path_cons_nl_ub) = Components.path_constraints_nl(
            ocp
        )
        (boundary_cons_nl_lb, boundary_cons_nl!, boundary_cons_nl_ub) = Components.boundary_constraints_nl(
            ocp
        )
        (state_cons_box_lb, state_cons_box_ind, state_cons_box_ub) = Components.state_constraints_box(
            ocp
        )
        (control_cons_box_lb, control_cons_box_ind, control_cons_box_ub) = Components.control_constraints_box(
            ocp
        )
        (variable_cons_box_lb, variable_cons_box_ind, variable_cons_box_ub) = Components.variable_constraints_box(
            ocp
        )

        # path constraints
        Test.@test sort(path_cons_nl_lb) == [0, 1, 3]
        Test.@test sort(path_cons_nl_ub) == [1, 2, 3]
        ra = zeros(Float64, 2)
        rb = zeros(Float64, 1)
        f_path_a(ra, t, x, u, v)
        f_path_b(rb, t, x, u, v)
        r = zeros(Float64, 3)
        path_cons_nl!(r, t, x, u, v)
        Test.@test sort(r) == sort([ra; rb])

        # boundary constraints
        Test.@test sort(boundary_cons_nl_lb) == [0, 1, 3]
        Test.@test sort(boundary_cons_nl_ub) == [1, 2, 3]
        ra = zeros(Float64, 2)
        rb = zeros(Float64, 1)
        f_boundary_a(ra, x0, xf, v)
        f_boundary_b(rb, x0, xf, v)
        r = zeros(Float64, 3)
        boundary_cons_nl!(r, x0, xf, v)
        Test.@test sort(r) == sort([ra; rb])

        # state box constraints (2 unique components after dedup)
        Test.@test sort(state_cons_box_lb) == [0, 1]
        Test.@test sort(state_cons_box_ub) == [1, 1.5]
        Test.@test sort(state_cons_box_ind) == [1, 2]

        # control box constraints
        Test.@test sort(control_cons_box_lb) == [0, 1]
        Test.@test sort(control_cons_box_ub) == [1, 1.5]
        Test.@test sort(control_cons_box_ind) == [1, 2]

        # variable box constraints
        Test.@test sort(variable_cons_box_lb) == [0, 1]
        Test.@test sort(variable_cons_box_ub) == [1, 1.5]
        Test.@test sort(variable_cons_box_ind) == [1, 2]

        # -------------------------------------------------------------------------- #
        # ocp with fixed times
        times = Components.TimesModel(
            Components.FixedTimeModel(0.0, "t₀"), Components.FixedTimeModel(10.0, "t_f"), "t"
        )
        ocp = Models.Model{Components.NonAutonomous}(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )

        # tests on times
        Test.@test Components.initial_time(ocp) == 0.0
        Test.@test Components.final_time(ocp) == 10.0
        Test.@test Components.time_name(ocp) == "t"
        Test.@test Components.initial_time_name(ocp) == "t₀"
        Test.@test Components.final_time_name(ocp) == "t_f"
        Test.@test Components.has_fixed_initial_time(ocp) == true
        Test.@test Components.has_fixed_final_time(ocp) == true
        Test.@test Components.has_free_initial_time(ocp) == false
        Test.@test Components.has_free_final_time(ocp) == false

        # -------------------------------------------------------------------------- #
        # ocp with fixed initial time and free final time
        times = Components.TimesModel(
            Components.FixedTimeModel(0.0, "t₀"), Components.FreeTimeModel(1, "t_f"), "t"
        )
        ocp = Models.Model{Components.NonAutonomous}(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )

        # tests on times
        Test.@test Components.initial_time(ocp) == 0.0
        Test.@test Components.final_time(ocp, [2.0, 50.0]) == 2.0
        Test.@test Components.time_name(ocp) == "t"
        Test.@test Components.initial_time_name(ocp) == "t₀"
        Test.@test Components.final_time_name(ocp) == "t_f"
        Test.@test Components.has_fixed_initial_time(ocp) == true
        Test.@test Components.has_fixed_final_time(ocp) == false
        Test.@test Components.has_free_initial_time(ocp) == false
        Test.@test Components.has_free_final_time(ocp) == true

        # -------------------------------------------------------------------------- #
        # ocp with free initial time and fixed final time
        times = Components.TimesModel(
            Components.FreeTimeModel(1, "t₀"), Components.FixedTimeModel(10.0, "t_f"), "t"
        )
        ocp = Models.Model{Components.NonAutonomous}(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )

        # tests on times
        Test.@test Components.initial_time(ocp, [0.0, 10.0]) == 0.0
        Test.@test Components.final_time(ocp) == 10.0
        Test.@test Components.time_name(ocp) == "t"
        Test.@test Components.initial_time_name(ocp) == "t₀"
        Test.@test Components.final_time_name(ocp) == "t_f"
        Test.@test Components.has_fixed_initial_time(ocp) == false
        Test.@test Components.has_fixed_final_time(ocp) == true
        Test.@test Components.has_free_initial_time(ocp) == true
        Test.@test Components.has_free_final_time(ocp) == false

        # -------------------------------------------------------------------------- #
        # ocp with Lagrange objective
        objective = Components.LagrangeObjectiveModel(lagrange_user, :max)
        ocp = Models.Model{Components.NonAutonomous}(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )

        # print (captured, no terminal output)
        io = IOBuffer()
        show(io, MIME"text/plain"(), ocp)

        # tests on objective
        Test.@test Models.objective(ocp) == objective
        Test.@test Components.criterion(ocp) == :max
        Test.@test Components.has_mayer_cost(ocp) == false
        Test.@test Components.has_lagrange_cost(ocp) == true

        # tests on lagrange
        lagrange = Components.lagrange(ocp)
        Test.@test lagrange(t, x, u, v) == lagrange_user(t, x, u, v)

        # -------------------------------------------------------------------------- #
        # ocp with both Mayer and Lagrange objective, that is Bolza objective
        objective = Components.BolzaObjectiveModel(mayer_user, lagrange, :min)
        ocp = Models.Model{Components.NonAutonomous}(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )

        # tests on objective
        Test.@test Models.objective(ocp) == objective
        Test.@test Components.criterion(ocp) == :min
        Test.@test Components.has_mayer_cost(ocp) == true
        Test.@test Components.has_lagrange_cost(ocp) == true

        # -------------------------------------------------------------------------- #
        # Just for printing
        #
        times = Components.TimesModel(
            Components.FreeTimeModel(1, "a"), Components.FreeTimeModel(2, "b"), "s"
        )
        state = Components.StateModel("y", ["y"])
        control = Components.ControlModel("u", ["u"])
        variable = Components.VariableModel("v", ["v"])
        dynamics = dynamics_user!
        objective = Components.MayerObjectiveModel(mayer_user, :min)
        pre_constraints = Components.ConstraintsDictType()
        constraints = Building.build(pre_constraints)
        definition = Components.EmptyDefinition()
        ocp = Models.Model{Components.NonAutonomous}(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )
        io = IOBuffer()
        show(io, MIME"text/plain"(), ocp)

        #
        times = Components.TimesModel(
            Components.FreeTimeModel(1, "a"), Components.FreeTimeModel(2, "b"), "s"
        )
        state = Components.StateModel("y", ["q", "p"])
        control = Components.ControlModel("u", ["w", "z"])
        variable = Components.VariableModel("v", ["c", "d"])
        dynamics = dynamics_user!
        objective = Components.MayerObjectiveModel(mayer_user, :min)
        pre_constraints = Components.ConstraintsDictType()
        constraints = Building.build(pre_constraints)
        definition = Components.EmptyDefinition()
        ocp = Models.Model{Components.NonAutonomous}(
            times,
            state,
            control,
            variable,
            dynamics,
            objective,
            constraints,
            definition,
            build_examodel,
        )
        io = IOBuffer()
        show(io, MIME"text/plain"(), ocp)
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_ocp() = TestOCP.test_ocp()
