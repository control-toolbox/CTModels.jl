# Tests for abstract strategy contract

using CTModels.Strategies
using CTModels.Options

# ============================================================================
# Fake strategy types for testing (must be at module top-level)
# ============================================================================

struct FakeStrategy <: CTModels.Strategies.AbstractStrategy
    options::CTModels.Strategies.StrategyOptions
end

struct IncompleteStrategy <: CTModels.Strategies.AbstractStrategy
    # Missing options field - should trigger error path
end

# ============================================================================
# Implement required contract methods for FakeStrategy
# ============================================================================

CTModels.Strategies.id(::Type{<:FakeStrategy}) = :fake
CTModels.Strategies.id(::Type{<:IncompleteStrategy}) = :incomplete

CTModels.Strategies.metadata(::Type{<:FakeStrategy}) = CTModels.Strategies.StrategyMetadata(
    CTModels.Options.OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 100,
        description = "Maximum iterations",
        aliases = (:max, :maxiter)
    ),
    CTModels.Options.OptionDefinition(
        name = :tol,
        type = Float64,
        default = 1e-6,
        description = "Tolerance"
    )
)

CTModels.Strategies.metadata(::Type{<:IncompleteStrategy}) = CTModels.Strategies.StrategyMetadata()

CTModels.Strategies.options(strategy::FakeStrategy) = strategy.options

# Additional test struct for error handling
struct UnimplementedStrategy <: CTModels.Strategies.AbstractStrategy end

# ============================================================================
# Test function
# ============================================================================

function test_abstract_strategy()
    Test.@testset "Abstract Strategy" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ========================================================================
        # UNIT TESTS
        # ========================================================================
        
        Test.@testset "Unit Tests" begin
            
            Test.@testset "AbstractStrategy type" begin
                Test.@test FakeStrategy <: CTModels.Strategies.AbstractStrategy
                Test.@test IncompleteStrategy <: CTModels.Strategies.AbstractStrategy
            end
            
            Test.@testset "id() type-level" begin
                Test.@test CTModels.Strategies.id(FakeStrategy) == :fake
                Test.@test CTModels.Strategies.id(IncompleteStrategy) == :incomplete
            end
            
            Test.@testset "id() with typeof" begin
                fake_opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user)
                )
                fake_strategy = FakeStrategy(fake_opts)
                
                Test.@test CTModels.Strategies.id(typeof(fake_strategy)) == :fake
                Test.@test CTModels.Strategies.id(typeof(fake_strategy)) == CTModels.Strategies.id(FakeStrategy)
            end
            
            Test.@testset "metadata function" begin
                fake_meta = CTModels.Strategies.metadata(FakeStrategy)
                Test.@test fake_meta isa CTModels.Strategies.StrategyMetadata
                Test.@test length(fake_meta) == 2
                Test.@test :max_iter in keys(fake_meta)
                Test.@test :tol in keys(fake_meta)
                
                incomplete_meta = CTModels.Strategies.metadata(IncompleteStrategy)
                Test.@test incomplete_meta isa CTModels.Strategies.StrategyMetadata
                Test.@test length(incomplete_meta) == 0
            end
            
            Test.@testset "options function" begin
                fake_opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user)
                )
                fake_strategy = FakeStrategy(fake_opts)
                
                retrieved_opts = CTModels.Strategies.options(fake_strategy)
                Test.@test retrieved_opts === fake_opts
                Test.@test retrieved_opts[:max_iter] == 200
            end
            
            Test.@testset "Error handling" begin
                # Test NotImplemented errors for unimplemented methods
                Test.@test_throws CTBase.NotImplemented CTModels.Strategies.id(UnimplementedStrategy)
                Test.@test_throws CTBase.NotImplemented CTModels.Strategies.metadata(UnimplementedStrategy)
                
                # Test options error for strategy without options field
                incomplete_strategy = IncompleteStrategy()
                Test.@test_throws CTBase.NotImplemented CTModels.Strategies.options(incomplete_strategy)
            end
        end
        
        # ========================================================================
        # INTEGRATION TESTS
        # ========================================================================
        
        Test.@testset "Integration Tests" begin
            
            Test.@testset "Complete strategy workflow" begin
                # Create strategy with options
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-8, :user)
                )
                strategy = FakeStrategy(opts)
                
                # Test complete contract
                Test.@test CTModels.Strategies.id(typeof(strategy)) == :fake
                Test.@test CTModels.Strategies.metadata(typeof(strategy)) isa CTModels.Strategies.StrategyMetadata
                Test.@test CTModels.Strategies.options(strategy) === opts
                
                # Verify metadata contains expected options
                meta = CTModels.Strategies.metadata(typeof(strategy))
                Test.@test :max_iter in keys(meta)
                Test.@test meta[:max_iter].type == Int
                Test.@test meta[:max_iter].default == 100
            end
            
            Test.@testset "Strategy with aliases" begin
                # Test that metadata correctly handles aliases
                meta = CTModels.Strategies.metadata(FakeStrategy)
                max_iter_def = meta[:max_iter]
                
                Test.@test max_iter_def.aliases == (:max, :maxiter)
                Test.@test :max_iter in keys(meta)
                Test.@test :tol in keys(meta)
            end
            
            Test.@testset "Strategy display" begin
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-8, :default)
                )
                strategy = FakeStrategy(opts)
                
                # Test that strategy components can be displayed
                Test.@test_nowarn show(stdout, CTModels.Strategies.metadata(typeof(strategy)))
                Test.@test_nowarn show(stdout, CTModels.Strategies.options(strategy))
            end
        end
    end
end
