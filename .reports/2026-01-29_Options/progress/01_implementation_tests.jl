# Tests for Enhanced Modelers Options
#
# This file contains comprehensive tests for the enhanced ADNLPModeler and ExaModeler
# options and validation functions.
#
# Author: CTModels Development Team
# Date: 2026-01-31

using Test
using CTModels

# Include validation functions for testing
include("../analysis/03_validation_functions.jl")

@testset "Enhanced Modelers Options Tests" begin

    @testset "ADNLPModeler Validation" begin
        
        @testset "Backend Validation" begin
            # Valid backends
            @test validate_adnlp_backend(:default) == :default
            @test validate_adnlp_backend(:optimized) == :optimized
            @test validate_adnlp_backend(:generic) == :generic
            @test validate_adnlp_backend(:enzyme) == :enzyme
            @test validate_adnlp_backend(:zygote) == :zygote
            
            # Invalid backend
            @test_throws ArgumentError validate_adnlp_backend(:invalid)
            @test_throws ArgumentError validate_adnlp_backend(:forwarddiff)
        end
        
        @testset "Backend Override Validation" begin
            # Valid overrides
            @test validate_adnlp_backend_override(nothing, "gradient") === nothing
            @test validate_adnlp_backend_override(String, "gradient") == String  # Type check only
            
            # Invalid overrides
            @test_throws ArgumentError validate_adnlp_backend_override("not_a_type", "gradient")
        end
        
        @testset "Matrix-Free Validation" begin
            # Valid values
            @test validate_matrix_free(true, 1000) == true
            @test validate_matrix_free(false, 1000) == false
            
            # Type checking
            @test_throws ArgumentError validate_matrix_free("true", 1000)
        end
        
        @testset "Model Name Validation" begin
            # Valid names
            @test validate_model_name("TestModel") == "TestModel"
            @test validate_model_name("model_123") == "model_123"
            @test validate_model_name("My-Model") == "My-Model"
            
            # Invalid names
            @test_throws ArgumentError validate_model_name("")
            @test_throws ArgumentError validate_model_name(123)
        end
        
        @testset "Optimization Direction Validation" begin
            # Valid values
            @test validate_optimization_direction(true) == true
            @test validate_optimization_direction(false) == false
            
            # Type checking
            @test_throws ArgumentError validate_optimization_direction("true")
        end
        
        @testset "Complete ADNLP Options Validation" begin
            # Valid options
            valid_opts = (
                backend = :optimized,
                matrix_free = true,
                name = "TestModel",
                minimize = false,
                show_time = true
            )
            @test validate_adnlp_options(valid_opts) isa NamedTuple
            
            # Invalid options
            invalid_opts = (backend = :invalid,)
            @test_throws ArgumentError validate_adnlp_options(invalid_opts)
        end
    end
    
    @testset "ExaModeler Validation" begin
        
        @testset "Base Type Validation" begin
            # Valid types
            @test validate_exa_base_type(Float64) == Float64
            @test validate_exa_base_type(Float32) == Float32
            @test validate_exa_base_type(Float16) == Float16
            
            # Invalid types
            @test_throws ArgumentError validate_exa_base_type(Int)
            @test_throws ArgumentError validate_exa_base_type(String)
        end
        
        @testset "GPU Backend Detection" begin
            # This test will depend on available hardware
            available = detect_available_gpu_backends()
            @test available isa Vector{Symbol}
            @test all(x -> x in (:cuda, :rocm, :oneapi), available)
        end
        
        @testset "GPU Backend Selection" begin
            # Test selection logic
            available = [:cuda, :rocm]
            @test select_best_gpu_backend(available, :rocm) == :rocm
            @test select_best_gpu_backend(available, :cuda) == :cuda
            @test select_best_gpu_backend(available, :oneapi) == :cuda  # Falls back to first
            @test select_best_gpu_backend([], :cuda) === nothing
        end
        
        @testset "GPU Preference Validation" begin
            # Valid preferences
            @test validate_gpu_preference(:cuda) == :cuda
            @test validate_gpu_preference(:rocm) == :rocm
            @test validate_gpu_preference(:oneapi) == :oneapi
            
            # Invalid preferences
            @test_throws ArgumentError validate_gpu_preference(:invalid)
            @test_throws ArgumentError validate_gpu_preference(:vulkan)
        end
        
        @testset "Precision Mode Validation" begin
            # Valid modes
            @test validate_precision_mode(:standard) == :standard
            @test validate_precision_mode(:high) == :high
            @test validate_precision_mode(:mixed) == :mixed
            
            # Invalid modes
            @test_throws ArgumentError validate_precision_mode(:invalid)
            @test_throws ArgumentError validate_precision_mode(:ultra)
        end
        
        @testset "Complete Exa Options Validation" begin
            # Valid options
            valid_opts = (
                base_type = Float32,
                auto_detect_gpu = true,
                gpu_preference = :cuda,
                precision_mode = :standard,
                minimize = true
            )
            @test validate_exa_options(valid_opts) isa NamedTuple
            
            # Invalid options
            invalid_opts = (base_type = Int,)
            @test_throws ArgumentError validate_exa_options(invalid_opts)
        end
    end
    
    @testset "Integration Tests" begin
        
        @testset "ADNLPModeler Creation" begin
            # Test with enhanced options
            modeler = ADNLPModeler(
                backend = :optimized,
                matrix_free = true,
                name = "IntegrationTest",
                show_time = false
            )
            @test modeler isa ADNLPModeler
            @test Strategies.options(modeler).options[:backend] == :optimized
            @test Strategies.options(modeler).options[:matrix_free] == true
            @test Strategies.options(modeler).options[:name] == "IntegrationTest"
        end
        
        @testset "ExaModeler Creation" begin
            # Test with enhanced options
            modeler = ExaModeler(
                base_type = Float32,
                auto_detect_gpu = false,
                gpu_preference = :cuda
            )
            @test modeler isa ExaModeler{Float32}
            @test Strategies.options(modeler).options[:base_type] == Float32
            @test Strategies.options(modeler).options[:auto_detect_gpu] == false
        end
        
        @testset "Option Validation Integration" begin
            # Test that validation is properly integrated
            @test_nowarn validate_all_options(ADNLPModeler, (backend=:optimized,))
            @test_nowarn validate_all_options(ExaModeler, (base_type=Float64,))
            
            # Test error cases
            @test_throws ArgumentError validate_all_options(ADNLPModeler, (backend=:invalid,))
            @test_throws ArgumentError validate_all_options(ExaModeler, (base_type=Int,))
        end
    end
    
    @testset "Performance Recommendations" begin
        
        @testset "Matrix-Free Recommendations" begin
            # Large problem recommendation
            @test_logs (:info, r"Consider using matrix_free=true") validate_matrix_free(false, 200_000)
            
            # Small problem warning
            @test_logs (:info, r"matrix_free=true may have overhead") validate_matrix_free(true, 500)
        end
        
        @testset "Base Type Recommendations" begin
            # Float32 recommendation
            @test_logs (:info, r"Float32 is recommended for GPU") validate_exa_base_type(Float32)
            
            # Float64 recommendation
            @test_logs (:info, r"Float64 provides higher precision") validate_exa_base_type(Float64)
        end
        
        @testset "Precision Mode Recommendations" begin
            # High precision warning
            @test_logs (:info, r"High precision mode may impact performance") validate_precision_mode(:high)
            
            # Mixed precision info
            @test_logs (:info, r"Mixed precision mode can improve performance") validate_precision_mode(:mixed)
        end
    end
    
    @testset "Error Messages" begin
        
        @testset "Helpful Error Messages" begin
            # Backend error
            try
                validate_adnlp_backend(:invalid)
            catch e
                @test e isa ArgumentError
                @test occursin("Invalid backend", e.msg)
                @test occursin("Valid options", e.msg)
            end
            
            # Type error
            try
                validate_exa_base_type(Int)
            catch e
                @test e isa ArgumentError
                @test occursin("must be a subtype of AbstractFloat", e.msg)
            end
            
            # Name error
            try
                validate_model_name("")
            catch e
                @test e isa ArgumentError
                @test occursin("cannot be empty", e.msg)
            end
        end
    end
end

@testset "Backward Compatibility Tests" begin
    """Ensure that existing code continues to work with enhanced modelers"""
    
    @testset "ADNLPModeler Backward Compatibility" begin
        # Original constructor should still work
        modeler1 = ADNLPModeler()
        @test modeler1 isa ADNLPModeler
        
        # Original options should still work
        modeler2 = ADNLPModeler(show_time=true, backend=:default)
        @test modeler2 isa ADNLPModeler
        @test Strategies.options(modeler2).options[:show_time] == true
        @test Strategies.options(modeler2).options[:backend] == :default
    end
    
    @testset "ExaModeler Backward Compatibility" begin
        # Original constructor should still work
        modeler1 = ExaModeler()
        @test modeler1 isa ExaModeler{Float64}
        
        # Original options should still work
        modeler2 = ExaModeler(base_type=Float32, minimize=false)
        @test modeler2 isa ExaModeler{Float32}
        @test Strategies.options(modeler2).options[:base_type] == Float32
        @test Strategies.options(modeler2).options[:minimize] == false
    end
end

@testset "Edge Cases" begin
    
    @testset "Unusual Option Values" begin
        # Test with unusual but valid values
        @test_nowarn validate_model_name("a")  # Single character
        @test_nowarn validate_model_name("a" ^ 100)  # Very long name
        
        # Test boundary conditions
        @test validate_matrix_free(true, 999) == true  # Just under recommendation threshold
        @test validate_matrix_free(true, 1001) == true  # Just over recommendation threshold
    end
    
    @testset "Missing Dependencies" begin
        # These tests simulate scenarios where optional packages are not available
        # In practice, the validation functions should handle missing packages gracefully
        
        # Test backend validation without Enzyme loaded
        # Note: This would need to be tested in an environment without Enzyme
        @test validate_adnlp_backend(:enzyme) == :enzyme  # Should warn but not error
    end
end

# Performance benchmarks (optional, only run if explicitly requested)
if ENV["CTMODELS_BENCHMARK_TESTS"] == "true"
    @testset "Performance Benchmarks" begin
        
        @testset "Validation Performance" begin
            # Ensure validation doesn't add significant overhead
            options = (backend=:optimized, matrix_free=true, name="Test")
            
            # Time validation
            time_val = @elapsed validate_adnlp_options(options)
            @test time_val < 0.001  # Should be very fast (< 1ms)
        end
        
        @testset "Modeler Creation Performance" begin
            # Ensure enhanced modelers don't slow down creation
            time_creation = @elapsed ADNLPModeler(backend=:optimized, matrix_free=true)
            @test time_creation < 0.01  # Should be fast (< 10ms)
        end
    end
end
