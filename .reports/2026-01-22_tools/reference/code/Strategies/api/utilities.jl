# ============================================================================ #
# Strategies Module - Internal Utilities
# ============================================================================ #
# This file implements internal utility functions for the Strategies module.
# ============================================================================ #

module Strategies

"""
    validate_options(user_nt::NamedTuple, strategy_type::Type{<:AbstractStrategy}; strict_keys::Bool=true)

Validate user-provided options against strategy metadata.

# Checks
- Type correctness for each option
- Unknown keys (if strict_keys=true)
- Custom validators

# Arguments
- `user_nt`: User-provided options as NamedTuple
- `strategy_type`: Strategy type to validate against
- `strict_keys`: If true, error on unknown keys; if false, allow them

# Errors
- Type mismatch
- Unknown option (if strict_keys=true)
- Validation failure

# Example
```julia
validate_options((max_iter=200,), MyStrategy; strict_keys=true)
# Validates that max_iter is known and has correct type
```

# Note
This is called internally by `build_strategy_options()`.
"""
function validate_options(
    user_nt::NamedTuple,
    strategy_type::Type{<:AbstractStrategy};
    strict_keys::Bool=true
)
    meta = metadata(strategy_type)
    
    for (key, value) in pairs(user_nt)
        # Resolve alias to primary key
        actual_key = resolve_alias(meta, key)
        
        if actual_key === nothing
            if strict_keys
                available = collect(keys(meta.specs))
                # Try to suggest similar keys
                suggestions = suggest_options(key, strategy_type)
                if !isempty(suggestions)
                    error("Unknown option: $key. Available: $available. Did you mean: $suggestions?")
                else
                    error("Unknown option: $key. Available: $available")
                end
            else
                continue  # Allow unknown keys in non-strict mode
            end
        end
        
        # Get specification
        spec = meta[actual_key]
        
        # Validate type
        if !isa(value, spec.type)
            error("Option $actual_key expects type $(spec.type), got $(typeof(value))")
        end
        
        # Validate with custom validator
        if spec.validator !== nothing
            if !spec.validator(value)
                error("Validation failed for option $actual_key with value $value")
            end
        end
    end
    
    return nothing
end

"""
    filter_options(nt::NamedTuple, exclude::Union{Symbol, Tuple{Vararg{Symbol}}})

Filter a NamedTuple by excluding specified keys.

# Arguments
- `nt`: NamedTuple to filter
- `exclude`: Single key or tuple of keys to exclude

# Returns
New NamedTuple without the excluded keys

# Example
```julia
opts = (max_iter=100, tol=1e-6, debug=true)
filter_options(opts, :debug)  # => (max_iter=100, tol=1e-6)
filter_options(opts, (:debug, :tol))  # => (max_iter=100,)
```
"""
function filter_options(nt::NamedTuple, exclude::Symbol)
    return filter_options(nt, (exclude,))
end

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
    suggest_options(key::Symbol, strategy_type::Type{<:AbstractStrategy}; max_suggestions::Int=3)

Suggest similar option names for an unknown key using Levenshtein distance.

# Arguments
- `key`: Unknown key to find suggestions for
- `strategy_type`: Strategy type to search in
- `max_suggestions`: Maximum number of suggestions to return

# Returns
Vector of suggested keys, sorted by similarity

# Example
```julia
suggest_options(:max_it, MyStrategy)  # => [:max_iter]
suggest_options(:tolrance, MyStrategy)  # => [:tolerance]
```

# Note
Used internally by error messages to provide helpful suggestions.
"""
function suggest_options(
    key::Symbol,
    strategy_type::Type{<:AbstractStrategy};
    max_suggestions::Int=3
)
    meta = metadata(strategy_type)
    available_keys = collect(keys(meta.specs))
    
    # Also include aliases
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
    suggestions = [k for (k, d) in distances[1:min(max_suggestions, length(distances))]]
    
    return suggestions
end

"""
    levenshtein_distance(s1::String, s2::String)

Compute the Levenshtein distance between two strings.

# Returns
Integer representing the minimum number of single-character edits
(insertions, deletions, or substitutions) required to change s1 into s2.

# Example
```julia
levenshtein_distance("kitten", "sitting")  # => 3
```
"""
function levenshtein_distance(s1::String, s2::String)
    m, n = length(s1), length(s2)
    d = zeros(Int, m + 1, n + 1)
    
    for i in 0:m
        d[i+1, 1] = i
    end
    for j in 0:n
        d[1, j+1] = j
    end
    
    for j in 1:n
        for i in 1:m
            if s1[i] == s2[j]
                d[i+1, j+1] = d[i, j]
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

end # module Strategies
