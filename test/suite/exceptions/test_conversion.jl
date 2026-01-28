module TestExceptionConversion

using Test
using CTModels.Exceptions
using CTBase

"""
Tests for CTBase compatibility layer (conversion.jl)
"""
function test_exception_conversion()
    @testset "CTBase Conversion" verbose = true begin
        
        @testset "IncorrectArgument - Simple Conversion" begin
            e = IncorrectArgument("Invalid input")
            ctbase_e = to_ctbase(e)
            
            @test ctbase_e isa CTBase.IncorrectArgument
            @test contains(ctbase_e.var, "Invalid input")
        end
        
        @testset "IncorrectArgument - Full Conversion" begin
            e = IncorrectArgument(
                "Invalid input",
                got="x",
                expected="y",
                suggestion="Use y instead"
            )
            
            ctbase_e = to_ctbase(e)
            
            @test ctbase_e isa CTBase.IncorrectArgument
            @test contains(ctbase_e.var, "Invalid input")
            @test contains(ctbase_e.var, "got: x")
            @test contains(ctbase_e.var, "expected: y")
            @test contains(ctbase_e.var, "Suggestion: Use y instead")
        end
        
        @testset "IncorrectArgument - Partial Fields" begin
            # Only got field
            e1 = IncorrectArgument("Error", got="value")
            ctbase_e1 = to_ctbase(e1)
            @test contains(ctbase_e1.var, "Error")
            @test contains(ctbase_e1.var, "got: value")
            
            # Only expected field
            e2 = IncorrectArgument("Error", expected="expected_value")
            ctbase_e2 = to_ctbase(e2)
            @test contains(ctbase_e2.var, "Error")
            @test contains(ctbase_e2.var, "expected: expected_value")
            
            # Only suggestion field
            e3 = IncorrectArgument("Error", suggestion="Fix it")
            ctbase_e3 = to_ctbase(e3)
            @test contains(ctbase_e3.var, "Error")
            @test contains(ctbase_e3.var, "Suggestion: Fix it")
        end
        
        @testset "UnauthorizedCall - Simple Conversion" begin
            e = UnauthorizedCall("Cannot call")
            ctbase_e = to_ctbase(e)
            
            @test ctbase_e isa CTBase.UnauthorizedCall
            @test contains(ctbase_e.var, "Cannot call")
        end
        
        @testset "UnauthorizedCall - Full Conversion" begin
            e = UnauthorizedCall(
                "Cannot call",
                reason="already called",
                suggestion="Create new instance"
            )
            
            ctbase_e = to_ctbase(e)
            
            @test ctbase_e isa CTBase.UnauthorizedCall
            @test contains(ctbase_e.var, "Cannot call")
            @test contains(ctbase_e.var, "reason: already called")
            @test contains(ctbase_e.var, "Suggestion: Create new instance")
        end
        
        @testset "UnauthorizedCall - Partial Fields" begin
            # Only reason field
            e1 = UnauthorizedCall("Error", reason="test reason")
            ctbase_e1 = to_ctbase(e1)
            @test contains(ctbase_e1.var, "Error")
            @test contains(ctbase_e1.var, "reason: test reason")
            
            # Only suggestion field
            e2 = UnauthorizedCall("Error", suggestion="Fix it")
            ctbase_e2 = to_ctbase(e2)
            @test contains(ctbase_e2.var, "Error")
            @test contains(ctbase_e2.var, "Suggestion: Fix it")
        end
        
        @testset "Conversion - Preserves Information" begin
            # Test that all information is preserved in conversion
            e = IncorrectArgument(
                "Complex error",
                got="actual_value",
                expected="expected_value",
                suggestion="Do this instead"
            )
            
            ctbase_e = to_ctbase(e)
            msg = ctbase_e.var
            
            # All parts should be in the message
            @test contains(msg, "Complex error")
            @test contains(msg, "actual_value")
            @test contains(msg, "expected_value")
            @test contains(msg, "Do this instead")
        end
    end
end

end # module

test_conversion() = TestExceptionConversion.test_exception_conversion()
