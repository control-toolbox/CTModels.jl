# ============================================================================
# NotProvided Type - Sentinel for "no default value"
# ============================================================================

"""
    NotProvidedType

Singleton type representing the absence of a default value for an option.

This type is used to distinguish between:
- `default = NotProvided`: No default value, option must be provided by user or not stored
- `default = nothing`: The default value is explicitly `nothing`

# Example
```julia-repl
julia> using CTModels.Options

julia> # Option with no default - won't be stored if not provided
julia> opt1 = OptionDefinition(
           name = :minimize,
           type = Union{Bool, Nothing},
           default = NotProvided,
           description = "Whether to minimize"
       )

julia> # Option with explicit nothing default - will be stored as nothing
julia> opt2 = OptionDefinition(
           name = :backend,
           type = Union{Nothing, KernelAbstractions.Backend},
           default = nothing,
           description = "Execution backend"
       )
```

See also: [`OptionDefinition`](@ref), [`extract_options`](@ref)
"""
struct NotProvidedType end

"""
    NotProvided

Singleton instance of [`NotProvidedType`](@ref).

Use this as the default value in [`OptionDefinition`](@ref) to indicate
that an option has no default value and should not be stored if not provided
by the user.

# Example
```julia-repl
julia> using CTModels.Options

julia> def = OptionDefinition(
           name = :optional_param,
           type = Any,
           default = NotProvided,
           description = "Optional parameter"
       )

julia> # If user doesn't provide it, it won't be stored
julia> opts, _ = extract_options((other=1,), [def])
julia> haskey(opts, :optional_param)
false
```
"""
const NotProvided = NotProvidedType()

# Pretty printing
Base.show(io::IO, ::NotProvidedType) = print(io, "NotProvided")
