"""
Tests for extract_solver_infos function
"""

using Test
using CTModels
using SolverCore
using NLPModels
using MadNLP
using ADNLPModels

# Mock execution statistics for testing generic stats
mutable struct MockExecutionStats <: SolverCore.AbstractExecutionStats
    objective::Float64
    iter::Int
    primal_feas::Float64
    status::Symbol
end

# Mock NLP model for testing - using ADNLPModel as a simple concrete model
function create_mock_nlp(minimize::Bool)
    return ADNLPModel(x -> x[1]^2, [1.0]; minimize=minimize)
end

function test_extract_solver_infos()
    @testset "extract_solver_infos" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ============================================================================
        # UNIT TESTS
        # ============================================================================

        @testset "Generic method - API contract" begin
            
            @testset "first_order status (success)" begin
                nlp_solution = MockExecutionStats(1.23, 15, 1.0e-6, :first_order)
                nlp = create_mock_nlp(true)
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(nlp_solution, NLPModels.get_minimize(nlp))
                
                @test obj ≈ 1.23
                @test iter == 15
                @test viol ≈ 1.0e-6
                @test msg == "Ipopt/generic"
                @test stat == :first_order
                @test success == true
            end

            @testset "acceptable status (success)" begin
                nlp_solution = MockExecutionStats(2.34, 20, 1.0e-5, :acceptable)
                nlp = create_mock_nlp(true)
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(nlp_solution, NLPModels.get_minimize(nlp))
                
                @test obj ≈ 2.34
                @test iter == 20
                @test viol ≈ 1.0e-5
                @test msg == "Ipopt/generic"
                @test stat == :acceptable
                @test success == true
            end

            @testset "failure status - max_iter" begin
                nlp_solution = MockExecutionStats(3.45, 100, 1.0e-3, :max_iter)
                nlp = create_mock_nlp(true)
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(nlp_solution, NLPModels.get_minimize(nlp))
                
                @test obj ≈ 3.45
                @test iter == 100
                @test viol ≈ 1.0e-3
                @test msg == "Ipopt/generic"
                @test stat == :max_iter
                @test success == false
            end

            @testset "failure status - infeasible" begin
                nlp_solution = MockExecutionStats(4.56, 50, 1.0, :infeasible)
                nlp = create_mock_nlp(true)
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(nlp_solution, NLPModels.get_minimize(nlp))
                
                @test obj ≈ 4.56
                @test iter == 50
                @test viol ≈ 1.0
                @test msg == "Ipopt/generic"
                @test stat == :infeasible
                @test success == false
            end

            @testset "failure status - unknown" begin
                nlp_solution = MockExecutionStats(5.67, 10, 0.5, :unknown)
                nlp = create_mock_nlp(true)
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(nlp_solution, NLPModels.get_minimize(nlp))
                
                @test obj ≈ 5.67
                @test iter == 10
                @test viol ≈ 0.5
                @test msg == "Ipopt/generic"
                @test stat == :unknown
                @test success == false
            end
        end

        @testset "Generic method - edge cases" begin
            
            @testset "zero values" begin
                nlp_solution = MockExecutionStats(0.0, 0, 0.0, :first_order)
                nlp = create_mock_nlp(true)
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(nlp_solution, NLPModels.get_minimize(nlp))
                
                @test obj == 0.0
                @test iter == 0
                @test viol == 0.0
                @test success == true
            end

            @testset "negative objective" begin
                nlp_solution = MockExecutionStats(-10.5, 25, 1.0e-8, :first_order)
                nlp = create_mock_nlp(true)
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(nlp_solution, NLPModels.get_minimize(nlp))
                
                @test obj ≈ -10.5
                @test iter == 25
                @test viol ≈ 1.0e-8
                @test success == true
            end

            @testset "large values" begin
                nlp_solution = MockExecutionStats(1e10, 1000, 1e-10, :acceptable)
                nlp = create_mock_nlp(true)
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(nlp_solution, NLPModels.get_minimize(nlp))
                
                @test obj ≈ 1e10
                @test iter == 1000
                @test viol ≈ 1e-10
                @test success == true
            end
        end

        # ============================================================================
        # INTEGRATION TESTS
        # ============================================================================

        @testset "MadNLP extension" begin
            
            nlp_min = ADNLPModel(x -> x[1]^2, [1.0]; minimize=true)
            nlp_max = ADNLPModel(x -> x[1]^2, [1.0]; minimize=false)

            base_stats = madnlp(nlp_min; print_level=MadNLP.ERROR)

            @testset "minimize - SOLVE_SUCCEEDED" begin
                base_stats.objective = 1.23
                base_stats.iter = 15
                base_stats.primal_feas = 1.0e-6
                base_stats.status = MadNLP.SOLVE_SUCCEEDED
                
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(base_stats, NLPModels.get_minimize(nlp_min))
                
                @test obj ≈ 1.23
                @test iter == 15
                @test viol ≈ 1.0e-6
                @test msg == "MadNLP"
                @test stat == :SOLVE_SUCCEEDED
                @test success == true
            end

            @testset "maximize - objective sign flip" begin
                base_stats.objective = 1.23
                base_stats.iter = 20
                base_stats.primal_feas = 1.0e-7
                base_stats.status = MadNLP.SOLVE_SUCCEEDED
                
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(base_stats, NLPModels.get_minimize(nlp_max))
                
                @test obj ≈ -1.23
                @test iter == 20
                @test viol ≈ 1.0e-7
                @test msg == "MadNLP"
                @test stat == :SOLVE_SUCCEEDED
                @test success == true
            end

            @testset "SOLVED_TO_ACCEPTABLE_LEVEL" begin
                base_stats.objective = 2.34
                base_stats.iter = 30
                base_stats.primal_feas = 1.0e-5
                base_stats.status = MadNLP.SOLVED_TO_ACCEPTABLE_LEVEL
                
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(base_stats, NLPModels.get_minimize(nlp_min))
                
                @test obj ≈ 2.34
                @test iter == 30
                @test viol ≈ 1.0e-5
                @test msg == "MadNLP"
                @test stat == :SOLVED_TO_ACCEPTABLE_LEVEL
                @test success == true
            end

            @testset "MAXIMUM_ITERATIONS_EXCEEDED" begin
                base_stats.objective = 3.45
                base_stats.iter = 100
                base_stats.primal_feas = 1.0e-3
                base_stats.status = MadNLP.MAXIMUM_ITERATIONS_EXCEEDED
                
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(base_stats, NLPModels.get_minimize(nlp_min))
                
                @test obj ≈ 3.45
                @test iter == 100
                @test viol ≈ 1.0e-3
                @test msg == "MadNLP"
                @test stat == :MAXIMUM_ITERATIONS_EXCEEDED
                @test success == false
            end

            @testset "INFEASIBLE_PROBLEM_DETECTED" begin
                base_stats.objective = 4.56
                base_stats.iter = 50
                base_stats.primal_feas = 1.0
                base_stats.status = MadNLP.INFEASIBLE_PROBLEM_DETECTED
                
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(base_stats, NLPModels.get_minimize(nlp_min))
                
                @test obj ≈ 4.56
                @test iter == 50
                @test viol ≈ 1.0
                @test msg == "MadNLP"
                @test stat == :INFEASIBLE_PROBLEM_DETECTED
                @test success == false
            end

            @testset "maximize with negative objective" begin
                base_stats.objective = -5.67
                base_stats.iter = 25
                base_stats.primal_feas = 1.0e-8
                base_stats.status = MadNLP.SOLVE_SUCCEEDED
                
                obj, iter, viol, msg, stat, success = CTModels.extract_solver_infos(base_stats, NLPModels.get_minimize(nlp_max))
                
                @test obj ≈ 5.67
                @test iter == 25
                @test viol ≈ 1.0e-8
                @test success == true
            end
        end
    end
end
