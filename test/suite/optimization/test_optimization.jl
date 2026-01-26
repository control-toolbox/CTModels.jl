"""
Tests for Optimization module

This file tests the complete Optimization module including:
- Abstract types (AbstractOptimizationProblem, AbstractBuilder, etc.)
- Concrete builder types (ADNLPModelBuilder, ExaModelBuilder, etc.)
- Contract interface (get_*_builder functions)
- Building functions (build_model, build_solution)
- Solver utilities (extract_solver_infos)
"""

using Test
using CTModels
using CTBase
using NLPModels
using SolverCore
using ADNLPModels
using ExaModels

# Import from Optimization module to avoid name conflicts
import CTModels.Optimization
import CTModels.Optimization: AbstractOptimizationProblem, AbstractBuilder
import CTModels.Optimization: AbstractModelBuilder, AbstractSolutionBuilder, AbstractOCPSolutionBuilder
import CTModels.Optimization: get_adnlp_model_builder, get_exa_model_builder
import CTModels.Optimization: get_adnlp_solution_builder, get_exa_solution_builder
import CTModels.Optimization: build_model, build_solution, extract_solver_infos

# ============================================================================
# FAKE TYPES FOR CONTRACT TESTING (TOP-LEVEL)
# ============================================================================

"""
Fake optimization problem for testing the contract interface.
"""
struct FakeOptimizationProblem <: AbstractOptimizationProblem
    adnlp_builder::Optimization.ADNLPModelBuilder
    exa_builder::Optimization.ExaModelBuilder
    adnlp_solution_builder::Optimization.ADNLPSolutionBuilder
    exa_solution_builder::Optimization.ExaSolutionBuilder
end

# Implement contract for FakeOptimizationProblem
Optimization.get_adnlp_model_builder(prob::FakeOptimizationProblem) = prob.adnlp_builder
Optimization.get_exa_model_builder(prob::FakeOptimizationProblem) = prob.exa_builder
Optimization.get_adnlp_solution_builder(prob::FakeOptimizationProblem) = prob.adnlp_solution_builder
Optimization.get_exa_solution_builder(prob::FakeOptimizationProblem) = prob.exa_solution_builder

"""
Minimal problem for testing NotImplemented errors.
"""
struct MinimalProblem <: AbstractOptimizationProblem end

"""
Fake modeler for testing building functions.
"""
struct FakeModeler
    backend::Symbol
end

function (modeler::FakeModeler)(prob::AbstractOptimizationProblem, initial_guess)
    if modeler.backend == :adnlp
        builder = get_adnlp_model_builder(prob)
        return builder(initial_guess)
    else
        builder = get_exa_model_builder(prob)
        return builder(Float64, initial_guess)
    end
end

function (modeler::FakeModeler)(prob::AbstractOptimizationProblem, nlp_solution::SolverCore.AbstractExecutionStats)
    if modeler.backend == :adnlp
        builder = get_adnlp_solution_builder(prob)
        return builder(nlp_solution)
    else
        builder = get_exa_solution_builder(prob)
        return builder(nlp_solution)
    end
end

"""
Mock execution statistics for testing.
"""
mutable struct MockExecutionStats <: SolverCore.AbstractExecutionStats
    objective::Float64
    iter::Int
    primal_feas::Float64
    status::Symbol
end

# ============================================================================
# TEST FUNCTION
# ============================================================================

function test_optimization()
    @testset "Optimization Module" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        @testset "Abstract Types" begin
            @testset "Type hierarchy" begin
                @test AbstractOptimizationProblem <: Any
                @test AbstractBuilder <: Any
                @test AbstractModelBuilder <: AbstractBuilder
                @test AbstractSolutionBuilder <: AbstractBuilder
                @test AbstractOCPSolutionBuilder <: AbstractSolutionBuilder
            end
            
            @testset "Contract interface - NotImplemented errors" begin
                prob = MinimalProblem()
                
                @test_throws CTBase.NotImplemented get_adnlp_model_builder(prob)
                @test_throws CTBase.NotImplemented get_exa_model_builder(prob)
                @test_throws CTBase.NotImplemented get_adnlp_solution_builder(prob)
                @test_throws CTBase.NotImplemented get_exa_solution_builder(prob)
            end
        end

        # ====================================================================
        # UNIT TESTS - Concrete Builder Types
        # ====================================================================
        
        @testset "Concrete Builder Types" begin
            @testset "ADNLPModelBuilder" begin
                # Test construction
                calls = Ref(0)
                function test_builder(x; show_time=false)
                    calls[] += 1
                    return ADNLPModel(z -> sum(z.^2), x; show_time=show_time)
                end
                
                builder = Optimization.ADNLPModelBuilder(test_builder)
                @test builder isa Optimization.ADNLPModelBuilder
                @test builder isa AbstractModelBuilder
                
                # Test callable
                x0 = [1.0, 2.0]
                nlp = builder(x0)
                @test nlp isa ADNLPModels.ADNLPModel
                @test calls[] == 1
                @test nlp.meta.x0 == x0
                
                # Test with kwargs
                nlp2 = builder(x0; show_time=true)
                @test calls[] == 2
            end
            
            @testset "ExaModelBuilder" begin
                # Test construction
                calls = Ref(0)
                function test_exa_builder(::Type{T}, x; backend=nothing) where T
                    calls[] += 1
                    # Use correct ExaModels syntax (like in Rosenbrock)
                    m = ExaModels.ExaCore(T; backend=backend)
                    x_var = ExaModels.variable(m, length(x); start=x)
                    ExaModels.objective(m, sum(x_var[i]^2 for i=1:length(x)))
                    return ExaModels.ExaModel(m)
                end
                
                builder = Optimization.ExaModelBuilder(test_exa_builder)
                @test builder isa Optimization.ExaModelBuilder
                @test builder isa AbstractModelBuilder
                
                # Test callable
                x0 = [1.0, 2.0]
                nlp = builder(Float64, x0)
                @test nlp isa ExaModels.ExaModel{Float64}
                @test calls[] == 1
                
                # Test with different base type
                nlp32 = builder(Float32, x0)
                @test nlp32 isa ExaModels.ExaModel{Float32}
                @test calls[] == 2
            end
            
            @testset "ADNLPSolutionBuilder" begin
                # Test construction
                calls = Ref(0)
                function test_solution_builder(stats)
                    calls[] += 1
                    return (objective=stats.objective, status=stats.status)
                end
                
                builder = Optimization.ADNLPSolutionBuilder(test_solution_builder)
                @test builder isa Optimization.ADNLPSolutionBuilder
                @test builder isa AbstractOCPSolutionBuilder
                
                # Test callable
                stats = MockExecutionStats(1.23, 10, 1e-6, :first_order)
                sol = builder(stats)
                @test calls[] == 1
                @test sol.objective ≈ 1.23
                @test sol.status == :first_order
            end
            
            @testset "ExaSolutionBuilder" begin
                # Test construction
                calls = Ref(0)
                function test_exa_solution_builder(stats)
                    calls[] += 1
                    return (objective=stats.objective, iterations=stats.iter)
                end
                
                builder = Optimization.ExaSolutionBuilder(test_exa_solution_builder)
                @test builder isa Optimization.ExaSolutionBuilder
                @test builder isa AbstractOCPSolutionBuilder
                
                # Test callable
                stats = MockExecutionStats(2.34, 15, 1e-5, :acceptable)
                sol = builder(stats)
                @test calls[] == 1
                @test sol.objective ≈ 2.34
                @test sol.iterations == 15
            end
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================
        
        @testset "Contract Implementation" begin
            # Create builders
            adnlp_builder = Optimization.ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
            exa_builder = Optimization.ExaModelBuilder((T, x) -> begin
                m = ExaModels.ExaCore(T)
                x_var = ExaModels.variable(m, length(x); start=x)
                # Define objective using ExaModels syntax (like Rosenbrock)
                obj_func(v) = sum(v[i]^2 for i=1:length(x))
                ExaModels.objective(m, obj_func(x_var))
                ExaModels.ExaModel(m)
            end)
            adnlp_sol_builder = Optimization.ADNLPSolutionBuilder(s -> (obj=s.objective,))
            exa_sol_builder = Optimization.ExaSolutionBuilder(s -> (obj=s.objective,))
            
            # Create fake problem
            prob = FakeOptimizationProblem(
                adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
            )
            
            @testset "get_adnlp_model_builder" begin
                builder = get_adnlp_model_builder(prob)
                @test builder === adnlp_builder
                @test builder isa Optimization.ADNLPModelBuilder
            end
            
            @testset "get_exa_model_builder" begin
                builder = get_exa_model_builder(prob)
                @test builder === exa_builder
                @test builder isa Optimization.ExaModelBuilder
            end
            
            @testset "get_adnlp_solution_builder" begin
                builder = get_adnlp_solution_builder(prob)
                @test builder === adnlp_sol_builder
                @test builder isa Optimization.ADNLPSolutionBuilder
            end
            
            @testset "get_exa_solution_builder" begin
                builder = get_exa_solution_builder(prob)
                @test builder === exa_sol_builder
                @test builder isa Optimization.ExaSolutionBuilder
            end
        end

        # ====================================================================
        # UNIT TESTS - Building Functions
        # ====================================================================
        
        @testset "Building Functions" begin
            # Setup
            adnlp_builder = Optimization.ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
            exa_builder = Optimization.ExaModelBuilder((T, x) -> begin
                m = ExaModels.ExaCore(T)
                x_var = ExaModels.variable(m, length(x); start=x)
                # Define objective using ExaModels syntax (like Rosenbrock)
                obj_func(v) = sum(v[i]^2 for i=1:length(x))
                ExaModels.objective(m, obj_func(x_var))
                ExaModels.ExaModel(m)
            end)
            adnlp_sol_builder = Optimization.ADNLPSolutionBuilder(s -> (obj=s.objective, status=s.status))
            exa_sol_builder = Optimization.ExaSolutionBuilder(s -> (obj=s.objective, iter=s.iter))
            
            prob = FakeOptimizationProblem(
                adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
            )
            
            @testset "build_model with ADNLP" begin
                modeler = FakeModeler(:adnlp)
                x0 = [1.0, 2.0]
                
                nlp = build_model(prob, x0, modeler)
                @test nlp isa ADNLPModels.ADNLPModel
                @test nlp.meta.x0 == x0
            end
            
            @testset "build_model with Exa" begin
                modeler = FakeModeler(:exa)
                x0 = [1.0, 2.0]
                
                nlp = build_model(prob, x0, modeler)
                @test nlp isa ExaModels.ExaModel{Float64}
            end
            
            @testset "build_solution with ADNLP" begin
                modeler = FakeModeler(:adnlp)
                stats = MockExecutionStats(1.23, 10, 1e-6, :first_order)
                
                sol = build_solution(prob, stats, modeler)
                @test sol.obj ≈ 1.23
                @test sol.status == :first_order
            end
            
            @testset "build_solution with Exa" begin
                modeler = FakeModeler(:exa)
                stats = MockExecutionStats(2.34, 15, 1e-5, :acceptable)
                
                sol = build_solution(prob, stats, modeler)
                @test sol.obj ≈ 2.34
                @test sol.iter == 15
            end
        end

        # ====================================================================
        # UNIT TESTS - Solver Info Extraction
        # ====================================================================
        
        @testset "Solver Info Extraction" begin
            @testset "extract_solver_infos - first_order status" begin
                stats = MockExecutionStats(1.23, 15, 1.0e-6, :first_order)
                nlp = ADNLPModel(x -> x[1]^2, [1.0])
                
                obj, iter, viol, msg, status, success = extract_solver_infos(stats, nlp)
                
                @test obj ≈ 1.23
                @test iter == 15
                @test viol ≈ 1.0e-6
                @test msg == "Ipopt/generic"
                @test status == :first_order
                @test success == true
            end
            
            @testset "extract_solver_infos - acceptable status" begin
                stats = MockExecutionStats(2.34, 20, 1.0e-5, :acceptable)
                nlp = ADNLPModel(x -> x[1]^2, [1.0])
                
                obj, iter, viol, msg, status, success = extract_solver_infos(stats, nlp)
                
                @test obj ≈ 2.34
                @test iter == 20
                @test viol ≈ 1.0e-5
                @test msg == "Ipopt/generic"
                @test status == :acceptable
                @test success == true
            end
            
            @testset "extract_solver_infos - failure status" begin
                stats = MockExecutionStats(3.45, 5, 1.0e-3, :max_iter)
                nlp = ADNLPModel(x -> x[1]^2, [1.0])
                
                obj, iter, viol, msg, status, success = extract_solver_infos(stats, nlp)
                
                @test obj ≈ 3.45
                @test iter == 5
                @test viol ≈ 1.0e-3
                @test msg == "Ipopt/generic"
                @test status == :max_iter
                @test success == false
            end
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================
        
        @testset "Integration Tests" begin
            @testset "Complete workflow - ADNLP" begin
                # Create builders
                adnlp_builder = Optimization.ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
                exa_builder = Optimization.ExaModelBuilder((T, x) -> begin
                    c = ExaModels.ExaCore(T)
                    ExaModels.variable(c, 1 <= x[i=1:length(x)] <= 3, start=x[i])
                    ExaModels.objective(c, sum(x[i]^2 for i=1:length(x)))
                    ExaModels.ExaModel(c)
                end)
                adnlp_sol_builder = Optimization.ADNLPSolutionBuilder(s -> (objective=s.objective, status=s.status))
                exa_sol_builder = Optimization.ExaSolutionBuilder(s -> (objective=s.objective, iter=s.iter))
                
                # Create problem
                prob = FakeOptimizationProblem(
                    adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
                )
                
                # Build model
                modeler = FakeModeler(:adnlp)
                x0 = [1.0, 2.0]
                nlp = build_model(prob, x0, modeler)
                
                @test nlp isa ADNLPModels.ADNLPModel
                @test NLPModels.obj(nlp, x0) ≈ 5.0
                
                # Build solution
                stats = MockExecutionStats(5.0, 10, 1e-6, :first_order)
                sol = build_solution(prob, stats, modeler)
                
                @test sol.objective ≈ 5.0
                @test sol.status == :first_order
                
                # Extract solver info
                obj, iter, viol, msg, status, success = extract_solver_infos(stats, nlp)
                @test obj ≈ 5.0
                @test success == true
            end
            
            @testset "Complete workflow - Exa" begin
                # Create builders
                adnlp_builder = Optimization.ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
                exa_builder = Optimization.ExaModelBuilder((T, x) -> begin
                    n = length(x)
                    m = ExaModels.ExaCore(T)
                    x_var = ExaModels.variable(m, n; start=x)
                    # Define objective directly (like Rosenbrock does with F(x))
                    ExaModels.objective(m, sum(x_var[i]^2 for i=1:n))
                    ExaModels.ExaModel(m)
                end)
                adnlp_sol_builder = Optimization.ADNLPSolutionBuilder(s -> (objective=s.objective, status=s.status))
                exa_sol_builder = Optimization.ExaSolutionBuilder(s -> (objective=s.objective, iter=s.iter))
                
                # Create problem
                prob = FakeOptimizationProblem(
                    adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
                )
                
                # Build model
                modeler = FakeModeler(:exa)
                x0 = [1.0, 2.0]
                nlp = build_model(prob, x0, modeler)
                
                @test nlp isa ExaModels.ExaModel{Float64}
                @test NLPModels.obj(nlp, x0) ≈ 5.0
                
                # Build solution
                stats = MockExecutionStats(5.0, 15, 1e-5, :acceptable)
                sol = build_solution(prob, stats, modeler)
                
                @test sol.objective ≈ 5.0
                @test sol.iter == 15
            end
        end
    end
end
