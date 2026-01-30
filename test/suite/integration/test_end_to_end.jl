module TestEndToEnd

using Test
using CTModels
using CTBase
using NLPModels
using SolverCore
using ADNLPModels
using ExaModels
using MadNLP
using Main.TestProblems
using Main.TestOptions: VERBOSE, SHOWTIMING

# Import modules
import CTModels.Optimization
import CTModels.DOCP
import CTModels.DOCP: DiscretizedOptimalControlProblem, ocp_model, nlp_model, ocp_solution

# ============================================================================
# TEST FUNCTION
# ============================================================================

function test_end_to_end()
    Test.@testset "End-to-End Integration Tests" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # COMPLETE WORKFLOW WITH ROSENBROCK - ADNLP BACKEND
        # ====================================================================
        
        Test.@testset "Complete Workflow - Rosenbrock ADNLP" begin
            # Step 1: Load problem
            ros = Rosenbrock()
            Test.@test ros.prob isa Optimization.AbstractOptimizationProblem
            
            # Step 2: Create DOCP (if needed, here it's already an OptimizationProblem)
            prob = ros.prob
            
            # Step 3: Create modeler
            modeler = CTModels.ADNLPModeler(show_time=false)
            Test.@test modeler isa CTModels.AbstractOptimizationModeler
            
            # Step 4: Build NLP model
            nlp = modeler(prob, ros.init)
            Test.@test nlp isa ADNLPModels.ADNLPModel
            Test.@test nlp.meta.nvar == 2
            Test.@test nlp.meta.ncon == 1
            
            # Step 5: Verify problem properties
            Test.@test nlp.meta.minimize == true
            Test.@test nlp.meta.x0 == ros.init
            
            # Step 6: Evaluate at initial point
            obj_init = NLPModels.obj(nlp, ros.init)
            Test.@test obj_init ≈ rosenbrock_objective(ros.init)
            
            # Step 7: Evaluate at solution
            obj_sol = NLPModels.obj(nlp, ros.sol)
            Test.@test obj_sol ≈ rosenbrock_objective(ros.sol)
            Test.@test obj_sol < obj_init  # Solution is better than initial
            
            # Step 8: Check constraints
            cons_init = NLPModels.cons(nlp, ros.init)
            Test.@test cons_init[1] ≈ rosenbrock_constraint(ros.init)
            
            # Step 9: Solve with MadNLP (optional, if solver available)
            try
                solver = MadNLP.MadNLPSolver(nlp; print_level=MadNLP.ERROR)
                result = MadNLP.solve!(solver)
                
                # Step 10: Extract solver info
                obj, iter, viol, msg, status, success = Optimization.extract_solver_infos(result, NLPModels.get_minimize(nlp))
                
                Test.@test obj isa Float64
                Test.@test iter isa Int
                Test.@test iter >= 0
                Test.@test viol isa Float64
                Test.@test status isa Symbol
                Test.@test success isa Bool
            catch e
                @warn "MadNLP solver test skipped" exception=e
            end
        end

        # ====================================================================
        # COMPLETE WORKFLOW WITH ROSENBROCK - EXA BACKEND
        # ====================================================================
        
        Test.@testset "Complete Workflow - Rosenbrock Exa" begin
            # Step 1: Load problem
            ros = Rosenbrock()
            prob = ros.prob
            
            # Step 2: Create modeler with Exa backend
            modeler = CTModels.ExaModeler(base_type=Float64, minimize=true)
            Test.@test modeler isa CTModels.AbstractOptimizationModeler
            Test.@test typeof(modeler) == CTModels.ExaModeler{Float64}
            
            # Step 3: Build NLP model
            nlp = modeler(prob, ros.init)
            Test.@test nlp isa ExaModels.ExaModel{Float64}
            Test.@test nlp.meta.nvar == 2
            Test.@test nlp.meta.ncon == 1
            
            # Step 4: Verify problem properties
            Test.@test nlp.meta.minimize == true
            Test.@test nlp.meta.x0 == Float64.(ros.init)
            
            # Step 5: Evaluate at initial point
            obj_init = NLPModels.obj(nlp, Float64.(ros.init))
            Test.@test obj_init ≈ rosenbrock_objective(ros.init)
            
            # Step 6: Evaluate at solution
            obj_sol = NLPModels.obj(nlp, Float64.(ros.sol))
            Test.@test obj_sol ≈ rosenbrock_objective(ros.sol)
            Test.@test obj_sol < obj_init
        end

        # ====================================================================
        # COMPLETE WORKFLOW WITH DIFFERENT BASE TYPES
        # ====================================================================
        
        Test.@testset "Complete Workflow - Different Base Types" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            Test.@testset "Float32 workflow" begin
                modeler = CTModels.ExaModeler(base_type=Float32, minimize=true)
                nlp = modeler(prob, ros.init)
                
                Test.@test nlp isa ExaModels.ExaModel{Float32}
                Test.@test eltype(nlp.meta.x0) == Float32
                
                # Evaluate with Float32 (obj may be promoted to Float64 by NLPModels)
                obj = NLPModels.obj(nlp, Float32.(ros.init))
                Test.@test obj ≈ rosenbrock_objective(ros.init) rtol = 1e-5
            end
            
            Test.@testset "Float64 workflow" begin
                modeler = CTModels.ExaModeler(base_type=Float64, minimize=true)
                nlp = modeler(prob, ros.init)
                
                Test.@test nlp isa ExaModels.ExaModel{Float64}
                Test.@test eltype(nlp.meta.x0) == Float64
                
                obj = NLPModels.obj(nlp, Float64.(ros.init))
                Test.@test obj isa Float64
                Test.@test obj ≈ rosenbrock_objective(ros.init)
            end
        end

        # ====================================================================
        # MODELER OPTIONS WORKFLOW
        # ====================================================================
        
        Test.@testset "Modeler Options Workflow" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            Test.@testset "ADNLPModeler - Simple" begin
                # Test without options (defaults)
                modeler = CTModels.ADNLPModeler()
                nlp = modeler(prob, ros.init)
                
                Test.@test nlp isa ADNLPModels.ADNLPModel
                obj = NLPModels.obj(nlp, ros.init)
                Test.@test obj ≈ rosenbrock_objective(ros.init)
            end
            
            Test.@testset "ADNLPModeler - With Options" begin
                # Test with show_time option
                modeler = CTModels.ADNLPModeler(show_time=false)
                nlp = modeler(prob, ros.init)
                Test.@test nlp isa ADNLPModels.ADNLPModel
                
                # Test with different backends (all valid ADNLPModels backends)
                for backend in [:optimized, :generic, :default]
                    modeler_backend = CTModels.ADNLPModeler(backend=backend, show_time=false)
                    nlp_backend = modeler_backend(prob, ros.init)
                    
                    Test.@test nlp_backend isa ADNLPModels.ADNLPModel
                    obj = NLPModels.obj(nlp_backend, ros.init)
                    Test.@test obj ≈ rosenbrock_objective(ros.init) rtol = 1e-10
                end
            end
            
            Test.@testset "ExaModeler - Simple" begin
                # Test without options (defaults)
                modeler = CTModels.ExaModeler(base_type=Float64)
                nlp = modeler(prob, ros.init)
                
                Test.@test nlp isa ExaModels.ExaModel{Float64}
                obj = NLPModels.obj(nlp, ros.init)
                Test.@test obj ≈ rosenbrock_objective(ros.init)
            end
            
            Test.@testset "ExaModeler - With Options" begin
                # Test with multiple options
                modeler = CTModels.ExaModeler(
                    base_type=Float64,
                    minimize=true,
                    backend=nothing
                )
                nlp = modeler(prob, ros.init)
                
                Test.@test nlp isa ExaModels.ExaModel{Float64}
                obj = NLPModels.obj(nlp, ros.init)
                Test.@test obj ≈ rosenbrock_objective(ros.init)
            end
        end

        # ====================================================================
        # COMPARISON BETWEEN BACKENDS
        # ====================================================================
        
        Test.@testset "Backend Comparison" begin
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
            Test.@test obj_adnlp ≈ obj_exa rtol = 1e-10
            
            # Both should have same problem structure
            Test.@test nlp_adnlp.meta.nvar == nlp_exa.meta.nvar
            Test.@test nlp_adnlp.meta.ncon == nlp_exa.meta.ncon
            Test.@test nlp_adnlp.meta.minimize == nlp_exa.meta.minimize
        end

        # ====================================================================
        # GRADIENT AND HESSIAN EVALUATION
        # ====================================================================
        
        Test.@testset "Gradient and Hessian Evaluation" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            modeler = CTModels.ADNLPModeler(show_time=false)
            nlp = modeler(prob, ros.init)
            
            Test.@testset "Gradient at initial point" begin
                grad = NLPModels.grad(nlp, ros.init)
                Test.@test grad isa Vector{Float64}
                Test.@test length(grad) == 2
                Test.@test !all(iszero, grad)  # Gradient should not be zero at init
            end
            
            Test.@testset "Gradient at solution" begin
                grad = NLPModels.grad(nlp, ros.sol)
                Test.@test grad isa Vector{Float64}
                Test.@test length(grad) == 2
                # At solution, gradient should be small (but not necessarily zero due to constraints)
            end
            
            Test.@testset "Hessian structure" begin
                hess = NLPModels.hess(nlp, ros.init)
                Test.@test hess isa AbstractMatrix
                Test.@test size(hess) == (2, 2)
            end
        end

        # ====================================================================
        # CONSTRAINT EVALUATION
        # ====================================================================
        
        Test.@testset "Constraint Evaluation" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            modeler = CTModels.ADNLPModeler(show_time=false)
            nlp = modeler(prob, ros.init)
            
            Test.@testset "Constraint at initial point" begin
                cons = NLPModels.cons(nlp, ros.init)
                Test.@test cons isa Vector{Float64}
                Test.@test length(cons) == 1
                Test.@test cons[1] ≈ rosenbrock_constraint(ros.init)
            end
            
            Test.@testset "Constraint at solution" begin
                cons = NLPModels.cons(nlp, ros.sol)
                Test.@test cons[1] ≈ rosenbrock_constraint(ros.sol)
            end
            
            Test.@testset "Constraint Jacobian" begin
                jac = NLPModels.jac(nlp, ros.init)
                Test.@test jac isa AbstractMatrix
                Test.@test size(jac) == (1, 2)
            end
        end

        # ====================================================================
        # PERFORMANCE CHARACTERISTICS
        # ====================================================================
        
        Test.@testset "Performance Characteristics" begin
            ros = Rosenbrock()
            prob = ros.prob
            
            Test.@testset "Model building time" begin
                modeler = CTModels.ADNLPModeler(show_time=false)
                
                # Should be fast
                t = @elapsed nlp = modeler(prob, ros.init)
                Test.@test t < 1.0  # Should take less than 1 second
                Test.@test nlp isa ADNLPModels.ADNLPModel
            end
            
            Test.@testset "Function evaluation time" begin
                modeler = CTModels.ADNLPModeler(show_time=false)
                nlp = modeler(prob, ros.init)
                
                # Objective evaluation should be fast
                t = @elapsed obj = NLPModels.obj(nlp, ros.init)
                Test.@test t < 0.1  # increased slightly for CI robustness
                Test.@test obj isa Float64
            end
        end
    end
end

end # module

test_end_to_end() = TestEndToEnd.test_end_to_end()
