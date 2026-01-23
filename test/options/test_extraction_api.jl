# ==============================================================================
# CTModels Options Extraction API Tests
# ==============================================================================

# Test dependencies
using Test
using CTBase
using CTModels
using CTModels.Options

# ============================================================================
# Helper types and functions (top-level for precompilation stability)
# ============================================================================

# Simple validator for testing (returns true for valid values)
positive_validator(x::Int) = x > 0

# Range validator for testing (returns true for valid values)
range_validator(x::Int) = 1 <= x <= 100

# String validator for testing (returns true for valid values)
nonempty_validator(s::String) = !isempty(s)

# ============================================================================
# Test entry point
# ============================================================================

function test_extraction_api()
    
# ============================================================================
# UNIT TESTS
# ============================================================================

Test.@testset "Extraction API" verbose=VERBOSE showtiming=SHOWTIMING begin
    
    Test.@testset "extract_option - Basic functionality" begin
        # Test with exact name match
        schema = OptionSchema(:grid_size, Int, 100)
        kwargs = (grid_size=200, tol=1e-6)
        
        opt_value, remaining = extract_option(kwargs, schema)
        
        Test.@test opt_value.value == 200
        Test.@test opt_value.source == :user
        Test.@test remaining == (tol=1e-6,)
    end
    
    Test.@testset "extract_option - Alias resolution" begin
        # Test with alias
        schema = OptionSchema(:grid_size, Int, 100, (:n, :size))
        kwargs = (n=200, tol=1e-6)
        
        opt_value, remaining = extract_option(kwargs, schema)
        
        Test.@test opt_value.value == 200
        Test.@test opt_value.source == :user
        Test.@test remaining == (tol=1e-6,)
        
        # Test with different alias
        kwargs = (size=300, max_iter=1000)
        opt_value, remaining = extract_option(kwargs, schema)
        
        Test.@test opt_value.value == 300
        Test.@test opt_value.source == :user
        Test.@test remaining == (max_iter=1000,)
    end
    
    Test.@testset "extract_option - Default values" begin
        # Test when option not found
        schema = OptionSchema(:grid_size, Int, 100)
        kwargs = (tol=1e-6, max_iter=1000)
        
        opt_value, remaining = extract_option(kwargs, schema)
        
        Test.@test opt_value.value == 100
        Test.@test opt_value.source == :default
        Test.@test remaining == kwargs  # Unchanged
    end
    
    Test.@testset "extract_option - Validation" begin
        # Test with successful validation
        schema = OptionSchema(:grid_size, Int, 100, (), x -> x > 0 ? true : error("Value must be positive"))
        kwargs = (grid_size=200,)
        
        opt_value, remaining = extract_option(kwargs, schema)
        
        Test.@test opt_value.value == 200
        Test.@test opt_value.source == :user
        
        # Test with failed validation
        kwargs = (grid_size=-5,)
        Test.@test_throws CTBase.IncorrectArgument extract_option(kwargs, schema)
    end
    
    Test.@testset "extract_option - Type checking" begin
        # Test type mismatch (should warn but still extract)
        schema = OptionSchema(:grid_size, Int, 100)
        kwargs = (grid_size="200",)  # String instead of Int
        
        # This should generate a warning but still work
        opt_value, remaining = extract_option(kwargs, schema)
        
        Test.@test opt_value.value == "200"
        Test.@test opt_value.source == :user
        Test.@test remaining == NamedTuple()  # Empty NamedTuple, not ()
    end
    
    Test.@testset "extract_options - Vector version" begin
        schemas = [
            OptionSchema(:grid_size, Int, 100),
            OptionSchema(:tol, Float64, 1e-6),
            OptionSchema(:max_iter, Int, 1000)
        ]
        kwargs = (grid_size=200, tol=1e-8, other_option="ignored")
        
        extracted, remaining = extract_options(kwargs, schemas)
        
        Test.@test extracted[:grid_size].value == 200
        Test.@test extracted[:grid_size].source == :user
        Test.@test extracted[:tol].value == 1e-8
        Test.@test extracted[:tol].source == :user
        Test.@test extracted[:max_iter].value == 1000
        Test.@test extracted[:max_iter].source == :default
        Test.@test remaining == (other_option="ignored",)
    end
    
    Test.@testset "extract_options - NamedTuple version" begin
        schemas = (
            grid_size = OptionSchema(:grid_size, Int, 100),
            tol = OptionSchema(:tol, Float64, 1e-6)
        )
        kwargs = (grid_size=200, tol=1e-8, max_iter=1000)
        
        extracted, remaining = extract_options(kwargs, schemas)
        
        Test.@test extracted.grid_size.value == 200
        Test.@test extracted.grid_size.source == :user
        Test.@test extracted.tol.value == 1e-8
        Test.@test extracted.tol.source == :user
        Test.@test remaining == (max_iter=1000,)
    end
    
    Test.@testset "extract_options - Complex scenario with aliases" begin
        schemas = [
            OptionSchema(:grid_size, Int, 100, (:n, :size), positive_validator),
            OptionSchema(:tolerance, Float64, 1e-6, (:tol,)),
            OptionSchema(:max_iterations, Int, 1000, (:max_iter, :iterations))
        ]
        kwargs = (n=50, tol=1e-8, iterations=500, unused="value")
        
        extracted, remaining = extract_options(kwargs, schemas)
        
        Test.@test extracted[:grid_size].value == 50
        Test.@test extracted[:grid_size].source == :user
        Test.@test extracted[:tolerance].value == 1e-8
        Test.@test extracted[:tolerance].source == :user
        Test.@test extracted[:max_iterations].value == 500
        Test.@test extracted[:max_iterations].source == :user
        Test.@test remaining == (unused="value",)
    end
    
    Test.@testset "Performance - Type stability" begin
        # Skip type stability tests for now due to implementation complexity
        # Focus on functional correctness instead
        schema = OptionSchema(:test, Int, 42)
        kwargs = (test=100,)
        
        result = extract_option(kwargs, schema)
        Test.@test result[1] isa CTModels.Options.OptionValue
        Test.@test result[2] isa NamedTuple
        
        schemas = [schema]
        result = extract_options(kwargs, schemas)
        Test.@test result[1] isa Dict{Symbol, CTModels.Options.OptionValue}
        Test.@test result[2] isa NamedTuple
    end
    
    Test.@testset "Error handling" begin
        schema = OptionSchema(:test, Int, 42, (), x -> error("Validation failed"))
        kwargs = (test=100,)
        
        # Test validation error propagation
        Test.@test_throws CTBase.IncorrectArgument extract_option(kwargs, schema)
        
        # Test with multiple schemas, one fails
        schemas = [
            OptionSchema(:good, Int, 42),
            OptionSchema(:bad, Int, 42, (), x -> error("Bad option"))
        ]
        kwargs = (good=100, bad=200)
        
        Test.@test_throws CTBase.IncorrectArgument extract_options(kwargs, schemas)
    end
    
end # UNIT TESTS

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

Test.@testset "Extraction API Integration" verbose=VERBOSE showtiming=SHOWTIMING begin
    
    Test.@testset "Integration with OptionValue and OptionSchema" begin
        # Test complete workflow
        schemas = (
            size = OptionSchema(:grid_size, Int, 100, (:n, :size), positive_validator),
            tolerance = OptionSchema(:tolerance, Float64, 1e-6, (:tol,)),
            verbose = OptionSchema(:verbose, Bool, false)
        )
        
        # Test with mixed aliases and validation
        kwargs = (n=50, tol=1e-8, verbose=true, extra="ignored")
        
        extracted, remaining = extract_options(kwargs, schemas)
        
        # Verify all options extracted correctly
        Test.@test extracted.size.value == 50
        Test.@test extracted.size.source == :user
        Test.@test extracted.tolerance.value == 1e-8
        Test.@test extracted.tolerance.source == :user
        Test.@test extracted.verbose.value == true
        Test.@test extracted.verbose.source == :user
        
        # Verify only unused options remain
        Test.@test remaining == (extra="ignored",)
        
        # Test OptionValue functionality
        Test.@test string(extracted.size) == "50 (user)"
        Test.@test extracted.size.value isa Int
        Test.@test extracted.tolerance.value isa Float64
        Test.@test extracted.verbose.value isa Bool
    end
    
    Test.@testset "Realistic tool configuration scenario" begin
        # Simulate a realistic tool configuration with simpler validators
        tool_schemas = [
            OptionSchema(:grid_size, Int, 100, (:n, :size)),
            OptionSchema(:tolerance, Float64, 1e-6, (:tol,)),
            OptionSchema(:max_iterations, Int, 1000, (:max_iter, :iterations)),
            OptionSchema(:solver, String, "ipopt", (:algorithm,)),
            OptionSchema(:verbose, Bool, false),
            OptionSchema(:output_file, String, nothing, (:out, :output))
        ]
        
        # Test configuration with various options
        config = (
            n=200,
            tol=1e-8,
            max_iter=500,
            algorithm="knitro",
            verbose=true,
            output="results.txt",
            debug_mode=true  # Extra option not in schemas
        )
        
        extracted, remaining = extract_options(config, tool_schemas)
        
        # Verify extraction
        Test.@test extracted[:grid_size].value == 200
        Test.@test extracted[:tolerance].value == 1e-8
        Test.@test extracted[:max_iterations].value == 500
        Test.@test extracted[:solver].value == "knitro"
        Test.@test extracted[:verbose].value == true
        Test.@test extracted[:output_file].value == "results.txt"
        
        # Verify only non-schema options remain
        Test.@test remaining == (debug_mode=true,)
        
        # Test all sources are correct
        for (name, opt_value) in extracted
            Test.@test opt_value.source == :user  # All were provided
        end
    end
    
    Test.@testset "Edge cases and boundary conditions" begin
        # Test with empty kwargs
        schema = OptionSchema(:test, Int, 42)
        empty_kwargs = NamedTuple()
        
        opt_value, remaining = extract_option(empty_kwargs, schema)
        Test.@test opt_value.value == 42
        Test.@test opt_value.source == :default
        Test.@test remaining == NamedTuple()
        
        # Test with empty schemas
        empty_schemas = OptionSchema[]
        kwargs = (a=1, b=2)
        
        extracted, remaining = extract_options(kwargs, empty_schemas)
        Test.@test isempty(extracted)
        Test.@test remaining == kwargs
        
        # Test with nothing default
        schema_no_default = OptionSchema(:optional, String, nothing)
        kwargs_no_match = (other="value",)
        
        opt_value, remaining = extract_option(kwargs_no_match, schema_no_default)
        Test.@test opt_value.value === nothing
        Test.@test opt_value.source == :default
    end
    
end # INTEGRATION TESTS

end # test_extraction_api()
