# Tests for strategy registry API

using CTModels.Strategies
using CTModels.Options

# ============================================================================
# Fake strategy types for testing (must be at module top-level)
# ============================================================================

abstract type AbstractTestFamily <: CTModels.Strategies.AbstractStrategy end
abstract type AbstractOtherFamily <: CTModels.Strategies.AbstractStrategy end

struct TestStrategyA <: AbstractTestFamily
    options::CTModels.Strategies.StrategyOptions
end

struct TestStrategyB <: AbstractTestFamily
    options::CTModels.Strategies.StrategyOptions
end

struct TestStrategyC <: AbstractOtherFamily
    options::CTModels.Strategies.StrategyOptions
end

struct WrongTypeStrategy <: CTModels.Strategies.AbstractStrategy
    options::CTModels.Strategies.StrategyOptions
end

# ============================================================================
# Implement contract methods
# ============================================================================

CTModels.Strategies.id(::Type{<:TestStrategyA}) = :strategy_a
CTModels.Strategies.id(::Type{<:TestStrategyB}) = :strategy_b
CTModels.Strategies.id(::Type{<:TestStrategyC}) = :strategy_c
CTModels.Strategies.id(::Type{<:WrongTypeStrategy}) = :wrong

CTModels.Strategies.metadata(::Type{<:TestStrategyA}) = CTModels.Strategies.StrategyMetadata()
CTModels.Strategies.metadata(::Type{<:TestStrategyB}) = CTModels.Strategies.StrategyMetadata()
CTModels.Strategies.metadata(::Type{<:TestStrategyC}) = CTModels.Strategies.StrategyMetadata()
CTModels.Strategies.metadata(::Type{<:WrongTypeStrategy}) = CTModels.Strategies.StrategyMetadata()

# ============================================================================
# Test function
# ============================================================================

function test_registry()
    Test.@testset "Strategy Registry API" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ========================================================================
        # UNIT TESTS
        # ========================================================================
        
        Test.@testset "Unit Tests" begin
            
            Test.@testset "StrategyRegistry type" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, TestStrategyB)
                )
                Test.@test registry isa CTModels.Strategies.StrategyRegistry
                Test.@test hasfield(typeof(registry), :families)
            end
            
            Test.@testset "create_registry - basic creation" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, TestStrategyB),
                    AbstractOtherFamily => (TestStrategyC,)
                )
                
                Test.@test registry isa CTModels.Strategies.StrategyRegistry
                Test.@test length(registry.families) == 2
                Test.@test haskey(registry.families, AbstractTestFamily)
                Test.@test haskey(registry.families, AbstractOtherFamily)
            end
            
            Test.@testset "create_registry - empty registry" begin
                registry = CTModels.Strategies.create_registry()
                Test.@test registry isa CTModels.Strategies.StrategyRegistry
                Test.@test length(registry.families) == 0
            end
            
            Test.@testset "create_registry - single family" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA,)
                )
                Test.@test length(registry.families) == 1
                Test.@test length(registry.families[AbstractTestFamily]) == 1
            end
            
            Test.@testset "create_registry - validation: duplicate IDs" begin
                # Create a duplicate ID by reusing TestStrategyA
                Test.@test_throws CTBase.IncorrectArgument CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, TestStrategyA)
                )
            end
            
            Test.@testset "create_registry - validation: wrong type hierarchy" begin
                # WrongTypeStrategy is not a subtype of AbstractTestFamily
                Test.@test_throws CTBase.IncorrectArgument CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, WrongTypeStrategy)
                )
            end
            
            Test.@testset "create_registry - validation: duplicate family" begin
                Test.@test_throws CTBase.IncorrectArgument CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA,),
                    AbstractTestFamily => (TestStrategyB,)
                )
            end
            
            Test.@testset "strategy_ids - basic lookup" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, TestStrategyB),
                    AbstractOtherFamily => (TestStrategyC,)
                )
                
                ids = CTModels.Strategies.strategy_ids(AbstractTestFamily, registry)
                Test.@test ids isa Tuple
                Test.@test length(ids) == 2
                Test.@test :strategy_a in ids
                Test.@test :strategy_b in ids
                
                other_ids = CTModels.Strategies.strategy_ids(AbstractOtherFamily, registry)
                Test.@test length(other_ids) == 1
                Test.@test :strategy_c in other_ids
            end
            
            Test.@testset "strategy_ids - empty family" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => ()
                )
                ids = CTModels.Strategies.strategy_ids(AbstractTestFamily, registry)
                Test.@test ids isa Tuple
                Test.@test length(ids) == 0
            end
            
            Test.@testset "strategy_ids - unknown family" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA,)
                )
                Test.@test_throws CTBase.IncorrectArgument CTModels.Strategies.strategy_ids(
                    AbstractOtherFamily, registry
                )
            end
            
            Test.@testset "type_from_id - basic lookup" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, TestStrategyB)
                )
                
                T = CTModels.Strategies.type_from_id(:strategy_a, AbstractTestFamily, registry)
                Test.@test T === TestStrategyA
                
                T2 = CTModels.Strategies.type_from_id(:strategy_b, AbstractTestFamily, registry)
                Test.@test T2 === TestStrategyB
            end
            
            Test.@testset "type_from_id - unknown ID" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA,)
                )
                Test.@test_throws CTBase.IncorrectArgument CTModels.Strategies.type_from_id(
                    :nonexistent, AbstractTestFamily, registry
                )
            end
            
            Test.@testset "type_from_id - unknown family" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA,)
                )
                Test.@test_throws CTBase.IncorrectArgument CTModels.Strategies.type_from_id(
                    :strategy_a, AbstractOtherFamily, registry
                )
            end
            
            Test.@testset "Display - show(io, registry)" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, TestStrategyB)
                )
                io = IOBuffer()
                show(io, registry)
                output = String(take!(io))
                Test.@test occursin("StrategyRegistry", output)
                Test.@test occursin("families", output) || occursin("family", output)
            end
            
            Test.@testset "Display - show(io, MIME, registry)" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, TestStrategyB),
                    AbstractOtherFamily => (TestStrategyC,)
                )
                io = IOBuffer()
                show(io, MIME("text/plain"), registry)
                output = String(take!(io))
                Test.@test occursin("StrategyRegistry", output)
                Test.@test occursin("AbstractTestFamily", output)
                Test.@test occursin("AbstractOtherFamily", output)
            end
        end
        
        # ========================================================================
        # INTEGRATION TESTS
        # ========================================================================
        
        Test.@testset "Integration Tests" begin
            
            Test.@testset "Registry with multiple families" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, TestStrategyB),
                    AbstractOtherFamily => (TestStrategyC,)
                )
                
                # Lookup across families
                T1 = CTModels.Strategies.type_from_id(:strategy_a, AbstractTestFamily, registry)
                T2 = CTModels.Strategies.type_from_id(:strategy_c, AbstractOtherFamily, registry)
                
                Test.@test T1 === TestStrategyA
                Test.@test T2 === TestStrategyC
                Test.@test T1 !== T2
                
                # IDs are scoped to families
                ids1 = CTModels.Strategies.strategy_ids(AbstractTestFamily, registry)
                ids2 = CTModels.Strategies.strategy_ids(AbstractOtherFamily, registry)
                Test.@test length(ids1) == 2
                Test.@test length(ids2) == 1
            end
            
            Test.@testset "Round-trip: type -> id -> type" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA, TestStrategyB)
                )
                
                original_type = TestStrategyA
                strategy_id = CTModels.Strategies.id(original_type)
                retrieved_type = CTModels.Strategies.type_from_id(
                    strategy_id, AbstractTestFamily, registry
                )
                
                Test.@test retrieved_type === original_type
            end
            
            Test.@testset "Registry immutability" begin
                registry = CTModels.Strategies.create_registry(
                    AbstractTestFamily => (TestStrategyA,)
                )
                
                # Registry should be immutable - cannot add families after creation
                Test.@test !ismutable(registry)
            end
        end
    end
end
