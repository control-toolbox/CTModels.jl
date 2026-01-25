# ============================================================================
# Unit tests for Orchestration disambiguation helpers
# ============================================================================

using Test
using CTModels.Orchestration
using CTModels.Strategies
using CTModels.Options
using CTBase

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
    @testset "Orchestration Disambiguation" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # extract_strategy_ids - Unit Tests
        # ====================================================================
        
        @testset "extract_strategy_ids" begin
            # No disambiguation - plain value
            @test extract_strategy_ids(:sparse, TEST_METHOD) === nothing
            @test extract_strategy_ids(100, TEST_METHOD) === nothing
            @test extract_strategy_ids("string", TEST_METHOD) === nothing
            
            # Single strategy disambiguation
            result = extract_strategy_ids((:sparse, :adnlp), TEST_METHOD)
            @test result isa Vector{Tuple{Any, Symbol}}
            @test length(result) == 1
            @test result[1] == (:sparse, :adnlp)
            
            # Multi-strategy disambiguation
            result = extract_strategy_ids(
                ((:sparse, :adnlp), (:cpu, :ipopt)),
                TEST_METHOD
            )
            @test result isa Vector{Tuple{Any, Symbol}}
            @test length(result) == 2
            @test result[1] == (:sparse, :adnlp)
            @test result[2] == (:cpu, :ipopt)
            
            # Invalid strategy ID in single disambiguation
            @test_throws CTBase.IncorrectArgument extract_strategy_ids(
                (:sparse, :unknown),
                TEST_METHOD
            )
            
            # Invalid strategy ID in multi disambiguation
            @test_throws CTBase.IncorrectArgument extract_strategy_ids(
                ((:sparse, :adnlp), (:cpu, :unknown)),
                TEST_METHOD
            )
            
            # Mixed valid/invalid tuples - should return nothing
            # (second element is not a (value, :id) tuple)
            result = extract_strategy_ids(
                ((:sparse, :adnlp), :plain_value),
                TEST_METHOD
            )
            @test result === nothing
            
            # Another mixed case - first element valid, second not a tuple
            result2 = extract_strategy_ids(
                ((:sparse, :adnlp), 100),
                TEST_METHOD
            )
            @test result2 === nothing
            
            # Empty tuple
            @test extract_strategy_ids((), TEST_METHOD) === nothing
        end
        
        # ====================================================================
        # build_strategy_to_family_map - Unit Tests
        # ====================================================================
        
        @testset "build_strategy_to_family_map" begin
            map = build_strategy_to_family_map(
                TEST_METHOD, TEST_FAMILIES, TEST_REGISTRY
            )
            
            @test map isa Dict{Symbol, Symbol}
            @test length(map) == 3
            @test map[:collocation] == :discretizer
            @test map[:adnlp] == :modeler
            @test map[:ipopt] == :solver
        end
        
        # ====================================================================
        # build_option_ownership_map - Unit Tests
        # ====================================================================
        
        @testset "build_option_ownership_map" begin
            map = build_option_ownership_map(
                TEST_METHOD, TEST_FAMILIES, TEST_REGISTRY
            )
            
            @test map isa Dict{Symbol, Set{Symbol}}
            
            # max_iter only in solver
            @test haskey(map, :max_iter)
            @test map[:max_iter] == Set([:solver])
            
            # backend in both modeler and solver (ambiguous!)
            @test haskey(map, :backend)
            @test map[:backend] == Set([:modeler, :solver])
            @test length(map[:backend]) == 2
        end
        
        # ====================================================================
        # Integration test
        # ====================================================================
        
        @testset "Integration: Disambiguation workflow" begin
            # Build both maps
            strat_map = build_strategy_to_family_map(
                TEST_METHOD, TEST_FAMILIES, TEST_REGISTRY
            )
            option_map = build_option_ownership_map(
                TEST_METHOD, TEST_FAMILIES, TEST_REGISTRY
            )
            
            # Simulate disambiguation detection
            disamb = extract_strategy_ids((:sparse, :adnlp), TEST_METHOD)
            @test disamb !== nothing
            @test length(disamb) == 1
            
            value, strategy_id = disamb[1]
            @test value == :sparse
            @test strategy_id == :adnlp
            
            # Verify routing would work
            family = strat_map[strategy_id]
            @test family == :modeler
            
            # Verify option ownership
            @test :backend in keys(option_map)
            @test family in option_map[:backend]
        end
    end
end
