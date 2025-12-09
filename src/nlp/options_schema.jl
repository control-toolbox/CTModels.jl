# Internal metadata schema for backend and discretizer options.

"""
$(TYPEDSIGNATURES)

Return a short `Symbol` identifying the package or implementation used by a
given [`AbstractOCPTool`](@ref).

Concrete tool types are expected to specialize this method on their own type,
for example `get_symbol(::Type{<:MyTool}) = :mytool`.
"""
function get_symbol(tool::AbstractOCPTool)
    return get_symbol(typeof(tool))
end

"""
$(TYPEDSIGNATURES)

Default implementation that throws `CTBase.NotImplemented`.

Concrete tool types must specialize this method.
"""
function get_symbol(::Type{T}) where {T<:AbstractOCPTool}
    throw(CTBase.NotImplemented("get_symbol not implemented for $(T)"))
end

"""
$(TYPEDSIGNATURES)

Return the package name associated with a tool instance.
"""
function tool_package_name(tool::AbstractOCPTool)
    return tool_package_name(typeof(tool))
end

"""
$(TYPEDSIGNATURES)

Return the package name for a tool type.

Default implementation returns `missing`.
"""
function tool_package_name(::Type{T}) where {T<:AbstractOCPTool}
    return missing
end

# ---------------------------------------------------------------------------
# Internal options API overview
#
# For each tool T<:AbstractOCPTool:
#   - _option_specs(T) :: NamedTuple of OptionSpec describing option keys.
#   - default_options(T) :: NamedTuple of default values taken from specs
#       (only options with non-missing defaults are included).
#   - _build_ocp_tool_options(T; kwargs..., strict_keys=false) :: (values, sources)
#       merges default options with user kwargs and tracks provenance
#       (:ct_default or :user) in a parallel NamedTuple.
#   - Concrete tools store `options_values` and `options_sources` fields and
#       are accessed via _options_values(tool) and _option_sources(tool).
#
# OptionSpec fields:
#   - type        : expected Julia type for validation (or `missing`).
#   - default     : default value at the tool level (or `missing` if none).
#   - description : short human-readable description (or `missing`).
# ---------------------------------------------------------------------------

function OptionSpec(; type=missing, default=missing, description=missing)
    OptionSpec(type, default, description)
end

# Default: no metadata for a given tool type.
"""
$(TYPEDSIGNATURES)

Return the option metadata specification for a concrete
[`AbstractOCPTool`](@ref) subtype.

Concrete tools typically specialize this method on their own type and return a
`NamedTuple` whose fields correspond to option names and whose values are
[`OptionSpec`](@ref) instances.

The default implementation returns `missing`, meaning that no option metadata
is available for the given tool type.
"""
function _option_specs(::Type{T}) where {T<:AbstractOCPTool}
    return missing
end

"""
$(TYPEDSIGNATURES)

Convenience overload to accept tool instances.
"""
_option_specs(x::AbstractOCPTool) = _option_specs(typeof(x))

"""
$(TYPEDSIGNATURES)

Return the current option values for a tool instance.
"""
function _options_values(tool::AbstractOCPTool)
    return tool.options_values
end

"""
$(TYPEDSIGNATURES)

Return the option sources (`:ct_default` or `:user`) for a tool instance.
"""
function _option_sources(tool::AbstractOCPTool)
    return tool.options_sources
end

"""
$(TYPEDSIGNATURES)

Return the list of known option keys for a tool type.

Returns `missing` if no option metadata is available.
"""
function options_keys(tool_type::Type{<:AbstractOCPTool})
    specs = _option_specs(tool_type)
    specs === missing && return missing
    return propertynames(specs)
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
options_keys(x::AbstractOCPTool) = options_keys(typeof(x))

"""
$(TYPEDSIGNATURES)

Check if `key` is a valid option key for the given tool type.

Returns `missing` if no option metadata is available.
"""
function is_an_option_key(key::Symbol, tool_type::Type{<:AbstractOCPTool})
    specs = _option_specs(tool_type)
    specs === missing && return missing
    return key in propertynames(specs)
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
is_an_option_key(key::Symbol, x::AbstractOCPTool) = is_an_option_key(key, typeof(x))

"""
$(TYPEDSIGNATURES)

Return the expected type for an option key.

Returns `missing` if the key is unknown or no type is specified.
"""
function option_type(key::Symbol, tool_type::Type{<:AbstractOCPTool})
    specs = _option_specs(tool_type)
    specs === missing && return missing
    if !(haskey(specs, key))
        return missing
    end
    spec = getfield(specs, key)::OptionSpec
    return spec.type
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
option_type(key::Symbol, x::AbstractOCPTool) = option_type(key, typeof(x))

"""
$(TYPEDSIGNATURES)

Return the description for an option key.

Returns `missing` if the key is unknown or no description is available.
"""
function option_description(key::Symbol, tool_type::Type{<:AbstractOCPTool})
    specs = _option_specs(tool_type)
    specs === missing && return missing
    if !(haskey(specs, key))
        return missing
    end
    spec = getfield(specs, key)::OptionSpec
    return spec.description
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
option_description(key::Symbol, x::AbstractOCPTool) = option_description(key, typeof(x))

"""
$(TYPEDSIGNATURES)

Return the default value for an option key.

Returns `missing` if the key is unknown or no default is specified.
"""
function option_default(key::Symbol, tool_type::Type{<:AbstractOCPTool})
    specs = _option_specs(tool_type)
    specs === missing && return missing
    if !(haskey(specs, key))
        return missing
    end
    spec = getfield(specs, key)::OptionSpec
    return spec.default
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
option_default(key::Symbol, x::AbstractOCPTool) = option_default(key, typeof(x))

"""
$(TYPEDSIGNATURES)

Return a `NamedTuple` of default option values for a tool type.

Only options with non-missing defaults are included.
"""
function default_options(tool_type::Type{<:AbstractOCPTool})
    specs = _option_specs(tool_type)
    specs === missing && return NamedTuple()
    pairs = Pair{Symbol,Any}[]
    for name in propertynames(specs)
        spec = getfield(specs, name)::OptionSpec
        if spec.default !== missing
            push!(pairs, name => spec.default)
        end
    end
    return (; pairs...)
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
default_options(x::AbstractOCPTool) = default_options(typeof(x))

"""
$(TYPEDSIGNATURES)

Filter a `NamedTuple` by excluding specified keys.
"""
function _filter_options(nt::NamedTuple, exclude)
    return (; (k => v for (k, v) in pairs(nt) if !(k in exclude))...)
end

"""
$(TYPEDSIGNATURES)

Compute the Levenshtein distance between two strings.

Used for suggesting similar option names when a typo is detected.
"""
function _string_distance(a::AbstractString, b::AbstractString)
    m = lastindex(a)
    n = lastindex(b)
    # Use 1-based indices over code units for simplicity; option keys are short.
    da = collect(codeunits(a))
    db = collect(codeunits(b))
    # dp[i+1, j+1] = distance between first i chars of a and first j chars of b
    dp = Array{Int}(undef, m + 1, n + 1)
    for i in 0:m
        dp[i + 1, 1] = i
    end
    for j in 0:n
        dp[1, j + 1] = j
    end
    for i in 1:m
        for j in 1:n
            cost = da[i] == db[j] ? 0 : 1
            dp[i + 1, j + 1] = min(
                dp[i, j + 1] + 1,      # deletion
                dp[i + 1, j] + 1,      # insertion
                dp[i, j] + cost,       # substitution
            )
        end
    end
    return dp[m + 1, n + 1]
end

"""
$(TYPEDSIGNATURES)

Suggest up to `max_suggestions` closest option keys for a tool type.

Used to provide helpful error messages when an unknown option is specified.
"""
function _suggest_option_keys(
    key::Symbol, tool_type::Type{<:AbstractOCPTool}; max_suggestions::Int=3
)
    specs = _option_specs(tool_type)
    specs === missing && return Symbol[]
    names = collect(propertynames(specs))
    distances = [(_string_distance(String(key), String(n)), n) for n in names]
    sort!(distances; by=first)
    take = min(max_suggestions, length(distances))
    return [distances[i][2] for i in 1:take]
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
function _suggest_option_keys(key::Symbol, x::AbstractOCPTool; max_suggestions::Int=3)
    _suggest_option_keys(key, typeof(x); max_suggestions=max_suggestions)
end

# ---------------------------------------------------------------------------
# High-level getters for option value/source/default on instantiated tools.
# These helpers validate the option key and reuse the suggestion machinery
# used when parsing user keyword arguments.
# ---------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Generate and throw an error for an unknown option key with suggestions.
"""
function _unknown_option_error(
    key::Symbol, tool_type::Type{<:AbstractOCPTool}, context::AbstractString
)
    suggestions = _suggest_option_keys(key, tool_type; max_suggestions=3)
    tool_name = string(nameof(tool_type))
    msg = "Unknown option $(key) for $(tool_name) when querying the $(context)."
    if !isempty(suggestions)
        msg *= " Did you mean " * join(string.(suggestions), " or ") * "?"
    end
    msg *= " Use show_options($(tool_name)) to list all available options."
    throw(CTBase.IncorrectArgument(msg))
end

"""
$(TYPEDSIGNATURES)

Get the current value of an option for a tool instance.

Throws an error if the option is unknown or has no value.
"""
function get_option_value(tool::AbstractOCPTool, key::Symbol)
    vals = _options_values(tool)
    if haskey(vals, key)
        return vals[key]
    end

    tool_type = typeof(tool)
    specs = _option_specs(tool_type)
    if specs === missing || !haskey(specs, key)
        return _unknown_option_error(key, tool_type, "value")
    end

    tool_name = string(nameof(tool_type))
    msg =
        "Option $(key) is defined for $(tool_name) but has no value: " *
        "no default was provided and the option was not set by the user."
    throw(CTBase.IncorrectArgument(msg))
end

"""
$(TYPEDSIGNATURES)

Get the source (`:ct_default` or `:user`) of an option value.

Throws an error if the option is unknown.
"""
function get_option_source(tool::AbstractOCPTool, key::Symbol)
    srcs = _option_sources(tool)
    if haskey(srcs, key)
        return srcs[key]
    end

    tool_type = typeof(tool)
    specs = _option_specs(tool_type)
    if specs === missing || !haskey(specs, key)
        return _unknown_option_error(key, tool_type, "source")
    end

    tool_name = string(nameof(tool_type))
    msg = "Option $(key) is defined for $(tool_name) but has no recorded source."
    throw(CTBase.IncorrectArgument(msg))
end

"""
$(TYPEDSIGNATURES)

Get the default value of an option for a tool instance.

Throws an error if the option is unknown.
"""
function get_option_default(tool::AbstractOCPTool, key::Symbol)
    tool_type = typeof(tool)
    specs = _option_specs(tool_type)
    if specs === missing || !haskey(specs, key)
        return _unknown_option_error(key, tool_type, "default")
    end
    return option_default(key, tool_type)
end

"""
$(TYPEDSIGNATURES)

Print a human-readable listing of options and their metadata for a tool type.
"""
function _show_options(tool_type::Type{<:AbstractOCPTool})
    specs = _option_specs(tool_type)
    if specs === missing
        println("No option metadata available for ", tool_type, ".")
        return nothing
    end
    println("Options for ", tool_type, ":")
    for name in propertynames(specs)
        spec = getfield(specs, name)::OptionSpec
        T = spec.type === missing ? "Any" : string(spec.type)
        desc = spec.description === missing ? "" : " — " * String(spec.description)
        println(" - ", name, " :: ", T, desc)
    end
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
function _show_options(x::AbstractOCPTool)
    return _show_options(typeof(x))
end

"""
$(TYPEDSIGNATURES)

Display available options for a tool type.

Prints option names, types, and descriptions to stdout.
"""
function show_options(tool_type::Type{<:AbstractOCPTool})
    return _show_options(tool_type)
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
function show_options(x::AbstractOCPTool)
    return _show_options(typeof(x))
end

"""
$(TYPEDSIGNATURES)

Validate user-supplied keyword options against tool metadata.

If `strict_keys` is `true`, unknown keys trigger an error. If `false`, unknown
keys are accepted and only known keys are type-checked.
"""
function _validate_option_kwargs(
    user_nt::NamedTuple, tool_type::Type{<:AbstractOCPTool}; strict_keys::Bool=false
)
    specs = _option_specs(tool_type)
    specs === missing && return nothing

    known_keys = propertynames(specs)

    # Unknown keys
    if strict_keys
        unknown = Symbol[]
        for k in keys(user_nt)
            if !(k in known_keys)
                push!(unknown, k)
            end
        end
        if !isempty(unknown)
            # Only report the first unknown key with suggestions.
            k = first(unknown)
            suggestions = _suggest_option_keys(k, tool_type; max_suggestions=3)
            tool_name = string(nameof(tool_type))
            msg = "Unknown option $(k) for $(tool_name)."
            if !isempty(suggestions)
                msg *= " Did you mean " * join(string.(suggestions), " or ") * "?"
            end
            msg *= " Use show_options($(tool_name)) to list all available options."
            throw(CTBase.IncorrectArgument(msg))
        end
    end

    # Type checks for known keys where a type is provided.
    for k in keys(user_nt)
        if !(k in known_keys)
            continue
        end
        T = option_type(k, tool_type)
        T === missing && continue
        v = user_nt[k]
        if !(v isa T)
            tool_name = string(nameof(tool_type))
            msg =
                "Invalid type for option $(k) of $(tool_name). " *
                "Expected value of type $(T), got value of type $(typeof(v))."
            throw(CTBase.IncorrectArgument(msg))
        end
    end

    return nothing
end

"""
$(TYPEDSIGNATURES)

Convenience overload for tool instances.
"""
function _validate_option_kwargs(
    user_nt::NamedTuple, x::AbstractOCPTool; strict_keys::Bool=false
)
    _validate_option_kwargs(user_nt, typeof(x); strict_keys=strict_keys)
end

"""
$(TYPEDSIGNATURES)

Build a normalized pair of option `values` and `sources` for a concrete
[`AbstractOCPTool`](@ref) subtype.

This helper is typically used in the keyword-only constructor of a tool type,
for example `MyTool(; kwargs...) = MyTool(_build_ocp_tool_options(MyTool; kwargs...)...)`.

# Arguments

- `::Type{T}`: concrete subtype of `AbstractOCPTool`.
- `strict_keys::Bool`: if `true`, unknown option keys are rejected with a
  detailed error; if `false`, unknown keys are accepted.
- `kwargs...`: user-supplied option values.

# Returns

A pair `(values, sources)` where:

- `values::NamedTuple`: effective option values after merging tool defaults
  (from [`default_options`](@ref)) with the user keywords.
- `sources::NamedTuple`: for each option name, either `:ct_default` or
  `:user` indicating whether the value comes from the tool defaults or from
  user input.
"""
function _build_ocp_tool_options(
    ::Type{T}; strict_keys::Bool=false, kwargs...
) where {T<:AbstractOCPTool}
    # Normalize user-supplied keyword arguments to a NamedTuple.
    user_nt = NamedTuple(kwargs)

    # Validate option keys and types against the tool metadata.
    _validate_option_kwargs(user_nt, T; strict_keys=strict_keys)

    # Merge tool-level default options with user overrides (user wins).
    defaults = default_options(T)
    values = merge(defaults, user_nt)

    # Build a parallel NamedTuple recording the provenance of each option
    # (:ct_default for defaults coming from the tool, :user for overrides).
    src_pairs = Pair{Symbol,Symbol}[]
    for name in keys(values)
        src = haskey(user_nt, name) ? :user : :ct_default
        push!(src_pairs, name => src)
    end
    sources = (; src_pairs...)

    return values, sources
end
