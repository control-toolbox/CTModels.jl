module TestExceptionTypes

using Test
using CTModels.Exceptions
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

"""
Tests for exception type definitions (types.jl)
"""
function test_exception_types()
    @testset "Exception Types" verbose = VERBOSE showtiming = SHOWTIMING begin
        
        @testset "CTModelsException Hierarchy" begin
            # Test that all exceptions inherit from CTModelsException
            @test IncorrectArgument("test") isa CTModelsException
            @test UnauthorizedCall("test") isa CTModelsException
            @test NotImplemented("test") isa CTModelsException
            @test ParsingError("test") isa CTModelsException
            
            # Test that they are also standard Exceptions
            @test IncorrectArgument("test") isa Exception
            @test UnauthorizedCall("test") isa Exception
            @test NotImplemented("test") isa Exception
            @test ParsingError("test") isa Exception
        end
        
        @testset "IncorrectArgument - Construction" begin
            # Simple message only
            e = IncorrectArgument("Invalid input")
            @test e.msg == "Invalid input"
            @test isnothing(e.got)
            @test isnothing(e.expected)
            @test isnothing(e.suggestion)
            @test isnothing(e.context)
            
            # With got and expected
            e = IncorrectArgument("Invalid value", got="x", expected="y")
            @test e.msg == "Invalid value"
            @test e.got == "x"
            @test e.expected == "y"
            @test isnothing(e.suggestion)
            @test isnothing(e.context)
            
            # With all fields
            e = IncorrectArgument(
                "Invalid criterion",
                got=":invalid",
                expected=":min or :max",
                suggestion="Use objective!(ocp, :min, ...)",
                context="objective! function"
            )
            @test e.msg == "Invalid criterion"
            @test e.got == ":invalid"
            @test e.expected == ":min or :max"
            @test e.suggestion == "Use objective!(ocp, :min, ...)"
            @test e.context == "objective! function"
            
            # Test that it can be thrown
            @test_throws IncorrectArgument throw(IncorrectArgument("Test error"))
        end
        
        @testset "UnauthorizedCall - Construction" begin
            # Simple message only
            e = UnauthorizedCall("State already set")
            @test e.msg == "State already set"
            @test isnothing(e.reason)
            @test isnothing(e.suggestion)
            @test isnothing(e.context)
            
            # With reason
            e = UnauthorizedCall("Cannot call", reason="already called")
            @test e.msg == "Cannot call"
            @test e.reason == "already called"
            @test isnothing(e.suggestion)
            
            # With all fields
            e = UnauthorizedCall(
                "Cannot call state! twice",
                reason="state has already been defined for this OCP",
                suggestion="Create a new OCP instance",
                context="state! function"
            )
            @test e.msg == "Cannot call state! twice"
            @test e.reason == "state has already been defined for this OCP"
            @test e.suggestion == "Create a new OCP instance"
            @test e.context == "state! function"
            
            # Test that it can be thrown
            @test_throws UnauthorizedCall throw(UnauthorizedCall("Test error"))
        end
        
        @testset "NotImplemented - Construction" begin
            # Simple message only
            e = NotImplemented("run! not implemented")
            @test e.msg == "run! not implemented"
            @test isnothing(e.type_info)
            @test isnothing(e.suggestion)
            @test isnothing(e.context)
            
            # With type info
            e = NotImplemented("run! not implemented", type_info="MyAlgorithm")
            @test e.msg == "run! not implemented"
            @test e.type_info == "MyAlgorithm"
            @test isnothing(e.suggestion)
            @test isnothing(e.context)
            
            # With all fields (NEW)
            e = NotImplemented(
                "Method solve! not implemented",
                type_info="MyStrategy",
                context="solve call",
                suggestion="Import the relevant package (e.g. CTDirect) or implement solve!(::MyStrategy, ...)"
            )
            @test e.msg == "Method solve! not implemented"
            @test e.type_info == "MyStrategy"
            @test e.context == "solve call"
            @test e.suggestion == "Import the relevant package (e.g. CTDirect) or implement solve!(::MyStrategy, ...)"
            
            # Test that it can be thrown
            @test_throws NotImplemented throw(NotImplemented("Test"))
        end
        
        @testset "ParsingError - Construction" begin
            # Simple message only
            e = ParsingError("Unexpected token")
            @test e.msg == "Unexpected token"
            @test isnothing(e.location)
            @test isnothing(e.suggestion)
            
            # With location
            e = ParsingError("Unexpected token", location="line 42")
            @test e.msg == "Unexpected token"
            @test e.location == "line 42"
            @test isnothing(e.suggestion)
            
            # With all fields (NEW)
            e = ParsingError(
                "Unexpected token 'end'",
                location="line 42, column 15",
                suggestion="Check syntax balance or remove extra 'end'"
            )
            @test e.msg == "Unexpected token 'end'"
            @test e.location == "line 42, column 15"
            @test e.suggestion == "Check syntax balance or remove extra 'end'"
            
            # Test that it can be thrown
            @test_throws ParsingError throw(ParsingError("Test"))
        end
    end
end

end # module

test_types() = TestExceptionTypes.test_exception_types()
