module TestInterpolationHelpers

using Test
using CTModels
using CTModels.OCP: build_interpolated_function, _interpolate_from_data, _wrap_scalar_and_deepcopy
using CTModels.Exceptions: IncorrectArgument
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_interpolation_helpers()
    @testset "Interpolation Helpers" verbose = VERBOSE showtiming = SHOWTIMING begin
        
        # Test data setup
        T = [0.0, 0.5, 1.0]
        X_2d = [1.0 2.0; 1.5 2.5; 2.0 3.0]  # 3x2 matrix
        X_1d = [1.0; 1.5; 2.0]  # 3x1 matrix
        
        @testset "_interpolate_from_data: basic functionality" begin
            # Test with Matrix and dimension extraction
            func = _interpolate_from_data(X_2d, T, 2, Matrix{Float64})
            @test !isnothing(func)
            @test func(0.0) ≈ [1.0, 2.0]
            @test func(1.0) ≈ [2.0, 3.0]
            
            # Test with Function passthrough
            test_func = t -> [t, 2t]
            result = _interpolate_from_data(test_func, T, 2, Function)
            @test result === test_func
            @test result(0.5) == [0.5, 1.0]
        end
        
        @testset "_interpolate_from_data: nothing handling" begin
            # Test allow_nothing=true
            result = _interpolate_from_data(nothing, T, 2, Nothing; allow_nothing=true)
            @test isnothing(result)
            
            # Test allow_nothing=false (should throw)
            @test_throws IncorrectArgument _interpolate_from_data(
                nothing, T, 2, Nothing; allow_nothing=false
            )
        end
        
        @testset "_interpolate_from_data: constant_if_two_points" begin
            T_short = [0.0, 1.0]
            X_short = [1.0 2.0; 3.0 4.0]
            
            # With constant_if_two_points=true
            func = _interpolate_from_data(
                X_short, T_short, 2, Matrix{Float64}; 
                constant_if_two_points=true
            )
            @test func(0.0) == [1.0, 2.0]
            @test func(0.5) == [1.0, 2.0]  # Constant
            @test func(1.0) == [1.0, 2.0]  # Constant
            
            # With constant_if_two_points=false (default)
            func2 = _interpolate_from_data(X_short, T_short, 2, Matrix{Float64})
            @test func2(0.0) ≈ [1.0, 2.0]
            @test func2(1.0) ≈ [3.0, 4.0]
            # Linear interpolation
            @test func2(0.5) ≈ [2.0, 3.0]
        end
        
        @testset "_interpolate_from_data: dimension validation" begin
            # Valid: matrix has 2 columns, we extract 2
            func = _interpolate_from_data(
                X_2d, T, 2, Matrix{Float64}; 
                expected_dim=2
            )
            @test !isnothing(func)
            
            # Valid: matrix has 2 columns, we extract 1
            func = _interpolate_from_data(
                X_2d, T, 1, Matrix{Float64}; 
                expected_dim=1
            )
            @test !isnothing(func)
            
            # Invalid: matrix has 2 columns, we expect 3
            @test_throws IncorrectArgument _interpolate_from_data(
                X_2d, T, 3, Matrix{Float64}; 
                expected_dim=3
            )
        end
        
        @testset "_interpolate_from_data: full matrix extraction" begin
            # dim=nothing means take all columns
            func = _interpolate_from_data(X_2d, T, nothing, Matrix{Float64})
            @test func(0.0) ≈ [1.0, 2.0]
            @test func(1.0) ≈ [2.0, 3.0]
        end
        
        @testset "_wrap_scalar_and_deepcopy: scalar extraction" begin
            test_func = t -> [t, 2t]
            
            # dim=1: should extract scalar
            wrapped = _wrap_scalar_and_deepcopy(test_func, 1)
            @test wrapped(0.5) == 0.5  # Scalar, not vector
            
            # dim=2: should keep vector
            wrapped = _wrap_scalar_and_deepcopy(test_func, 2)
            @test wrapped(0.5) == [0.5, 1.0]  # Vector
            
            # dim=nothing: should keep vector
            wrapped = _wrap_scalar_and_deepcopy(test_func, nothing)
            @test wrapped(0.5) == [0.5, 1.0]
        end
        
        @testset "_wrap_scalar_and_deepcopy: nothing handling" begin
            result = _wrap_scalar_and_deepcopy(nothing, 1)
            @test isnothing(result)
        end
        
        @testset "_wrap_scalar_and_deepcopy: deepcopy isolation" begin
            # Test that deepcopy prevents external variable capture
            external_var = 1.0
            test_func = t -> [external_var * t]
            
            wrapped = _wrap_scalar_and_deepcopy(test_func, 1)
            val1 = wrapped(0.5)
            
            # Modify external variable
            external_var = 999.0
            val2 = wrapped(0.5)
            
            # Values should be the same (deepcopy isolated the closure)
            @test val1 == val2
            @test val1 == 0.5  # Original value
        end
        
        @testset "build_interpolated_function: complete workflow" begin
            # Test state-like: required, with validation
            fx = build_interpolated_function(X_2d, T, 2, Matrix{Float64}; expected_dim=2)
            @test !isnothing(fx)
            @test fx(0.0) ≈ [1.0, 2.0]
            @test fx(1.0) ≈ [2.0, 3.0]
            
            # Test scalar dimension
            fx_1d = build_interpolated_function(X_1d, T, 1, Matrix{Float64}; expected_dim=1)
            @test fx_1d(0.5) isa Float64  # Scalar extraction
            @test fx_1d(0.5) ≈ 1.5
        end
        
        @testset "build_interpolated_function: costate special case" begin
            T_short = [0.0, 1.0]
            P_short = [1.0 2.0; 3.0 4.0]
            
            # With constant_if_two_points=true
            fp = build_interpolated_function(
                P_short, T_short, 2, Matrix{Float64};
                constant_if_two_points=true,
                expected_dim=2
            )
            @test fp(0.0) == [1.0, 2.0]
            @test fp(0.5) == [1.0, 2.0]  # Constant
            @test fp(1.0) == [1.0, 2.0]  # Constant
        end
        
        @testset "build_interpolated_function: optional duals" begin
            # Test with nothing (allowed)
            fdual = build_interpolated_function(
                nothing, T, 2, Nothing;
                allow_nothing=true
            )
            @test isnothing(fdual)
            
            # Test with actual data
            fdual = build_interpolated_function(
                X_2d, T, 2, Matrix{Float64};
                allow_nothing=true
            )
            @test !isnothing(fdual)
            @test fdual(0.0) ≈ [1.0, 2.0]
        end
        
        @testset "build_interpolated_function: error cases" begin
            # Nothing not allowed
            @test_throws IncorrectArgument build_interpolated_function(
                nothing, T, 2, Nothing;
                allow_nothing=false
            )
            
            # Dimension mismatch
            @test_throws IncorrectArgument build_interpolated_function(
                X_2d, T, 3, Matrix{Float64};
                expected_dim=3
            )
        end
        
        @testset "build_interpolated_function: function passthrough" begin
            # Test that functions are passed through correctly
            test_func = t -> [sin(t), cos(t)]
            result = build_interpolated_function(test_func, T, 2, Function)
            
            # Should be wrapped with deepcopy but still work
            @test result(0.0) ≈ [0.0, 1.0]
            @test result(π/2) ≈ [1.0, 0.0] atol=1e-10
        end
    end
end

end  # module

# Export test function for test runner
test_interpolation_helpers() = TestInterpolationHelpers.test_interpolation_helpers()
