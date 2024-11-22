function test_ocp()
    
    @test isconcretetype(CTModels.OptimalControlModelMutable)
    @test all_concrete(CTModels.OptimalControlModel)

    # times
    times = CTModels.TimesModel(CTModels.FreeTimeModel(1, "t₀"), CTModels.FreeTimeModel(2, "t_f"), "t")

    # control
    control = CTModels.ControlModel("u", SA["u₁", "u₂"])

    # state 
    state = CTModels.StateModel("y", SA["y₁", "y₂"])

    # variable
    variable = CTModels.VariableModel("v", SA["v₁", "v₂"])

    # concrete ocp
    ocp = CTModels.OptimalControlModel(times, state, control, variable)

    # tests on times
    @test CTModels.times(ocp) == times
    @test CTModels.initial_time(ocp, [0.0, 10.0]) == 0.0
    @test CTModels.final_time(ocp, [0.0, 10.0]) == 10.0
    @test CTModels.time_name(ocp) == "t"
    @test CTModels.initial_time_name(ocp) == "t₀"
    @test CTModels.final_time_name(ocp) == "t_f"

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

end