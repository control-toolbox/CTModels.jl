module TestOptimizationErrorCases

using Test
using CTBase: CTBase, Exceptions
using CTModels
using NLPModels
using SolverCore
using ADNLPModels
using ExaModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Import from Optimization module
import CTModels.Optimization
import CTModels.Optimization: AbstractOptimizationProblem
import CTModels.Optimization: get_adnlp_model_builder, get_exa_model_builder
import CTModels.Optimization: get_adnlp_solution_builder, get_exa_solution_builder

# ============================================================================
# FAKE TYPES FOR ERROR TESTING (TOP-LEVEL)
# ============================================================================

"""
Minimal problem that doesn't implement the contract.
"""
struct MinimalProblemForErrors <: AbstractOptimizationProblem end

"""
Problem with only partial contract implementation.
"""
struct PartialProblem <: AbstractOptimizationProblem end

# Implement only ADNLP builder
Optimization.get_adnlp_model_builder(::PartialProblem) = Optimization.ADNLPModelBuilder(x -> ADNLPModels.ADNLPModel(z -> sum(z.^2), x))

"""
Mock stats for testing.
"""
mutable struct MockStats <: SolverCore.AbstractExecutionStats
    objective::Float64
end

"""
Edge case stats for testing.
"""
mutable struct EdgeCaseStats <: SolverCore.AbstractExecutionStats
    objective::Float64
    iter::Int
    primal_feas::Float64
    status::Symbol
end

"""
Type test stats for testing.
"""
mutable struct TypeTestStats <: SolverCore.AbstractExecutionStats
    objective::Float64
    status::Symbol
end

# ============================================================================
# TEST FUNCTION
# ============================================================================

"""
    test_error_cases()

Tests for error cases and edge cases in Optimization module.

This function tests error handling, NotImplemented errors, and edge cases
to ensure the module fails gracefully with clear error messages.
"""
function test_error_cases()
    Test.@testset "Error Cases and Edge Cases" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # CONTRACT NOT IMPLEMENTED ERRORS
        # ====================================================================
        
        @testset "NotImplemented Errors" begin
            prob = MinimalProblemForErrors()
            
            @testset "get_adnlp_model_builder - NotImplemented" begin
                @test_throws Exceptions.NotImplemented get_adnlp_model_builder(prob)
            end
            
            @testset "get_exa_model_builder - NotImplemented" begin
                @test_throws Exceptions.NotImplemented get_exa_model_builder(prob)
            end
            
            @testset "get_adnlp_solution_builder - NotImplemented" begin
                @test_throws Exceptions.NotImplemented get_adnlp_solution_builder(prob)
            end
            
            @testset "get_exa_solution_builder - NotImplemented" begin
                @test_throws Exceptions.NotImplemented get_exa_solution_builder(prob)
            end
        end

        # ====================================================================
        # PARTIAL CONTRACT IMPLEMENTATION
        # ====================================================================
        
        @testset "Partial Contract Implementation" begin
            prob = PartialProblem()
            
            @testset "Implemented builder works" begin
                builder = get_adnlp_model_builder(prob)
                @test builder isa Optimization.ADNLPModelBuilder
                
                # Can build model with implemented builder
                x0 = [1.0, 2.0]
                nlp = builder(x0)
                @test nlp isa ADNLPModels.ADNLPModel
            end
            
            @testset "Non-implemented builders throw NotImplemented" begin
                @test_throws Exceptions.NotImplemented get_exa_model_builder(prob)
                @test_throws Exceptions.NotImplemented get_adnlp_solution_builder(prob)
                @test_throws Exceptions.NotImplemented get_exa_solution_builder(prob)
            end
        end

        # ====================================================================
        # BUILDER ERRORS
        # ====================================================================
        
        @testset "Builder Errors" begin
            @testset "ADNLPModelBuilder with failing function" begin
                # Builder that throws an error
                failing_builder = Optimization.ADNLPModelBuilder(x -> error("Intentional error"))
                
                @test_throws ErrorException failing_builder([1.0, 2.0])
            end
            
            @testset "ExaModelBuilder with failing function" begin
                # Builder that throws an error
                failing_builder = Optimization.ExaModelBuilder((T, x) -> error("Intentional error"))
                
                @test_throws ErrorException failing_builder(Float64, [1.0, 2.0])
            end
            
            @testset "ADNLPSolutionBuilder with failing function" begin
                # Builder that throws an error
                failing_builder = Optimization.ADNLPSolutionBuilder(s -> error("Intentional error"))
                
                # Mock stats
                stats = MockStats(1.0)
                
                @test_throws ErrorException failing_builder(stats)
            end
        end

        # ====================================================================
        # EDGE CASES
        # ====================================================================
        
        @testset "Edge Cases" begin
            # Note: Empty initial guess (nvar=0) is not supported by ADNLPModels
            # ADNLPModels requires nvar > 0, so we skip this edge case
            
            @testset "Single variable problem" begin
                builder = Optimization.ADNLPModelBuilder(x -> ADNLPModels.ADNLPModel(z -> z[1]^2, x))
                
                x0 = [1.0]
                nlp = builder(x0)
                @test nlp isa ADNLPModels.ADNLPModel
                @test nlp.meta.nvar == 1
                @test NLPModels.obj(nlp, x0) ≈ 1.0
            end
            
            @testset "Large dimension problem" begin
                n = 1000
                builder = Optimization.ADNLPModelBuilder(x -> ADNLPModels.ADNLPModel(z -> sum(z.^2), x))
                
                x0 = ones(n)
                nlp = builder(x0)
                @test nlp isa ADNLPModels.ADNLPModel
                @test nlp.meta.nvar == n
            end
            
            @testset "Different numeric types" begin
                # Float32
                builder32 = Optimization.ExaModelBuilder((T, x) -> begin
                    m = ExaModels.ExaCore(T)
                    x_var = ExaModels.variable(m, length(x); start=x)
                    ExaModels.objective(m, sum(x_var[i]^2 for i=1:length(x)))
                    ExaModels.ExaModel(m)
                end)
                
                x0_32 = Float32[1.0, 2.0]
                nlp32 = builder32(Float32, x0_32)
                @test nlp32 isa ExaModels.ExaModel{Float32}
                @test eltype(nlp32.meta.x0) == Float32
                
                # Float64
                x0_64 = Float64[1.0, 2.0]
                nlp64 = builder32(Float64, x0_64)
                @test nlp64 isa ExaModels.ExaModel{Float64}
                @test eltype(nlp64.meta.x0) == Float64
            end
        end

        # ====================================================================
        # SOLVER INFO EDGE CASES
        # ====================================================================
        
        @testset "Solver Info Edge Cases" begin
            @testset "Zero iterations" begin
                stats = EdgeCaseStats(0.0, 0, 0.0, :first_order)
                nlp = ADNLPModels.ADNLPModel(x -> x[1]^2, [1.0])
                
                obj, iter, viol, msg, status, success = Optimization.extract_solver_infos(stats, NLPModels.get_minimize(nlp))
                @test iter == 0
                @test success == true
            end
            
            @testset "Very large objective" begin
                stats = EdgeCaseStats(1e100, 10, 1e-6, :first_order)
                nlp = ADNLPModels.ADNLPModel(x -> x[1]^2, [1.0])
                
                obj, iter, viol, msg, status, success = Optimization.extract_solver_infos(stats, NLPModels.get_minimize(nlp))
                @test obj ≈ 1e100
                @test success == true
            end
            
            @testset "Very small constraint violation" begin
                stats = EdgeCaseStats(1.0, 10, 1e-15, :first_order)
                nlp = ADNLPModels.ADNLPModel(x -> x[1]^2, [1.0])
                
                obj, iter, viol, msg, status, success = Optimization.extract_solver_infos(stats, NLPModels.get_minimize(nlp))
                @test viol ≈ 1e-15
                @test success == true
            end
            
            @testset "Unknown status" begin
                stats = EdgeCaseStats(1.0, 10, 1e-6, :unknown_status)
                nlp = ADNLPModels.ADNLPModel(x -> x[1]^2, [1.0])
                
                obj, iter, viol, msg, status, success = Optimization.extract_solver_infos(stats, NLPModels.get_minimize(nlp))
                @test status == :unknown_status
                @test success == false  # Not :first_order or :acceptable
            end
        end

        # ====================================================================
        # TYPE STABILITY TESTS
        # ====================================================================
        
        @testset "Type Stability" begin
            @testset "Builder return types" begin
                adnlp_builder = Optimization.ADNLPModelBuilder(x -> ADNLPModels.ADNLPModel(z -> sum(z.^2), x))
                x0 = [1.0, 2.0]
                
                nlp = adnlp_builder(x0)
                @test nlp isa ADNLPModels.ADNLPModel
                @test typeof(nlp) <: ADNLPModels.ADNLPModel
            end
            
            @testset "Solution builder return types" begin
                sol_builder = Optimization.ADNLPSolutionBuilder(s -> (obj=s.objective, status=s.status))
                
                stats = TypeTestStats(1.0, :first_order)
                
                sol = sol_builder(stats)
                @test sol isa NamedTuple
                @test haskey(sol, :obj)
                @test haskey(sol, :status)
            end
        end
    end
end

end # module

test_error_cases() = TestOptimizationErrorCases.test_error_cases()
