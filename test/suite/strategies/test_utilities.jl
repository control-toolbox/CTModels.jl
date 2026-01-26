module TestStrategiesUtilities

using Test
using CTModels
using CTModels.Strategies
using CTModels.Options: OptionDefinition
using Main.TestOptions: VERBOSE, SHOWTIMING

# ============================================================================
# Test strategy for suggestions
# ============================================================================

abstract type AbstractTestUtilStrategy <: CTModels.Strategies.AbstractStrategy end

struct TestUtilStrategy <: AbstractTestUtilStrategy
    options::CTModels.Strategies.StrategyOptions
end

CTModels.Strategies.id(::Type{TestUtilStrategy}) = :test_util

CTModels.Strategies.metadata(::Type{TestUtilStrategy}) = CTModels.Strategies.StrategyMetadata(
    OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 100,
        description = "Maximum iterations",
        aliases = (:max, :maxiter)
    ),
    OptionDefinition(
        name = :tolerance,
        type = Float64,
        default = 1e-6,
        description = "Convergence tolerance",
        aliases = (:tol,)
    ),
    OptionDefinition(
        name = :verbose,
        type = Bool,
        default = false,
        description = "Verbose output"
    )
)

CTModels.Strategies.options(s::TestUtilStrategy) = s.options

# ============================================================================
# Test function
# ============================================================================

"""
    test_utilities()

Tests for strategy utilities.
"""
function test_utilities()
    Test.@testset "Strategy Utilities" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # filter_options - Single key
        # ====================================================================
        
        Test.@testset "filter_options - single key" begin
            opts = (max_iter=100, tolerance=1e-6, verbose=true, debug=false)
            
            # Filter single key
            filtered = CTModels.Strategies.filter_options(opts, :debug)
            Test.@test filtered == (max_iter=100, tolerance=1e-6, verbose=true)
            Test.@test !haskey(filtered, :debug)
            Test.@test haskey(filtered, :max_iter)
            Test.@test haskey(filtered, :tolerance)
            Test.@test haskey(filtered, :verbose)
            
            # Filter another key
            filtered2 = CTModels.Strategies.filter_options(opts, :verbose)
            Test.@test filtered2 == (max_iter=100, tolerance=1e-6, debug=false)
            Test.@test !haskey(filtered2, :verbose)
            
            # Filter non-existent key (should not error)
            filtered3 = CTModels.Strategies.filter_options(opts, :nonexistent)
            Test.@test filtered3 == opts
            Test.@test length(filtered3) == 4
        end
        
        # ====================================================================
        # filter_options - Multiple keys
        # ====================================================================
        
        Test.@testset "filter_options - multiple keys" begin
            opts = (max_iter=100, tolerance=1e-6, verbose=true, debug=false)
            
            # Filter two keys
            filtered1 = CTModels.Strategies.filter_options(opts, (:debug, :verbose))
            Test.@test filtered1 == (max_iter=100, tolerance=1e-6)
            Test.@test !haskey(filtered1, :debug)
            Test.@test !haskey(filtered1, :verbose)
            Test.@test length(filtered1) == 2
            
            # Filter three keys
            filtered2 = CTModels.Strategies.filter_options(opts, (:debug, :verbose, :tolerance))
            Test.@test filtered2 == (max_iter=100,)
            Test.@test length(filtered2) == 1
            
            # Filter all keys
            filtered3 = CTModels.Strategies.filter_options(opts, (:max_iter, :tolerance, :verbose, :debug))
            Test.@test filtered3 == NamedTuple()
            Test.@test length(filtered3) == 0
            Test.@test isempty(filtered3)
            
            # Filter with some non-existent keys
            filtered4 = CTModels.Strategies.filter_options(opts, (:debug, :nonexistent))
            Test.@test filtered4 == (max_iter=100, tolerance=1e-6, verbose=true)
        end
        
        # ====================================================================
        # suggest_options
        # ====================================================================
        
        Test.@testset "suggest_options" begin
            # Similar to existing option
            suggestions1 = CTModels.Strategies.suggest_options(:max_it, TestUtilStrategy)
            Test.@test suggestions1 isa Vector{Symbol}
            Test.@test !isempty(suggestions1)
            Test.@test :max_iter in suggestions1 || :max in suggestions1 || :maxiter in suggestions1
            
            # Similar to alias
            suggestions2 = CTModels.Strategies.suggest_options(:tolrance, TestUtilStrategy)
            Test.@test :tolerance in suggestions2 || :tol in suggestions2
            
            # Very different key
            suggestions3 = CTModels.Strategies.suggest_options(:xyz, TestUtilStrategy)
            Test.@test length(suggestions3) <= 3  # Default max_suggestions
            Test.@test !isempty(suggestions3)
            
            # Limit suggestions
            suggestions4 = CTModels.Strategies.suggest_options(:x, TestUtilStrategy; max_suggestions=2)
            Test.@test length(suggestions4) <= 2
            Test.@test suggestions4 isa Vector{Symbol}
            
            # Single suggestion
            suggestions5 = CTModels.Strategies.suggest_options(:unknown, TestUtilStrategy; max_suggestions=1)
            Test.@test length(suggestions5) == 1
            
            # Exact match should be first suggestion
            suggestions6 = CTModels.Strategies.suggest_options(:max_iter, TestUtilStrategy)
            Test.@test suggestions6[1] == :max_iter
        end
        
        # ====================================================================
        # levenshtein_distance
        # ====================================================================
        
        Test.@testset "levenshtein_distance" begin
            # Identical strings
            Test.@test CTModels.Strategies.levenshtein_distance("test", "test") == 0
            Test.@test CTModels.Strategies.levenshtein_distance("", "") == 0
            Test.@test CTModels.Strategies.levenshtein_distance("hello", "hello") == 0
            
            # Single character difference - substitution
            Test.@test CTModels.Strategies.levenshtein_distance("test", "best") == 1
            Test.@test CTModels.Strategies.levenshtein_distance("test", "text") == 1
            Test.@test CTModels.Strategies.levenshtein_distance("cat", "bat") == 1
            
            # Single character difference - insertion
            Test.@test CTModels.Strategies.levenshtein_distance("test", "tests") == 1
            Test.@test CTModels.Strategies.levenshtein_distance("cat", "cart") == 1
            
            # Single character difference - deletion
            Test.@test CTModels.Strategies.levenshtein_distance("tests", "test") == 1
            Test.@test CTModels.Strategies.levenshtein_distance("cart", "cat") == 1
            
            # Multiple differences
            Test.@test CTModels.Strategies.levenshtein_distance("kitten", "sitting") == 3
            Test.@test CTModels.Strategies.levenshtein_distance("saturday", "sunday") == 3
            
            # Empty strings
            Test.@test CTModels.Strategies.levenshtein_distance("test", "") == 4
            Test.@test CTModels.Strategies.levenshtein_distance("", "test") == 4
            Test.@test CTModels.Strategies.levenshtein_distance("hello", "") == 5
            
            # Relevant for option names
            Test.@test CTModels.Strategies.levenshtein_distance("max_iter", "max_it") == 2
            Test.@test CTModels.Strategies.levenshtein_distance("tolerance", "tolrance") == 1
            Test.@test CTModels.Strategies.levenshtein_distance("verbose", "verbos") == 1
            
            # Symmetry property
            Test.@test CTModels.Strategies.levenshtein_distance("abc", "def") == 
                       CTModels.Strategies.levenshtein_distance("def", "abc")
            Test.@test CTModels.Strategies.levenshtein_distance("hello", "world") == 
                       CTModels.Strategies.levenshtein_distance("world", "hello")
        end
        
        # ====================================================================
        # Integration: Utilities pipeline
        # ====================================================================
        
        Test.@testset "Integration: Utilities pipeline" begin
            # Create options and filter
            opts = (max_iter=100, tolerance=1e-6, verbose=true, debug=false, extra=:value)
            
            # Filter debug options
            filtered = CTModels.Strategies.filter_options(opts, (:debug, :extra))
            Test.@test filtered == (max_iter=100, tolerance=1e-6, verbose=true)
            
            # Get suggestions for typo
            suggestions = CTModels.Strategies.suggest_options(:max_itr, TestUtilStrategy)
            Test.@test :max_iter in suggestions || :max in suggestions
            
            # Verify distance calculation
            dist = CTModels.Strategies.levenshtein_distance("max_itr", "max_iter")
            Test.@test dist == 1  # One character difference
        end
    end
end

end # module

test_utilities() = TestStrategiesUtilities.test_utilities()
