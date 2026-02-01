module TestExceptionConversion

using Test
using CTModels.Exceptions
using CTBase
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

"""
Tests for CTBase compatibility layer (conversion.jl)
"""
function test_exception_conversion()
    @testset "CTBase Conversion" verbose = VERBOSE showtiming = SHOWTIMING begin
        
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
        
        @testset "NotImplemented - Simple Conversion" begin
            e = NotImplemented("run! not implemented")
            ctbase_e = to_ctbase(e)
            
            @test ctbase_e isa CTBase.NotImplemented
            @test contains(ctbase_e.var, "run! not implemented")
        end
        
        @testset "NotImplemented - Full Conversion" begin
            e = NotImplemented(
                "Method solve! not implemented",
                type_info="MyStrategy",
                context="solve call",
                suggestion="Import the relevant package (e.g. CTDirect) or implement solve!(::MyStrategy, ...)"
            )
            
            ctbase_e = to_ctbase(e)
            
            @test ctbase_e isa CTBase.NotImplemented
            @test contains(ctbase_e.var, "Method solve! not implemented")
            @test contains(ctbase_e.var, "type: MyStrategy")
            @test contains(ctbase_e.var, "context: solve call")
            @test contains(ctbase_e.var, "Suggestion: Import the relevant package")
        end
        
        @testset "NotImplemented - Partial Fields" begin
            # Only type_info field
            e1 = NotImplemented("Error", type_info="MyType")
            ctbase_e1 = to_ctbase(e1)
            @test contains(ctbase_e1.var, "Error")
            @test contains(ctbase_e1.var, "type: MyType")
            
            # Only context field
            e2 = NotImplemented("Error", context="test context")
            ctbase_e2 = to_ctbase(e2)
            @test contains(ctbase_e2.var, "Error")
            @test contains(ctbase_e2.var, "context: test context")
            
            # Only suggestion field
            e3 = NotImplemented("Error", suggestion="Fix it")
            ctbase_e3 = to_ctbase(e3)
            @test contains(ctbase_e3.var, "Error")
            @test contains(ctbase_e3.var, "Suggestion: Fix it")
        end
        
        @testset "ParsingError - Simple Conversion" begin
            e = ParsingError("Unexpected token")
            ctbase_e = to_ctbase(e)
            
            @test ctbase_e isa CTBase.NotImplemented
            @test contains(ctbase_e.var, "Unexpected token")
        end
        
        @testset "ParsingError - Full Conversion" begin
            e = ParsingError(
                "Unexpected token 'end'",
                location="line 42, column 15",
                suggestion="Check syntax balance or remove extra 'end'"
            )
            
            ctbase_e = to_ctbase(e)
            
            @test ctbase_e isa CTBase.NotImplemented
            @test contains(ctbase_e.var, "Unexpected token 'end'")
            @test contains(ctbase_e.var, "at: line 42, column 15")
            @test contains(ctbase_e.var, "Suggestion: Check syntax balance")
        end
        
        @testset "ParsingError - Partial Fields" begin
            # Only location field
            e1 = ParsingError("Error", location="line 10")
            ctbase_e1 = to_ctbase(e1)
            @test contains(ctbase_e1.var, "Error")
            @test contains(ctbase_e1.var, "at: line 10")
            
            # Only suggestion field
            e2 = ParsingError("Error", suggestion="Fix syntax")
            ctbase_e2 = to_ctbase(e2)
            @test contains(ctbase_e2.var, "Error")
            @test contains(ctbase_e2.var, "Suggestion: Fix syntax")
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
