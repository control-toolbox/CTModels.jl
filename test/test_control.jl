function test_control()

    #
    @test isconcretetype(CTModels.ControlModel)

    # ControlModel
    control = CTModels.ControlModel("u", ["u₁", "u₂"])
    @test CTModels.dimension(control) == 2
    @test CTModels.name(control) == "u"
    @test CTModels.components(control) == ["u₁", "u₂"]

    # some checkings
    ocp = CTModels.OptimalControlModelMutable()
    @test isnothing(ocp.control)
    @test !CTModels.__is_control_set(ocp)
    CTModels.control!(ocp, 1)
    @test CTModels.__is_control_set(ocp)

    # control!
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 1)
    @test CTModels.dimension(ocp.control) == 1
    @test CTModels.name(ocp.control) == "u"
    @test CTModels.components(ocp.control) == ["u"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 1, "v")
    @test CTModels.dimension(ocp.control) == 1
    @test CTModels.name(ocp.control) == "v"

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 2)
    @test CTModels.dimension(ocp.control) == 2
    @test CTModels.name(ocp.control) == "u"
    @test CTModels.components(ocp.control) == ["u₁", "u₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 2, :v)
    @test CTModels.dimension(ocp.control) == 2
    @test CTModels.name(ocp.control) == "v"
    @test CTModels.components(ocp.control) == ["v₁", "v₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 2, "v", ["a", "b"])
    @test CTModels.dimension(ocp.control) == 2
    @test CTModels.name(ocp.control) == "v"
    @test CTModels.components(ocp.control) == ["a", "b"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 2, "v", [:a, :b])
    @test CTModels.dimension(ocp.control) == 2
    @test CTModels.name(ocp.control) == "v"
    @test CTModels.components(ocp.control) == ["a", "b"]

    # set twice
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.control!(ocp, 1)

    # wrong number of components
    ocp = CTModels.OptimalControlModelMutable()
    @test_throws CTBase.IncorrectArgument CTModels.control!(ocp, 2, "v", ["a"])
end
