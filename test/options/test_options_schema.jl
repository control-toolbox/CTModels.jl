function test_options_schema()
    Test.@testset "OptionSchema" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Test OptionSchema construction and basic properties
        Test.@testset "OptionSchema construction" begin
            # Test with all parameters
            schema_full = CTModels.Options.OptionSchema(
                :grid_size,
                Int,
                100,
                (:n, :size),
                x -> x > 0 || error("grid_size must be positive")
            )
            Test.@test schema_full.name == :grid_size
            Test.@test schema_full.type == Int
            Test.@test schema_full.default == 100
            Test.@test schema_full.aliases == (:n, :size)
            Test.@test schema_full.validator !== nothing
            
            # Test with minimal parameters
            schema_minimal = CTModels.Options.OptionSchema(:tolerance, Float64, 1e-6)
            Test.@test schema_minimal.name == :tolerance
            Test.@test schema_minimal.type == Float64
            Test.@test schema_minimal.default == 1e-6
            Test.@test schema_minimal.aliases == ()
            Test.@test schema_minimal.validator === nothing
            
            # Test with no default
            schema_no_default = CTModels.Options.OptionSchema(:optional_param, String, nothing)
            Test.@test schema_no_default.name == :optional_param
            Test.@test schema_no_default.type == String
            Test.@test schema_no_default.default === nothing
        end
        
        # Test OptionSchema validation
        Test.@testset "OptionSchema validation" begin
            # Test invalid default type
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionSchema(:invalid, Int, "not_an_int")
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionSchema(:invalid, Float64, 42)
            
            # Test duplicate names
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionSchema(:name, Int, 1, (:name,))
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionSchema(:name, Int, 1, (:alias1, :alias1))
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionSchema(:name, Int, 1, (:alias1, :name))
        end
        
        # Test all_names function
        Test.@testset "all_names function" begin
            # Test with aliases
            schema_with_aliases = CTModels.Options.OptionSchema(:grid_size, Int, 100, (:n, :size))
            names = CTModels.Options.all_names(schema_with_aliases)
            Test.@test names == (:grid_size, :n, :size)
            
            # Test without aliases
            schema_no_aliases = CTModels.Options.OptionSchema(:tolerance, Float64, 1e-6)
            names = CTModels.Options.all_names(schema_no_aliases)
            Test.@test names == (:tolerance,)
            
            # Test with single alias
            schema_single_alias = CTModels.Options.OptionSchema(:param, Int, 1, (:alt,))
            names = CTModels.Options.all_names(schema_single_alias)
            Test.@test names == (:param, :alt)
        end
        
        # Test OptionSchema type stability
        Test.@testset "OptionSchema type stability" begin
            schema_int = CTModels.Options.OptionSchema(:int_param, Int, 42)
            schema_float = CTModels.Options.OptionSchema(:float_param, Float64, 3.14)
            schema_string = CTModels.Options.OptionSchema(:string_param, String, "default")
            
            # Test that types are preserved
            Test.@test schema_int.type === Int
            Test.@test schema_float.type === Float64
            Test.@test schema_string.type === String
            
            # Test that defaults have correct types
            Test.@test typeof(schema_int.default) == Int
            Test.@test typeof(schema_float.default) == Float64
            Test.@test typeof(schema_string.default) == String
        end
        
        # Test OptionSchema with validator
        Test.@testset "OptionSchema validators" begin
            # Test with a simple validator
            positive_validator = x -> x > 0
            schema = CTModels.Options.OptionSchema(:positive_param, Int, 1, (), positive_validator)
            Test.@test schema.validator === positive_validator
            
            # Test with a complex validator
            range_validator = x -> 0 <= x <= 100
            schema_range = CTModels.Options.OptionSchema(:range_param, Int, 50, (), range_validator)
            Test.@test schema_range.validator === range_validator
        end
    end
end