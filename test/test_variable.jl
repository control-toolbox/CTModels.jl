function test_variable()

    #
    @test isconcretetype(CTModels.VariableModel{2})

    # VariableModel
    variable = CTModels.VariableModel("v", SA["v₁", "v₂"])
    @test CTModels.dimension(variable) == 2
    @test CTModels.name(variable) == "v"
    @test CTModels.components(variable) == ["v₁", "v₂"]

    # some checkings
    ocp = CTModels.OptimalControlModelMutable()
    @test ocp.variable isa CTModels.EmptyVariableModel
    @test !CTModels.__is_variable_set(ocp)
    CTModels.variable!(ocp, 1)
    @test CTModels.__is_variable_set(ocp)

    # variable!
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 1)
    @test CTModels.dimension(ocp.variable) == 1
    @test CTModels.name(ocp.variable) == "v"
    @test CTModels.components(ocp.variable) == ["v"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 1, "w")
    @test CTModels.dimension(ocp.variable) == 1
    @test CTModels.name(ocp.variable) == "w"
    @test CTModels.components(ocp.variable) == ["w"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 2)
    @test CTModels.dimension(ocp.variable) == 2
    @test CTModels.name(ocp.variable) == "v"
    @test CTModels.components(ocp.variable) == ["v₁", "v₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 2, :w)
    @test CTModels.dimension(ocp.variable) == 2
    @test CTModels.name(ocp.variable) == "w"
    @test CTModels.components(ocp.variable) == ["w₁", "w₂"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 2, "w", ["a", "b"])
    @test CTModels.dimension(ocp.variable) == 2
    @test CTModels.name(ocp.variable) == "w"
    @test CTModels.components(ocp.variable) == ["a", "b"]

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 2, "w", [:a, :b])
    @test CTModels.dimension(ocp.variable) == 2
    @test CTModels.name(ocp.variable) == "w"
    @test CTModels.components(ocp.variable) == ["a", "b"]

    # set twice
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.variable!(ocp, 1)

    # wrong number of components
    ocp = CTModels.OptimalControlModelMutable()
    @test_throws CTBase.IncorrectArgument CTModels.variable!(ocp, 2, "w", ["a"])

end