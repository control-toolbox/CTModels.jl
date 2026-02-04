# ============================================================================
# Option value representation with provenance
# ============================================================================

"""
$(TYPEDEF)

Represents an option value with its source provenance.

# Fields
- `value::T`: The actual option value.
- `source::Symbol`: Where the value came from (`:default`, `:user`, `:computed`).

# Notes
The `source` field tracks the provenance of the option value:
- `:default`: Value comes from the tool's default configuration
- `:user`: Value was explicitly provided by the user
- `:computed`: Value was computed/derived from other options

# Example
```julia-repl
julia> using CTModels.Options

julia> opt = OptionValue(100, :user)
100 (user)

julia> opt.value
100

julia> opt.source
:user
```
"""
struct OptionValue{T}
    value::T
    source::Symbol
    
    function OptionValue(value::T, source::Symbol) where T
        if source ∉ (:default, :user, :computed)
            throw(Exceptions.IncorrectArgument(
                "Invalid option source",
                got="source=$source",
                expected=":default, :user, or :computed",
                suggestion="Use one of the valid source symbols: :default (tool default), :user (user-provided), or :computed (derived)",
                context="OptionValue constructor - validating source provenance"
            ))
        end
        new{T}(value, source)
    end
end

"""
$(TYPEDSIGNATURES)

Create an `OptionValue` with user-provided source.

# Arguments
- `value`: The option value.

# Returns
- `OptionValue{T}`: Option value with `:user` source.

# Example
```julia-repl
julia> using CTModels.Options

julia> OptionValue(42)
42 (user)
```
"""
OptionValue(value) = OptionValue(value, :user)

"""
$(TYPEDSIGNATURES)

Display the option value in the format "value (source)".

# Example
```julia-repl
julia> using CTModels.Options

julia> println(OptionValue(3.14, :default))
3.14 (default)
```
"""
Base.show(io::IO, opt::OptionValue) = print(io, "$(opt.value) ($(opt.source))")
