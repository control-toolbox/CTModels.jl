# ============================================================================
# Option routing with strategy-aware disambiguation
# ============================================================================

using ..Options
using ..Strategies
using CTBase: CTBase
using DocStringExtensions

# ----------------------------------------------------------------------------
# Main Routing Function
# ----------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Route all options with support for disambiguation and multi-strategy routing.

This is the main orchestration function that separates action options from
strategy options and routes each strategy option to the appropriate family.
It supports automatic routing for unambiguous options and explicit
disambiguation syntax for options that appear in multiple strategies.

# Arguments
- `method::Tuple{Vararg{Symbol}}`: Complete method tuple (e.g.,
  `(:collocation, :adnlp, :ipopt)`)
- `families::NamedTuple`: NamedTuple mapping family names to AbstractStrategy
  types
- `action_defs::Vector{Options.OptionDefinition}`: Definitions for
  action-specific options
- `kwargs::NamedTuple`: All keyword arguments (action + strategy options mixed)
- `registry::Strategies.StrategyRegistry`: Strategy registry
- `source_mode::Symbol=:description`: Controls error verbosity (`:description`
  for user-facing, `:explicit` for internal)

# Returns
NamedTuple with two fields:
- `action::NamedTuple`: NamedTuple of action options (with `OptionValue`
  wrappers)
- `strategies::NamedTuple`: NamedTuple of strategy options per family (raw
  values)

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

# Throws
- `CTBase.IncorrectArgument`: If an option is unknown, ambiguous without
  disambiguation, or routed to the wrong strategy

# Example
```julia-repl
julia> method = (:collocation, :adnlp, :ipopt)

julia> families = (
           discretizer = AbstractOptimalControlDiscretizer,
           modeler = AbstractOptimizationModeler,
           solver = AbstractOptimizationSolver
       )

julia> action_defs = [
           OptionDefinition(name=:display, type=Bool, default=true,
                          description="Display progress")
       ]

julia> kwargs = (
           grid_size = 100,
           backend = (:sparse, :adnlp),
           max_iter = 1000,
           display = true
       )

julia> routed = route_all_options(method, families, action_defs, kwargs,
                                   registry)
(action = (display = true (user),),
 strategies = (discretizer = (grid_size = 100,),
              modeler = (backend = :sparse,),
              solver = (max_iter = 1000,)))
```

See also: [`extract_strategy_ids`](@ref),
[`build_strategy_to_family_map`](@ref), [`build_option_ownership_map`](@ref)
"""
function route_all_options(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,
    action_defs::Vector{Options.OptionDefinition},
    kwargs::NamedTuple,
    registry::Strategies.StrategyRegistry;
    source_mode::Symbol = :description,
)
    # Step 1: Extract action options FIRST
    action_options, remaining_kwargs = Options.extract_options(
        kwargs, action_defs
    )

    # Step 2: Build strategy-to-family mapping
    strategy_to_family = build_strategy_to_family_map(
        method, families, registry
    )

    # Step 3: Build option ownership map
    option_owners = build_option_ownership_map(method, families, registry)

    # Step 4: Route each remaining option
    routed = Dict{Symbol, Vector{Pair{Symbol, Any}}}()
    for family_name in keys(families)
        routed[family_name] = Pair{Symbol, Any}[]
    end
    for (key, raw_val) in pairs(remaining_kwargs)
        # Try to extract disambiguation
        disambiguations = extract_strategy_ids(raw_val, method)

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
                    valid_strategies = [
                        id for (id, fam) in strategy_to_family if fam in owners
                    ]
                    throw(Exceptions.IncorrectArgument(
                        "Invalid option routing",
                        got="option :$key to strategy :$strategy_id",
                        expected="option to be routed to one of: $valid_strategies",
                        suggestion="Check option ownership or use correct strategy identifier",
                        context="route_options - validating strategy-specific option routing"
                    ))
                end
            end
        else
            # Auto-route based on ownership
            value = raw_val
            owners = get(option_owners, key, Set{Symbol}())

            if isempty(owners)
                # Unknown option - provide helpful error
                _error_unknown_option(
                    key, method, families, strategy_to_family, registry
                )
            elseif length(owners) == 1
                # Unambiguous - auto-route
                family_name = first(owners)
                push!(routed[family_name], key => value)
            else
                # Ambiguous - need disambiguation
                _error_ambiguous_option(
                    key, value, owners, strategy_to_family, source_mode
                )
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

# ----------------------------------------------------------------------------
# Error Message Helpers (Private)
# ----------------------------------------------------------------------------

function _error_unknown_option(
    key::Symbol,
    method::Tuple,
    families::NamedTuple,
    strategy_to_family::Dict{Symbol, Symbol},
    registry::Strategies.StrategyRegistry
)
    # Build helpful error message showing all available options
    all_options = Dict{Symbol, Vector{Symbol}}()
    for (family_name, family_type) in pairs(families)
        id = Strategies.extract_id_from_method(method, family_type, registry)
        option_names = Strategies.option_names_from_method(
            method, family_type, registry
        )
        all_options[id] = collect(option_names)
    end

    msg = "Option :$key doesn't belong to any strategy in method $method.\n\n" *
          "Available options:\n"
    for (id, option_names) in all_options
        family = strategy_to_family[id]
        msg *= "  $family (:$id): $(join(option_names, ", "))\n"
    end

    throw(Exceptions.IncorrectArgument(
        "Unknown option provided",
        got="option :$key in method $method",
        expected="valid option name for one of the strategies",
        suggestion="Check available options above and use correct option name",
        context="route_options - unknown option validation"
    ))
end

function _error_ambiguous_option(
    key::Symbol,
    value::Any,
    owners::Set{Symbol},
    strategy_to_family::Dict{Symbol, Symbol},
    source_mode::Symbol
)
    # Find which strategies own this option
    strategies = [
        id for (id, fam) in strategy_to_family if fam in owners
    ]

    if source_mode === :description
        # User-friendly error message
        msg = "Option :$key is ambiguous between strategies: " *
              "$(join(strategies, ", ")).\n\n" *
              "Disambiguate by specifying the strategy ID:\n"
        for id in strategies
            fam = strategy_to_family[id]
            msg *= "  $key = ($value, :$id)    # Route to $fam\n"
        end
        msg *= "\nOr set for multiple strategies:\n" *
               "  $key = (" *
               join(["($value, :$id)" for id in strategies], ", ") *
               ")"
        throw(Exceptions.IncorrectArgument(
            "Ambiguous option requires disambiguation",
            got="option :$key between strategies: $(join(strategies, ", "))",
            expected="strategy-specific routing using (value, :strategy_id) syntax",
            suggestion="Use disambiguation syntax like $key = ($value, :$id) to specify target strategy",
            context="route_options - ambiguous option resolution"
        ))
    else
        # Internal/developer error message
        throw(Exceptions.IncorrectArgument(
            "Ambiguous option in explicit mode",
            got="option :$key between families: $owners",
            expected="unambiguous option routing in explicit mode",
            suggestion="Use strategy-specific routing or switch to description mode for ambiguous options",
            context="route_options - explicit mode ambiguity validation"
        ))
    end
end