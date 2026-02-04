# Tests for Enhanced Modelers Options
#
# This file tests the enhanced ADNLPModeler and ExaModeler options
# to ensure they work correctly with validation and provide expected behavior.
#
# Author: CTModels Development Team
# Date: 2026-01-31

module TestEnhancedOptions

using Test
using CTBase: CTBase, Exceptions
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Import the specific types we need
using CTModels.Modelers: ADNLPModeler, ExaModeler
using KernelAbstractions: CPU
using CTModels.Strategies: options

# Define structs at top-level (crucial!)
struct TestDummyModel end

function test_enhanced_options()
    @testset "Enhanced Modelers Options" verbose = VERBOSE showtiming = SHOWTIMING begin

        @testset "ADNLPModeler Enhanced Options" begin
            
            @testset "New Options Validation" begin
                # Test matrix_free option
                modeler = ADNLPModeler(matrix_free=true)
                @test options(modeler)[:matrix_free] == true
                
                modeler = ADNLPModeler(matrix_free=false)
                @test options(modeler)[:matrix_free] == false
                
                # Test name option
                modeler = ADNLPModeler(name="TestProblem")
                @test options(modeler)[:name] == "TestProblem"
            end
            
            @testset "Backend Validation" begin
                # Valid backends should work (some may generate warnings if packages not loaded)
                @test_nowarn ADNLPModeler(backend=:default)
                @test_nowarn ADNLPModeler(backend=:optimized)
                @test_nowarn ADNLPModeler(backend=:generic)
                # Enzyme and Zygote may generate warnings if packages not loaded - that's expected
                redirect_stderr(devnull) do
                    ADNLPModeler(backend=:enzyme)  # May warn if Enzyme not loaded
                    ADNLPModeler(backend=:zygote)  # May warn if Zygote not loaded
                end
                
                # Invalid backend should throw error (redirect stderr to hide error logs)
                redirect_stderr(devnull) do
                    @test_throws ArgumentError ADNLPModeler(backend=:invalid)
                end
            end
            
            @testset "Name Validation" begin
                # Valid names should work
                @test_nowarn ADNLPModeler(name="ValidName")
                @test_nowarn ADNLPModeler(name="name_with_123")
                
                # Empty name should throw error (redirect stderr to hide error logs)
                redirect_stderr(devnull) do
                    @test_throws ArgumentError ADNLPModeler(name="")
                end
            end
            
            @testset "Combined Options" begin
                # Test multiple options together
                modeler = ADNLPModeler(
                    backend=:optimized,
                    matrix_free=true,
                    name="CombinedTest",
                    show_time=true
                )
                
                opts = options(modeler)
                @test opts[:backend] == :optimized
                @test opts[:matrix_free] == true
                @test opts[:name] == "CombinedTest"
                @test opts[:show_time] == true
            end
        end
        
        @testset "ExaModeler Enhanced Options" begin
            
            @testset "Base Type Validation" begin
                # Test valid base types
                modeler = ExaModeler(base_type=Float32)
                @test options(modeler)[:base_type] == Float32
                
                modeler = ExaModeler(base_type=Float64)
                @test options(modeler)[:base_type] == Float64
            end
            
            @testset "Backend Validation" begin
                # Test backend option
                modeler = ExaModeler(backend=nothing)
                @test options(modeler)[:backend] === nothing
                
                # Test with a backend type
                modeler = ExaModeler(backend=CPU())
                @test options(modeler)[:backend] == CPU()
            end
            
            @testset "Base Type Extraction in Build" begin
                # Test that BaseType is correctly extracted and used in build process
                modeler = ExaModeler(base_type=Float32)
                
                # Verify base_type is stored in options
                @test options(modeler)[:base_type] == Float32
                
                # Test with Float64 as well
                modeler64 = ExaModeler(base_type=Float64)
                @test options(modeler64)[:base_type] == Float64
                
                # Test that default base_type is preserved
                default_modeler = ExaModeler()
                @test options(default_modeler)[:base_type] == Float64
            end
            
            @testset "Combined Options" begin
                # Test multiple options together
                modeler = ExaModeler(
                    base_type=Float32,
                    backend=nothing
                )
                
                opts = options(modeler)
                @test opts[:backend] === nothing
                @test opts[:base_type] == Float32
                
                # Check that modeler is not parameterized anymore
                @test modeler isa ExaModeler
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
                @test options(modeler2)[:show_time] == true
                @test options(modeler2)[:backend] == :default
                
                # Default values should be preserved
                modeler3 = ADNLPModeler()
                opts = options(modeler3)
                @test opts[:show_time] == false
                @test opts[:backend] == :optimized
                @test opts[:matrix_free] == false
                @test opts[:name] == "CTModels-ADNLP"
            end
            
            @testset "ExaModeler Backward Compatibility" begin
                # Original constructor should still work
                modeler1 = ExaModeler()
                @test modeler1 isa ExaModeler
                
                # Original options should still work
                modeler2 = ExaModeler(base_type=Float32)
                @test modeler2 isa ExaModeler
                @test options(modeler2)[:base_type] == Float32
                
                # Default values should be preserved
                modeler3 = ExaModeler()
                opts = options(modeler3)
                @test opts[:backend] === nothing
                @test opts[:base_type] == Float64
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
                opts = options(modeler)
                @test opts[:gradient_backend] === nothing
                @test opts[:hprod_backend] === nothing
                @test opts[:ghjvprod_backend] === nothing
            end

            @testset "Backend Override Type Validation" begin
                # Invalid types should throw enriched exceptions (redirect stderr to hide error logs)
                redirect_stderr(devnull) do
                    @test_throws Exceptions.IncorrectArgument ADNLPModeler(gradient_backend="invalid")
                    @test_throws Exceptions.IncorrectArgument ADNLPModeler(hprod_backend=123)
                    @test_throws Exceptions.IncorrectArgument ADNLPModeler(jprod_backend=:invalid)
                    @test_throws Exceptions.IncorrectArgument ADNLPModeler(ghjvprod_backend="invalid")
                end
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

                opts = options(modeler)
                @test opts[:backend] == :optimized
                @test opts[:matrix_free] == true
                @test opts[:name] == "AdvancedTest"
                # Options with NotProvided default are only stored when explicitly set
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
