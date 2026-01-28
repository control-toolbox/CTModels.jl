# ============================================================================ #
# Orchestration Module - Disambiguation Helpers
# ============================================================================ #
# This file implements helper functions for strategy-based disambiguation.
# Supports both single and multi-strategy disambiguation syntax.
# ============================================================================ #

module Orchestration

using ..Strategies

# ---------------------------------------------------------------------------- #
# Strategy ID Extraction
# ---------------------------------------------------------------------------- #

"""
    extract_strategy_ids(raw, method::Tuple{Vararg{Symbol}}) 
        -> Union{Nothing, Vector{Tuple{Any, Symbol}}}

Extract strategy IDs from disambiguation syntax.

# Disambiguation Syntax

**Single strategy**:
```julia
value = (:sparse, :adnlp)  # Route to :adnlp strategy
```

**Multiple strategies**:
```julia
value = ((:sparse, :adnlp), (:cpu, :ipopt))  # Route to both
```

# Returns
- `nothing` if no disambiguation syntax detected
- `Vector{Tuple{Any, Symbol}}` of (value, strategy_id) pairs if disambiguated

# Examples
```julia
# Single strategy disambiguation
extract_strategy_ids((:sparse, :adnlp), (:collocation, :adnlp, :ipopt))
# => [(:sparse, :adnlp)]

# Multi-strategy disambiguation
extract_strategy_ids(((:sparse, :adnlp), (:cpu, :ipopt)), (:collocation, :adnlp, :ipopt))
# => [(:sparse, :adnlp), (:cpu, :ipopt)]

# No disambiguation
extract_strategy_ids(:sparse, (:collocation, :adnlp, :ipopt))
# => nothing
```

# Errors
- If strategy ID is not in method tuple
"""
function extract_strategy_ids(
    raw,
    method::Tuple{Vararg{Symbol}}
)::Union{Nothing, Vector{Tuple{Any, Symbol}}}
    
    # Single strategy: (value, :id)
    if raw isa Tuple{Any, Symbol} && length(raw) == 2
        value, id = raw
        if id in method
            return [(value, id)]
        else
            error("Strategy ID :$id not in method $method. Available: $method")
        end
    end
    
    # Multiple strategies: ((v1, :id1), (v2, :id2), ...)
    if raw isa Tuple && length(raw) > 0
        results = Tuple{Any, Symbol}[]
        all_valid = true
        
        for item in raw
            if item isa Tuple{Any, Symbol} && length(item) == 2
                value, id = item
                if id in method
                    push!(results, (value, id))
                else
                    error("Strategy ID :$id not in method $method. Available: $method")
                end
            else
                # Not a valid disambiguation tuple
                all_valid = false
                break
            end
        end
        
        if all_valid && !isempty(results)
            return results
        end
    end
    
    # No disambiguation detected
    return nothing
end

# ---------------------------------------------------------------------------- #
# Strategy-to-Family Mapping
# ---------------------------------------------------------------------------- #

"""
    build_strategy_to_family_map(
        method::Tuple{Vararg{Symbol}},
        families::NamedTuple,
        registry::StrategyRegistry
    ) -> Dict{Symbol, Symbol}

Build a mapping from strategy IDs to family names.

# Arguments
- `method`: Complete method tuple (e.g., `(:collocation, :adnlp, :ipopt)`)
- `families`: NamedTuple mapping family names to types
- `registry`: Strategy registry

# Returns
Dictionary mapping strategy ID => family name

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
families = (
    discretizer = AbstractOptimalControlDiscretizer,
    modeler = AbstractOptimizationModeler,
    solver = AbstractOptimizationSolver
)

map = build_strategy_to_family_map(method, families, registry)
# => Dict(:collocation => :discretizer, :adnlp => :modeler, :ipopt => :solver)
```
"""
function build_strategy_to_family_map(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,
    registry::StrategyRegistry
)::Dict{Symbol, Symbol}
    
    strategy_to_family = Dict{Symbol, Symbol}()
    
    for (family_name, family_type) in pairs(families)
        id = Strategies.extract_id_from_method(method, family_type, registry)
        strategy_to_family[id] = family_name
    end
    
    return strategy_to_family
end

# ---------------------------------------------------------------------------- #
# Option Ownership Map
# ---------------------------------------------------------------------------- #

"""
    build_option_ownership_map(
        method::Tuple{Vararg{Symbol}},
        families::NamedTuple,
        registry::StrategyRegistry
    ) -> Dict{Symbol, Set{Symbol}}

Build a mapping from option names to the families that own them.

# Arguments
- `method`: Complete method tuple
- `families`: NamedTuple mapping family names to types
- `registry`: Strategy registry

# Returns
Dictionary mapping option_name => Set{family_name}

# Example
```julia
map = build_option_ownership_map(method, families, registry)
# => Dict(
#     :grid_size => Set([:discretizer]),
#     :backend => Set([:modeler, :solver]),  # Ambiguous!
#     :max_iter => Set([:solver])
# )
```
"""
function build_option_ownership_map(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,
    registry::StrategyRegistry
)::Dict{Symbol, Set{Symbol}}
    
    option_owners = Dict{Symbol, Set{Symbol}}()
    
    for (family_name, family_type) in pairs(families)
        option_names = Strategies.option_names_from_method(method, family_type, registry)
        
        for option_name in option_names
            if !haskey(option_owners, option_name)
                option_owners[option_name] = Set{Symbol}()
            end
            push!(option_owners[option_name], family_name)
        end
    end
    
    return option_owners
end

end # module Orchestration
