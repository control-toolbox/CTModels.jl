function test_export_import()
    ocp, sol = solution_example()

    # JSON
    CTModels.export_ocp_solution(sol; filename_prefix="solution_test", format=:JSON)
    sol_reloaded = CTModels.import_ocp_solution(
        ocp; filename_prefix="solution_test", format=:JSON
    )
    @test sol.objective == sol_reloaded.objective

    # JLD
    CTModels.export_ocp_solution(sol; filename_prefix="solution_test", format=:JLD)
    sol_reloaded = CTModels.import_ocp_solution(
        ocp; filename_prefix="solution_test", format=:JLD
    )
    @test sol.objective == sol_reloaded.objective
end
