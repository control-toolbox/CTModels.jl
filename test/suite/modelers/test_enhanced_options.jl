# Tests for Enhanced Modelers Options
#
# This file tests the enhanced ADNLPModeler and ExaModeler options
# to ensure they work correctly with validation and provide expected behavior.
#
# Author: CTModels Development Team
# Date: 2026-01-31

module TestEnhancedOptions

using Test
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Import the specific types we need
using ..CTModels: ADNLPModeler, ExaModeler
using ..CTModels.Strategies: options

# Define structs at top-level (crucial!)
struct TestDummyModel end

function test_enhanced_options()
    @testset "Enhanced Modelers Options" verbose = VERBOSE showtiming = SHOWTIMING begin

        @testset "ADNLPModeler Enhanced Options" begin
            
            @testset "New Options Validation" begin
                # Test matrix_free option
                modeler = ADNLPModeler(matrix_free=true)
                @test options(modeler).options[:matrix_free] == true
                
                modeler = ADNLPModeler(matrix_free=false)
                @test options(modeler).options[:matrix_free] == false
                
                # Test name option
                modeler = ADNLPModeler(name="TestProblem")
                @test options(modeler).options[:name] == "TestProblem"
                
                # Test minimize option
                modeler = ADNLPModeler(minimize=false)
                @test options(modeler).options[:minimize] == false
                
                modeler = ADNLPModeler(minimize=true)
                @test options(modeler).options[:minimize] == true
            end
            
            @testset "Backend Validation" begin
                # Valid backends should work
                valid_backends = [:default, :optimized, :generic, :enzyme, :zygote]
                for backend in valid_backends
                    @test_nowarn ADNLPModeler(backend=backend)
                end
                
                # Invalid backend should throw error
                @test_throws ArgumentError ADNLPModeler(backend=:invalid)
            end
            
            @testset "Name Validation" begin
                # Valid names should work
                @test_nowarn ADNLPModeler(name="ValidName")
                @test_nowarn ADNLPModeler(name="name_with_123")
                
                # Empty name should throw error
                @test_throws ArgumentError ADNLPModeler(name="")
            end
            
            @testset "Combined Options" begin
                # Test multiple options together
                modeler = ADNLPModeler(
                    backend=:optimized,
                    matrix_free=true,
                    name="CombinedTest",
                    minimize=false,
                    show_time=true
                )
                
                opts = options(modeler).options
                @test opts[:backend] == :optimized
                @test opts[:matrix_free] == true
                @test opts[:name] == "CombinedTest"
                @test opts[:minimize] == false
                @test opts[:show_time] == true
            end
        end
        
        @testset "ExaModeler Enhanced Options" begin
            
            @testset "New Options Validation" begin
                # Test auto_detect_gpu option
                modeler = ExaModeler(auto_detect_gpu=true)
                @test options(modeler).options[:auto_detect_gpu] == true
                
                modeler = ExaModeler(auto_detect_gpu=false)
                @test options(modeler).options[:auto_detect_gpu] == false
                
                # Test gpu_preference option
                modeler = ExaModeler(gpu_preference=:cuda)
                @test options(modeler).options[:gpu_preference] == :cuda
                
                modeler = ExaModeler(gpu_preference=:rocm)
                @test options(modeler).options[:gpu_preference] == :rocm
                
                # Test precision_mode option
                modeler = ExaModeler(precision_mode=:high)
                @test options(modeler).options[:precision_mode] == :high
                
                modeler = ExaModeler(precision_mode=:mixed)
                @test options(modeler).options[:precision_mode] == :mixed
            end
            
            @testset "Base Type Validation" begin
                # Valid types should work
                @test_nowarn ExaModeler(base_type=Float64)
                @test_nowarn ExaModeler(base_type=Float32)
                @test_nowarn ExaModeler(base_type=Float16)
                
                # Invalid type should throw error
                @test_throws ArgumentError ExaModeler(base_type=Int)
                @test_throws ArgumentError ExaModeler(base_type=String)
            end
            
            @testset "GPU Preference Validation" begin
                # Valid preferences should work
                valid_prefs = [:cuda, :rocm, :oneapi]
                for pref in valid_prefs
                    @test_nowarn ExaModeler(gpu_preference=pref)
                end
                
                # Invalid preference should throw error
                @test_throws ArgumentError ExaModeler(gpu_preference=:invalid)
            end
            
            @testset "Combined Options" begin
                # Test multiple options together
                modeler = ExaModeler(
                    base_type=Float32,
                    auto_detect_gpu=true,
                    gpu_preference=:cuda,
                    precision_mode=:mixed,
                    minimize=true
                )
                
                opts = options(modeler).options
                @test opts[:auto_detect_gpu] == true
                @test opts[:gpu_preference] == :cuda
                @test opts[:precision_mode] == :mixed
                @test opts[:minimize] == true
                
                # Check that base_type is in the type parameter
                @test modeler isa ExaModeler{Float32}
            end
        end
        
        @testset "Backward Compatibility" begin
            
            @testset "ADNLPModeler Backward Compatibility" begin
                # Original constructor should still work
                modeler1 = ADNLPModeler()
                @test modeler1 isa ADNLPModeler
                
                # Original options should still work
                modeler2 = ADNLPModeler(show_time=true, backend=:default)
                @test modeler2 isa ADNLPModeler
                @test options(modeler2).options[:show_time] == true
                @test options(modeler2).options[:backend] == :default
                
                # Default values should be preserved
                modeler3 = ADNLPModeler()
                opts = options(modeler3).options
                @test opts[:show_time] == false
                @test opts[:backend] == :optimized
                @test opts[:matrix_free] == false
                @test opts[:name] == "CTModels-ADNLP"
                @test opts[:minimize] == true
            end
            
            @testset "ExaModeler Backward Compatibility" begin
                # Original constructor should still work
                modeler1 = ExaModeler()
                @test modeler1 isa ExaModeler{Float64}
                
                # Original options should still work
                modeler2 = ExaModeler(base_type=Float32, minimize=false)
                @test modeler2 isa ExaModeler{Float32}
                @test options(modeler2).options[:minimize] == false
                
                # Default values should be preserved
                modeler3 = ExaModeler()
                opts = options(modeler3).options
                @test opts[:auto_detect_gpu] == true
                @test opts[:gpu_preference] == :cuda
                @test opts[:precision_mode] == :standard
            end
        end

        @testset "Advanced Backend Overrides" begin
            @testset "Backend Override Validation" begin
                # Valid backend overrides should work
                @test_nowarn ADNLPModeler(gradient_backend=nothing)
                @test_nowarn ADNLPModeler(hprod_backend=nothing)
                @test_nowarn ADNLPModeler(jprod_backend=nothing)
                @test_nowarn ADNLPModeler(jtprod_backend=nothing)
                @test_nowarn ADNLPModeler(jacobian_backend=nothing)
                @test_nowarn ADNLPModeler(hessian_backend=nothing)

                # NLS backend overrides should work
                @test_nowarn ADNLPModeler(ghjvprod_backend=nothing)
                @test_nowarn ADNLPModeler(hprod_residual_backend=nothing)
                @test_nowarn ADNLPModeler(jprod_residual_backend=nothing)
                @test_nowarn ADNLPModeler(jtprod_residual_backend=nothing)
                @test_nowarn ADNLPModeler(jacobian_residual_backend=nothing)
                @test_nowarn ADNLPModeler(hessian_residual_backend=nothing)

                # Test that options are accessible
                modeler = ADNLPModeler(
                    gradient_backend=nothing,
                    hprod_backend=nothing,
                    ghjvprod_backend=nothing
                )
                opts = options(modeler).options
                @test opts[:gradient_backend] === nothing
                @test opts[:hprod_backend] === nothing
                @test opts[:ghjvprod_backend] === nothing
            end

            @testset "Backend Override Type Validation" begin
                # Invalid types should throw enriched exceptions
                @test_throws CTModels.Exceptions.IncorrectArgument ADNLPModeler(gradient_backend="invalid")
                @test_throws CTModels.Exceptions.IncorrectArgument ADNLPModeler(hprod_backend=123)
                @test_throws CTModels.Exceptions.IncorrectArgument ADNLPModeler(jprod_backend=:invalid)
                @test_throws CTModels.Exceptions.IncorrectArgument ADNLPModeler(ghjvprod_backend="invalid")
            end

            @testset "Combined Advanced Options" begin
                # Test advanced options with basic options
                modeler = ADNLPModeler(
                    backend=:optimized,
                    matrix_free=true,
                    name="AdvancedTest",
                    gradient_backend=nothing,
                    hprod_backend=nothing,
                    jacobian_backend=nothing,
                    ghjvprod_backend=nothing
                )

                opts = options(modeler).options
                @test opts[:backend] == :optimized
                @test opts[:matrix_free] == true
                @test opts[:name] == "AdvancedTest"
                @test opts[:gradient_backend] === nothing
                @test opts[:hprod_backend] === nothing
                @test opts[:jacobian_backend] === nothing
                @test opts[:ghjvprod_backend] === nothing
            end
        end
    end

end # function test_enhanced_options

end # module TestEnhancedOptions

# CRITICAL: Redefine the function in the outer scope so TestRunner can find it
test_enhanced_options() = TestEnhancedOptions.test_enhanced_options()
