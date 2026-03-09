module TestUtilsFunctionUtils

using Test: Test
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

"""
    test_function_utils()

Test function utility functions from src/utils/function_utils.jl.
"""
function test_function_utils()
    Test.@testset "Function Utils Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for function utils functionality
        end

        # ====================================================================
        # UNIT TESTS - Function Utility Functions
        # ====================================================================
        Test.@testset "to_out_of_place - basic conversion" begin
            # In-place function that fills a 2-element vector
            function f!(r, x)
                r[1] = sin(x)
                r[2] = cos(x)
                return r
            end

            # Convert to out-of-place (private function from Utils module)
            f = CTModels.Utils.to_out_of_place(f!, 2)

            # Test the converted function
            result = f(π/4)
            Test.@test result isa Vector
            Test.@test length(result) == 2
            Test.@test result[1] ≈ sin(π/4)
            Test.@test result[2] ≈ cos(π/4)
        end

        Test.@testset "to_out_of_place - scalar output (n=1)" begin
            # In-place function with scalar output
            function g!(r, x)
                r[1] = x^2
                return r
            end

            # Convert to out-of-place with n=1
            g = CTModels.Utils.to_out_of_place(g!, 1)

            # Should return a scalar, not a vector
            result = g(3.0)
            Test.@test result isa Float64
            Test.@test result ≈ 9.0
        end

        Test.@testset "to_out_of_place - with kwargs" begin
            # In-place function that uses kwargs
            function h!(r, x; scale=1.0)
                r[1] = x * scale
                r[2] = x^2 * scale
                return r
            end

            # Convert to out-of-place
            h = CTModels.Utils.to_out_of_place(h!, 2)

            # Test with default kwargs
            result1 = h(2.0)
            Test.@test result1[1] ≈ 2.0
            Test.@test result1[2] ≈ 4.0

            # Test with custom kwargs
            result2 = h(2.0; scale=3.0)
            Test.@test result2[1] ≈ 6.0
            Test.@test result2[2] ≈ 12.0
        end

        Test.@testset "to_out_of_place - multiple arguments" begin
            # In-place function with multiple arguments
            function k!(r, x, y)
                r[1] = x + y
                r[2] = x * y
                return r
            end

            # Convert to out-of-place
            k = CTModels.Utils.to_out_of_place(k!, 2)

            # Test with multiple arguments
            result = k(3.0, 4.0)
            Test.@test result[1] ≈ 7.0
            Test.@test result[2] ≈ 12.0
        end

        Test.@testset "to_out_of_place - custom type" begin
            # Test with Int type
            function m!(r, x)
                r[1] = x + 1
                r[2] = x + 2
                return r
            end

            # Convert with Int type
            m = CTModels.Utils.to_out_of_place(m!, 2; T=Int)

            result = m(5)
            Test.@test result isa Vector{Int}
            Test.@test result[1] == 6
            Test.@test result[2] == 7
        end

        Test.@testset "to_out_of_place - nothing input" begin
            # Test that nothing input returns nothing
            result = CTModels.Utils.to_out_of_place(nothing, 2)
            Test.@test result === nothing
        end

        Test.@testset "to_out_of_place - larger output" begin
            # Test with larger output vector
            function big!(r, x)
                for i in 1:5
                    r[i] = x * i
                end
                return r
            end

            big = CTModels.Utils.to_out_of_place(big!, 5)

            result = big(2.0)
            Test.@test length(result) == 5
            Test.@test result == [2.0, 4.0, 6.0, 8.0, 10.0]
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_function_utils() = TestUtilsFunctionUtils.test_function_utils()
