function test_ocp()
    
    @test isconcretetype(CTModels.OptimalControlModelMutable)
    @test all_concrete(CTModels.OptimalControlModel)

    # dimensions
    n = 2 # state dimension
    m = 2 # control dimension
    q = 2 # variable dimension

    # functions
    mayer_user!(r, x0, xf, v) = r .= [0.0]
    lagrange_user!(r, t, x, u, v) = r .= [0.0]
    dynamics_user!(r, t, x, u, v) = r .= [0.0; 0.0]

    # points
    x0 = [0.0, 0.0]
    xf = [0.0, 0.0]
    v = [0.0, 0.0]
    t = 0.0
    x = [0.0, 0.0]
    u = [0.0, 0.0]

    # models
    times = CTModels.TimesModel(CTModels.FreeTimeModel(1, "t₀"), CTModels.FreeTimeModel(2, "t_f"), "t")
    state = CTModels.StateModel("y", ["y₁", "y₂"])
    control = CTModels.ControlModel("u", ["u₁", "u₂"])
    variable = CTModels.VariableModel("v", ["v₁", "v₂"])
    dynamics = dynamics_user!
    objective = CTModels.MayerObjectiveModel(mayer_user!, :min)

    # concrete ocp
    ocp = CTModels.OptimalControlModel(times, state, control, variable, dynamics, objective)

    # tests on times
    @test CTModels.times(ocp) == times
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
    @test CTModels.state(ocp) == state
    @test CTModels.state_dimension(ocp) == 2
    @test CTModels.state_name(ocp) == "y"
    @test CTModels.state_components(ocp) == ["y₁", "y₂"]

    # tests on control
    @test CTModels.control(ocp) == control
    @test CTModels.control_dimension(ocp) == 2
    @test CTModels.control_name(ocp) == "u"
    @test CTModels.control_components(ocp) == ["u₁", "u₂"]

    # tests on variable
    @test CTModels.variable(ocp) == variable
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
    r = zeros(Float64, 1)
    r_user = zeros(Float64, 1)
    mayer! = CTModels.mayer(ocp)
    mayer!(r, x0, xf, v)
    mayer_user!(r_user, x0, xf, v)
    @test r == r_user
    @test_throws CTBase.UnauthorizedCall CTModels.lagrange(ocp)

    # -------------------------------------------------------------------------- #
    # ocp with fixed times
    times = CTModels.TimesModel(CTModels.FixedTimeModel(0.0, "t₀"), CTModels.FixedTimeModel(10.0, "t_f"), "t")
    ocp = CTModels.OptimalControlModel(times, state, control, variable, dynamics, objective)

    # tests on times
    @test CTModels.times(ocp) == times
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
    times = CTModels.TimesModel(CTModels.FixedTimeModel(0.0, "t₀"), CTModels.FreeTimeModel(1, "t_f"), "t")
    ocp = CTModels.OptimalControlModel(times, state, control, variable, dynamics, objective)

    # tests on times
    @test CTModels.times(ocp) == times
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
    times = CTModels.TimesModel(CTModels.FreeTimeModel(1, "t₀"), CTModels.FixedTimeModel(10.0, "t_f"), "t")
    ocp = CTModels.OptimalControlModel(times, state, control, variable, dynamics, objective)

    # tests on times
    @test CTModels.times(ocp) == times
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
    ocp = CTModels.OptimalControlModel(times, state, control, variable, dynamics, objective)

    # tests on objective
    @test CTModels.objective(ocp) == objective
    @test CTModels.criterion(ocp) == :max
    @test CTModels.has_mayer_cost(ocp) == false
    @test CTModels.has_lagrange_cost(ocp) == true

    # tests on lagrange
    r = zeros(Float64, 1)
    r_user = zeros(Float64, 1)
    lagrange! = CTModels.lagrange(ocp)
    lagrange!(r, t, x, u, v)
    lagrange_user!(r_user, t, x, u, v)
    @test r == r_user
    @test_throws CTBase.UnauthorizedCall CTModels.mayer(ocp)

    # -------------------------------------------------------------------------- #
    # ocp with both Mayer and Lagrange objective, that is Bolza objective
    objective = CTModels.BolzaObjectiveModel(mayer_user!, lagrange, :min)
    ocp = CTModels.OptimalControlModel(times, state, control, variable, dynamics, objective)

    # tests on objective
    @test CTModels.objective(ocp) == objective
    @test CTModels.criterion(ocp) == :min
    @test CTModels.has_mayer_cost(ocp) == true
    @test CTModels.has_lagrange_cost(ocp) == true

end