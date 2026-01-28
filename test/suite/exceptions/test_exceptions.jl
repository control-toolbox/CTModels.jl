module TestExceptions

using Test
using CTModels
using CTModels.Exceptions
using CTBase

function test_exceptions()
    @testset "Enhanced Exception System" verbose = true begin
        
        @testset "IncorrectArgument - Basic" begin
            # Simple message
            e = IncorrectArgument("Invalid input")
            @test e.msg == "Invalid input"
            @test isnothing(e.got)
            @test isnothing(e.expected)
            @test isnothing(e.suggestion)
            @test isnothing(e.context)
            
            # Test that it can be thrown
            @test_throws IncorrectArgument throw(IncorrectArgument("Test error"))
        end
        
        @testset "IncorrectArgument - Enriched" begin
            # With all fields
            e = IncorrectArgument(
                "Invalid criterion",
                got=":invalid",
                expected=":min or :max",
                suggestion="Use objective!(ocp, :min, ...) or objective!(ocp, :max, ...)",
                context="objective! function"
            )
            
            @test e.msg == "Invalid criterion"
            @test e.got == ":invalid"
            @test e.expected == ":min or :max"
            @test !isnothing(e.suggestion)
            @test e.context == "objective! function"
        end
        
        @testset "UnauthorizedCall - Basic" begin
            e = UnauthorizedCall("State already set")
            @test e.msg == "State already set"
            @test isnothing(e.reason)
            @test isnothing(e.suggestion)
            
            @test_throws UnauthorizedCall throw(UnauthorizedCall("Test error"))
        end
        
        @testset "UnauthorizedCall - Enriched" begin
            e = UnauthorizedCall(
                "Cannot call state! twice",
                reason="state has already been defined for this OCP",
                suggestion="Create a new OCP instance"
            )
            
            @test e.msg == "Cannot call state! twice"
            @test !isnothing(e.reason)
            @test !isnothing(e.suggestion)
        end
        
        @testset "NotImplemented" begin
            e = NotImplemented("run! not implemented", type_info="MyAlgorithm")
            @test e.msg == "run! not implemented"
            @test e.type_info == "MyAlgorithm"
            
            @test_throws NotImplemented throw(NotImplemented("Test"))
        end
        
        @testset "ParsingError" begin
            e = ParsingError("Unexpected token", location="line 42")
            @test e.msg == "Unexpected token"
            @test e.location == "line 42"
            
            @test_throws ParsingError throw(ParsingError("Test"))
        end
        
        @testset "Stacktrace Control" begin
            # Test default value
            @test CTModels.get_show_full_stacktrace() == false
            
            # Test setting to true
            CTModels.set_show_full_stacktrace!(true)
            @test CTModels.get_show_full_stacktrace() == true
            
            # Test setting back to false
            CTModels.set_show_full_stacktrace!(false)
            @test CTModels.get_show_full_stacktrace() == false
        end
        
        @testset "Error Display" begin
            # Test that showerror doesn't crash
            io = IOBuffer()
            e = IncorrectArgument(
                "Test error",
                got="value1",
                expected="value2",
                suggestion="Fix it like this"
            )
            
            # User-friendly display (default)
            CTModels.set_show_full_stacktrace!(false)
            @test_nowarn showerror(io, e)
            output = String(take!(io))
            @test contains(output, "ERROR in CTModels")
            @test contains(output, "Test error")
            @test contains(output, "value1")
            @test contains(output, "value2")
            @test contains(output, "Fix it like this")
            
            # Full stacktrace display
            CTModels.set_show_full_stacktrace!(true)
            @test_nowarn showerror(io, e)
            output = String(take!(io))
            @test contains(output, "IncorrectArgument")
            @test contains(output, "Test error")
            
            # Reset to default
            CTModels.set_show_full_stacktrace!(false)
        end
        
        @testset "CTBase Compatibility" begin
            # Test conversion to CTBase
            e1 = IncorrectArgument(
                "Invalid input",
                got="x",
                expected="y",
                suggestion="Use y instead"
            )
            
            ctbase_e1 = CTModels.Exceptions.to_ctbase(e1)
            @test ctbase_e1 isa CTBase.IncorrectArgument
            @test contains(ctbase_e1.var, "Invalid input")
            @test contains(ctbase_e1.var, "got: x")
            @test contains(ctbase_e1.var, "expected: y")
            
            e2 = UnauthorizedCall(
                "Cannot call",
                reason="already called",
                suggestion="Create new instance"
            )
            
            ctbase_e2 = CTModels.Exceptions.to_ctbase(e2)
            @test ctbase_e2 isa CTBase.UnauthorizedCall
            @test contains(ctbase_e2.var, "Cannot call")
            @test contains(ctbase_e2.var, "reason: already called")
        end
        
        @testset "Exception Hierarchy" begin
            # Test that all exceptions are CTModelsException
            @test IncorrectArgument("test") isa CTModelsException
            @test UnauthorizedCall("test") isa CTModelsException
            @test NotImplemented("test") isa CTModelsException
            @test ParsingError("test") isa CTModelsException
            
            # Test that they are also Exception
            @test IncorrectArgument("test") isa Exception
            @test UnauthorizedCall("test") isa Exception
        end
    end
end

end # module

test_exceptions() = TestExceptions.test_exceptions()
