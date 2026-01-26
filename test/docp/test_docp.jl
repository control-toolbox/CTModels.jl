"""
Tests for DOCP module

This file tests the complete DOCP module including:
- DiscretizedOptimalControlProblem type
- Contract implementation (get_*_builder functions)
- Accessors (ocp_model)
- Building functions (nlp_model, ocp_solution)
"""

using Test
using CTModels
using CTModels.DOCP
using CTModels.Optimization
using CTBase
using NLPModels
using SolverCore
using ADNLPModels
using ExaModels

# ============================================================================
# FAKE TYPES FOR TESTING (TOP-LEVEL)
# ============================================================================

"""
Fake OCP for testing DOCP construction.
"""
struct FakeOCP
    name::String
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

"""
Fake modeler for testing building functions.
"""
struct FakeModelerDOCP
    backend::Symbol
end

function (modeler::FakeModelerDOCP)(prob::DiscretizedOptimalControlProblem, initial_guess)
    if modeler.backend == :adnlp
        builder = get_adnlp_model_builder(prob)
        return builder(initial_guess)
    else
        builder = get_exa_model_builder(prob)
        return builder(Float64, initial_guess)
    end
end

function (modeler::FakeModelerDOCP)(prob::DiscretizedOptimalControlProblem, nlp_solution::SolverCore.AbstractExecutionStats)
    if modeler.backend == :adnlp
        builder = get_adnlp_solution_builder(prob)
        return builder(nlp_solution)
    else
        builder = get_exa_solution_builder(prob)
        return builder(nlp_solution)
    end
end

# ============================================================================
# TEST FUNCTION
# ============================================================================

function test_docp()
    @testset "DOCP Module" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - DiscretizedOptimalControlProblem Type
        # ====================================================================
        
        @testset "DiscretizedOptimalControlProblem Type" begin
            @testset "Construction" begin
                # Create builders
                adnlp_builder = ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
                exa_builder = ExaModelBuilder((T, x) -> begin
                    c = ExaModels.ExaCore(T)
                    ExaModels.variable(c, 1 <= x[i=1:length(x)] <= 3, start=x[i])
                    ExaModels.objective(c, sum(x[i]^2 for i=1:length(x)))
                    ExaModels.ExaModel(c)
                end)
                adnlp_sol_builder = ADNLPSolutionBuilder(s -> (objective=s.objective,))
                exa_sol_builder = ExaSolutionBuilder(s -> (objective=s.objective,))
                
                # Create fake OCP
                ocp = FakeOCP("test_ocp")
                
                # Create DOCP
                docp = DiscretizedOptimalControlProblem(
                    ocp,
                    adnlp_builder,
                    exa_builder,
                    adnlp_sol_builder,
                    exa_sol_builder
                )
                
                @test docp isa DiscretizedOptimalControlProblem
                @test docp isa AbstractOptimizationProblem
                @test docp.optimal_control_problem === ocp
                @test docp.adnlp_model_builder === adnlp_builder
                @test docp.exa_model_builder === exa_builder
                @test docp.adnlp_solution_builder === adnlp_sol_builder
                @test docp.exa_solution_builder === exa_sol_builder
            end
            
            @testset "Type parameters" begin
                ocp = FakeOCP("test")
                adnlp_builder = ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
                exa_builder = ExaModelBuilder((T, x) -> begin
                    c = ExaModels.ExaCore(T)
                    ExaModels.variable(c, 1 <= x[i=1:length(x)] <= 3, start=x[i])
                    ExaModels.objective(c, sum(x[i]^2 for i=1:length(x)))
                    ExaModels.ExaModel(c)
                end)
                adnlp_sol_builder = ADNLPSolutionBuilder(s -> (objective=s.objective,))
                exa_sol_builder = ExaSolutionBuilder(s -> (objective=s.objective,))
                
                docp = DiscretizedOptimalControlProblem(
                    ocp, adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
                )
                
                @test typeof(docp.optimal_control_problem) == FakeOCP
                @test typeof(docp.adnlp_model_builder) <: ADNLPModelBuilder
                @test typeof(docp.exa_model_builder) <: ExaModelBuilder
                @test typeof(docp.adnlp_solution_builder) <: ADNLPSolutionBuilder
                @test typeof(docp.exa_solution_builder) <: ExaSolutionBuilder
            end
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================
        
        @testset "Contract Implementation" begin
            # Setup
            ocp = FakeOCP("test_ocp")
            adnlp_builder = ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
            exa_builder = ExaModelBuilder((T, x) -> begin
                c = ExaModels.ExaCore(T)
                ExaModels.variable(c, 1 <= x[i=1:length(x)] <= 3, start=x[i])
                ExaModels.objective(c, sum(x[i]^2 for i=1:length(x)))
                ExaModels.ExaModel(c)
            end)
            adnlp_sol_builder = ADNLPSolutionBuilder(s -> (objective=s.objective,))
            exa_sol_builder = ExaSolutionBuilder(s -> (objective=s.objective,))
            
            docp = DiscretizedOptimalControlProblem(
                ocp, adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
            )
            
            @testset "get_adnlp_model_builder" begin
                builder = get_adnlp_model_builder(docp)
                @test builder === adnlp_builder
                @test builder isa ADNLPModelBuilder
            end
            
            @testset "get_exa_model_builder" begin
                builder = get_exa_model_builder(docp)
                @test builder === exa_builder
                @test builder isa ExaModelBuilder
            end
            
            @testset "get_adnlp_solution_builder" begin
                builder = get_adnlp_solution_builder(docp)
                @test builder === adnlp_sol_builder
                @test builder isa ADNLPSolutionBuilder
            end
            
            @testset "get_exa_solution_builder" begin
                builder = get_exa_solution_builder(docp)
                @test builder === exa_sol_builder
                @test builder isa ExaSolutionBuilder
            end
        end

        # ====================================================================
        # UNIT TESTS - Accessors
        # ====================================================================
        
        @testset "Accessors" begin
            @testset "ocp_model" begin
                ocp = FakeOCP("my_ocp")
                adnlp_builder = ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
                exa_builder = ExaModelBuilder((T, x) -> begin
                    c = ExaModels.ExaCore(T)
                    ExaModels.variable(c, 1 <= x[i=1:length(x)] <= 3, start=x[i])
                    ExaModels.objective(c, sum(x[i]^2 for i=1:length(x)))
                    ExaModels.ExaModel(c)
                end)
                adnlp_sol_builder = ADNLPSolutionBuilder(s -> (objective=s.objective,))
                exa_sol_builder = ExaSolutionBuilder(s -> (objective=s.objective,))
                
                docp = DiscretizedOptimalControlProblem(
                    ocp, adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
                )
                
                retrieved_ocp = ocp_model(docp)
                @test retrieved_ocp === ocp
                @test retrieved_ocp.name == "my_ocp"
            end
        end

        # ====================================================================
        # UNIT TESTS - Building Functions
        # ====================================================================
        
        @testset "Building Functions" begin
            # Setup
            ocp = FakeOCP("test_ocp")
            adnlp_builder = ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
            exa_builder = ExaModelBuilder((T, x) -> begin
                c = ExaModels.ExaCore(T)
                ExaModels.variable(c, 1 <= x[i=1:length(x)] <= 3, start=x[i])
                ExaModels.objective(c, sum(x[i]^2 for i=1:length(x)))
                ExaModels.ExaModel(c)
            end)
            adnlp_sol_builder = ADNLPSolutionBuilder(s -> (objective=s.objective, status=s.status))
            exa_sol_builder = ExaSolutionBuilder(s -> (objective=s.objective, iter=s.iter))
            
            docp = DiscretizedOptimalControlProblem(
                ocp, adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
            )
            
            @testset "nlp_model with ADNLP" begin
                modeler = FakeModelerDOCP(:adnlp)
                x0 = [1.0, 2.0]
                
                nlp = nlp_model(docp, x0, modeler)
                @test nlp isa NLPModels.AbstractNLPModel
                @test nlp isa ADNLPModels.ADNLPModel
                @test nlp.meta.x0 == x0
                @test NLPModels.obj(nlp, x0) ≈ 5.0
            end
            
            @testset "nlp_model with Exa" begin
                modeler = FakeModelerDOCP(:exa)
                x0 = [1.0, 2.0]
                
                nlp = nlp_model(docp, x0, modeler)
                @test nlp isa NLPModels.AbstractNLPModel
                @test nlp isa ExaModels.ExaModel{Float64}
                @test NLPModels.obj(nlp, x0) ≈ 5.0
            end
            
            @testset "ocp_solution with ADNLP" begin
                modeler = FakeModelerDOCP(:adnlp)
                stats = MockExecutionStats(1.23, 10, 1e-6, :first_order)
                
                sol = ocp_solution(docp, stats, modeler)
                @test sol.objective ≈ 1.23
                @test sol.status == :first_order
            end
            
            @testset "ocp_solution with Exa" begin
                modeler = FakeModelerDOCP(:exa)
                stats = MockExecutionStats(2.34, 15, 1e-5, :acceptable)
                
                sol = ocp_solution(docp, stats, modeler)
                @test sol.objective ≈ 2.34
                @test sol.iter == 15
            end
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================
        
        @testset "Integration Tests" begin
            @testset "Complete DOCP workflow - ADNLP" begin
                # Create OCP
                ocp = FakeOCP("integration_test_ocp")
                
                # Create builders
                adnlp_builder = ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
                exa_builder = ExaModelBuilder((T, x) -> begin
                    c = ExaModels.ExaCore(T)
                    ExaModels.variable(c, 1 <= x[i=1:length(x)] <= 3, start=x[i])
                    ExaModels.objective(c, sum(x[i]^2 for i=1:length(x)))
                    ExaModels.ExaModel(c)
                end)
                adnlp_sol_builder = ADNLPSolutionBuilder(s -> (
                    objective=s.objective,
                    iterations=s.iter,
                    status=s.status,
                    success=(s.status == :first_order || s.status == :acceptable)
                ))
                exa_sol_builder = ExaSolutionBuilder(s -> (objective=s.objective, iter=s.iter))
                
                # Create DOCP
                docp = DiscretizedOptimalControlProblem(
                    ocp, adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
                )
                
                # Verify OCP retrieval
                @test ocp_model(docp) === ocp
                
                # Build NLP model
                modeler = FakeModelerDOCP(:adnlp)
                x0 = [1.0, 2.0, 3.0]
                nlp = nlp_model(docp, x0, modeler)
                
                @test nlp isa ADNLPModels.ADNLPModel
                @test NLPModels.obj(nlp, x0) ≈ 14.0
                
                # Build solution
                stats = MockExecutionStats(14.0, 20, 1e-8, :first_order)
                sol = ocp_solution(docp, stats, modeler)
                
                @test sol.objective ≈ 14.0
                @test sol.iterations == 20
                @test sol.status == :first_order
                @test sol.success == true
            end
            
            @testset "Complete DOCP workflow - Exa" begin
                # Create OCP
                ocp = FakeOCP("integration_test_exa")
                
                # Create builders
                adnlp_builder = ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
                exa_builder = ExaModelBuilder((T, x) -> begin
                    c = ExaModels.ExaCore(T)
                    ExaModels.variable(c, 1 <= x[i=1:length(x)] <= 3, start=x[i])
                    ExaModels.objective(c, sum(x[i]^2 for i=1:length(x)))
                    ExaModels.ExaModel(c)
                end)
                adnlp_sol_builder = ADNLPSolutionBuilder(s -> (objective=s.objective,))
                exa_sol_builder = ExaSolutionBuilder(s -> (
                    objective=s.objective,
                    iterations=s.iter,
                    status=s.status
                ))
                
                # Create DOCP
                docp = DiscretizedOptimalControlProblem(
                    ocp, adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
                )
                
                # Verify OCP retrieval
                @test ocp_model(docp) === ocp
                
                # Build NLP model
                modeler = FakeModelerDOCP(:exa)
                x0 = [1.0, 2.0, 3.0]
                nlp = nlp_model(docp, x0, modeler)
                
                @test nlp isa ExaModels.ExaModel{Float64}
                @test NLPModels.obj(nlp, x0) ≈ 14.0
                
                # Build solution
                stats = MockExecutionStats(14.0, 25, 1e-7, :acceptable)
                sol = ocp_solution(docp, stats, modeler)
                
                @test sol.objective ≈ 14.0
                @test sol.iterations == 25
                @test sol.status == :acceptable
            end
            
            @testset "DOCP with different base types" begin
                ocp = FakeOCP("base_type_test")
                
                # Create builders
                adnlp_builder = ADNLPModelBuilder(x -> ADNLPModel(z -> sum(z.^2), x))
                exa_builder = ExaModelBuilder((T, x) -> begin
                    c = ExaModels.ExaCore(T)
                    ExaModels.variable(c, 1 <= x[i=1:length(x)] <= 3, start=x[i])
                    ExaModels.objective(c, sum(x[i]^2 for i=1:length(x)))
                    ExaModels.ExaModel(c)
                end)
                adnlp_sol_builder = ADNLPSolutionBuilder(s -> (objective=s.objective,))
                exa_sol_builder = ExaSolutionBuilder(s -> (objective=s.objective,))
                
                docp = DiscretizedOptimalControlProblem(
                    ocp, adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
                )
                
                # Test with Float64
                builder64 = get_exa_model_builder(docp)
                x0_64 = [1.0, 2.0]
                nlp64 = builder64(Float64, x0_64)
                @test nlp64 isa ExaModels.ExaModel{Float64}
                
                # Test with Float32
                builder32 = get_exa_model_builder(docp)
                x0_32 = Float32[1.0, 2.0]
                nlp32 = builder32(Float32, x0_32)
                @test nlp32 isa ExaModels.ExaModel{Float32}
            end
        end
    end
end
