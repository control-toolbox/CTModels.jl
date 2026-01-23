# Tests for strategy metadata functionality

function test_metadata()
    Test.@testset "StrategyMetadata" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ========================================================================
        # Basic construction with varargs
        # ========================================================================
        
        Test.@testset "Basic construction" begin
            meta = CTModels.Strategies.StrategyMetadata(
                CTModels.Options.OptionDefinition(
                    name = :max_iter,
                    type = Int,
                    default = 100,
                    description = "Maximum iterations"
                ),
                CTModels.Options.OptionDefinition(
                    name = :tol,
                    type = Float64,
                    default = 1e-6,
                    description = "Tolerance"
                )
            )
            
            Test.@test length(meta) == 2
            Test.@test Set(keys(meta)) == Set((:max_iter, :tol))
            Test.@test meta[:max_iter].name == :max_iter
            Test.@test meta[:max_iter].type == Int
            Test.@test meta[:max_iter].default == 100
            Test.@test meta[:tol].type == Float64
            Test.@test meta[:tol].default == 1e-6
        end
        
        # ========================================================================
        # Construction with aliases and validators
        # ========================================================================
        
        Test.@testset "Advanced construction" begin
            meta = CTModels.Strategies.StrategyMetadata(
                CTModels.Options.OptionDefinition(
                    name = :max_iter,
                    type = Int,
                    default = 100,
                    description = "Maximum iterations",
                    aliases = (:max, :maxiter),
                    validator = x -> x > 0
                )
            )
            
            def = meta[:max_iter]
            Test.@test def.aliases == (:max, :maxiter)
            Test.@test def.validator !== nothing
            Test.@test def.validator(10) == true
        end
        
        # ========================================================================
        # Duplicate name detection
        # ========================================================================
        
        Test.@testset "Duplicate detection" begin
            Test.@test_throws ErrorException CTModels.Strategies.StrategyMetadata(
                CTModels.Options.OptionDefinition(
                    name = :max_iter,
                    type = Int,
                    default = 100,
                    description = "First"
                ),
                CTModels.Options.OptionDefinition(
                    name = :max_iter,
                    type = Int,
                    default = 200,
                    description = "Second"
                )
            )
        end
        
        # ========================================================================
        # Empty metadata
        # ========================================================================
        
        Test.@testset "Empty metadata" begin
            meta = CTModels.Strategies.StrategyMetadata()
            Test.@test length(meta) == 0
            Test.@test collect(keys(meta)) == []
        end
        
        # ========================================================================
        # Indexability and iteration
        # ========================================================================
        
        Test.@testset "Indexability" begin
            meta = CTModels.Strategies.StrategyMetadata(
                CTModels.Options.OptionDefinition(
                    name = :option1,
                    type = Int,
                    default = 1,
                    description = "First option"
                ),
                CTModels.Options.OptionDefinition(
                    name = :option2,
                    type = String,
                    default = "test",
                    description = "Second option"
                )
            )
            
            # Test getindex
            Test.@test meta[:option1].default == 1
            Test.@test meta[:option2].default == "test"
            
            # Test keys, values, pairs
            Test.@test Set(keys(meta)) == Set((:option1, :option2))
            Test.@test length(collect(values(meta))) == 2
            Test.@test length(collect(pairs(meta))) == 2
            
            # Test iteration
            count = 0
            for (key, def) in meta
                Test.@test key in (:option1, :option2)
                Test.@test def isa CTModels.Options.OptionDefinition
                count += 1
            end
            Test.@test count == 2
        end
    end
end
