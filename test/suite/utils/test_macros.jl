module TestUtilsMacros

using Test: Test
using CTModels: CTModels
using CTBase: CTBase

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

"""
    test_macros()

Test macro utility functions from src/utils/macros.jl.
"""
function test_macros()
    Test.@testset "Macro Utils Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for macro utils functionality
        end

        # ====================================================================
        # UNIT TESTS - Macro Utility Functions
        # ====================================================================
        Test.@testset "@ensure - condition true" begin
            # Should not throw when condition is true
            x = 5
            Test.@test_nowarn CTModels.@ensure x > 0 CTBase.IncorrectArgument(
                "x must be positive"
            )
            Test.@test_nowarn CTModels.@ensure x == 5 CTBase.IncorrectArgument(
                "x must be 5"
            )
        end

        Test.@testset "@ensure - condition false" begin
            # Should throw when condition is false
            x = -5
            Test.@test_throws CTBase.IncorrectArgument CTModels.@ensure x > 0 CTBase.IncorrectArgument(
                "x must be positive"
            )

            y = 10
            Test.@test_throws CTBase.IncorrectArgument CTModels.@ensure y < 0 CTBase.IncorrectArgument(
                "y must be negative"
            )
        end

        Test.@testset "@ensure - with different exception types" begin
            # Test with different exception types
            x = 0
            Test.@test_throws ArgumentError CTModels.@ensure x != 0 ArgumentError(
                "x cannot be zero"
            )
            Test.@test_throws DomainError CTModels.@ensure x > 0 DomainError(
                x, "x must be positive"
            )
        end

        Test.@testset "@ensure - complex conditions" begin
            # Test with more complex conditions
            x = 5
            y = 10

            Test.@test_nowarn CTModels.@ensure x < y CTBase.IncorrectArgument(
                "x must be less than y"
            )
            Test.@test_throws CTBase.IncorrectArgument CTModels.@ensure x > y CTBase.IncorrectArgument(
                "x must be greater than y"
            )

            # Test with logical operators
            Test.@test_nowarn CTModels.@ensure (x > 0 && y > 0) CTBase.IncorrectArgument(
                "both must be positive"
            )
            Test.@test_throws CTBase.IncorrectArgument CTModels.@ensure (x < 0 || y < 0) CTBase.IncorrectArgument(
                "at least one must be negative"
            )
        end

        Test.@testset "@ensure - with function calls" begin
            # Test with function calls in condition
            function is_positive(x)
                return x > 0
            end

            x = 5
            Test.@test_nowarn CTModels.@ensure is_positive(x) CTBase.IncorrectArgument(
                "x must be positive"
            )

            x = -5
            Test.@test_throws CTBase.IncorrectArgument CTModels.@ensure is_positive(x) CTBase.IncorrectArgument(
                "x must be positive"
            )
        end

        Test.@testset "@ensure - exception message verification" begin
            # Verify that the exception is thrown correctly
            x = -5
            try
                CTModels.@ensure x > 0 CTBase.IncorrectArgument("x must be positive")
                Test.@test false  # Should not reach here
            catch e
                Test.@test e isa CTBase.IncorrectArgument
                # CTBase.IncorrectArgument stores the message in var field
                Test.@test e.msg == "x must be positive"
            end
        end

        Test.@testset "@ensure - with type checks" begin
            # Test with type checking conditions
            x = 5
            Test.@test_nowarn CTModels.@ensure x isa Int CTBase.IncorrectArgument(
                "x must be an Int"
            )
            Test.@test_throws CTBase.IncorrectArgument CTModels.@ensure x isa String CTBase.IncorrectArgument(
                "x must be a String"
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_macros() = TestUtilsMacros.test_macros()
