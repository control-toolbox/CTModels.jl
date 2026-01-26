# Test NotProvided behavior

using Test
using CTModels.Options

"""
    test_not_provided()

Test the NotProvided type and its behavior in the option system.
"""
function test_not_provided()
    @testset "NotProvided Type Tests" begin
        @testset "NotProvided Basic Properties" begin
            @test NotProvided isa NotProvidedType
            @test typeof(NotProvided) == NotProvidedType
            @test string(NotProvided) == "NotProvided"
        end
        
        @testset "OptionDefinition with NotProvided" begin
            # Option with NotProvided default
            def_not_provided = OptionDefinition(
                name = :optional_param,
                type = Union{Int, Nothing},
                default = NotProvided,
                description = "Optional parameter"
            )
            
            @test def_not_provided.default === NotProvided
            @test def_not_provided.default isa NotProvidedType
            
            # Option with nothing default (different!)
            def_nothing = OptionDefinition(
                name = :nullable_param,
                type = Union{Int, Nothing},
                default = nothing,
                description = "Nullable parameter"
            )
            
            @test def_nothing.default === nothing
            @test !(def_nothing.default isa NotProvidedType)
        end
        
        @testset "extract_option with NotProvided" begin
            def = OptionDefinition(
                name = :optional,
                type = Union{Int, Nothing},
                default = NotProvided,
                description = "Optional"
            )
            
            # Case 1: User provides value
            kwargs_provided = (optional = 42, other = "test")
            opt_val, remaining = extract_option(kwargs_provided, def)
            
            @test opt_val !== nothing  # Should return OptionValue
            @test opt_val isa OptionValue
            @test opt_val.value == 42
            @test opt_val.source == :user
            @test !haskey(remaining, :optional)
            
            # Case 2: User does NOT provide value
            kwargs_not_provided = (other = "test",)
            opt_val2, remaining2 = extract_option(kwargs_not_provided, def)
            
            @test opt_val2 isa Options.NotStoredType  # Should return NotStored (signal "don't store")
            @test remaining2 == kwargs_not_provided
        end
        
        @testset "extract_options filters NotProvided" begin
            defs = [
                OptionDefinition(
                    name = :required,
                    type = Int,
                    default = 100,
                    description = "Required with default"
                ),
                OptionDefinition(
                    name = :optional,
                    type = Union{Int, Nothing},
                    default = NotProvided,
                    description = "Optional"
                ),
                OptionDefinition(
                    name = :nullable,
                    type = Union{Int, Nothing},
                    default = nothing,
                    description = "Nullable with nothing default"
                )
            ]
            
            # User provides only 'required'
            kwargs = (required = 200,)
            extracted, remaining = extract_options(kwargs, defs)
            
            # Check what's stored
            @test haskey(extracted, :required)
            @test !haskey(extracted, :optional)  # NotProvided + not provided = not stored
            @test haskey(extracted, :nullable)   # nothing default = always stored
            
            @test extracted[:required].value == 200
            @test extracted[:nullable].value === nothing
            
            # Verify NO NotProvidedType in extracted values
            for (k, v) in pairs(extracted)
                @test !(v.value isa NotProvidedType)
            end
        end
        
        @testset "extract_options stores nothing defaults correctly" begin
            # Test that options with explicit nothing default are stored
            defs = [
                OptionDefinition(
                    name = :backend,
                    type = Union{Nothing, Symbol},
                    default = nothing,
                    description = "Backend with nothing default"
                ),
                OptionDefinition(
                    name = :minimize,
                    type = Union{Bool, Nothing},
                    default = NotProvided,
                    description = "Minimize with NotProvided"
                )
            ]
            
            # User provides neither option
            kwargs = (other = "test",)
            extracted, remaining = extract_options(kwargs, defs)
            
            # backend should be stored with nothing value
            @test haskey(extracted, :backend)
            @test extracted[:backend].value === nothing
            @test extracted[:backend].source == :default
            
            # minimize should NOT be stored
            @test !haskey(extracted, :minimize)
            
            # Now test when user provides backend = nothing explicitly
            kwargs2 = (backend = nothing,)
            extracted2, _ = extract_options(kwargs2, defs)
            
            # backend should be stored with nothing value from user
            @test haskey(extracted2, :backend)
            @test extracted2[:backend].value === nothing
            @test extracted2[:backend].source == :user  # User provided it
            
            # minimize still not stored
            @test !haskey(extracted2, :minimize)
        end
        
        @testset "extract_raw_options should never see NotProvided" begin
            # Simulate what would be stored in an instance
            stored_options = (
                backend = OptionValue(:optimized, :default),
                show_time = OptionValue(false, :user),
                nullable_opt = OptionValue(nothing, :default)
                # Note: optional with NotProvided is NOT here (not stored)
            )
            
            raw = extract_raw_options(stored_options)
            
            # Verify all values are unwrapped
            @test raw.backend == :optimized
            @test raw.show_time == false
            @test raw.nullable_opt === nothing
            
            # Verify NO NotProvidedType in raw values
            for (k, v) in pairs(raw)
                @test !(v isa NotProvidedType)
            end
        end
        
        @testset "Complete workflow: NotProvided never stored" begin
            # Define options like ExaModeler
            defs_nt = (
                base_type = OptionDefinition(
                    name = :base_type,
                    type = DataType,
                    default = Float64,
                    description = "Base type"
                ),
                minimize = OptionDefinition(
                    name = :minimize,
                    type = Union{Bool, Nothing},
                    default = NotProvided,
                    description = "Minimize flag"
                ),
                backend = OptionDefinition(
                    name = :backend,
                    type = Any,
                    default = nothing,
                    description = "Backend"
                )
            )
            
            # User provides only base_type
            user_kwargs = (base_type = Float32,)
            
            # Extract options (what gets stored in instance)
            extracted, _ = extract_options(user_kwargs, defs_nt)
            
            # Verify minimize is NOT stored (NotProvided + not provided)
            @test haskey(extracted, :base_type)
            @test !haskey(extracted, :minimize)  # ✅ Key point!
            @test haskey(extracted, :backend)    # nothing default = stored
            
            # Verify NO NotProvidedType in extracted
            for (k, v) in pairs(extracted)
                @test !(v.value isa NotProvidedType)
            end
            
            # Extract raw options (what gets passed to builder)
            raw = extract_raw_options(extracted)
            
            # Verify minimize is NOT in raw options
            @test haskey(raw, :base_type)
            @test !haskey(raw, :minimize)  # ✅ Not passed to builder
            @test haskey(raw, :backend)
            
            # Verify NO NotProvidedType in raw
            for (k, v) in pairs(raw)
                @test !(v isa NotProvidedType)
            end
        end
    end
end

test_not_provided()
