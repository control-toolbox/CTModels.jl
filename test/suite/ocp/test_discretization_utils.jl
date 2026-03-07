module TestDiscretizationUtils

import Test
import CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_discretization_utils()
    Test.@testset "Discretization Utils Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for discretization utils functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Discretization Utilities
        # ====================================================================
        
        Test.@testset "Basic discretization - scalar function" verbose=VERBOSE showtiming=SHOWTIMING begin
            # Simple scalar function
            f_scalar = t -> 2.0 * t
            T = [0.0, 0.5, 1.0]

            # With explicit dimension
            result = CTModels.OCP._discretize_function(f_scalar, T, 1)
            Test.@test size(result) == (3, 1)
            Test.@test result ≈ [0.0; 1.0; 2.0]

            # With auto-detection
            result_auto = CTModels.OCP._discretize_function(f_scalar, T)
            Test.@test result_auto ≈ result
        end

        Test.@testset "Basic discretization - vector function" begin
            # Vector function
            f_vec = t -> [t, 2*t]
            T = [0.0, 0.5, 1.0]

            # With explicit dimension
            result = CTModels.OCP._discretize_function(f_vec, T, 2)
            Test.@test size(result) == (3, 2)
            Test.@test result ≈ [0.0 0.0; 0.5 1.0; 1.0 2.0]

            # With auto-detection
            result_auto = CTModels.OCP._discretize_function(f_vec, T)
            Test.@test result_auto ≈ result
        end

        Test.@testset "TimeGridModel support" begin
            # Test with TimeGridModel
            T_grid = CTModels.TimeGridModel(LinRange(0.0, 1.0, 5))
            f = t -> [t, t^2]

            result = CTModels.OCP._discretize_function(f, T_grid, 2)
            Test.@test size(result) == (5, 2)
            Test.@test result[1, :] ≈ [0.0, 0.0]
            Test.@test result[end, :] ≈ [1.0, 1.0]
        end

        Test.@testset "Discretize dual - nothing handling" begin
            T = [0.0, 0.5, 1.0]

            # Dual function is nothing
            result_nothing = CTModels.OCP._discretize_dual(nothing, T)
            Test.@test isnothing(result_nothing)

            # Dual function exists
            f_dual = t -> [t, 2*t]
            result_func = CTModels.OCP._discretize_dual(f_dual, T, 2)
            Test.@test !isnothing(result_func)
            Test.@test size(result_func) == (3, 2)
            Test.@test result_func ≈ [0.0 0.0; 0.5 1.0; 1.0 2.0]

            # Auto-detection
            result_auto = CTModels.OCP._discretize_dual(f_dual, T)
            Test.@test result_auto ≈ result_func
        end

        Test.@testset "Edge cases" begin
            # Single time point
            f = t -> [t, 2*t]
            T_single = [0.5]
            result = CTModels.OCP._discretize_function(f, T_single, 2)
            Test.@test size(result) == (1, 2)
            Test.@test result ≈ [0.5 1.0]

            # Large dimension
            f_large = t -> ones(10) .* t
            T = [0.0, 1.0]
            result = CTModels.OCP._discretize_function(f_large, T, 10)
            Test.@test size(result) == (2, 10)
            Test.@test result[1, :] ≈ zeros(10)
            Test.@test result[2, :] ≈ ones(10)
        end

        Test.@testset "Scalar return from vector function" begin
            # Function returns vector but we want dim=1
            f = t -> [2.0 * t]  # Returns vector of size 1
            T = [0.0, 0.5, 1.0]

            result = CTModels.OCP._discretize_function(f, T, 1)
            Test.@test size(result) == (3, 1)
            Test.@test result ≈ [0.0; 1.0; 2.0]
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_discretization_utils() = TestDiscretizationUtils.test_discretization_utils()
