# ============================================================================
# Disambiguation helpers for strategy-based option routing
# ============================================================================

using ..Strategies
using CTBase: CTBase
using DocStringExtensions

# ----------------------------------------------------------------------------
# Strategy ID Extraction
# ----------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Extract strategy IDs from disambiguation syntax.

This function detects whether an option value uses disambiguation syntax to
explicitly route the option to specific strategies. It supports both single
and multi-strategy disambiguation.

# Disambiguation Syntax

**Single strategy**:
```julia
value = (:sparse, :adnlp)  # Route to :adnlp strategy
```

**Multiple strategies**:
```julia
value = ((:sparse, :adnlp), (:cpu, :ipopt))  # Route to both
```

# Arguments
- `raw`: The raw option value to analyze
- `method::Tuple{Vararg{Symbol}}`: Complete method tuple containing all
  strategy IDs

# Returns
- `nothing` if no disambiguation syntax detected
- `Vector{Tuple{Any, Symbol}}` of (value, strategy_id) pairs if disambiguated

# Throws
- `CTBase.IncorrectArgument`: If a strategy ID in the disambiguation syntax
  is not present in the method tuple

# Examples
```julia-repl
julia> # Single strategy disambiguation
julia> extract_strategy_ids((:sparse, :adnlp), (:collocation, :adnlp, :ipopt))
[(:sparse, :adnlp)]

julia> # Multi-strategy disambiguation
julia> extract_strategy_ids(((:sparse, :adnlp), (:cpu, :ipopt)), (:collocation, :adnlp, :ipopt))
[(:sparse, :adnlp), (:cpu, :ipopt)]

julia> # No disambiguation
julia> extract_strategy_ids(:sparse, (:collocation, :adnlp, :ipopt))
nothing
```

See also: [`route_all_options`](@ref), [`build_strategy_to_family_map`](@ref)
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
            throw(CTBase.IncorrectArgument(
                "Strategy ID :$id not in method $method. Available: $method"
            ))
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
                    throw(CTBase.IncorrectArgument(
                        "Strategy ID :$id not in method $method. Available: $method"
                    ))
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

# ----------------------------------------------------------------------------
# Strategy-to-Family Mapping
# ----------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Build a mapping from strategy IDs to family names.

This helper function creates a reverse lookup dictionary that maps each
strategy ID in the method to its corresponding family name. This is used
by the routing system to determine which family owns each strategy.

# Arguments
- `method::Tuple{Vararg{Symbol}}`: Complete method tuple (e.g.,
  `(:collocation, :adnlp, :ipopt)`)
- `families::NamedTuple`: NamedTuple mapping family names to abstract types
- `registry::Strategies.StrategyRegistry`: Strategy registry

# Returns
- `Dict{Symbol, Symbol}`: Dictionary mapping strategy ID => family name

# Example
```julia-repl
julia> method = (:collocation, :adnlp, :ipopt)

julia> families = (
           discretizer = AbstractOptimalControlDiscretizer,
           modeler = AbstractOptimizationModeler,
           solver = AbstractOptimizationSolver
       )

julia> map = build_strategy_to_family_map(method, families, registry)
Dict{Symbol, Symbol} with 3 entries:
  :collocation => :discretizer
  :adnlp       => :modeler
  :ipopt       => :solver
```

See also: [`build_option_ownership_map`](@ref), [`extract_strategy_ids`](@ref)
"""
function build_strategy_to_family_map(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,
    registry::Strategies.StrategyRegistry
)::Dict{Symbol, Symbol}
    
    strategy_to_family = Dict{Symbol, Symbol}()
    
    for (family_name, family_type) in pairs(families)
        id = Strategies.extract_id_from_method(method, family_type, registry)
        strategy_to_family[id] = family_name
    end
    
    return strategy_to_family
end

# ----------------------------------------------------------------------------
# Option Ownership Map
# ----------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Build a mapping from option names to the families that own them.

This function analyzes the metadata of all strategies in the method to
determine which family (or families) define each option. Options that
appear in multiple families are considered ambiguous and require
disambiguation.

# Arguments
- `method::Tuple{Vararg{Symbol}}`: Complete method tuple
- `families::NamedTuple`: NamedTuple mapping family names to abstract types
- `registry::Strategies.StrategyRegistry`: Strategy registry

# Returns
- `Dict{Symbol, Set{Symbol}}`: Dictionary mapping option_name =>
  Set{family_name}

# Example
```julia-repl
julia> map = build_option_ownership_map(method, families, registry)
Dict{Symbol, Set{Symbol}} with 3 entries:
  :grid_size => Set([:discretizer])
  :backend   => Set([:modeler, :solver])  # Ambiguous!
  :max_iter  => Set([:solver])
```

# Notes
- Options appearing in only one family can be auto-routed
- Options appearing in multiple families require disambiguation syntax
- Options not appearing in any family will trigger an error during routing

See also: [`build_strategy_to_family_map`](@ref), [`route_all_options`](@ref)
"""
function build_option_ownership_map(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,
    registry::Strategies.StrategyRegistry
)::Dict{Symbol, Set{Symbol}}
    
    option_owners = Dict{Symbol, Set{Symbol}}()
    
    for (family_name, family_type) in pairs(families)
        option_names = Strategies.option_names_from_method(
            method, family_type, registry
        )
        
        for option_name in option_names
            if !haskey(option_owners, option_name)
                option_owners[option_name] = Set{Symbol}()
            end
            push!(option_owners[option_name], family_name)
        end
    end
    
    return option_owners
end