module TestRealProblems

using Test
using CTModels
using CTBase
using NLPModels
using SolverCore
using ADNLPModels
using ExaModels
using ..TestProblems

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Import from Optimization module
import CTModels.Optimization
import CTModels.Optimization: AbstractOptimizationProblem
import CTModels.Optimization: get_adnlp_model_builder, get_exa_model_builder

# ============================================================================
# TEST FUNCTION
# ============================================================================

function test_real_problems()
    @testset "Optimization with Real Problems" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # TESTS WITH ROSENBROCK PROBLEM
        # ====================================================================
        
        @testset "Rosenbrock Problem" begin
            # Load Rosenbrock problem from TestProblems module
            ros = Rosenbrock()
            
            @testset "ADNLPModelBuilder with Rosenbrock" begin
                # Get the builder from the problem
                builder = get_adnlp_model_builder(ros.prob)
                @test builder isa Optimization.ADNLPModelBuilder
                
                # Build the NLP model
                nlp = builder(ros.init; show_time=false)
                @test nlp isa ADNLPModels.ADNLPModel
                @test nlp.meta.x0 == ros.init
                @test nlp.meta.minimize == true
                
                # Test objective evaluation
                obj_val = NLPModels.obj(nlp, ros.init)
                expected_obj = rosenbrock_objective(ros.init)
                @test obj_val ≈ expected_obj
                
                # Test constraint evaluation
                cons_val = NLPModels.cons(nlp, ros.init)
                expected_cons = rosenbrock_constraint(ros.init)
                @test cons_val[1] ≈ expected_cons
            end
            
            @testset "ExaModelBuilder with Rosenbrock" begin
                # Get the builder from the problem
                builder = get_exa_model_builder(ros.prob)
                @test builder isa Optimization.ExaModelBuilder
                
                # Build the NLP model with Float64
                nlp64 = builder(Float64, ros.init)
                @test nlp64 isa ExaModels.ExaModel{Float64}
                @test nlp64.meta.x0 == Float64.(ros.init)
                @test nlp64.meta.minimize == true
                
                # Test objective evaluation
                obj_val = NLPModels.obj(nlp64, nlp64.meta.x0)
                expected_obj = rosenbrock_objective(Float64.(ros.init))
                @test obj_val ≈ expected_obj
                
                # Test constraint evaluation
                cons_val = NLPModels.cons(nlp64, nlp64.meta.x0)
                expected_cons = rosenbrock_constraint(Float64.(ros.init))
                @test cons_val[1] ≈ expected_cons
            end
            
            @testset "ExaModelBuilder with Rosenbrock - Float32" begin
                # Get the builder from the problem
                builder = get_exa_model_builder(ros.prob)
                
                # Build the NLP model with Float32
                nlp32 = builder(Float32, ros.init)
                @test nlp32 isa ExaModels.ExaModel{Float32}
                @test nlp32.meta.x0 == Float32.(ros.init)
                @test eltype(nlp32.meta.x0) == Float32
                @test nlp32.meta.minimize == true
                
                # Test objective evaluation
                obj_val = NLPModels.obj(nlp32, nlp32.meta.x0)
                expected_obj = rosenbrock_objective(Float32.(ros.init))
                @test obj_val ≈ expected_obj
                
                # Test constraint evaluation
                cons_val = NLPModels.cons(nlp32, nlp32.meta.x0)
                expected_cons = rosenbrock_constraint(Float32.(ros.init))
                @test cons_val[1] ≈ expected_cons
            end
        end

        # ====================================================================
        # INTEGRATION TESTS WITH REAL PROBLEMS
        # ====================================================================
        
        @testset "Integration with Real Problems" begin
            @testset "Complete workflow - Rosenbrock ADNLP" begin
                ros = Rosenbrock()
                
                # Get builder
                builder = get_adnlp_model_builder(ros.prob)
                
                # Build model
                nlp = builder(ros.init; show_time=false)
                @test nlp isa ADNLPModels.ADNLPModel
                
                # Verify problem properties
                @test nlp.meta.nvar == 2
                @test nlp.meta.ncon == 1
                @test nlp.meta.minimize == true
                
                # Verify at initial point
                @test NLPModels.obj(nlp, ros.init) ≈ rosenbrock_objective(ros.init)
                
                # Verify at solution
                @test NLPModels.obj(nlp, ros.sol) ≈ rosenbrock_objective(ros.sol)
                @test rosenbrock_objective(ros.sol) < rosenbrock_objective(ros.init)
            end
            
            @testset "Complete workflow - Rosenbrock Exa" begin
                ros = Rosenbrock()
                
                # Get builder
                builder = get_exa_model_builder(ros.prob)
                
                # Build model
                nlp = builder(Float64, ros.init)
                @test nlp isa ExaModels.ExaModel{Float64}
                
                # Verify problem properties
                @test nlp.meta.nvar == 2
                @test nlp.meta.ncon == 1
                @test nlp.meta.minimize == true
                
                # Verify at initial point
                @test NLPModels.obj(nlp, Float64.(ros.init)) ≈ rosenbrock_objective(ros.init)
                
                # Verify at solution
                @test NLPModels.obj(nlp, Float64.(ros.sol)) ≈ rosenbrock_objective(ros.sol)
            end
        end
    end
end

end # module

test_real_problems() = TestRealProblems.test_real_problems()
