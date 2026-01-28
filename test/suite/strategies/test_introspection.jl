module TestStrategiesIntrospection

using Test
using CTModels
using CTModels.Strategies
using CTModels.Options
using Main.TestOptions: VERBOSE, SHOWTIMING

# ============================================================================
# Fake strategy types for testing (must be at module top-level)
# ============================================================================

struct IntrospectionTestStrategy <: CTModels.Strategies.AbstractStrategy
    options::CTModels.Strategies.StrategyOptions
end

struct EmptyOptionsStrategy <: CTModels.Strategies.AbstractStrategy
    options::CTModels.Strategies.StrategyOptions
end

# ============================================================================
# Implement contract methods
# ============================================================================

CTModels.Strategies.id(::Type{<:IntrospectionTestStrategy}) = :introspection_test

CTModels.Strategies.metadata(::Type{<:IntrospectionTestStrategy}) = CTModels.Strategies.StrategyMetadata(
    CTModels.Options.OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 100,
        description = "Maximum number of iterations",
        aliases = (:max, :maxiter)
    ),
    CTModels.Options.OptionDefinition(
        name = :tol,
        type = Float64,
        default = 1e-6,
        description = "Convergence tolerance"
    ),
    CTModels.Options.OptionDefinition(
        name = :backend,
        type = Symbol,
        default = :cpu,
        description = "Execution backend"
    )
)

CTModels.Strategies.id(::Type{<:EmptyOptionsStrategy}) = :empty_options
CTModels.Strategies.metadata(::Type{<:EmptyOptionsStrategy}) = CTModels.Strategies.StrategyMetadata()

# ============================================================================
# Test function
# ============================================================================

"""
    test_introspection()

Tests for strategy introspection utilities.
"""
function test_introspection()
    Test.@testset "Strategy Introspection" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ========================================================================
        # UNIT TESTS
        # ========================================================================
        
        Test.@testset "Unit Tests" begin
            
            # ====================================================================
            # Type-level introspection (metadata access)
            # ====================================================================
            
            Test.@testset "option_names - type-level" begin
                names = CTModels.Strategies.option_names(IntrospectionTestStrategy)
                Test.@test names isa Tuple
                Test.@test length(names) == 3
                Test.@test :max_iter in names
                Test.@test :tol in names
                Test.@test :backend in names
                
                # Empty strategy
                empty_names = CTModels.Strategies.option_names(EmptyOptionsStrategy)
                Test.@test empty_names isa Tuple
                Test.@test length(empty_names) == 0
            end
            
            Test.@testset "option_type - type-level" begin
                Test.@test CTModels.Strategies.option_type(IntrospectionTestStrategy, :max_iter) === Int
                Test.@test CTModels.Strategies.option_type(IntrospectionTestStrategy, :tol) === Float64
                Test.@test CTModels.Strategies.option_type(IntrospectionTestStrategy, :backend) === Symbol
                
                # Unknown option (FieldError in Julia 1.11+, ErrorException in 1.10)
                Test.@test_throws Exception CTModels.Strategies.option_type(
                    IntrospectionTestStrategy, :nonexistent
                )
            end
            
            Test.@testset "option_description - type-level" begin
                desc = CTModels.Strategies.option_description(IntrospectionTestStrategy, :max_iter)
                Test.@test desc isa String
                Test.@test desc == "Maximum number of iterations"
                
                desc2 = CTModels.Strategies.option_description(IntrospectionTestStrategy, :tol)
                Test.@test desc2 == "Convergence tolerance"
                
                # Unknown option (FieldError in Julia 1.11+, ErrorException in 1.10)
                Test.@test_throws Exception CTModels.Strategies.option_description(
                    IntrospectionTestStrategy, :nonexistent
                )
            end
            
            Test.@testset "option_default - type-level" begin
                Test.@test CTModels.Strategies.option_default(IntrospectionTestStrategy, :max_iter) == 100
                Test.@test CTModels.Strategies.option_default(IntrospectionTestStrategy, :tol) == 1e-6
                Test.@test CTModels.Strategies.option_default(IntrospectionTestStrategy, :backend) == :cpu
                
                # Unknown option (FieldError in Julia 1.11+, ErrorException in 1.10)
                Test.@test_throws Exception CTModels.Strategies.option_default(
                    IntrospectionTestStrategy, :nonexistent
                )
            end
            
            Test.@testset "option_defaults - type-level" begin
                defaults = CTModels.Strategies.option_defaults(IntrospectionTestStrategy)
                Test.@test defaults isa NamedTuple
                Test.@test length(defaults) == 3
                Test.@test defaults.max_iter == 100
                Test.@test defaults.tol == 1e-6
                Test.@test defaults.backend == :cpu
                
                # Empty strategy
                empty_defaults = CTModels.Strategies.option_defaults(EmptyOptionsStrategy)
                Test.@test empty_defaults isa NamedTuple
                Test.@test length(empty_defaults) == 0
            end
            
            # ====================================================================
            # Instance-level introspection (configured state access)
            # ====================================================================
            
            Test.@testset "option_value - instance-level" begin
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-8, :user),
                    backend = CTModels.Options.OptionValue(:gpu, :user)
                )
                strategy = IntrospectionTestStrategy(opts)
                
                Test.@test CTModels.Strategies.option_value(strategy, :max_iter) == 200
                Test.@test CTModels.Strategies.option_value(strategy, :tol) == 1e-8
                Test.@test CTModels.Strategies.option_value(strategy, :backend) == :gpu
                
                # Unknown option (NamedTuple throws FieldError in Julia 1.11+, ErrorException in 1.10)
                Test.@test_throws Exception CTModels.Strategies.option_value(strategy, :nonexistent)
            end
            
            Test.@testset "option_source - instance-level" begin
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-6, :default),
                    backend = CTModels.Options.OptionValue(:cpu, :computed)
                )
                strategy = IntrospectionTestStrategy(opts)
                
                Test.@test CTModels.Strategies.option_source(strategy, :max_iter) === :user
                Test.@test CTModels.Strategies.option_source(strategy, :tol) === :default
                Test.@test CTModels.Strategies.option_source(strategy, :backend) === :computed
                
                # Unknown option (NamedTuple throws FieldError in Julia 1.11+, ErrorException in 1.10)
                Test.@test_throws Exception CTModels.Strategies.option_source(strategy, :nonexistent)
            end
            
            Test.@testset "is_user - instance-level" begin
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-6, :default),
                    backend = CTModels.Options.OptionValue(:cpu, :computed)
                )
                strategy = IntrospectionTestStrategy(opts)
                
                Test.@test CTModels.Strategies.is_user(strategy, :max_iter) === true
                Test.@test CTModels.Strategies.is_user(strategy, :tol) === false
                Test.@test CTModels.Strategies.is_user(strategy, :backend) === false
            end
            
            Test.@testset "is_default - instance-level" begin
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-6, :default),
                    backend = CTModels.Options.OptionValue(:cpu, :computed)
                )
                strategy = IntrospectionTestStrategy(opts)
                
                Test.@test CTModels.Strategies.is_default(strategy, :max_iter) === false
                Test.@test CTModels.Strategies.is_default(strategy, :tol) === true
                Test.@test CTModels.Strategies.is_default(strategy, :backend) === false
            end
            
            Test.@testset "is_computed - instance-level" begin
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-6, :default),
                    backend = CTModels.Options.OptionValue(:cpu, :computed)
                )
                strategy = IntrospectionTestStrategy(opts)
                
                Test.@test CTModels.Strategies.is_computed(strategy, :max_iter) === false
                Test.@test CTModels.Strategies.is_computed(strategy, :tol) === false
                Test.@test CTModels.Strategies.is_computed(strategy, :backend) === true
            end
        end
        
        # ========================================================================
        # INTEGRATION TESTS
        # ========================================================================
        
        Test.@testset "Integration Tests" begin
            
            Test.@testset "Type-level vs instance-level consistency" begin
                # Type-level metadata
                type_names = CTModels.Strategies.option_names(IntrospectionTestStrategy)
                type_defaults = CTModels.Strategies.option_defaults(IntrospectionTestStrategy)
                
                # Create instance with user values
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-8, :user),
                    backend = CTModels.Options.OptionValue(:gpu, :user)
                )
                strategy = IntrospectionTestStrategy(opts)
                
                # Type-level should be independent of instance
                Test.@test CTModels.Strategies.option_names(typeof(strategy)) == type_names
                Test.@test CTModels.Strategies.option_defaults(typeof(strategy)) == type_defaults
                
                # Instance values should differ from defaults
                Test.@test CTModels.Strategies.option_value(strategy, :max_iter) != type_defaults.max_iter
                Test.@test CTModels.Strategies.option_value(strategy, :tol) != type_defaults.tol
                Test.@test CTModels.Strategies.option_value(strategy, :backend) != type_defaults.backend
            end
            
            Test.@testset "Provenance tracking workflow" begin
                # Create strategy with mixed sources
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-6, :default),
                    backend = CTModels.Options.OptionValue(:cpu, :computed)
                )
                strategy = IntrospectionTestStrategy(opts)
                
                # Verify provenance predicates are mutually exclusive
                for key in (:max_iter, :tol, :backend)
                    sources = [
                        CTModels.Strategies.is_user(strategy, key),
                        CTModels.Strategies.is_default(strategy, key),
                        CTModels.Strategies.is_computed(strategy, key)
                    ]
                    Test.@test count(sources) == 1  # Exactly one should be true
                end
            end
            
            Test.@testset "Complete introspection workflow" begin
                # 1. Discover available options (type-level)
                names = CTModels.Strategies.option_names(IntrospectionTestStrategy)
                Test.@test length(names) == 3
                
                # 2. Query metadata for each option (type-level)
                for name in names
                    type_info = CTModels.Strategies.option_type(IntrospectionTestStrategy, name)
                    desc = CTModels.Strategies.option_description(IntrospectionTestStrategy, name)
                    default = CTModels.Strategies.option_default(IntrospectionTestStrategy, name)
                    
                    Test.@test type_info isa Type
                    Test.@test desc isa String
                    Test.@test !isnothing(default)
                end
                
                # 3. Create instance with custom values
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(150, :user),
                    tol = CTModels.Options.OptionValue(1e-6, :default),
                    backend = CTModels.Options.OptionValue(:cpu, :default)
                )
                strategy = IntrospectionTestStrategy(opts)
                
                # 4. Query instance state
                for name in names
                    value = CTModels.Strategies.option_value(strategy, name)
                    source = CTModels.Strategies.option_source(strategy, name)
                    
                    Test.@test !isnothing(value)
                    Test.@test source in (:user, :default, :computed)
                end
            end
            
            Test.@testset "typeof() pattern for type-level functions" begin
                # Create instance
                opts = CTModels.Strategies.StrategyOptions(
                    max_iter = CTModels.Options.OptionValue(200, :user),
                    tol = CTModels.Options.OptionValue(1e-6, :default),
                    backend = CTModels.Options.OptionValue(:cpu, :default)
                )
                strategy = IntrospectionTestStrategy(opts)
                
                # Type-level functions should work with typeof()
                Test.@test CTModels.Strategies.option_names(typeof(strategy)) == 
                           CTModels.Strategies.option_names(IntrospectionTestStrategy)
                
                Test.@test CTModels.Strategies.option_type(typeof(strategy), :max_iter) ==
                           CTModels.Strategies.option_type(IntrospectionTestStrategy, :max_iter)
                
                Test.@test CTModels.Strategies.option_defaults(typeof(strategy)) ==
                           CTModels.Strategies.option_defaults(IntrospectionTestStrategy)
            end
        end
    end
end

end # module

test_introspection() = TestStrategiesIntrospection.test_introspection()
