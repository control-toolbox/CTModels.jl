# ============================================================================
# Strategy utilities and helper functions
# ============================================================================

using DocStringExtensions

"""
$(TYPEDSIGNATURES)

Filter a NamedTuple by excluding specified keys.

# Arguments
- `nt::NamedTuple`: NamedTuple to filter
- `exclude::Symbol`: Single key to exclude

# Returns
- `NamedTuple`: New NamedTuple without the excluded key

# Example
```julia-repl
julia> opts = (max_iter=100, tol=1e-6, debug=true)
julia> filter_options(opts, :debug)
(max_iter = 100, tol = 1.0e-6)
```

See also: [`filter_options(::NamedTuple, ::Tuple)`](@ref)
"""
function filter_options(nt::NamedTuple, exclude::Symbol)
    return filter_options(nt, (exclude,))
end

"""
$(TYPEDSIGNATURES)

Filter a NamedTuple by excluding specified keys.

# Arguments
- `nt::NamedTuple`: NamedTuple to filter
- `exclude::Tuple{Vararg{Symbol}}`: Tuple of keys to exclude

# Returns
- `NamedTuple`: New NamedTuple without the excluded keys

# Example
```julia-repl
julia> opts = (max_iter=100, tol=1e-6, debug=true)
julia> filter_options(opts, (:debug, :tol))
(max_iter = 100,)
```

See also: [`filter_options(::NamedTuple, ::Symbol)`](@ref)
"""
function filter_options(nt::NamedTuple, exclude::Tuple{Vararg{Symbol}})
    exclude_set = Set(exclude)
    filtered_pairs = [
        key => value
        for (key, value) in pairs(nt)
        if key ∉ exclude_set
    ]
    return NamedTuple(filtered_pairs)
end

"""
$(TYPEDSIGNATURES)

Suggest similar option names for an unknown key using Levenshtein distance.

This function helps provide helpful error messages by suggesting option names
that are similar to the unknown key provided by the user.

# Arguments
- `key::Symbol`: Unknown key to find suggestions for
- `strategy_type::Type{<:AbstractStrategy}`: Strategy type to search in
- `max_suggestions::Int=3`: Maximum number of suggestions to return

# Returns
- `Vector{Symbol}`: Suggested keys, sorted by similarity (closest first)

# Example
```julia-repl
julia> suggest_options(:max_it, MyStrategy)
[:max_iter]

julia> suggest_options(:tolrance, MyStrategy)
[:tolerance]
```

# Note
Used internally by error messages to provide helpful suggestions.

See also: [`resolve_alias`](@ref), [`levenshtein_distance`](@ref)
"""
function suggest_options(
    key::Symbol,
    strategy_type::Type{<:AbstractStrategy};
    max_suggestions::Int=3
)
    meta = metadata(strategy_type)
    
    # Collect all available keys (primary names + aliases)
    all_keys = Symbol[]
    for (primary_key, spec) in pairs(meta.specs)
        push!(all_keys, primary_key)
        append!(all_keys, spec.aliases)
    end
    
    # Compute Levenshtein distances
    key_str = string(key)
    distances = [
        (k, levenshtein_distance(key_str, string(k)))
        for k in all_keys
    ]
    
    # Sort by distance and take top suggestions
    sort!(distances, by=x -> x[2])
    n_suggestions = min(max_suggestions, length(distances))
    suggestions = [k for (k, d) in distances[1:n_suggestions]]
    
    return suggestions
end

"""
$(TYPEDSIGNATURES)

Compute the Levenshtein distance between two strings.

The Levenshtein distance is the minimum number of single-character edits
(insertions, deletions, or substitutions) required to change one string into another.

# Arguments
- `s1::String`: First string
- `s2::String`: Second string

# Returns
- `Int`: Levenshtein distance between the two strings

# Example
```julia-repl
julia> levenshtein_distance("kitten", "sitting")
3

julia> levenshtein_distance("max_iter", "max_it")
2
```

# Algorithm
Uses dynamic programming with O(m*n) time and space complexity,
where m and n are the lengths of the input strings.

See also: [`suggest_options`](@ref)
"""
function levenshtein_distance(s1::String, s2::String)
    m, n = length(s1), length(s2)
    d = zeros(Int, m + 1, n + 1)
    
    # Initialize base cases
    for i in 0:m
        d[i+1, 1] = i
    end
    for j in 0:n
        d[1, j+1] = j
    end
    
    # Fill the matrix
    for j in 1:n
        for i in 1:m
            if s1[i] == s2[j]
                d[i+1, j+1] = d[i, j]  # No operation needed
            else
                d[i+1, j+1] = min(
                    d[i, j+1] + 1,    # deletion
                    d[i+1, j] + 1,    # insertion
                    d[i, j] + 1       # substitution
                )
            end
        end
    end
    
    return d[m+1, n+1]
end
