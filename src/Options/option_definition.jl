"""
    OptionDefinition

Unified option definition for both action schemas and strategy contracts.

# Fields
- `name::Symbol`: Primary name of the option.
- `type::Type`: Expected Julia type for the option value.
- `default::Any`: Default value when the option is not provided.
- `description::String`: Human-readable description of the option.
- `aliases::Tuple{Vararg{Symbol}}`: Alternative names that can be used to reference this option.
- `validator::Union{Function, Nothing}`: Optional validation function that takes a value and returns `true` or throws an error.

# Notes
- The constructor validates that the default value matches the expected type.
- Validators should return `true` for valid values or throw an error for invalid ones.
- Aliases allow users to specify options using alternative names.

# Example
```julia
OptionDefinition(
    name = :max_iter,
    type = Int,
    default = 100,
    description = "Maximum iterations",
    aliases = (:max, :maxiter),
    validator = x -> x > 0
)
```
"""
struct OptionDefinition
    name::Symbol
    type::Type
    default::Any
    description::String
    aliases::Tuple{Vararg{Symbol}}
    validator::Union{Function, Nothing}
    
    function OptionDefinition(;
        name::Symbol,
        type::Type,
        default,
        description::String,
        aliases::Tuple{Vararg{Symbol}} = (),
        validator::Union{Function, Nothing} = nothing
    )
        # Validate default value type
        if default !== nothing && !isa(default, type)
            throw(CTBase.IncorrectArgument("Default value $default is not of type $type"))
        end
        
        # Validate with custom validator if provided
        if validator !== nothing && default !== nothing
            try
                result = validator(default)
                if result !== true && !isa(result, Nothing)
                    throw(CTBase.IncorrectArgument("Validation failed for option $name"))
                end
            catch e
                if isa(e, CTBase.IncorrectArgument)
                    rethrow(e)
                else
                    throw(CTBase.IncorrectArgument("Validation failed for option $name: $(e isa Exception ? e.msg : string(e))"))
                end
            end
        end
        
        new(name, type, default, description, aliases, validator)
    end
end

# Get all names (primary + aliases) for extraction
all_names(def::OptionDefinition) = (def.name, def.aliases...)
