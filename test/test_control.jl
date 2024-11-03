function test_control()

    #
    @test isconcretetype(CTModels.ControlModel)

    # ControlModel
    control = CTModels.ControlModel(2, "u", ["u₁", "u₂"])
    @test CTModels.dimension(control) == 2
    @test CTModels.name(control) == "u"
    @test CTModels.components(control) == ["u₁", "u₂"]

    # control!
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 1)
    @test CTModels.control_dimension(ocp) == 1
    @test CTModels.control_name(ocp) == "u"
    @test CTModels.control_components(ocp) == ["u"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 1, "v")
    @test CTModels.control_dimension(ocp) == 1
    @test CTModels.control_name(ocp) == "v"

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 2)
    @test CTModels.control_dimension(ocp) == 2
    @test CTModels.control_name(ocp) == "u"
    @test CTModels.control_components(ocp) == ["u₁", "u₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 2, :v)
    @test CTModels.control_dimension(ocp) == 2
    @test CTModels.control_name(ocp) == "v"
    @test CTModels.control_components(ocp) == ["v₁", "v₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 2, "v", ["a", "b"])
    @test CTModels.control_dimension(ocp) == 2
    @test CTModels.control_name(ocp) == "v"
    @test CTModels.control_components(ocp) == ["a", "b"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 2, "v", [:a, :b])
    @test CTModels.control_dimension(ocp) == 2
    @test CTModels.control_name(ocp) == "v"
    @test CTModels.control_components(ocp) == ["a", "b"]

    # set twice
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.control!(ocp, 1)

    # wrong number of components
    ocp = CTModels.OptimalControlModelMutable()
    @test_throws CTBase.IncorrectArgument CTModels.control!(ocp, 2, "v", ["a"])

end