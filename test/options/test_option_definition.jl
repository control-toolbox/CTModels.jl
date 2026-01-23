function test_option_definition()
    Test.@testset "OptionDefinition" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ========================================================================
        # Basic construction
        # ========================================================================
        
        Test.@testset "Basic construction" begin
            # Minimal constructor
            def = CTModels.Options.OptionDefinition(
                name = :test_option,
                type = Int,
                default = 42,
                description = "Test option"
            )
            Test.@test def.name == :test_option
            Test.@test def.type == Int
            Test.@test def.default == 42
            Test.@test def.description == "Test option"
            Test.@test def.aliases == ()
            Test.@test def.validator === nothing
        end
        
        # ========================================================================
        # Full construction with aliases and validator
        # ========================================================================
        
        Test.@testset "Full construction" begin
            validator = x -> x > 0
            def = CTModels.Options.OptionDefinition(
                name = :max_iter,
                type = Int,
                default = 100,
                description = "Maximum iterations",
                aliases = (:max, :maxiter),
                validator = validator
            )
            Test.@test def.name == :max_iter
            Test.@test def.type == Int
            Test.@test def.default == 100
            Test.@test def.description == "Maximum iterations"
            Test.@test def.aliases == (:max, :maxiter)
            Test.@test def.validator === validator
        end
        
        # ========================================================================
        # Minimal construction
        # ========================================================================
        
        Test.@testset "Minimal construction" begin
            def = CTModels.Options.OptionDefinition(
                name = :test,
                type = String,
                default = "default",
                description = "Test option"
            )
            Test.@test def.name == :test
            Test.@test def.type == String
            Test.@test def.default == "default"
            Test.@test def.description == "Test option"
            Test.@test def.aliases == ()
            Test.@test def.validator === nothing
        end
        
        # ========================================================================
        # Validation
        # ========================================================================
        
        Test.@testset "Validation" begin
            # Valid default value type
            Test.@test_nowarn CTModels.Options.OptionDefinition(
                name = :test,
                type = Int,
                default = 42,
                description = "Test"
            )
            
            # Invalid default value type
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionDefinition(
                name = :test,
                type = Int,
                default = "not an int",
                description = "Test"
            )
            
            # Valid validator with valid default
            Test.@test_nowarn CTModels.Options.OptionDefinition(
                name = :test,
                type = Int,
                default = 42,
                description = "Test",
                validator = x -> x > 0
            )
            
            # Invalid validator with invalid default
            Test.@test_throws CTBase.IncorrectArgument CTModels.Options.OptionDefinition(
                name = :test,
                type = Int,
                default = -5,
                description = "Test",
                validator = x -> x > 0 || error("Must be positive")
            )
        end
        
        # ========================================================================
        # all_names function
        # ========================================================================
        
        Test.@testset "all_names function" begin
            def = CTModels.Options.OptionDefinition(
                name = :max_iter,
                type = Int,
                default = 100,
                description = "Test",
                aliases = (:max, :maxiter)
            )
            names = CTModels.Options.all_names(def)
            Test.@test names == (:max_iter, :max, :maxiter)
        end
        
        # ========================================================================
        # Edge cases
        # ========================================================================
        
        Test.@testset "Edge cases" begin
            # nothing default (allowed)
            def = CTModels.Options.OptionDefinition(
                name = :test,
                type = Any,
                default = nothing,
                description = "Test"
            )
            Test.@test def.default === nothing
            
            # nothing validator (allowed)
            def = CTModels.Options.OptionDefinition(
                name = :test,
                type = Int,
                default = 42,
                description = "Test",
                validator = nothing
            )
            Test.@test def.validator === nothing
        end
    end
end
