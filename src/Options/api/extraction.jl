"""
$(TYPEDSIGNATURES)

Extract a single option from a NamedTuple using its schema, with support for aliases.

This function searches through all valid names (primary name + aliases) in the schema
to find the option value in the provided kwargs. If found, it validates the value,
checks the type, and returns an `OptionValue` with `:user` source. If not found,
returns the default value with `:default` source.

# Arguments
- `kwargs::NamedTuple`: NamedTuple containing potential option values.
- `schema::OptionSchema`: Schema defining the option to extract.

# Returns
- `(OptionValue, NamedTuple)`: Tuple containing the extracted option value and the remaining kwargs.

# Notes
- If a validator is provided in the schema, it will be called on the extracted value.
- Type mismatches generate warnings but do not prevent extraction.
- The function removes the found option from the returned kwargs.

# Example
```julia-repl
julia> using CTModels.Options

julia> schema = OptionSchema(:grid_size, Int, 100, (:n, :size))
OptionSchema(:grid_size, Int, 100, (:n, :size), nothing)

julia> kwargs = (n=200, tol=1e-6, max_iter=1000)
(n = 200, tol = 1.0e-6, max_iter = 1000)

julia> opt_value, remaining = extract_option(kwargs, schema)
(200 (user), (tol = 1.0e-6, max_iter = 1000))

julia> opt_value.value
200

julia> opt_value.source
:user
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
                    result = schema.validator(value)
                    # Validators should return true or throw an error
                    if result !== true && !isa(result, Nothing)
                        throw(CTBase.IncorrectArgument("Validation failed for option $(schema.name)"))
                    end
                catch e
                    if isa(e, CTBase.IncorrectArgument)
                        rethrow(e)
                    else
                        throw(CTBase.IncorrectArgument("Validation failed for option $(schema.name): $(e isa Exception ? e.msg : string(e))"))
                    end
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
$(TYPEDSIGNATURES)

Extract multiple options from a NamedTuple using a vector of schemas.

This function iteratively applies `extract_option` for each schema in the vector,
building a dictionary of extracted options while progressively removing processed
options from the kwargs.

# Arguments
- `kwargs::NamedTuple`: NamedTuple containing potential option values.
- `schemas::Vector{OptionSchema}`: Vector of schemas defining options to extract.

# Returns
- `(Dict{Symbol, OptionValue}, NamedTuple)`: Dictionary mapping option names to their values, and remaining kwargs.

# Notes
- The extraction order follows the order of schemas in the vector.
- Each schema's primary name is used as the dictionary key.
- Options not found in kwargs use their schema default values.

# Example
```julia-repl
julia> using CTModels.Options

julia> schemas = [
           OptionSchema(:grid_size, Int, 100),
           OptionSchema(:tol, Float64, 1e-6)
       ]
2-element Vector{OptionSchema}:

julia> kwargs = (grid_size=200, max_iter=1000)
(grid_size = 200, max_iter = 1000)

julia> extracted, remaining = extract_options(kwargs, schemas)
(Dict(:grid_size => 200 (user), :tol => 1.0e-6 (default)), (max_iter = 1000,))

julia> extracted[:grid_size]
200 (user)

julia> extracted[:tol]
1.0e-6 (default)
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
$(TYPEDSIGNATURES)

Extract multiple options from a NamedTuple using a NamedTuple of schemas.

This function is similar to the Vector version but returns a NamedTuple instead
of a Dict for convenience when the schema structure is known at compile time.

# Arguments
- `kwargs::NamedTuple`: NamedTuple containing potential option values.
- `schemas::NamedTuple`: NamedTuple of schemas defining options to extract.

# Returns
- `(NamedTuple, NamedTuple)`: NamedTuple of extracted options and remaining kwargs.

# Notes
- The returned NamedTuple preserves the field names from the schemas NamedTuple.
- This version is useful when the option set is fixed and known beforehand.
- Performance is similar to the Vector version.

# Example
```julia-repl
julia> using CTModels.Options

julia> schemas = (
           grid_size = OptionSchema(:grid_size, Int, 100),
           tol = OptionSchema(:tol, Float64, 1e-6)
       )
(grid_size = OptionSchema(:grid_size, Int, 100, (), nothing), tol = OptionSchema(:tol, Float64, 1.0e-6, (), nothing))

julia> kwargs = (grid_size=200, max_iter=1000, tol=1e-8)
(grid_size = 200, max_iter = 1000, tol = 1.0e-8)

julia> extracted, remaining = extract_options(kwargs, schemas)
((grid_size = 200 (user), tol = 1.0e-8 (user)), (max_iter = 1000,))

julia> extracted.grid_size
200 (user)

julia> extracted.tol
1.0e-8 (user)
```
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
