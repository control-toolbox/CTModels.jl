function test_ext_exceptions()
    ocp, sol, pre_ocp = solution_example()

    # export
    @test_throws CTBase.IncorrectArgument CTModels.export_ocp_solution(sol; format=:dummy)
    @test_throws CTBase.ExtensionError CTModels.export_ocp_solution(sol; format=:JSON)
    @test_throws CTBase.ExtensionError CTModels.export_ocp_solution(sol; format=:JLD)
    @test_throws MethodError CTModels.export_ocp_solution()

    # import
    @test_throws CTBase.IncorrectArgument CTModels.import_ocp_solution(ocp; format=:dummy)
    @test_throws CTBase.ExtensionError CTModels.import_ocp_solution(ocp; format=:JSON)
    @test_throws CTBase.ExtensionError CTModels.import_ocp_solution(ocp; format=:JLD)
    @test_throws MethodError CTModels.import_ocp_solution()

    # plot
    @test_throws CTBase.ExtensionError CTModels.plot(sol)
    @test_throws MethodError CTModels.plot(sol, 1)
end
