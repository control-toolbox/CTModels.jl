# ============================================================================ #
# Strategies Module - OptionSpecification
# ============================================================================ #
# This file defines the OptionSpecification type for strategy options.
# ============================================================================ #

module Strategies

"""
    OptionSpecification

Specification for a single strategy option.

# Fields
- `type::Type` - Expected type of the option value
- `default::Any` - Default value
- `description::String` - Human-readable description
- `aliases::Tuple{Vararg{Symbol}}` - Alternative names (optional)
- `validator::Union{Function, Nothing}` - Validation function (optional)

# Example
```julia
OptionSpecification(
    type = Int,
    default = 100,
    description = "Maximum iterations",
    aliases = (:max, :maxiter),
    validator = x -> x > 0
)
```

# Validation
The validator function should return `true` if the value is valid, `false` otherwise.

# Aliases
Aliases allow users to specify options using alternative names. For example:
```julia
# With aliases = (:init, :i)
MyStrategy(initial_guess=value)  # Primary name
MyStrategy(init=value)           # Alias
MyStrategy(i=value)              # Alias
```
"""
struct OptionSpecification
    type::Type
    default::Any
    description::String
    aliases::Tuple{Vararg{Symbol}}
    validator::Union{Function, Nothing}
    
    function OptionSpecification(;
        type::Type,
        default,
        description::String,
        aliases::Tuple{Vararg{Symbol}} = (),
        validator::Union{Function, Nothing} = nothing
    )
        # Validate default value type
        if default !== nothing && !isa(default, type)
            error("Default value $default is not of type $type")
        end
        
        # Validate with custom validator if provided
        if validator !== nothing && default !== nothing
            if !validator(default)
                error("Default value $default fails validation")
            end
        end
        
        new(type, default, description, aliases, validator)
    end
end

end # module Strategies
