module TestOrchestrationDisambiguation

using Test
using CTModels
using CTModels.Orchestration
using CTModels.Strategies
using CTModels.Options
using CTBase
using Main.TestOptions: VERBOSE, SHOWTIMING

# ============================================================================
# Test fixtures (minimal strategy setup)
# ============================================================================

abstract type TestDiscretizer <: Strategies.AbstractStrategy end
abstract type TestModeler <: Strategies.AbstractStrategy end
abstract type TestSolver <: Strategies.AbstractStrategy end

struct CollocationDiscretizer <: TestDiscretizer end
Strategies.id(::Type{CollocationDiscretizer}) = :collocation
Strategies.metadata(::Type{CollocationDiscretizer}) = Strategies.StrategyMetadata()

struct ADNLPModeler <: TestModeler end
Strategies.id(::Type{ADNLPModeler}) = :adnlp
Strategies.metadata(::Type{ADNLPModeler}) = Strategies.StrategyMetadata(
    Options.OptionDefinition(
        name = :backend,
        type = Symbol,
        default = :dense,
        description = "Backend type"
    )
)

struct IpoptSolver <: TestSolver end
Strategies.id(::Type{IpoptSolver}) = :ipopt
Strategies.metadata(::Type{IpoptSolver}) = Strategies.StrategyMetadata(
    Options.OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 1000,
        description = "Maximum iterations"
    ),
    Options.OptionDefinition(
        name = :backend,
        type = Symbol,
        default = :cpu,
        description = "Solver backend"
    )
)

const TEST_REGISTRY = Strategies.create_registry(
    TestDiscretizer => (CollocationDiscretizer,),
    TestModeler => (ADNLPModeler,),
    TestSolver => (IpoptSolver,)
)

const TEST_METHOD = (:collocation, :adnlp, :ipopt)

const TEST_FAMILIES = (
    discretizer = TestDiscretizer,
    modeler = TestModeler,
    solver = TestSolver
)

# ============================================================================
# Test function
# ============================================================================

function test_disambiguation()
    Test.@testset "Orchestration Disambiguation" verbose = VERBOSE showtiming = SHOWTIMING begin
        
        # ====================================================================
        # extract_strategy_ids - Unit Tests
        # ====================================================================
        
        Test.@testset "extract_strategy_ids" begin
            # No disambiguation - plain value
            Test.@test Orchestration.extract_strategy_ids(:sparse, TEST_METHOD) === nothing
            Test.@test Orchestration.extract_strategy_ids(100, TEST_METHOD) === nothing
            Test.@test Orchestration.extract_strategy_ids("string", TEST_METHOD) === nothing
            
            # Single strategy disambiguation
            result = Orchestration.extract_strategy_ids((:sparse, :adnlp), TEST_METHOD)
            Test.@test result isa Vector{Tuple{Any,Symbol}}
            Test.@test length(result) == 1
            Test.@test result[1] == (:sparse, :adnlp)
            
            # Multi-strategy disambiguation
            result = Orchestration.extract_strategy_ids(
                ((:sparse, :adnlp), (:cpu, :ipopt)),
                TEST_METHOD
            )
            Test.@test result isa Vector{Tuple{Any,Symbol}}
            Test.@test length(result) == 2
            Test.@test result[1] == (:sparse, :adnlp)
            Test.@test result[2] == (:cpu, :ipopt)
            
            # Invalid strategy ID in single disambiguation
            Test.@test_throws CTModels.Exceptions.IncorrectArgument Orchestration.extract_strategy_ids(
                (:sparse, :unknown),
                TEST_METHOD
            )
            
            # Invalid strategy ID in multi disambiguation
            Test.@test_throws CTModels.Exceptions.IncorrectArgument Orchestration.extract_strategy_ids(
                ((:sparse, :adnlp), (:cpu, :unknown)),
                TEST_METHOD
            )
            
            # Mixed valid/invalid tuples - should return nothing
            result = Orchestration.extract_strategy_ids(
                ((:sparse, :adnlp), :plain_value),
                TEST_METHOD
            )
            Test.@test result === nothing
            
            # Another mixed case
            result2 = Orchestration.extract_strategy_ids(
                ((:sparse, :adnlp), 100),
                TEST_METHOD
            )
            Test.@test result2 === nothing
            
            # Empty tuple
            Test.@test Orchestration.extract_strategy_ids((), TEST_METHOD) === nothing
        end
        
        # ====================================================================
        # build_strategy_to_family_map - Unit Tests
        # ====================================================================
        
        Test.@testset "build_strategy_to_family_map" begin
            map = Orchestration.build_strategy_to_family_map(
                TEST_METHOD, TEST_FAMILIES, TEST_REGISTRY
            )
            
            Test.@test map isa Dict{Symbol,Symbol}
            Test.@test length(map) == 3
            Test.@test map[:collocation] == :discretizer
            Test.@test map[:adnlp] == :modeler
            Test.@test map[:ipopt] == :solver
        end
        
        # ====================================================================
        # build_option_ownership_map - Unit Tests
        # ====================================================================
        
        Test.@testset "build_option_ownership_map" begin
            map = Orchestration.build_option_ownership_map(
                TEST_METHOD, TEST_FAMILIES, TEST_REGISTRY
            )
            
            Test.@test map isa Dict{Symbol,Set{Symbol}}
            
            # max_iter only in solver
            Test.@test haskey(map, :max_iter)
            Test.@test map[:max_iter] == Set([:solver])
            
            # backend in both modeler and solver (ambiguous!)
            Test.@test haskey(map, :backend)
            Test.@test map[:backend] == Set([:modeler, :solver])
            Test.@test length(map[:backend]) == 2
        end
        
        # ====================================================================
        # Integration test
        # ====================================================================
        
        Test.@testset "Integration: Disambiguation workflow" begin
            # Build both maps
            strategy_map = Orchestration.build_strategy_to_family_map(
                TEST_METHOD, TEST_FAMILIES, TEST_REGISTRY
            )
            option_map = Orchestration.build_option_ownership_map(
                TEST_METHOD, TEST_FAMILIES, TEST_REGISTRY
            )
            
            # Simulate disambiguation detection
            disamb = Orchestration.extract_strategy_ids((:sparse, :adnlp), TEST_METHOD)
            Test.@test disamb !== nothing
            Test.@test length(disamb) == 1
            
            value, strategy_id = disamb[1]
            Test.@test value == :sparse
            Test.@test strategy_id == :adnlp
            
            # Verify routing would work
            family = strategy_map[strategy_id]
            Test.@test family == :modeler
            
            # Verify option ownership
            Test.@test :backend in keys(option_map)
            Test.@test family in option_map[:backend]
        end
    end
end

end # module

test_disambiguation() = TestOrchestrationDisambiguation.test_disambiguation()
