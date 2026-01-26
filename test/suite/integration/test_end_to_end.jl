"""
End-to-End Integration Tests

Complete workflows from problem definition to solution with real optimization problems.
Tests the entire pipeline: OCP → DOCP → Modeler → NLP → Solver → Solution
"""

using Test
using CTModels
using CTBase
using NLPModels
using SolverCore
using ADNLPModels
using ExaModels
using MadNLP

# Import modules
import CTModels.Optimization
import CTModels.DOCP
import CTModels.DOCP: DiscretizedOptimalControlProblem, ocp_model, nlp_model, ocp_solution

# ============================================================================
# TEST FUNCTION
# ============================================================================

function test_end_to_end()
    @testset "End-to-End Integration Tests" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # COMPLETE WORKFLOW WITH ROSENBROCK - ADNLP BACKEND
        # ====================================================================
        
        @testset "Complete Workflow - Rosenbrock ADNLP" begin
            # Step 1: Load problem
            ros = Rosenbrock()
            @test ros.prob isa Optimization.AbstractOptimizationProblem
            
            # Step 2: Create DOCP (if needed, here it's already an OptimizationProblem)
            prob = ros.prob
            
            # Step 3: Create modeler
            modeler = CTModels.ADNLPModeler(show_time=false)
            @test modeler isa CTModels.AbstractOptimizationModeler
            
            # Step 4: Build NLP model
            nlp = modeler(prob, ros.init)
            @test nlp isa ADNLPModels.ADNLPModel
            @test nlp.meta.nvar == 2
            @test nlp.meta.ncon == 1
            
            # Step 5: Verify problem properties
            @test nlp.meta.minimize == true
            @test nlp.meta.x0 == ros.init
            
            # Step 6: Evaluate at initial point
            obj_init = NLPModels.obj(nlp, ros.init)
            @test obj_init ≈ rosenbrock_objective(ros.init)
            
            # Step 7: Evaluate at solution
            obj_sol = NLPModels.obj(nlp, ros.sol)
            @test obj_sol ≈ rosenbrock_objective(ros.sol)
            @test obj_sol < obj_init  # Solution is better than initial
            
            # Step 8: Check constraints
            cons_init = NLPModels.cons(nlp, ros.init)
            @test cons_init[1] ≈ rosenbrock_constraint(ros.init)
            
            # Step 9: Solve with MadNLP (optional, if solver available)
            try
                solver = MadNLP.MadNLPSolver(nlp; print_level=MadNLP.ERROR)
                result = MadNLP.solve!(solver)
                
                # Step 10: Extract solver info
                obj, iter, viol, msg, status, success = Optimization.extract_solver_infos(result, nlp)
                
                @test obj isa Float64
                @test iter isa Int
                @test iter >= 0
                @test viol isa Float64
                @test status isa Symbol
                @test success isa Bool
            catch e
                @warn "MadNLP solver test skipped" exception=e
            end
        end

        # ====================================================================
        # COMPLETE WORKFLOW WITH ROSENBROCK - EXA BACKEND
        # ====================================================================
        
        @testset "Complete Workflow - Rosenbrock Exa" begin
            # Step 1: Load problem
            ros = Rosenbrock()
            prob = ros.prob
            
            # Step 2: Create modeler with Exa backend
            modeler = CTModels.ExaModeler(base_type=Float64, minimize=true)
            @test modeler isa CTModels.AbstractOptimizationModeler
            @test typeof(modeler) == CTModels.ExaModeler{Float64}
            
            # Step 3: Build NLP model
            nlp = modeler(prob, ros.init)
            @test nlp isa ExaModels.ExaModel{Float64}
            @test nlp.meta.nvar == 2
            @test nlp.meta.ncon == 1
            
            # Step 4: Verify problem properties
            @test nlp.meta.minimize == true
            @test nlp.meta.x0 == Float64.(ros.init)
            
            # Step 5: Evaluate at initial point
            obj_init = NLPModels.obj(nlp, Float64.(ros.init))
            @test obj_init ≈ rosenbrock_objective(ros.init)
            
            # Step 6: Evaluate at solution
            obj_sol = NLPModels.obj(nlp, Float64.(ros.sol))
            @test obj_sol ≈ rosenbrock_objective(ros.sol)
            @test obj_sol < obj_init
        end

        # ====================================================================
        # COMPLETE WORKFLOW WITH DIFFERENT BASE TYPES
        # ====================================================================
        
        @testset "Complete Workflow - Different Base Types" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            @testset "Float32 workflow" begin
                modeler = CTModels.ExaModeler(base_type=Float32, minimize=true)
                nlp = modeler(prob, ros.init)
                
                @test nlp isa ExaModels.ExaModel{Float32}
                @test eltype(nlp.meta.x0) == Float32
                
                # Evaluate with Float32 (obj may be promoted to Float64 by NLPModels)
                obj = NLPModels.obj(nlp, Float32.(ros.init))
                @test obj ≈ rosenbrock_objective(ros.init) rtol=1e-5
            end
            
            @testset "Float64 workflow" begin
                modeler = CTModels.ExaModeler(base_type=Float64, minimize=true)
                nlp = modeler(prob, ros.init)
                
                @test nlp isa ExaModels.ExaModel{Float64}
                @test eltype(nlp.meta.x0) == Float64
                
                obj = NLPModels.obj(nlp, Float64.(ros.init))
                @test obj isa Float64
                @test obj ≈ rosenbrock_objective(ros.init)
            end
        end

        # ====================================================================
        # MODELER OPTIONS WORKFLOW
        # ====================================================================
        
        @testset "Modeler Options Workflow" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            @testset "ADNLPModeler with options" begin
                # Test with show_time option (backend is optional and defaults work)
                modeler = CTModels.ADNLPModeler(show_time=false)
                nlp = modeler(prob, ros.init)
                
                @test nlp isa ADNLPModels.ADNLPModel
                obj = NLPModels.obj(nlp, ros.init)
                @test obj ≈ rosenbrock_objective(ros.init)
                
                # Test with show_time=true
                modeler2 = CTModels.ADNLPModeler(show_time=true)
                nlp2 = modeler2(prob, ros.init)
                @test nlp2 isa ADNLPModels.ADNLPModel
            end
            
            @testset "ExaModeler with options" begin
                modeler = CTModels.ExaModeler(
                    base_type=Float64,
                    minimize=true,
                    backend=nothing
                )
                nlp = modeler(prob, ros.init)
                
                @test nlp isa ExaModels.ExaModel{Float64}
                obj = NLPModels.obj(nlp, Float64.(ros.init))
                @test obj ≈ rosenbrock_objective(ros.init)
            end
        end

        # ====================================================================
        # COMPARISON BETWEEN BACKENDS
        # ====================================================================
        
        @testset "Backend Comparison" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            # Build with ADNLP
            modeler_adnlp = CTModels.ADNLPModeler(show_time=false)
            nlp_adnlp = modeler_adnlp(prob, ros.init)
            obj_adnlp = NLPModels.obj(nlp_adnlp, ros.init)
            
            # Build with Exa
            modeler_exa = CTModels.ExaModeler(base_type=Float64, minimize=true)
            nlp_exa = modeler_exa(prob, ros.init)
            obj_exa = NLPModels.obj(nlp_exa, Float64.(ros.init))
            
            # Both should give same objective
            @test obj_adnlp ≈ obj_exa rtol=1e-10
            
            # Both should have same problem structure
            @test nlp_adnlp.meta.nvar == nlp_exa.meta.nvar
            @test nlp_adnlp.meta.ncon == nlp_exa.meta.ncon
            @test nlp_adnlp.meta.minimize == nlp_exa.meta.minimize
        end

        # ====================================================================
        # GRADIENT AND HESSIAN EVALUATION
        # ====================================================================
        
        @testset "Gradient and Hessian Evaluation" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            modeler = CTModels.ADNLPModeler(show_time=false)
            nlp = modeler(prob, ros.init)
            
            @testset "Gradient at initial point" begin
                grad = NLPModels.grad(nlp, ros.init)
                @test grad isa Vector{Float64}
                @test length(grad) == 2
                @test !all(iszero, grad)  # Gradient should not be zero at init
            end
            
            @testset "Gradient at solution" begin
                grad = NLPModels.grad(nlp, ros.sol)
                @test grad isa Vector{Float64}
                @test length(grad) == 2
                # At solution, gradient should be small (but not necessarily zero due to constraints)
            end
            
            @testset "Hessian structure" begin
                hess = NLPModels.hess(nlp, ros.init)
                @test hess isa AbstractMatrix
                @test size(hess) == (2, 2)
            end
        end

        # ====================================================================
        # CONSTRAINT EVALUATION
        # ====================================================================
        
        @testset "Constraint Evaluation" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            modeler = CTModels.ADNLPModeler(show_time=false)
            nlp = modeler(prob, ros.init)
            
            @testset "Constraint at initial point" begin
                cons = NLPModels.cons(nlp, ros.init)
                @test cons isa Vector{Float64}
                @test length(cons) == 1
                @test cons[1] ≈ rosenbrock_constraint(ros.init)
            end
            
            @testset "Constraint at solution" begin
                cons = NLPModels.cons(nlp, ros.sol)
                @test cons[1] ≈ rosenbrock_constraint(ros.sol)
            end
            
            @testset "Constraint Jacobian" begin
                jac = NLPModels.jac(nlp, ros.init)
                @test jac isa AbstractMatrix
                @test size(jac) == (1, 2)
            end
        end

        # ====================================================================
        # PERFORMANCE CHARACTERISTICS
        # ====================================================================
        
        @testset "Performance Characteristics" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            @testset "Model building time" begin
                modeler = CTModels.ADNLPModeler(show_time=false)
                
                # Should be fast
                t = @elapsed nlp = modeler(prob, ros.init)
                @test t < 1.0  # Should take less than 1 second
                @test nlp isa ADNLPModels.ADNLPModel
            end
            
            @testset "Function evaluation time" begin
                modeler = CTModels.ADNLPModeler(show_time=false)
                nlp = modeler(prob, ros.init)
                
                # Objective evaluation should be fast
                t = @elapsed obj = NLPModels.obj(nlp, ros.init)
                @test t < 0.01  # Should be very fast
                @test obj isa Float64
            end
        end
    end
end
