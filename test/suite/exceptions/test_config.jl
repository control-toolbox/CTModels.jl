module TestExceptionConfig

using Test
using CTModels
using CTModels.Exceptions
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

"""
Tests for exception configuration (config.jl)
"""
function test_exception_config()
    @testset "Exception Configuration" verbose = VERBOSE showtiming = SHOWTIMING begin
        
        @testset "Stacktrace Control - Default Value" begin
            # Test default value is false (user-friendly display)
            @test CTModels.get_show_full_stacktrace() == true
        end
        
        @testset "Stacktrace Control - Set to True" begin
            # Test setting to true (full Julia stacktraces)
            CTModels.set_show_full_stacktrace!(true)
            @test CTModels.get_show_full_stacktrace() == true
        end
        
        @testset "Stacktrace Control - Set to False" begin
            # Test setting back to false
            CTModels.set_show_full_stacktrace!(false)
            @test CTModels.get_show_full_stacktrace() == false
        end
        
        @testset "Stacktrace Control - Multiple Toggles" begin
            # Test multiple toggles work correctly
            original = CTModels.get_show_full_stacktrace()
            
            CTModels.set_show_full_stacktrace!(true)
            @test CTModels.get_show_full_stacktrace() == true
            
            CTModels.set_show_full_stacktrace!(false)
            @test CTModels.get_show_full_stacktrace() == false
            
            CTModels.set_show_full_stacktrace!(true)
            @test CTModels.get_show_full_stacktrace() == true
            
            # Restore original state
            CTModels.set_show_full_stacktrace!(original)
        end
        
        @testset "Stacktrace Control - Return Value" begin
            # Test that set_show_full_stacktrace! returns nothing
            result = CTModels.set_show_full_stacktrace!(false)
            @test isnothing(result)
        end
    end
end

end # module

test_config() = TestExceptionConfig.test_exception_config()
