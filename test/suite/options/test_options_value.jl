function test_options_value()
    Test.@testset "Options module" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Test OptionValue construction and basic properties
        Test.@testset "OptionValue construction" begin
            # Test with explicit source
            opt_user = CTModels.Options.OptionValue(42, :user)
            Test.@test opt_user.value == 42
            Test.@test opt_user.source == :user
            Test.@test typeof(opt_user) == CTModels.Options.OptionValue{Int}
            
            # Test with default source
            opt_default = CTModels.Options.OptionValue(3.14)
            Test.@test opt_default.value == 3.14
            Test.@test opt_default.source == :user
            Test.@test typeof(opt_default) == CTModels.Options.OptionValue{Float64}
            
            # Test with different types
            opt_str = CTModels.Options.OptionValue("hello", :default)
            Test.@test opt_str.value == "hello"
            Test.@test opt_str.source == :default
            
            opt_bool = CTModels.Options.OptionValue(true, :computed)
            Test.@test opt_bool.value == true
            Test.@test opt_bool.source == :computed
        end
        
        # Test OptionValue validation
        Test.@testset "OptionValue validation" begin
            # Test invalid sources
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionValue(42, :invalid)
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionValue(42, :wrong)
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionValue(42, :DEFAULT)  # case sensitive
        end
        
        # Test OptionValue display
        Test.@testset "OptionValue display" begin
            opt = CTModels.Options.OptionValue(100, :user)
            io = IOBuffer()
            Base.show(io, opt)
            Test.@test String(take!(io)) == "100 (user)"
            
            opt_default = CTModels.Options.OptionValue(3.14, :default)
            io = IOBuffer()
            Base.show(io, opt_default)
            Test.@test String(take!(io)) == "3.14 (default)"
        end
        
        # Test OptionValue type stability
        Test.@testset "OptionValue type stability" begin
            opt_int = CTModels.Options.OptionValue(42, :user)
            opt_float = CTModels.Options.OptionValue(3.14, :user)
            
            # Test that types are preserved
            Test.@test typeof(opt_int.value) == Int
            Test.@test typeof(opt_float.value) == Float64
            
            # Test that the struct is parameterized correctly
            Test.@test typeof(opt_int) == CTModels.Options.OptionValue{Int}
            Test.@test typeof(opt_float) == CTModels.Options.OptionValue{Float64}
        end
    end
end