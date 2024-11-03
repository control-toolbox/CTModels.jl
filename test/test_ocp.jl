function test_ocp()
    
    @test isconcretetype(CTModels.OptimalControlModelMutable)
    @test all_concrete(CTModels.OptimalControlModel)

    # control
    control = CTModels.ControlModel(2, "u", ["u₁", "u₂"])

    # state 
    state = CTModels.StateModel(2, "y", ["y₁", "y₂"])

    # concrete ocp
    ocp = CTModels.OptimalControlModel(control, state)

    # tests
    #@test CTModels.control(ocp) == control
    @test CTModels.state(ocp) == state

end