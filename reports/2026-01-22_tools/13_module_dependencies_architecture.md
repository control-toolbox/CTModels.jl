# Module Dependencies and Routing Architecture

**Date**: 2026-01-22  
**Status**: Architecture Design - Module Boundaries

---

## Problème : Dépendances Circulaires

### Question Clé

**Comment Options peut-il router sans connaître Strategies ou Orchestration ?**

```
Options ──┐
          ├──> Orchestration ──> Strategies
          │
          └──> ??? Comment router sans connaître les stratégies ?
```

---

## Solution : Inversion de Dépendance

### Principe

**Options ne fait PAS le routing**. Options fournit les **outils** pour le routing, mais c'est **Orchestration** qui orchestre.

```
Options (outils bas niveau)
   ↑
   │
Strategies (gestion des stratégies)
   ↑
   │
Orchestration (orchestration du routing)
```

---

## Architecture des Modules

### Module 1: **Options** (Bas niveau - Aucune dépendance)

**Responsabilité** : Manipulation générique des options (extraction, validation, aliases)

```julia
module Options

# Pas de dépendance sur Strategies ou Orchestration

struct OptionValue{T}
    value::T
    source::Symbol  # :default, :user, :computed
end

struct OptionSchema
    name::Symbol
    type::Type
    default::Any
    aliases::Tuple{Vararg{Symbol}}
    validator::Union{Function, Nothing}
end

"""
Extract a single option from kwargs using schema (handles aliases).
Returns (OptionValue, remaining_kwargs).
"""
function extract_option(kwargs::NamedTuple, schema::OptionSchema)
    for alias in (schema.name, schema.aliases...)
        if haskey(kwargs, alias)
            value = kwargs[alias]
            if schema.validator !== nothing
                schema.validator(value)
            end
            remaining = NamedTuple(k => v for (k, v) in pairs(kwargs) if k != alias)
            return OptionValue(value, :user), remaining
        end
    end
    return OptionValue(schema.default, :default), kwargs
end

"""
Extract multiple options from kwargs.
Returns (Dict{Symbol, OptionValue}, remaining_kwargs).
"""
function extract_options(kwargs::NamedTuple, schemas::Vector{OptionSchema})
    extracted = Dict{Symbol, OptionValue}()
    remaining = kwargs
    
    for schema in schemas
        opt_value, remaining = extract_option(remaining, schema)
        extracted[schema.name] = opt_value
    end
    
    return extracted, remaining
end

end
```

**Clé** : Options ne sait RIEN sur les stratégies. Il fournit juste des outils.

---

### Module 2: **Strategies** (Dépend de Options)

**Responsabilité** : Gestion des stratégies, registre, construction

```julia
module Strategies

using ..Options

abstract type AbstractStrategy end

# Contract (unchanged)
symbol(::Type{<:AbstractStrategy})::Symbol
options(strategy::AbstractStrategy)::NamedTuple{names, <:Tuple{Vararg{OptionValue}}}

# Registry (unchanged)
struct StrategyRegistry
    families::Dict{Type{<:AbstractStrategy}, Vector{Type}}
end

create_registry(pairs...)
build_strategy(id, family, registry; kwargs...)

"""
Get option names for a strategy type.
"""
function option_names(strategy_type::Type{<:AbstractStrategy})
    # Use metadata or reflection
    return metadata(strategy_type).option_names
end

"""
Get option names for a family from a method tuple.
"""
function option_names_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry
)
    id = extract_id_from_method(method, family, registry)
    strategy_type = type_from_id(id, family, registry)
    return option_names(strategy_type)
end

end
```

**Clé** : Strategies utilise Options pour gérer les options des stratégies, mais ne fait pas de routing multi-stratégies.

---

### Module 3: **Orchestration** (Dépend de Options et Strategies)

**Responsabilité** : Orchestration des actions, routing, dispatch multi-modes

```julia
module Orchestration

using ..Options
using ..Strategies

"""
Route options to strategies AND extract action options.

This is the ONLY place where routing happens.
"""
function route_all_options(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,  # family_name => Type
    action_schemas::Vector{OptionSchema},
    kwargs::NamedTuple,
    registry::StrategyRegistry
)
    # Step 1: Extract action options FIRST
    action_options, remaining = Options.extract_options(kwargs, action_schemas)
    
    # Step 2: Route remaining to strategies
    strategy_options = route_to_strategies(method, families, remaining, registry)
    
    return (action=action_options, strategies=strategy_options)
end

"""
Route options to strategies (internal helper).
"""
function route_to_strategies(
    method::Tuple{Vararg{Symbol}},
    families::NamedTuple,
    kwargs::NamedTuple,
    registry::StrategyRegistry
)
    # Build strategy-to-family mapping
    strategy_to_family = Dict{Symbol,Symbol}()
    for (family_name, family_type) in pairs(families)
        id = Strategies.extract_id_from_method(method, family_type, registry)
        strategy_to_family[id] = family_name
    end
    
    # Build option ownership
    option_owners = Dict{Symbol, Set{Symbol}}()
    for (family_name, family_type) in pairs(families)
        keys = Strategies.option_names_from_method(method, family_type, registry)
        for key in keys
            if !haskey(option_owners, key)
                option_owners[key] = Set{Symbol}()
            end
            push!(option_owners[key], family_name)
        end
    end
    
    # Route each option
    routed = Dict{Symbol, Vector{Pair{Symbol,Any}}}()
    for (family_name, _) in pairs(families)
        routed[family_name] = Pair{Symbol,Any}[]
    end
    
    for (key, raw_value) in pairs(kwargs)
        # Try disambiguation
        disambiguations = extract_strategy_ids(raw_value, method)
        
        if disambiguations !== nothing
            # Explicitly disambiguated
            for (value, strategy_id) in disambiguations
                family_name = strategy_to_family[strategy_id]
                owners = get(option_owners, key, Set{Symbol}())
                
                if family_name in owners
                    push!(routed[family_name], key => value)
                else
                    error("Option $key cannot be routed to $strategy_id")
                end
            end
        else
            # Auto-route
            owners = get(option_owners, key, Set{Symbol}())
            
            if length(owners) == 1
                push!(routed[first(owners)], key => raw_value)
            elseif isempty(owners)
                error("Unknown option $key")
            else
                error("Ambiguous option $key between $owners")
            end
        end
    end
    
    # Convert to NamedTuples
    result = NamedTuple(family_name => NamedTuple(pairs) for (family_name, pairs) in routed)
    return result
end

end
```

**Clé** : Orchestration orchestre tout. Il utilise Options pour extraire les options d'action, puis Strategies pour router aux stratégies.

---

## Flux de Données

### Mode Description

```
User: solve(ocp, :collocation, :adnlp; grid_size=100, initial_guess=ig)
  ↓
Orchestration.route_all_options(method, families, action_schemas, kwargs, registry)
  ↓
  ├─> Options.extract_options(kwargs, action_schemas)
  │     → (action_options, remaining_kwargs)
  │
  └─> Orchestration.route_to_strategies(method, families, remaining_kwargs, registry)
        ↓
        Uses Strategies.option_names_from_method() to know which options belong where
        → (strategy_options)
  ↓
Build strategies with Strategies.build_strategy()
  ↓
Call core action: _solve(ocp, discretizer, modeler, solver; action_options...)
```

---

## Contrat vs API

### Contrat (Public - Utilisateur)

**Ce que l'utilisateur voit et utilise** :

```julia
# Contrat Strategy
abstract type AbstractStrategy end
symbol(::Type{<:AbstractStrategy})::Symbol
options(strategy::AbstractStrategy)::NamedTuple

# Contrat Action (les 3 modes)
solve(ocp, discretizer, modeler, solver; initial_guess, display)  # Standard
solve(ocp, :collocation, :adnlp; grid_size=100, initial_guess=ig)  # Description
solve(ocp; discretizer=..., initial_guess=ig)  # Explicit
```

### API (Interne - Développeur de stratégies/actions)

**Ce que les développeurs utilisent pour créer des stratégies/actions** :

```julia
# API Options
Options.extract_option(kwargs, schema)
Options.extract_options(kwargs, schemas)

# API Strategies
Strategies.create_registry(pairs...)
Strategies.build_strategy(id, family, registry; kwargs...)
Strategies.option_names_from_method(method, family, registry)

# API Orchestration
Orchestration.route_all_options(method, families, action_schemas, kwargs, registry)
Orchestration.dispatch_action(signature, registry, args, kwargs)
```

---

## Documentation Structure

```
docs/
├── user/
│   ├── strategies_contract.md  # Comment implémenter une stratégie
│   ├── actions_usage.md        # Comment utiliser les 3 modes
│   └── examples.md
└── developer/
    ├── options_api.md          # API Options module
    ├── strategies_api.md       # API Strategies module
    ├── actions_api.md          # API Orchestration module
    └── creating_actions.md     # Comment créer une nouvelle action
```

---

## Résumé

### Dépendances

```
Options (aucune dépendance)
   ↑
Strategies (dépend de Options)
   ↑
Orchestration (dépend de Options + Strategies)
```

### Responsabilités

- **Options** : Outils bas niveau (extraction, validation)
- **Strategies** : Gestion des stratégies (registre, construction, métadonnées)
- **Orchestration** : Orchestration (routing, dispatch, modes)

### Routing

**Fait dans Orchestration**, pas dans Options.

Orchestration utilise :
- `Options.extract_options()` pour les options d'action
- `Strategies.option_names_from_method()` pour savoir quelles options appartiennent à quelles stratégies
- Sa propre logique pour router aux stratégies
