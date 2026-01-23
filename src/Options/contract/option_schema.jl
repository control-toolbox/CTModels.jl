"""
$(TYPEDEF)

Defines the schema for an option including name, type, default value, aliases, and optional validator.

# Fields
- `name::Symbol`: Primary name of the option.
- `type::Type`: Expected Julia type for the option value.
- `default::Any`: Default value when the option is not provided. Use `nothing` for no default.
- `aliases::Tuple{Vararg{Symbol}}`: Alternative names that can be used to reference this option.
- `validator::Union{Function, Nothing}`: Optional validation function that takes a value and returns `true` or throws an error.

# Notes
- The constructor validates that the default value matches the expected type.
- Duplicate names (including aliases) are not allowed.
- Validators should return `true` for valid values or throw an error for invalid ones.

# Example
```julia-repl
julia> using CTModels.Options

julia> schema = OptionSchema(
           :grid_size,
           Int,
           100,
           (:n, :size),
           x -> x > 0 || error("grid_size must be positive")
       )
OptionSchema(:grid_size, Int, 100, (:n, :size), Function)

julia> schema.name
:grid_size

julia> schema.aliases
(:n, :size)
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
            throw(CTBase.IncorrectArgument("Default value $default is not of type $type"))
        end
        
        # Check for duplicate aliases
        all_names = (name, aliases...)
        if length(all_names) != length(unique(all_names))
            throw(CTBase.IncorrectArgument("Duplicate names in schema: $all_names"))
        end
        
        new(name, type, default, aliases, validator)
    end
    
end

"""
$(TYPEDSIGNATURES)

Return all names that can be used to reference this option (primary name plus aliases).

# Arguments
- `schema::OptionSchema`: The option schema.

# Returns
- `Tuple{Vararg{Symbol}}: All valid names for this option.

# Example
```julia-repl
julia> using CTModels.Options

julia> schema = OptionSchema(:grid_size, Int, 100, (:n, :size))
OptionSchema(:grid_size, Int, 100, (:n, :size), nothing)

julia> all_names(schema)
(:grid_size, :n, :size)
```
"""
all_names(schema::OptionSchema) = (schema.name, schema.aliases...)
