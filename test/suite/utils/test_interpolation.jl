module TestUtilsInterpolation

import Test
import CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

"""
    test_interpolation()

Test interpolation utility functions from src/utils/interpolation.jl.
"""
function test_interpolation()
    Test.@testset "Interpolation Utils Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for interpolation utils functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Interpolation Utility Functions
        # ====================================================================
        Test.@testset "ctinterpolate - basic linear interpolation" begin
            # Simple linear data
            x = [0.0, 1.0, 2.0]
            f = [0.0, 1.0, 0.0]

            interp = CTModels.ctinterpolate(x, f)

            # Test at data points
            Test.@test interp(0.0) ≈ 0.0
            Test.@test interp(1.0) ≈ 1.0
            Test.@test interp(2.0) ≈ 0.0

            # Test at intermediate points
            Test.@test interp(0.5) ≈ 0.5
            Test.@test interp(1.5) ≈ 0.5
        end

        Test.@testset "ctinterpolate - extrapolation" begin
            # Test linear extrapolation beyond bounds
            x = [0.0, 1.0, 2.0]
            f = [1.0, 2.0, 3.0]

            interp = CTModels.ctinterpolate(x, f)

            # Extrapolate before first point (should follow line)
            Test.@test interp(-1.0) ≈ 0.0

            # Extrapolate after last point (should follow line)
            Test.@test interp(3.0) ≈ 4.0
        end

        Test.@testset "ctinterpolate - sine wave" begin
            # Interpolate a sine wave
            x = 0:0.5:2π
            f = sin.(x)

            interp = CTModels.ctinterpolate(x, f)

            # Test at some intermediate points
            Test.@test interp(π/4) ≈ sin(π/4) atol=0.1  # Linear interpolation, not exact
            Test.@test interp(π) ≈ sin(π) atol=0.1
        end

        Test.@testset "ctinterpolate - constant function" begin
            # Constant function
            x = [0.0, 1.0, 2.0, 3.0]
            f = [5.0, 5.0, 5.0, 5.0]

            interp = CTModels.ctinterpolate(x, f)

            # Should be constant everywhere
            Test.@test interp(0.5) ≈ 5.0
            Test.@test interp(1.5) ≈ 5.0
            Test.@test interp(2.5) ≈ 5.0
        end

        Test.@testset "ctinterpolate - non-uniform grid" begin
            # Non-uniform spacing
            x = [0.0, 0.1, 0.5, 1.0, 2.0]
            f = [0.0, 1.0, 2.0, 3.0, 4.0]

            interp = CTModels.ctinterpolate(x, f)

            # Test interpolation
            Test.@test interp(0.05) ≈ 0.5
            Test.@test interp(0.3) ≈ 1.5
            Test.@test interp(1.5) ≈ 3.5
        end

        Test.@testset "ctinterpolate - vector values" begin
            # Test with vector-valued function (if supported)
            x = [0.0, 1.0, 2.0]
            f = [[0.0, 0.0], [1.0, 2.0], [2.0, 4.0]]

            interp = CTModels.ctinterpolate(x, f)

            # Test at data points
            Test.@test interp(0.0) ≈ [0.0, 0.0]
            Test.@test interp(1.0) ≈ [1.0, 2.0]
            Test.@test interp(2.0) ≈ [2.0, 4.0]

            # Test at intermediate point
            Test.@test interp(0.5) ≈ [0.5, 1.0]
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_interpolation() = TestUtilsInterpolation.test_interpolation()
