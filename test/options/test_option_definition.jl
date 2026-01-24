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
            
            # Invalid validator with invalid default (redirect stderr to hide @error logs)
            Test.@test_throws ErrorException redirect_stderr(devnull) do
                CTModels.Options.OptionDefinition(
                    name = :test,
                    type = Int,
                    default = -5,
                    description = "Test",
                    validator = x -> x > 0 || error("Must be positive")
                )
            end
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
        
        # ========================================================================
        # Type stability tests
        # ========================================================================
        
        Test.@testset "Type stability" begin
            # Test that OptionDefinition is parameterized correctly
            def_int = CTModels.Options.OptionDefinition(
                name = :test_int,
                type = Int,
                default = 42,
                description = "Test"
            )
            Test.@test def_int isa CTModels.Options.OptionDefinition{Int64}
            
            def_float = CTModels.Options.OptionDefinition(
                name = :test_float,
                type = Float64,
                default = 3.14,
                description = "Test"
            )
            Test.@test def_float isa CTModels.Options.OptionDefinition{Float64}
            
            def_string = CTModels.Options.OptionDefinition(
                name = :test_string,
                type = String,
                default = "hello",
                description = "Test"
            )
            Test.@test def_string isa CTModels.Options.OptionDefinition{String}
            
            # Test type-stable access to default field via function
            function get_default(def::CTModels.Options.OptionDefinition{T}) where T
                return def.default
            end
            
            Test.@inferred get_default(def_int)
            Test.@test typeof(def_int.default) === Int64
            Test.@test get_default(def_int) === 42
            
            Test.@inferred get_default(def_float)
            Test.@test typeof(def_float.default) === Float64
            Test.@test get_default(def_float) === 3.14
            
            Test.@inferred get_default(def_string)
            Test.@test typeof(def_string.default) === String
            Test.@test get_default(def_string) === "hello"
            
            # Test heterogeneous collections (Vector{OptionDefinition{<:Any}})
            defs = CTModels.Options.OptionDefinition[def_int, def_float, def_string]
            Test.@test length(defs) == 3
            Test.@test defs[1] isa CTModels.Options.OptionDefinition{Int64}
            Test.@test defs[2] isa CTModels.Options.OptionDefinition{Float64}
            Test.@test defs[3] isa CTModels.Options.OptionDefinition{String}
            
            # Test that accessing defaults in a loop maintains type information
            function sum_int_defaults(defs::Vector{<:CTModels.Options.OptionDefinition})
                total = 0
                for def in defs
                    if def isa CTModels.Options.OptionDefinition{Int}
                        total += def.default  # Type-stable within branch
                    end
                end
                return total
            end
            
            int_defs = [
                CTModels.Options.OptionDefinition(name=Symbol("opt$i"), type=Int, default=i, description="test")
                for i in 1:5
            ]
            Test.@test sum_int_defaults(int_defs) == 15
        end
        
        # ========================================================================
        # Display functionality
        # ========================================================================
        
        Test.@testset "Display" begin
            # Test with minimal OptionDefinition
            def_min = CTModels.Options.OptionDefinition(
                name = :test,
                type = Int,
                default = 42,
                description = "Test option"
            )
            
            # Test with full OptionDefinition
            def_full = CTModels.Options.OptionDefinition(
                name = :max_iter,
                type = Int,
                default = 100,
                description = "Maximum iterations",
                aliases = (:max, :maxiter),
                validator = x -> x > 0
            )
            
            # Test default display format (custom format)
            io_min = IOBuffer()
            println(io_min, def_min)
            output_min = String(take!(io_min))
            
            io_full = IOBuffer()
            println(io_full, def_full)
            output_full = String(take!(io_full))
            
            # Check that custom display contains expected elements
            Test.@test occursin("test :: Int64", output_min)
            Test.@test occursin("  default: 42", output_min)
            Test.@test occursin("  description: Test option", output_min)
            
            Test.@test occursin("max_iter (max, maxiter) :: Int64", output_full)
            Test.@test occursin("  default: 100", output_full)
            Test.@test occursin("  description: Maximum iterations", output_full)
            
            # Test that all fields are present in output
            Test.@test occursin("test", output_min)
            Test.@test occursin("Int64", output_min)
            Test.@test occursin("42", output_min)
            Test.@test occursin("Test option", output_min)
            
            Test.@test occursin("max_iter", output_full)
            Test.@test occursin("Int64", output_full)
            Test.@test occursin("100", output_full)
            Test.@test occursin("Maximum iterations", output_full)
        end
    end
end
