# Options Module - option_schema.jl

"""
    OptionSchema

Defines the schema for an option (name, type, default, aliases, validator).

# Fields
- `name::Symbol` - Primary name of the option
- `type::Type` - Expected type
- `default::Any` - Default value
- `aliases::Tuple{Vararg{Symbol}}` - Alternative names
- `validator::Union{Function, Nothing}` - Optional validation function

# Example
```julia
schema = OptionSchema(
    :grid_size,
    Int,
    100,
    (:n, :size),
    x -> x > 0 || error("grid_size must be positive")
)
```
"""
struct OptionSchema
    name::Symbol
    type::Type
    default::Any
    aliases::Tuple{Vararg{Symbol}}
    validator::Union{Function, Nothing}
    
    function OptionSchema(
        name::Symbol,
        type::Type,
        default,
        aliases::Tuple{Vararg{Symbol}} = (),
        validator::Union{Function, Nothing} = nothing
    )
        # Validate default value type
        if default !== nothing && !isa(default, type)
            error("Default value $default is not of type $type")
        end
        
        # Check for duplicate aliases
        all_names = (name, aliases...)
        if length(all_names) != length(unique(all_names))
            error("Duplicate names in schema: $all_names")
        end
        
        new(name, type, default, aliases, validator)
    end
end

# Convenience constructor without aliases
OptionSchema(name::Symbol, type::Type, default) = OptionSchema(name, type, default, ())

# Get all names (primary + aliases)
all_names(schema::OptionSchema) = (schema.name, schema.aliases...)
