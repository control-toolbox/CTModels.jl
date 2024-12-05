function test_state()

    #
    @test isconcretetype(CTModels.StateModel)

    # StateModel
    state = CTModels.StateModel("y", ["u", "v"])
    @test CTModels.dimension(state) == 2
    @test CTModels.name(state) == "y"
    @test CTModels.components(state) == ["u", "v"]

    # some checkings
    ocp = CTModels.OptimalControlModelMutable()
    @test isnothing(ocp.state)
    @test !CTModels.__is_state_set(ocp)
    CTModels.state!(ocp, 1)
    @test CTModels.__is_state_set(ocp)

    # state!
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    @test CTModels.dimension(ocp.state) == 1
    @test CTModels.name(ocp.state) == "x"
    @test CTModels.components(ocp.state) == ["x"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1, "y")
    @test CTModels.dimension(ocp.state) == 1
    @test CTModels.name(ocp.state) == "y"
    @test CTModels.components(ocp.state) == ["y"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 2)
    @test CTModels.dimension(ocp.state) == 2
    @test CTModels.name(ocp.state) == "x"
    @test CTModels.components(ocp.state) == ["x₁", "x₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 2, :y)
    @test CTModels.dimension(ocp.state) == 2
    @test CTModels.name(ocp.state) == "y"
    @test CTModels.components(ocp.state) == ["y₁", "y₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 2, "y", ["u", "v"])
    @test CTModels.dimension(ocp.state) == 2
    @test CTModels.name(ocp.state) == "y"
    @test CTModels.components(ocp.state) == ["u", "v"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 2, "y", [:u, :v])
    @test CTModels.dimension(ocp.state) == 2
    @test CTModels.name(ocp.state) == "y"
    @test CTModels.components(ocp.state) == ["u", "v"]

    # set twice
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.state!(ocp, 1)

    # wrong number of components
    ocp = CTModels.OptimalControlModelMutable()
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 2, "y", ["u"])

end