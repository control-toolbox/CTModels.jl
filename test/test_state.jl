function test_state()

    #
    @test isconcretetype(CTModels.StateModel)

    # StateModel
    state = CTModels.StateModel(2, "y", ["u", "v"])
    @test CTModels.dimension(state) == 2
    @test CTModels.name(state) == "y"
    @test CTModels.components(state) == ["u", "v"]

    # state!
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    @test CTModels.state_dimension(ocp) == 1
    @test CTModels.state_name(ocp) == "x"
    @test CTModels.state_components(ocp) == ["x"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1, "y")
    @test CTModels.state_dimension(ocp) == 1
    @test CTModels.state_name(ocp) == "y"
    @test CTModels.state_components(ocp) == ["y"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 2)
    @test CTModels.state_dimension(ocp) == 2
    @test CTModels.state_name(ocp) == "x"
    @test CTModels.state_components(ocp) == ["x₁", "x₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 2, :y)
    @test CTModels.state_dimension(ocp) == 2
    @test CTModels.state_name(ocp) == "y"
    @test CTModels.state_components(ocp) == ["y₁", "y₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 2, "y", ["u", "v"])
    @test CTModels.state_dimension(ocp) == 2
    @test CTModels.state_name(ocp) == "y"
    @test CTModels.state_components(ocp) == ["u", "v"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 2, "y", [:u, :v])
    @test CTModels.state_dimension(ocp) == 2
    @test CTModels.state_name(ocp) == "y"
    @test CTModels.state_components(ocp) == ["u", "v"]

    # set twice
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.state!(ocp, 1)

    # wrong number of components
    ocp = CTModels.OptimalControlModelMutable()
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 2, "y", ["u"])

end