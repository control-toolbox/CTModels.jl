# ============================================================================ #
# Orchestration Module - Option Routing with Disambiguation
# ============================================================================ #
# This file implements the complete routing logic with support for:
# - Strategy-based disambiguation: backend = (:sparse, :adnlp)
# - Multi-strategy routing: backend = ((:sparse, :adnlp), (:cpu, :ipopt))
# - Automatic routing for unambiguous options
# ============================================================================ #

module Orchestration

using ..Options
using ..Strategies

# Import disambiguation helpers
include("disambiguation.jl")

# ---------------------------------------------------------------------------- #
# Complete Routing Function
# ---------------------------------------------------------------------------- #

"""
    route_all_options(
        method::Tuple{Vararg{Symbol}},
        families::NamedTuple,
        action_schemas::Vector{OptionSchema},
        kwargs::NamedTuple,
        registry::StrategyRegistry;
        source_mode::Symbol=:description
    ) -> (action=NamedTuple, strategies=NamedTuple)

Route all options with support for disambiguation and multi-strategy routing.

# Arguments
- `method`: Complete method tuple (e.g., `(:collocation, :adnlp, :ipopt)`)
- `families`: NamedTuple mapping family names to AbstractStrategy types
- `action_schemas`: Schemas for action-specific options
- `kwargs`: All keyword arguments (action + strategy options mixed)
- `registry`: Strategy registry
- `source_mode`: `:description` (user-facing) or `:explicit` (internal)

# Returns
Named tuple with:
- `action`: NamedTuple of action options (with OptionValue)
- `strategies`: NamedTuple of strategy options per family

# Disambiguation Syntax

**Auto-routing** (unambiguous):
```julia
solve(ocp, :collocation, :adnlp, :ipopt; grid_size=100)
# grid_size only belongs to discretizer => auto-route
```

**Single strategy** (disambiguate):
```julia
solve(ocp, :collocation, :adnlp, :ipopt; backend = (:sparse, :adnlp))
# backend belongs to both modeler and solver => disambiguate to :adnlp
```

**Multi-strategy** (set for multiple):
```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))
)
# Set backend to :sparse for modeler AND :cpu for solver
```

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
families = (
    discretizer = AbstractOptimalControlDiscretizer,
    modeler = AbstractOptimizationModeler,
    solver = AbstractOptimizationSolver
)
action_schemas = [
    OptionSchema(:initial_guess, Any, nothing, (:init, :i), nothing),
    OptionSchema(:display, Bool, true, (), nothing)
]
kwargs = (
    grid_size = 100,                        # Auto-route to discretizer
    backend = (:sparse, :adnlp),            # Disambiguate to modeler
    max_iter = 1000,                        # Auto-route to solver
    initial_guess = ig,                     # Action option
    display = true                          # Action option
)

routed = route_all_options(method, families, action_schemas, kwargs, registry)
# => (
#     action = (initial_guess = OptionValue(ig, :user), display = OptionValue(true, :user)),
#     strategies = (
#         discretizer = (grid_size = 100,),
#         modeler = (backend = :sparse,),
#         solver = (max_iter = 1000,)
#     )
# )
```
"""
function route_all_options(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,
    action_schemas::Vector{OptionSchema},
    kwargs::NamedTuple,
    registry::StrategyRegistry;
    source_mode::Symbol=:description
)::NamedTuple

    # Step 1: Extract action options FIRST
    action_options, remaining_kwargs = Options.extract_options(kwargs, action_schemas)

    # Step 2: Build strategy-to-family mapping
    strategy_to_family = build_strategy_to_family_map(method, families, registry)

    # Step 3: Build option ownership map
    option_owners = build_option_ownership_map(method, families, registry)

    # Step 4: Route each remaining option
    routed = Dict{Symbol,Vector{Pair{Symbol,Any}}}()
    for (family_name, _) in pairs(families)
        routed[family_name] = Pair{Symbol,Any}[]
    end

    for (key, raw_value) in pairs(remaining_kwargs)
        # Try to extract disambiguation
        disambiguations = extract_strategy_ids(raw_value, method)

        if disambiguations !== nothing
            # Explicitly disambiguated (single or multiple strategies)
            for (value, strategy_id) in disambiguations
                family_name = strategy_to_family[strategy_id]
                owners = get(option_owners, key, Set{Symbol}())

                # Validate that this family owns this option
                if family_name in owners
                    push!(routed[family_name], key => value)
                else
                    # Error: trying to route to wrong strategy
                    valid_strategies = [id for (id, fam) in strategy_to_family if fam in owners]
                    error("Option :$key cannot be routed to strategy :$strategy_id. " *
                          "This option belongs to: $valid_strategies")
                end
            end
        else
            # Auto-route based on ownership
            value = raw_value
            owners = get(option_owners, key, Set{Symbol}())

            if isempty(owners)
                # Unknown option - provide helpful error
                _error_unknown_option(key, method, families, strategy_to_family, registry)

            elseif length(owners) == 1
                # Unambiguous - auto-route
                family_name = first(owners)
                push!(routed[family_name], key => value)
            else
                # Ambiguous - need disambiguation
                _error_ambiguous_option(key, value, owners, strategy_to_family, source_mode)
            end
        end
    end

    # Step 5: Convert to NamedTuples
    strategy_options = NamedTuple(
        family_name => NamedTuple(pairs)
        for (family_name, pairs) in routed
    )

    return (action=action_options, strategies=strategy_options)
end

# ---------------------------------------------------------------------------- #
# Error Message Helpers
# ---------------------------------------------------------------------------- #

function _error_unknown_option(
    key::Symbol,
    method::Tuple,
    families::NamedTuple,
    strategy_to_family::Dict{Symbol,Symbol},
    registry::StrategyRegistry
)
    # Build helpful error message showing all available options
    all_options = Dict{Symbol,Vector{Symbol}}()
    for (family_name, family_type) in pairs(families)
        id = Strategies.extract_id_from_method(method, family_type, registry)
        option_names = Strategies.option_names_from_method(method, family_type, registry)
        all_options[id] = collect(option_names)
    end

    msg = "Option :$key doesn't belong to any strategy in method $method.\n\n" *
          "Available options:\n"
    for (id, option_names) in all_options
        family = strategy_to_family[id]
        msg *= "  $family (:$id): $(join(option_names, ", "))\n"
    end

    error(msg)
end

function _error_ambiguous_option(
    key::Symbol,
    value::Any,
    owners::Set{Symbol},
    strategy_to_family::Dict{Symbol,Symbol},
    source_mode::Symbol
)
    # Find which strategies own this option
    strategies = [id for (id, fam) in strategy_to_family if fam in owners]

    if source_mode === :description
        # User-friendly error message
        msg = "Option :$key is ambiguous between strategies: $(join(strategies, ", ")).\n\n" *
              "Disambiguate by specifying the strategy ID:\n"
        for id in strategies
            fam = strategy_to_family[id]
            msg *= "  $key = ($value, :$id)    # Route to $fam\n"
        end
        msg *= "\nOr set for multiple strategies:\n" *
               "  $key = (" * join(["($value, :$id)" for id in strategies], ", ") * ")"
        error(msg)
    else
        # Internal/developer error message
        error("Ambiguous option :$key in explicit mode between families: $owners")
    end
end

end # module Orchestration
