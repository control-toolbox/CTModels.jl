"""
$(TYPEDEF)

Unified option definition for both action schemas and strategy contracts.

This type combines the functionality of the previous `OptionSchema` and `OptionSpecification` types into a single, comprehensive option definition that can be used for both option extraction (in the Options module) and strategy contract definition (in the Strategies module).

# Fields
- `name::Symbol`: Primary name of the option.
- `type::Type`: Expected Julia type for the option value.
- `default::Any`: Default value when the option is not provided. Use `nothing` for no default.
- `description::String`: Human-readable description of the option.
- `aliases::Tuple{Vararg{Symbol}}`: Alternative names that can be used to reference this option.
- `validator::Union{Function, Nothing}`: Optional validation function that takes a value and returns `true` or throws an error.

# Notes
- The constructor validates that the default value matches the expected type.
- Validators should return `true` for valid values or throw an error for invalid ones.
- Aliases allow users to specify options using alternative names.
- This type is exported and intended for public use in both option extraction and strategy definition.

# Example
```julia-repl
julia> using CTModels.Options

julia> OptionDefinition(
           name = :max_iter,
           type = Int,
           default = 100,
           description = "Maximum iterations",
           aliases = (:max, :maxiter),
           validator = x -> x > 0
       )
OptionDefinition(:max_iter, Int, 100, "Maximum iterations", (:max, :maxiter), Function)

julia> def.name
:max_iter

julia> def.aliases
(:max, :maxiter)
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
"""
$(TYPEDSIGNATURES)

Return all valid names for an option definition (primary name plus aliases).

This function is used by the extraction system to search for an option in kwargs
using all possible names.

# Arguments
- `def::OptionDefinition`: The option definition.

# Returns
- `Tuple{Vararg{Symbol}}`: All valid names for this option.

# Example
```julia-repl
julia> using CTModels.Options

julia> def = OptionDefinition(
           name = :grid_size,
           type = Int,
           default = 100,
           description = "Grid size",
           aliases = (:n, :size)
       )
OptionDefinition(...)

julia> all_names(def)
(:grid_size, :n, :size)
```
"""
all_names(def::OptionDefinition) = (def.name, def.aliases...)

# Display
"""
$(TYPEDSIGNATURES)

Display an OptionDefinition in a readable format.

# Arguments
- `io::IO`: Output stream.
- `def::OptionDefinition`: The option definition to display.

# Example
```julia-repl
julia> using CTModels.Options

julia> def = OptionDefinition(
           name = :max_iter,
           type = Int,
           default = 100,
           description = "Maximum iterations",
           aliases = (:max, :maxiter)
       )
OptionDefinition(...)

julia> println(def)
:maxiter :: Int
  default: 100
  description: Maximum iterations
  aliases: (:max, :maxiter)
```
"""
function Base.show(io::IO, def::OptionDefinition)
    # Show primary name with aliases if present
    if isempty(def.aliases)
        println(io, "$(def.name) :: $(def.type)")
    else
        println(io, "$(def.name) ($(join(def.aliases, ", "))) :: $(def.type)")
    end
    
    # Show details
    println(io, "  default: $(def.default)")
    println(io, "  description: $(def.description)")
end
