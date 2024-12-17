function test_ocp()
    @test isconcretetype(CTModels.PreModel)

    # dimensions
    n = 2 # state dimension
    m = 2 # control dimension
    q = 2 # variable dimension

    # functions
    mayer_user!(x0, xf, v) = sum(xf .- x0 .- v)
    lagrange_user!(t, x, u, v) = sum(x .+ u .+ v .+ t)
    dynamics_user!(r, t, x, u, v) = r .= x .+ u .+ v .+ t

    # points
    x0 = [1.0, 2.0]
    xf = [3.0, 4.0]
    v = [5.0, 6.0]
    t = 7.0
    x = [8.0, 9.0]
    u = [10.0, 11.0]

    # models
    times = CTModels.TimesModel(
        CTModels.FreeTimeModel(1, "t₀"), CTModels.FreeTimeModel(2, "t_f"), "t"
    )
    state = CTModels.StateModel("y", ["y₁", "y₂"])
    control = CTModels.ControlModel("u", ["u₁", "u₂"])
    variable = CTModels.VariableModel("v", ["v₁", "v₂"])
    dynamics = dynamics_user!
    objective = CTModels.MayerObjectiveModel(mayer_user!, :min)
    pre_constraints = CTModels.ConstraintsDictType()

    # add some constraints:
    # - path constraint: one of dimension 2, and another of dimension 1
    # - boundary constraint: one of dimension 2, and another of dimension 1
    # - variable nonlinear (function) constraint: one of dimension 2, and another of dimension 1
    # - state box constraint: one of dimension 2, and another of dimension 1
    # - control box constraint: one of dimension 2, and another of dimension 1
    # - variable box constraint: one of dimension 2, and another of dimension 1

    # path constraint
    f_path_a(r, t, x, u, v) = r .= x .+ u .+ v .+ t
    CTModels.__constraint!(pre_constraints, :path, n, m, q; f=f_path_a, lb=[0, 1], ub=[1, 2])
    f_path_b(r, t, x, u, v) = r .= x[1] + u[1] + v[1] + t
    CTModels.__constraint!(pre_constraints, :path, n, m, q; f=f_path_b, lb=[3], ub=[3])

    # boundary constraint
    f_boundary_a(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)
    CTModels.__constraint!(
        pre_constraints, :boundary, n, m, q; f=f_boundary_a, lb=[0, 1], ub=[1, 2]
    )
    f_boundary_b(r, x0, xf, v) = r .= x0[1] - 1.0 + v[1] * (xf[1] - x0[1])
    CTModels.__constraint!(pre_constraints, :boundary, n, m, q; f=f_boundary_b, lb=[3], ub=[3])

    # variable constraint
    f_variable_a(r, v) = r .= 2v
    CTModels.__constraint!(
        pre_constraints, :variable, n, m, q; f=f_variable_a, lb=[0, 1], ub=[1, 2]
    )
    f_variable_b(r, v) = r .= v[1] - 1.0
    CTModels.__constraint!(pre_constraints, :variable, n, m, q; f=f_variable_b, lb=[3], ub=[3])

    # state box constraint
    CTModels.__constraint!(pre_constraints, :state, n, m, q; lb=[0, 1], ub=[1, 2])
    CTModels.__constraint!(pre_constraints, :state, n, m, q; rg=1:1, lb=[3], ub=[3])

    # control box constraint
    CTModels.__constraint!(pre_constraints, :control, n, m, q; lb=[0, 1], ub=[1, 2])
    CTModels.__constraint!(pre_constraints, :control, n, m, q; rg=1:1, lb=[3], ub=[3])

    # variable box constraint
    CTModels.__constraint!(pre_constraints, :variable, n, m, q; lb=[0, 1], ub=[1, 2])
    CTModels.__constraint!(pre_constraints, :variable, n, m, q; rg=1:1, lb=[3], ub=[3])

    # build constraints
    constraints = CTModels.build_constraints(pre_constraints)

    # Model definition
    definition = quote
        t ∈ [0, 1], time
        x ∈ R², state
        u ∈ R, control
        x(0) == [-1, 0]
        x(1) == [0, 0]
        ẋ(t) == [x₂(t), u(t)]
        ∫(0.5u(t)^2) → min
    end

    # concrete ocp
    ocp = CTModels.Model(
        times, state, control, variable, dynamics, objective, constraints, definition
    )

    # print
    display(ocp)

    # tests on times
    @test CTModels.initial_time(ocp, [0.0, 10.0]) == 0.0
    @test CTModels.final_time(ocp, [0.0, 10.0]) == 10.0
    @test CTModels.time_name(ocp) == "t"
    @test CTModels.initial_time_name(ocp) == "t₀"
    @test CTModels.final_time_name(ocp) == "t_f"
    @test CTModels.has_fixed_initial_time(ocp) == false
    @test CTModels.has_fixed_final_time(ocp) == false
    @test CTModels.has_free_initial_time(ocp) == true
    @test CTModels.has_free_final_time(ocp) == true

    # tests on state
    @test CTModels.state_dimension(ocp) == 2
    @test CTModels.state_name(ocp) == "y"
    @test CTModels.state_components(ocp) == ["y₁", "y₂"]

    # tests on control
    @test CTModels.control_dimension(ocp) == 2
    @test CTModels.control_name(ocp) == "u"
    @test CTModels.control_components(ocp) == ["u₁", "u₂"]

    # tests on variable
    @test CTModels.variable_dimension(ocp) == 2
    @test CTModels.variable_name(ocp) == "v"
    @test CTModels.variable_components(ocp) == ["v₁", "v₂"]

    # tests on dynamics
    r = zeros(Float64, 2)
    r_user = zeros(Float64, 2)
    dynamics! = CTModels.dynamics(ocp)
    dynamics!(r, t, x, u, v)
    dynamics_user!(r_user, t, x, u, v)
    @test r == r_user

    # tests on objective
    @test CTModels.objective(ocp) == objective
    @test CTModels.criterion(ocp) == :min
    @test CTModels.has_mayer_cost(ocp) == true
    @test CTModels.has_lagrange_cost(ocp) == false

    # tests on mayer
    mayer! = CTModels.mayer(ocp)
    @test mayer!(x0, xf, v) == mayer_user!(x0, xf, v)
    @test_throws CTBase.UnauthorizedCall CTModels.lagrange(ocp)

    # tests on constraints
    # dimensions: path, boundary, variable (nonlinear), state, control, variable (box)
    @test CTModels.dim_path_constraints_nl(ocp) == 3
    @test CTModels.dim_boundary_constraints_nl(ocp) == 3
    @test CTModels.dim_variable_constraints_nl(ocp) == 3
    @test CTModels.dim_state_constraints_box(ocp) == 3
    @test CTModels.dim_control_constraints_box(ocp) == 3
    @test CTModels.dim_variable_constraints_box(ocp) == 3

    # Get all constraints and test. Be careful, the order is not guaranteed. 
    # We will check up to permutations by sorting the results.
    (path_cons_nl_lb, path_cons_nl!, path_cons_nl_ub) = CTModels.path_constraints_nl(ocp)
    (variable_cons_nl_lb, variable_cons_nl!, variable_cons_nl_ub) = CTModels.variable_constraints_nl(ocp)
    (boundary_cons_nl_lb, boundary_cons_nl!, boundary_cons_nl_ub) = CTModels.boundary_constraints_nl(ocp)
    (state_cons_box_lb, state_cons_box_ind, state_cons_box_ub) = CTModels.state_constraints_box(ocp)
    (control_cons_box_lb, control_cons_box_ind, control_cons_box_ub) = CTModels.control_constraints_box(ocp)
    (variable_cons_box_lb, variable_cons_box_ind, variable_cons_box_ub) = CTModels.variable_constraints_box(ocp)

    # path constraints
    @test sort(path_cons_nl_lb) == [0, 1, 3]
    @test sort(path_cons_nl_ub) == [1, 2, 3]
    ra = zeros(Float64, 2)
    rb = zeros(Float64, 1)
    f_path_a(ra, t, x, u, v)
    f_path_b(rb, t, x, u, v)
    r = zeros(Float64, 3)
    path_cons_nl!(r, t, x, u, v)
    @test sort(r) == sort([ra; rb])

    # boundary constraints
    @test sort(boundary_cons_nl_lb) == [0, 1, 3]
    @test sort(boundary_cons_nl_ub) == [1, 2, 3]
    ra = zeros(Float64, 2)
    rb = zeros(Float64, 1)
    f_boundary_a(ra, x0, xf, v)
    f_boundary_b(rb, x0, xf, v)
    r = zeros(Float64, 3)
    boundary_cons_nl!(r, x0, xf, v)
    @test sort(r) == sort([ra; rb])

    # variable constraints
    @test sort(variable_cons_nl_lb) == [0, 1, 3]
    @test sort(variable_cons_nl_ub) == [1, 2, 3]
    ra = zeros(Float64, 2)
    rb = zeros(Float64, 1)
    f_variable_a(ra, v)
    f_variable_b(rb, v)
    r = zeros(Float64, 3)
    variable_cons_nl!(r, v)
    @test sort(r) == sort([ra; rb])

    # state box constraints
    @test sort(state_cons_box_lb) == [0, 1, 3]
    @test sort(state_cons_box_ub) == [1, 2, 3]
    @test sort(state_cons_box_ind) == [1, 1, 2]

    # control box constraints
    @test sort(control_cons_box_lb) == [0, 1, 3]
    @test sort(control_cons_box_ub) == [1, 2, 3]
    @test sort(control_cons_box_ind) == [1, 1, 2]

    # variable box constraints
    @test sort(variable_cons_box_lb) == [0, 1, 3]
    @test sort(variable_cons_box_ub) == [1, 2, 3]
    @test sort(variable_cons_box_ind) == [1, 1, 2]

    # -------------------------------------------------------------------------- #
    # ocp with fixed times
    times = CTModels.TimesModel(
        CTModels.FixedTimeModel(0.0, "t₀"), CTModels.FixedTimeModel(10.0, "t_f"), "t"
    )
    ocp = CTModels.Model(
        times, state, control, variable, dynamics, objective, constraints, definition
    )

    # tests on times
    @test CTModels.initial_time(ocp) == 0.0
    @test CTModels.final_time(ocp) == 10.0
    @test CTModels.time_name(ocp) == "t"
    @test CTModels.initial_time_name(ocp) == "t₀"
    @test CTModels.final_time_name(ocp) == "t_f"
    @test CTModels.has_fixed_initial_time(ocp) == true
    @test CTModels.has_fixed_final_time(ocp) == true
    @test CTModels.has_free_initial_time(ocp) == false
    @test CTModels.has_free_final_time(ocp) == false

    # -------------------------------------------------------------------------- #
    # ocp with fixed initial time and free final time
    times = CTModels.TimesModel(
        CTModels.FixedTimeModel(0.0, "t₀"), CTModels.FreeTimeModel(1, "t_f"), "t"
    )
    ocp = CTModels.Model(
        times, state, control, variable, dynamics, objective, constraints, definition
    )

    # tests on times
    @test CTModels.initial_time(ocp) == 0.0
    @test CTModels.final_time(ocp, [2.0, 50.0]) == 2.0
    @test CTModels.time_name(ocp) == "t"
    @test CTModels.initial_time_name(ocp) == "t₀"
    @test CTModels.final_time_name(ocp) == "t_f"
    @test CTModels.has_fixed_initial_time(ocp) == true
    @test CTModels.has_fixed_final_time(ocp) == false
    @test CTModels.has_free_initial_time(ocp) == false
    @test CTModels.has_free_final_time(ocp) == true

    # -------------------------------------------------------------------------- #
    # ocp with free initial time and fixed final time
    times = CTModels.TimesModel(
        CTModels.FreeTimeModel(1, "t₀"), CTModels.FixedTimeModel(10.0, "t_f"), "t"
    )
    ocp = CTModels.Model(
        times, state, control, variable, dynamics, objective, constraints, definition
    )

    # tests on times
    @test CTModels.initial_time(ocp, [0.0, 10.0]) == 0.0
    @test CTModels.final_time(ocp) == 10.0
    @test CTModels.time_name(ocp) == "t"
    @test CTModels.initial_time_name(ocp) == "t₀"
    @test CTModels.final_time_name(ocp) == "t_f"
    @test CTModels.has_fixed_initial_time(ocp) == false
    @test CTModels.has_fixed_final_time(ocp) == true
    @test CTModels.has_free_initial_time(ocp) == true
    @test CTModels.has_free_final_time(ocp) == false

    # -------------------------------------------------------------------------- #
    # ocp with Lagrange objective
    objective = CTModels.LagrangeObjectiveModel(lagrange_user!, :max)
    ocp = CTModels.Model(
        times, state, control, variable, dynamics, objective, constraints, definition
    )

    # tests on objective
    @test CTModels.objective(ocp) == objective
    @test CTModels.criterion(ocp) == :max
    @test CTModels.has_mayer_cost(ocp) == false
    @test CTModels.has_lagrange_cost(ocp) == true

    # tests on lagrange
    lagrange! = CTModels.lagrange(ocp)
    @test lagrange!(t, x, u, v) == lagrange_user!(t, x, u, v)
    @test_throws CTBase.UnauthorizedCall CTModels.mayer(ocp)

    # -------------------------------------------------------------------------- #
    # ocp with both Mayer and Lagrange objective, that is Bolza objective
    objective = CTModels.BolzaObjectiveModel(mayer_user!, lagrange, :min)
    ocp = CTModels.Model(
        times, state, control, variable, dynamics, objective, constraints, definition
    )

    # tests on objective
    @test CTModels.objective(ocp) == objective
    @test CTModels.criterion(ocp) == :min
    @test CTModels.has_mayer_cost(ocp) == true
    @test CTModels.has_lagrange_cost(ocp) == true
end
