# Options Module - extraction.jl

"""
    extract_option(kwargs::NamedTuple, schema::OptionSchema)

Extract a single option from kwargs using its schema (handles aliases).

# Returns
- `(OptionValue, remaining_kwargs)` - The extracted option and remaining kwargs

# Example
```julia
schema = OptionSchema(:grid_size, Int, 100, (:n,))
kwargs = (n=200, tol=1e-6)

opt_value, remaining = extract_option(kwargs, schema)
# opt_value => OptionValue(200, :user)
# remaining => (tol=1e-6,)
```
"""
function extract_option(kwargs::NamedTuple, schema::OptionSchema)
    # Try all names (primary + aliases)
    for name in all_names(schema)
        if haskey(kwargs, name)
            value = kwargs[name]
            
            # Validate if validator provided
            if schema.validator !== nothing
                try
                    schema.validator(value)
                catch e
                    error("Validation failed for option $(schema.name): $(e.msg)")
                end
            end
            
            # Type check
            if !isa(value, schema.type)
                @warn "Option $(schema.name) has value $value of type $(typeof(value)), expected $(schema.type)"
            end
            
            # Remove from kwargs
            remaining = NamedTuple(k => v for (k, v) in pairs(kwargs) if k != name)
            
            return OptionValue(value, :user), remaining
        end
    end
    
    # Not found, return default
    return OptionValue(schema.default, :default), kwargs
end

"""
    extract_options(kwargs::NamedTuple, schemas::Vector{OptionSchema})

Extract multiple options from kwargs.

# Returns
- `(Dict{Symbol, OptionValue}, remaining_kwargs)` - Extracted options and remaining kwargs

# Example
```julia
schemas = [
    OptionSchema(:grid_size, Int, 100),
    OptionSchema(:tol, Float64, 1e-6)
]
kwargs = (grid_size=200, max_iter=1000)

extracted, remaining = extract_options(kwargs, schemas)
# extracted => Dict(:grid_size => OptionValue(200, :user), :tol => OptionValue(1e-6, :default))
# remaining => (max_iter=1000,)
```
"""
function extract_options(kwargs::NamedTuple, schemas::Vector{OptionSchema})
    extracted = Dict{Symbol, OptionValue}()
    remaining = kwargs
    
    for schema in schemas
        opt_value, remaining = extract_option(remaining, schema)
        extracted[schema.name] = opt_value
    end
    
    return extracted, remaining
end

"""
    extract_options(kwargs::NamedTuple, schemas::NamedTuple)

Extract multiple options from kwargs using a named tuple of schemas.

Returns a NamedTuple instead of a Dict for convenience.
"""
function extract_options(kwargs::NamedTuple, schemas::NamedTuple)
    extracted = Dict{Symbol, OptionValue}()
    remaining = kwargs
    
    for (name, schema) in pairs(schemas)
        opt_value, remaining = extract_option(remaining, schema)
        extracted[name] = opt_value
    end
    
    return NamedTuple(extracted), remaining
end
