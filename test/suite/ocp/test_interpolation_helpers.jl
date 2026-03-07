module TestInterpolationHelpers

import Test
import CTBase.Exceptions
import CTModels
import CTModels.OCP

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_interpolation_helpers()
    Test.@testset "Interpolation Helpers Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for interpolation helpers functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Interpolation Helpers
        # ====================================================================

        # Test data setup
        T = [0.0, 0.5, 1.0]
        X_2d = [1.0 2.0; 1.5 2.5; 2.0 3.0]  # 3x2 matrix
        X_1d = [1.0; 1.5; 2.0]  # 3x1 matrix

        Test.@testset "_interpolate_from_data: basic functionality" begin
            # Test with Matrix and dimension extraction
            func = OCP._interpolate_from_data(X_2d, T, 2, Matrix{Float64})
            Test.@test !isnothing(func)
            Test.@test func(0.0) ≈ [1.0, 2.0]
            Test.@test func(1.0) ≈ [2.0, 3.0]

            # Test with Function passthrough
            test_func = t -> [t, 2t]
            result = OCP._interpolate_from_data(test_func, T, 2, Function)
            Test.@test result === test_func
            Test.@test result(0.5) == [0.5, 1.0]
        end

        Test.@testset "_interpolate_from_data: nothing handling" begin
            # Test allow_nothing=true
            result = OCP._interpolate_from_data(nothing, T, 2, Nothing; allow_nothing=true)
            Test.@test isnothing(result)

            # Test allow_nothing=false (should throw)
            Test.@test_throws Exceptions.IncorrectArgument OCP._interpolate_from_data(
                nothing, T, 2, Nothing; allow_nothing=false
            )
        end

        Test.@testset "_interpolate_from_data: constant_if_two_points" begin
            T_short = [0.0, 1.0]
            X_short = [1.0 2.0; 3.0 4.0]

            # With constant_if_two_points=true
            func = OCP._interpolate_from_data(
                X_short, T_short, 2, Matrix{Float64}; constant_if_two_points=true
            )
            Test.@test func(0.0) == [1.0, 2.0]
            Test.@test func(0.5) == [1.0, 2.0]  # Constant
            Test.@test func(1.0) == [1.0, 2.0]  # Constant

            # With constant_if_two_points=false (default)
            func2 = OCP._interpolate_from_data(X_short, T_short, 2, Matrix{Float64})
            Test.@test func2(0.0) ≈ [1.0, 2.0]
            Test.@test func2(1.0) ≈ [3.0, 4.0]
            # Linear interpolation
            Test.@test func2(0.5) ≈ [2.0, 3.0]
        end

        Test.@testset "_interpolate_from_data: dimension validation" begin
            # Valid: matrix has 2 columns, we extract 2
            func = OCP._interpolate_from_data(X_2d, T, 2, Matrix{Float64}; expected_dim=2)
            Test.@test !isnothing(func)

            # Valid: matrix has 2 columns, we extract 1
            func = OCP._interpolate_from_data(X_2d, T, 1, Matrix{Float64}; expected_dim=1)
            Test.@test !isnothing(func)

            # Invalid: matrix has 2 columns, we expect 3
            Test.@test_throws Exceptions.IncorrectArgument OCP._interpolate_from_data(
                X_2d, T, 3, Matrix{Float64}; expected_dim=3
            )
        end

        Test.@testset "_interpolate_from_data: full matrix extraction" begin
            # dim=nothing means take all columns
            func = OCP._interpolate_from_data(X_2d, T, nothing, Matrix{Float64})
            Test.@test func(0.0) ≈ [1.0, 2.0]
            Test.@test func(1.0) ≈ [2.0, 3.0]
        end

        Test.@testset "_wrap_scalar_and_deepcopy: scalar extraction" begin
            test_func = t -> [t, 2t]

            # dim=1: should extract scalar
            wrapped = OCP._wrap_scalar_and_deepcopy(test_func, 1)
            Test.@test wrapped(0.5) == 0.5  # Scalar, not vector

            # dim=2: should keep vector
            wrapped = OCP._wrap_scalar_and_deepcopy(test_func, 2)
            Test.@test wrapped(0.5) == [0.5, 1.0]  # Vector

            # dim=nothing: should keep vector
            wrapped = OCP._wrap_scalar_and_deepcopy(test_func, nothing)
            Test.@test wrapped(0.5) == [0.5, 1.0]
        end

        Test.@testset "_wrap_scalar_and_deepcopy: nothing handling" begin
            result = OCP._wrap_scalar_and_deepcopy(nothing, 1)
            Test.@test isnothing(result)
        end

        Test.@testset "_wrap_scalar_and_deepcopy: deepcopy isolation" begin
            # Test that deepcopy prevents external variable capture
            external_var = 1.0
            test_func = t -> [external_var * t]

            wrapped = OCP._wrap_scalar_and_deepcopy(test_func, 1)
            val1 = wrapped(0.5)

            # Modify external variable
            external_var = 999.0
            val2 = wrapped(0.5)

            # Values should be the same (deepcopy isolated the closure)
            Test.@test val1 == val2
            Test.@test val1 == 0.5  # Original value
        end

        Test.@testset "build_interpolated_function: complete workflow" begin
            # Test state-like: required, with validation
            fx = OCP.build_interpolated_function(X_2d, T, 2, Matrix{Float64}; expected_dim=2)
            Test.@test !isnothing(fx)
            Test.@test fx(0.0) ≈ [1.0, 2.0]
            Test.@test fx(1.0) ≈ [2.0, 3.0]

            # Test scalar dimension
            fx_1d = OCP.build_interpolated_function(X_1d, T, 1, Matrix{Float64}; expected_dim=1)
            Test.@test fx_1d(0.5) isa Float64  # Scalar extraction
            Test.@test fx_1d(0.5) ≈ 1.5
        end

        Test.@testset "build_interpolated_function: costate special case" begin
            T_short = [0.0, 1.0]
            P_short = [1.0 2.0; 3.0 4.0]

            # With constant_if_two_points=true
            fp = OCP.build_interpolated_function(
                P_short,
                T_short,
                2,
                Matrix{Float64};
                constant_if_two_points=true,
                expected_dim=2,
            )
            Test.@test fp(0.0) == [1.0, 2.0]
            Test.@test fp(0.5) == [1.0, 2.0]  # Constant
            Test.@test fp(1.0) == [1.0, 2.0]  # Constant
        end

        Test.@testset "build_interpolated_function: optional duals" begin
            # Test with nothing (allowed)
            fdual = OCP.build_interpolated_function(nothing, T, 2, Nothing; allow_nothing=true)
            Test.@test isnothing(fdual)

            # Test with actual data
            fdual = OCP.build_interpolated_function(
                X_2d, T, 2, Matrix{Float64}; allow_nothing=true
            )
            Test.@test !isnothing(fdual)
            Test.@test fdual(0.0) ≈ [1.0, 2.0]
        end

        Test.@testset "build_interpolated_function: error cases" begin
            # Nothing not allowed
            Test.@test_throws Exceptions.IncorrectArgument OCP.build_interpolated_function(
                nothing, T, 2, Nothing; allow_nothing=false
            )

            # Dimension mismatch
            Test.@test_throws Exceptions.IncorrectArgument OCP.build_interpolated_function(
                X_2d, T, 3, Matrix{Float64}; expected_dim=3
            )
        end

        Test.@testset "build_interpolated_function: function passthrough" begin
            # Test that functions are passed through correctly
            test_func = t -> [sin(t), cos(t)]
            result = OCP.build_interpolated_function(test_func, T, 2, Function)

            # Should be wrapped with deepcopy but still work
            Test.@test result(0.0) ≈ [0.0, 1.0]
            Test.@test result(π/2) ≈ [1.0, 0.0] atol=1e-10
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_interpolation_helpers() = TestInterpolationHelpers.test_interpolation_helpers()
