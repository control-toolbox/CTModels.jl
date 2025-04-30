function test_ext_exceptions()

    @test_throws CTBase.IncorrectArgument CTModels.export_ocp_solution(format=:dummy)
    @test_throws CTBase.ExtensionError CTModels.export_ocp_solution(format=:JSON)
    @test_throws CTBase.ExtensionError CTModels.export_ocp_solution(format=:JLD)

    @test_throws CTBase.IncorrectArgument CTModels.import_ocp_solution(format=:dummy)
    @test_throws CTBase.ExtensionError CTModels.import_ocp_solution(format=:JSON)
    @test_throws CTBase.ExtensionError CTModels.import_ocp_solution(format=:JLD)

    ocp, sol, pre_ocp = solution_example()
    @test_throws CTBase.ExtensionError CTModels.plot(sol)

end