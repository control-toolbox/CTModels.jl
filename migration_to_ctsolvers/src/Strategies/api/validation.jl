# ============================================================================
# Strategy validation and error collection
# ============================================================================

using DocStringExtensions

"""
$(TYPEDSIGNATURES)

Verify that a strategy type correctly implements the required `AbstractStrategy` contract.

This function performs comprehensive validation of a strategy type to ensure
it follows the `AbstractStrategy` contract and integrates properly with the
Options and Configuration APIs. Use this function during development to verify
that your custom strategy implementation is complete and correct before deployment.

# Validation Checks

The function validates the following contract requirements in order:

1. **ID Method**: `id(strategy_type)` must be implemented and return a `Symbol`
2. **Metadata Method**: `metadata(strategy_type)` must be implemented and return a `StrategyMetadata`
3. **Options Building**: `build_strategy_options(strategy_type)` must work and return a `StrategyOptions`
4. **Default Constructor**: `strategy_type()` must be implemented and return an instance of the correct type
5. **Instance Options**: `options(instance)` must be implemented and return a `StrategyOptions`
6. **Metadata-Options Consistency**: Instance options keys must exactly match metadata specification keys
7. **Constructor Behavior**: Constructor must properly use keyword arguments (tests with modified values)

If any check fails, the function throws an exception immediately without proceeding to subsequent checks.

# Arguments
- `strategy_type::Type{<:AbstractStrategy}`: The strategy type to validate

# Returns
- `Bool`: Returns `true` if all validation checks pass

# Throws

- `Exceptions.IncorrectArgument`: When a method returns an incorrect type (e.g., `id` returns a String instead of Symbol)
- `Exceptions.NotImplemented`: When a required method is not implemented for the strategy type

# Examples

**Valid strategy:**
```julia-repl
julia> validate_strategy_contract(MyStrategy)
true
```

**Missing method:**
```julia-repl
julia> validate_strategy_contract(IncompleteStrategy)
ERROR: Exceptions.NotImplemented: id(::Type{<:IncompleteStrategy}) must be implemented for all strategy types
```

**Wrong return type:**
```julia-repl
julia> validate_strategy_contract(BadStrategy)
ERROR: Exceptions.IncorrectArgument: id(::Type{<:BadStrategy}) must return a Symbol, got String
```

# Notes

- This function is primarily intended for **development and testing** purposes
- It creates **multiple instances** of the strategy type (default + test with custom values)
- Ensure constructors have **no side effects** as they will be called during validation
- The validation is performed in a specific order; earlier failures prevent later checks
- All validated methods are part of the core `AbstractStrategy` contract
- The constructor behavior check (step 7) may be skipped for options with complex types
- Metadata with no options (empty `StrategyMetadata`) is considered valid

See also: [`AbstractStrategy`](@ref), [`id`](@ref), [`metadata`](@ref), 
[`build_strategy_options`](@ref), [`StrategyMetadata`](@ref), [`StrategyOptions`](@ref)
"""
function validate_strategy_contract(strategy_type::Type{T}) where {T<:AbstractStrategy}
    # 1. ID check (using `id` not `symbol` as per our API)
    try
        strategy_id = id(strategy_type)
        if !isa(strategy_id, Symbol)
            throw(Exceptions.IncorrectArgument(
                "Invalid strategy ID type",
                got="$(typeof(strategy_id)) for id(::Type{<:$T})",
                expected="Symbol for strategy identifier",
                suggestion="Ensure your id() method returns a Symbol, e.g., id(::Type{MyStrategy}) = :mystrategy",
                context="validate_strategy_contract - checking id() method return type"
            ))
        end
    catch e
        if e isa MethodError
            throw(Exceptions.NotImplemented(
                "Strategy ID method not implemented",
                required_method="id(::Type{<:$T})",
                context="validate_strategy_contract - checking id() method availability",
                suggestion="Implement id(::Type{<:$T}) returning a Symbol for your strategy"
            ))
        else
            rethrow(e)
        end
    end
    
    # 2. Metadata check
    try
        meta = metadata(strategy_type)
        if !isa(meta, StrategyMetadata)
            throw(Exceptions.IncorrectArgument(
                "Invalid metadata type",
                got="$(typeof(meta)) for metadata(::Type{<:$T})",
                expected="StrategyMetadata containing option definitions",
                suggestion="Ensure your metadata() method returns a StrategyMetadata instance with OptionDefinition objects",
                context="validate_strategy_contract - checking metadata() method return type"
            ))
        end
    catch e
        if e isa MethodError
            throw(Exceptions.NotImplemented(
                "Strategy metadata method not implemented",
                required_method="metadata(::Type{<:$T})",
                context="validate_strategy_contract - checking metadata() method availability",
                suggestion="Implement metadata(::Type{<:$T}) returning a StrategyMetadata for your strategy"
            ))
        else
            rethrow(e)
        end
    end
    
    # 3. build_strategy_options check
    try
        # Try building options with defaults
        opts = build_strategy_options(strategy_type)
        if !isa(opts, StrategyOptions)
            throw(Exceptions.IncorrectArgument(
                "Invalid options builder type",
                got="$(typeof(opts)) for build_strategy_options(::Type{<:$T})",
                expected="StrategyOptions with validated option values",
                suggestion="Ensure build_strategy_options() returns a StrategyOptions instance for your strategy",
                context="validate_strategy_contract - checking build_strategy_options() method return type"
            ))
        end
    catch e
        if e isa MethodError
            throw(Exceptions.NotImplemented(
                "Strategy options builder not available",
                required_method="build_strategy_options(::Type{<:$T})",
                context="validate_strategy_contract - checking build_strategy_options() method availability",
                suggestion="Ensure build_strategy_options() is available for strategy type $T (usually provided by Options API)"
            ))
        else
            rethrow(e)
        end
    end
    
    # 4. Default constructor check
    instance = try
        strategy_type()
    catch e
        if e isa MethodError
            throw(Exceptions.NotImplemented(
                "Default constructor not implemented",
                required_method="$T(; kwargs...)",
                context="validate_strategy_contract - checking default constructor availability",
                suggestion="Implement default constructor $T(; kwargs...) that uses build_strategy_options"
            ))
        else
            rethrow(e)
        end
    end
    
    if !isa(instance, T)
        throw(Exceptions.IncorrectArgument(
            "Invalid constructor return type",
            got="$(typeof(instance)) for $T()",
            expected="instance of type $T",
            suggestion="Ensure your default constructor returns an instance of the strategy type",
            context="validate_strategy_contract - checking default constructor return type"
        ))
    end
    
    # 5. Instance options check (reuse instance from step 4)
    opts = try
        options(instance)
    catch e
        if e isa MethodError
            throw(Exceptions.NotImplemented(
                "Instance options method not implemented",
                required_method="options(instance::$T)",
                context="validate_strategy_contract - checking options() method availability",
                suggestion="Implement options(instance::T) returning the StrategyOptions for your strategy"
            ))
        else
            rethrow(e)
        end
    end
    
    if !isa(opts, StrategyOptions)
        throw(Exceptions.IncorrectArgument(
            "Invalid instance options type",
            got="$(typeof(opts)) for options(:: $T)",
            expected="StrategyOptions containing the strategy's configuration",
            suggestion="Ensure your options() method returns a StrategyOptions instance",
            context="validate_strategy_contract - checking options() method return type"
        ))
    end
    
    # 6. Metadata-Options consistency check
    # Verify that instance options match the metadata specification
    meta = metadata(strategy_type)
    meta_keys = Set(keys(meta.specs))
    opts_keys = Set(keys(opts.options))
    
    if meta_keys != opts_keys
        missing_keys = setdiff(meta_keys, opts_keys)
        extra_keys = setdiff(opts_keys, meta_keys)
        
        msg_parts = String[]
        if !isempty(missing_keys)
            push!(msg_parts, "missing options: $(collect(missing_keys))")
        end
        if !isempty(extra_keys)
            push!(msg_parts, "unexpected options: $(collect(extra_keys))")
        end
        
        throw(Exceptions.IncorrectArgument(
            "Instance options do not match metadata specification",
            got="options mismatch for strategy $T: " * join(msg_parts, ", "),
            expected="instance options keys to exactly match metadata specification keys",
            suggestion="Ensure your constructor creates options that match your metadata specification exactly",
            context="validate_strategy_contract - checking metadata-options consistency"
        ))
    end
    
    # 7. Constructor behavior check
    # Verify that constructor with custom kwargs produces different options
    # This indirectly checks that build_strategy_options is being used
    if !isempty(meta.specs)
        # Get the first option name and its default value
        first_key = first(keys(meta.specs))
        first_spec = meta.specs[first_key]
        default_value = first_spec.default
        
        # Try to create instance with a different value (if possible)
        test_value = if default_value isa Number
            default_value + 1
        elseif default_value isa Symbol
            Symbol(string(default_value) * "_test")
        elseif default_value isa String
            default_value * "_test"
        elseif default_value isa Bool
            !default_value
        else
            # Cannot test with this type, skip this check
            nothing
        end
        
        if test_value !== nothing
            try
                test_instance = strategy_type(; NamedTuple{(first_key,)}((test_value,))...)
                test_opts = options(test_instance)
                
                if test_opts[first_key] != test_value
                    throw(Exceptions.IncorrectArgument(
                        "Constructor does not use keyword arguments properly",
                        got="constructor result with $first_key=$(test_opts[first_key])",
                        expected="constructor result with $first_key=$test_value",
                        suggestion="Ensure constructor uses build_strategy_options and properly forwards keyword arguments",
                        context="validate_strategy_contract - testing constructor behavior"
                    ))
                end
            catch e
                # If the test fails for any reason other than our check, 
                # it might be a type constraint issue - allow it
                if e isa Exceptions.IncorrectArgument
                    rethrow(e)
                end
                # Otherwise, skip this check (might be type constraints)
            end
        end
    end
    
    return true
end
