using JLD2
using JSON3

function test_export_import()

    #
    ocp, sol = solution_example()

    # JSON
    CTModels.export_ocp_solution(sol; filename="solution_test", format=:JSON)
    sol_reloaded = CTModels.import_ocp_solution(ocp; filename="solution_test", format=:JSON)
    @test sol.objective ≈ sol_reloaded.objective atol=1e-8

    # JLD
    CTModels.export_ocp_solution(sol; filename="solution_test") # default is :JLD)
    sol_reloaded = CTModels.import_ocp_solution(ocp; filename="solution_test", format=:JLD)
    @test sol.objective ≈ sol_reloaded.objective atol=1e-8

    #
    ocp, sol = solution_example(; fun=true)

    # JSON
    CTModels.export_ocp_solution(sol; filename="solution_test", format=:JSON)
    sol_reloaded = CTModels.import_ocp_solution(ocp; filename="solution_test", format=:JSON)
    @test sol.objective ≈ sol_reloaded.objective atol=1e-8

    # JLD
    CTModels.export_ocp_solution(sol; filename="solution_test", format=:JLD)
    sol_reloaded = CTModels.import_ocp_solution(ocp; filename="solution_test", format=:JLD)
    @test sol.objective ≈ sol_reloaded.objective atol=1e-8

    # --------------------------------------------------------------------------------------
    # Other problem
    ocp = @def begin
        t ∈ [0, 1], time
        x ∈ R², state
        u ∈ R, control
        x₂(t) ≤ 1.2
        x(0) == [-1, 0]
        x(1) == [0, 0]
        ẋ(t) == [x₂(t), u(t)]
        ∫(0.5u(t)^2) → min
    end;

    sol = CTDirect.solve(ocp)

    # JLD
    CTModels.export_ocp_solution(sol; filename="solution_test")
    sol_reloaded = CTModels.import_ocp_solution(ocp; filename="solution_test")
    @test sol.objective ≈ sol_reloaded.objective atol=1e-8

    # JSON
    CTModels.export_ocp_solution(sol; filename="solution_test", format=:JSON)
    sol_reloaded = CTModels.import_ocp_solution(ocp; filename="solution_test", format=:JSON)
    @test sol.objective ≈ sol_reloaded.objective atol=1e-8
end
