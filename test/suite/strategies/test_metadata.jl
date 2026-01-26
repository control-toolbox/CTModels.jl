module TestStrategiesMetadata

using Test
using CTModels
using CTModels.Strategies
using CTModels.Options
using CTBase
using Main.TestOptions: VERBOSE, SHOWTIMING

"""
    test_metadata()

Tests for strategy metadata functionality.
"""
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
            Test.@test_throws CTBase.IncorrectArgument CTModels.Strategies.StrategyMetadata(
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
        
        # ========================================================================
        # Display functionality
        # ========================================================================
        
        Test.@testset "Display" begin
            meta = CTModels.Strategies.StrategyMetadata(
                CTModels.Options.OptionDefinition(
                    name = :max_iter,
                    type = Int,
                    default = 100,
                    description = "Maximum iterations",
                    aliases = (:max, :maxiter),
                    validator = x -> x > 0
                ),
                CTModels.Options.OptionDefinition(
                    name = :tol,
                    type = Float64,
                    default = 1e-6,
                    description = "Convergence tolerance"
                )
            )
            
            # Test that show method produces expected output format
            io = IOBuffer()
            Base.show(io, MIME"text/plain"(), meta)
            output = String(take!(io))
            
            # Check that output contains expected elements
            Test.@test occursin("StrategyMetadata with 2 options:", output)
            Test.@test occursin("max_iter (max, maxiter) :: Int64", output)
            Test.@test occursin("tol :: Float64", output)
            Test.@test occursin("default: 100", output)
            Test.@test occursin("default: 1.0e-6", output)
            Test.@test occursin("description: Maximum iterations", output)
            Test.@test occursin("description: Convergence tolerance", output)
        end
        
        # ========================================================================
        # Type stability tests
        # ========================================================================
        
        Test.@testset "Type stability" begin
            # Create metadata with different types
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
            
            # Test that StrategyMetadata is parameterized correctly
            Test.@test meta isa CTModels.Strategies.StrategyMetadata{<:NamedTuple}
            
            # Verify that the NamedTuple preserves concrete types
            Test.@test meta.specs.max_iter isa CTModels.Options.OptionDefinition{Int64}
            Test.@test meta.specs.tol isa CTModels.Options.OptionDefinition{Float64}
            
            # Test direct access to specs (type-stable)
            function get_max_iter_spec(m::CTModels.Strategies.StrategyMetadata)
                return m.specs.max_iter
            end
            function get_tol_spec(m::CTModels.Strategies.StrategyMetadata)
                return m.specs.tol
            end
            
            Test.@inferred get_max_iter_spec(meta)
            Test.@test get_max_iter_spec(meta).default === 100
            
            Test.@inferred get_tol_spec(meta)
            Test.@test get_tol_spec(meta).default === 1e-6
            
            # Note: Dynamic access via Symbol (meta[:key]) cannot be type-stable
            # This is expected and acceptable since metadata access happens at construction time
            Test.@test meta[:max_iter] isa CTModels.Options.OptionDefinition{Int64}
            Test.@test meta[:tol] isa CTModels.Options.OptionDefinition{Float64}
            
            # Test type-stable iteration with type narrowing
            function sum_int_defaults(m::CTModels.Strategies.StrategyMetadata)
                total = 0
                for (key, def) in m
                    if def isa CTModels.Options.OptionDefinition{Int}
                        total += def.default  # Type-stable within branch
                    end
                end
                return total
            end
            
            Test.@inferred sum_int_defaults(meta)
            Test.@test sum_int_defaults(meta) == 100
            
            # Test that values() preserves types
            vals = collect(values(meta))
            Test.@test vals[1] isa CTModels.Options.OptionDefinition{Int64}
            Test.@test vals[2] isa CTModels.Options.OptionDefinition{Float64}
        end
    end
end

end # module

test_metadata() = TestStrategiesMetadata.test_metadata()
