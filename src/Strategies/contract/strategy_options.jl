"""
$(TYPEDEF)

Wrapper for strategy option values with provenance tracking.

This type stores options as a collection of `OptionValue` objects, each containing
both the value and its source (`:user`, `:default`, or `:computed`).

# Fields
- `options::NamedTuple`: NamedTuple of OptionValue objects with provenance

# Construction

```julia-repl
julia> using CTModels.Strategies, CTModels.Options

julia> opts = StrategyOptions(
           max_iter = OptionValue(200, :user),
           tol = OptionValue(1e-6, :default)
       )
StrategyOptions with 2 options:
  max_iter = 200  [user]
  tol = 1.0e-6  [default]
```

# Access patterns

```julia-repl
# Get value only
julia> opts[:max_iter]
200

# Get OptionValue (value + source)
julia> opts.max_iter
OptionValue(200, :user)

# Get source only
julia> source(opts, :max_iter)
:user

# Check if user-provided
julia> is_user(opts, :max_iter)
true
```

# Iteration

```julia-repl
# Iterate over values
julia> for value in opts
           println(value)
       end

# Iterate over (name, value) pairs
julia> for (name, value) in opts
           println("\$name = \$value")
       end
```

See also: [`OptionValue`](@ref), [`source`](@ref), [`is_user`](@ref), [`is_default`](@ref), [`is_computed`](@ref)
"""
struct StrategyOptions
    options::NamedTuple
    
    function StrategyOptions(options::NamedTuple)
        for (key, val) in pairs(options)
            if !(val isa Options.OptionValue)
                error("All options must be OptionValue, got $(typeof(val)) for key :$key")
            end
        end
        new(options)
    end
    
    StrategyOptions(; kwargs...) = StrategyOptions((; kwargs...))
end

# ============================================================================
# Value access - returns unwrapped value
# ============================================================================

"""
$(TYPEDSIGNATURES)

Get the value of an option (without source information).

# Arguments
- `opts::StrategyOptions`: Strategy options
- `key::Symbol`: Option name

# Returns
- The unwrapped option value

# Example
```julia-repl
julia> opts[:max_iter]
200
```

See also: [`Base.getproperty`](@ref), [`source`](@ref)
"""
Base.getindex(opts::StrategyOptions, key::Symbol) = opts.options[key].value

"""
$(TYPEDSIGNATURES)

Get the OptionValue for an option (with source information).

# Arguments
- `opts::StrategyOptions`: Strategy options
- `key::Symbol`: Option name or `:options` for the internal field

# Returns
- `OptionValue`: Complete option with value and source, or the internal options field

# Example
```julia-repl
julia> opts.max_iter
OptionValue(200, :user)

julia> opts.max_iter.value
200

julia> opts.max_iter.source
:user
```

See also: [`Base.getindex`](@ref), [`source`](@ref)
"""
Base.getproperty(opts::StrategyOptions, key::Symbol) = 
    key === :options ? getfield(opts, :options) : getfield(opts, :options)[key]

# ============================================================================
# Source access helpers
# ============================================================================

"""
$(TYPEDSIGNATURES)

Get the source of an option.

# Arguments
- `opts::StrategyOptions`: Strategy options
- `key::Symbol`: Option name

# Returns
- `Symbol`: Source of the option (`:user`, `:default`, or `:computed`)

# Example
```julia-repl
julia> source(opts, :max_iter)
:user
```

See also: [`is_user`](@ref), [`is_default`](@ref), [`is_computed`](@ref)
"""
source(opts::StrategyOptions, key::Symbol) = opts.options[key].source
"""
$(TYPEDSIGNATURES)

Check if an option was provided by the user.

# Arguments
- `opts::StrategyOptions`: Strategy options
- `key::Symbol`: Option name

# Returns
- `Bool`: `true` if the option was provided by the user

# Example
```julia-repl
julia> is_user(opts, :max_iter)
true
```

See also: [`source`](@ref), [`is_default`](@ref), [`is_computed`](@ref)
"""
is_user(opts::StrategyOptions, key::Symbol) = source(opts, key) === :user
"""
$(TYPEDSIGNATURES)

Check if an option is using its default value.

# Arguments
- `opts::StrategyOptions`: Strategy options
- `key::Symbol`: Option name

# Returns
- `Bool`: `true` if the option is using its default value

# Example
```julia-repl
julia> is_default(opts, :tol)
true
```

See also: [`source`](@ref), [`is_user`](@ref), [`is_computed`](@ref)
"""
is_default(opts::StrategyOptions, key::Symbol) = source(opts, key) === :default
"""
$(TYPEDSIGNATURES)

Check if an option was computed.

# Arguments
- `opts::StrategyOptions`: Strategy options
- `key::Symbol`: Option name

# Returns
- `Bool`: `true` if the option was computed

# Example
```julia-repl
julia> is_computed(opts, :step)
true
```

See also: [`source`](@ref), [`is_user`](@ref), [`is_default`](@ref)
"""
is_computed(opts::StrategyOptions, key::Symbol) = source(opts, key) === :computed

# ============================================================================
# Collection interface
# ============================================================================

"""
$(TYPEDSIGNATURES)

Get all option names.

# Arguments
- `opts::StrategyOptions`: Strategy options

# Returns
- Iterator of option names (Symbols)

# Example
```julia-repl
julia> collect(keys(opts))
[:max_iter, :tol]
```

See also: [`Base.values`](@ref), [`Base.pairs`](@ref)
"""
Base.keys(opts::StrategyOptions) = keys(opts.options)
"""
$(TYPEDSIGNATURES)

Get all option values (unwrapped).

# Arguments
- `opts::StrategyOptions`: Strategy options

# Returns
- Generator of unwrapped option values

# Example
```julia-repl
julia> collect(values(opts))
[200, 1.0e-6]
```

See also: [`Base.keys`](@ref), [`Base.pairs`](@ref)
"""
Base.values(opts::StrategyOptions) = (opt.value for opt in values(opts.options))
"""
$(TYPEDSIGNATURES)

Get all (name, value) pairs (values unwrapped).

# Arguments
- `opts::StrategyOptions`: Strategy options

# Returns
- Generator of (Symbol, value) pairs

# Example
```julia-repl
julia> collect(pairs(opts))
[:max_iter => 200, :tol => 1.0e-6]
```

See also: [`Base.keys`](@ref), [`Base.values`](@ref)
"""
Base.pairs(opts::StrategyOptions) = (k => v.value for (k, v) in pairs(opts.options))

"""
$(TYPEDSIGNATURES)

Iterate over option values (unwrapped).

# Arguments
- `opts::StrategyOptions`: Strategy options
- `state...`: Iteration state (optional)

# Returns
- Tuple of (value, state) or `nothing` when done

# Example
```julia-repl
julia> for value in opts
           println(value)
       end
200
1.0e-6
```

See also: [`Base.keys`](@ref), [`Base.values`](@ref), [`Base.pairs`](@ref)
"""
Base.iterate(opts::StrategyOptions, state...) = begin
    result = iterate(values(opts.options), state...)
    result === nothing && return nothing
    (opt, newstate) = result
    return (opt.value, newstate)
end

"""
$(TYPEDSIGNATURES)

Get number of options.

# Arguments
- `opts::StrategyOptions`: Strategy options

# Returns
- `Int`: Number of options

# Example
```julia-repl
julia> length(opts)
2
```

See also: [`Base.isempty`](@ref), [`Base.haskey`](@ref)
"""
Base.length(opts::StrategyOptions) = length(opts.options)
"""
$(TYPEDSIGNATURES)

Check if options collection is empty.

# Arguments
- `opts::StrategyOptions`: Strategy options

# Returns
- `Bool`: `true` if no options are present

# Example
```julia-repl
julia> isempty(opts)
false
```

See also: [`Base.length`](@ref), [`Base.haskey`](@ref)
"""
Base.isempty(opts::StrategyOptions) = isempty(opts.options)
"""
$(TYPEDSIGNATURES)

Check if an option exists.

# Arguments
- `opts::StrategyOptions`: Strategy options
- `key::Symbol`: Option name to check

# Returns
- `Bool`: `true` if the option exists

# Example
```julia-repl
julia> haskey(opts, :max_iter)
true

julia> haskey(opts, :nonexistent)
false
```

See also: [`Base.length`](@ref), [`Base.isempty`](@ref)
"""
Base.haskey(opts::StrategyOptions, key::Symbol) = haskey(opts.options, key)

# ============================================================================
# Display
# ============================================================================

"""
$(TYPEDSIGNATURES)

Display StrategyOptions with values and their provenance sources.

This method formats the output to show each option value alongside its source
(`:user`, `:default`, or `:computed`) for complete traceability.

# Arguments
- `io::IO`: Output stream
- `::MIME"text/plain"`: MIME type for pretty printing
- `opts::StrategyOptions`: Strategy options to display

# Example
```julia-repl
julia> opts
StrategyOptions with 2 options:
  max_iter = 200  [user]
  tol = 1.0e-6  [default]
```

See also: [`Base.show`](@ref)
"""
function Base.show(io::IO, ::MIME"text/plain", opts::StrategyOptions)
    n = length(opts)
    println(io, "StrategyOptions with $n option$(n == 1 ? "" : "s"):")
    for (key, opt) in pairs(opts.options)
        println(io, "  $key = $(opt.value)  [$(opt.source)]")
    end
end

"""
$(TYPEDSIGNATURES)

Compact display of StrategyOptions.

# Arguments
- `io::IO`: Output stream
- `opts::StrategyOptions`: Strategy options to display

# Example
```julia-repl
julia> print(opts)
StrategyOptions(max_iter=200, tol=1.0e-6)
```

See also: [`Base.show(::IO, ::MIME"text/plain", ::StrategyOptions)`](@ref)
"""
function Base.show(io::IO, opts::StrategyOptions)
    print(io, "StrategyOptions(")
    print(io, join(("$k=$(v.value)" for (k, v) in pairs(opts.options)), ", "))
    print(io, ")")
end
