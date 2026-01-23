# Action Pattern Analysis - Strategy vs Action Options

**Date**: 2026-01-22  
**Status**: Architecture Analysis - Questions Résolues

---

## TL;DR

**Questions clés analysées** :

1. ✅ Signature de `_solve()` : Options d'action en kwargs (résolu)
2. ✅ Routing : Séparation action/stratégies (résolu dans doc 13)
3. ✅ Aliases : Module Options générique (résolu dans doc 13)
4. ✅ Construction de description : Nécessaire pour compatibilité

**Architecture finale** : 3 modules (Options → Strategies → Orchestration)

**Concepts abandonnés** :

- ❌ `AbstractAction` : Trop générique, chaque action gère ses propres modes
- ❌ `dispatch_action()` générique : Impossible à cause des signatures différentes

**Voir aussi** :

- [13_module_dependencies_architecture.md](../reference/13_module_dependencies_architecture.md) - Architecture finale
- [14_action_genericity_analysis.md](14_action_genericity_analysis.md) - Pourquoi le dispatch générique est abandonné

---

## Questions Soulevées

### Q1: Signature de `_solve()` - Action Options vs Strategy Options

**Question**: Devrait-on avoir `initial_guess` et `display` comme options de l'action plutôt que comme arguments positionnels ?

**Actuel** :

```julia
function _solve(
    ocp, initial_guess, discretizer, modeler, solver; display=true
)
```

**Proposé** :

```julia
function _solve(
    ocp, discretizer, modeler, solver; 
    initial_guess=nothing, 
    display=true
)
```

**Analyse** :

✅ **Pour le changement** :

- Plus cohérent : les stratégies sont des arguments positionnels, les options sont nommées
- Pattern clair : `action(object, strategies...; action_options...)`
- `initial_guess` est optionnel, donc plus naturel en kwarg

❌ **Contre le changement** :

- `initial_guess` est conceptuellement important, pas juste une "option"
- Actuellement très visible en tant qu'argument positionnel

**Recommandation** : ✅ **Changer**. Le pattern `action(object, strategies...; options...)` est plus clair.

---

### Q2: Routing des Options - Strategy vs Action Options

**Question**: Le routage gère-t-il correctement la séparation entre options de stratégies et options d'action ?

**Analyse du code actuel** :

Dans `_parse_kwargs()` (lignes 218-226) :

```julia
function _parse_kwargs(kwargs::NamedTuple)
    initial_guess, kwargs1 = _take_kwarg(kwargs, _SOLVE_INITIAL_GUESS_ALIASES, ...)
    display, kwargs2 = _take_kwarg(kwargs1, _SOLVE_DISPLAY_ALIASES, ...)
    discretizer, kwargs3 = _take_kwarg(kwargs2, _SOLVE_DISCRETIZER_ALIASES, nothing)
    modeler, kwargs4 = _take_kwarg(kwargs3, _SOLVE_MODELER_ALIASES, nothing)
    solver, other_kwargs = _take_kwarg(kwargs4, _SOLVE_SOLVER_ALIASES, nothing)
    
    return _ParsedKwargs(initial_guess, display, discretizer, modeler, solver, other_kwargs)
end
```

**Ce qui se passe** :

1. On extrait d'abord les **options d'action** : `initial_guess`, `display`
2. On extrait les **stratégies explicites** : `discretizer`, `modeler`, `solver`
3. Tout le reste va dans `other_kwargs` pour être routé

**Problème identifié** : ❌ **Non, ce n'est pas complet !**

Dans `solve.jl` (lignes 416-446), il y a une validation supplémentaire :

```julia
function _ensure_no_ambiguous_description_kwargs(method::Tuple, kwargs::NamedTuple)
    # ...
    for (k, raw) in pairs(kwargs)
        owners = Symbol[]
        
        # Check if option belongs to SOLVE
        if (k in _SOLVE_INITIAL_GUESS_ALIASES) ||
           (k in _SOLVE_DISCRETIZER_ALIASES) ||
           (k in _SOLVE_MODELER_ALIASES) ||
           (k in _SOLVE_SOLVER_ALIASES) ||
           (k in _SOLVE_DISPLAY_ALIASES) ||
           (k in _SOLVE_MODELER_OPTIONS_ALIASES)
            push!(owners, :solve)
        end
        
        # Check if option belongs to strategies
        if k in disc_keys
            push!(owners, :discretizer)
        end
        # ...
    end
end
```

**Ce qui manque dans `solve_simplified.jl`** :

- ❌ Pas de validation que les options d'action ne sont pas routées aux stratégies
- ❌ Pas de gestion des conflits entre options d'action et options de stratégies

**Recommandation** : Le routage doit **exclure** les options d'action avant de router aux stratégies.

---

### Q3: Aliases d'Options - Où les gérer ?

**Question**: Les aliases (`:initial_guess`, `:init`, `:i`) devraient-ils être dans le module Strategies ?

**Actuel** (dans solve.jl) :

```julia
const _SOLVE_INITIAL_GUESS_ALIASES = (:initial_guess, :init, :i)
const _SOLVE_DISCRETIZER_ALIASES = (:discretizer, :d)
const _SOLVE_MODELER_ALIASES = (:modeler, :modeller, :m)
```

**Analyse** :

✅ **Pour déplacer dans Strategies** :

- Concept générique : toute action peut avoir des aliases
- Réutilisable pour d'autres actions

❌ **Contre déplacer dans Strategies** :

- Spécifique à chaque action (`:i` pour initial_guess est spécifique à solve)
- Pas lié aux stratégies elles-mêmes

**Recommandation** : ⚠️ **Compromis** - Créer un système d'aliases générique dans un module **Options**, mais les aliases spécifiques restent dans chaque action.

---

### Q4: Construction de Description en Mode Explicite

**Question**: Est-on obligé de construire une description depuis les composants en mode explicite ?

**Code actuel** (lignes 316-321) :

```julia
# Otherwise, build partial description and complete it
partial_desc = _build_description_from_components(
    parsed.discretizer, parsed.modeler, parsed.solver
)
method = CTBase.complete(partial_desc...; descriptions=available_methods())

# Build missing components with default options
discretizer = parsed.discretizer !== nothing ? parsed.discretizer :
              build_strategy_from_method(method, STRATEGY_FAMILIES.discretizer, OCP_REGISTRY)
```

**Pourquoi on fait ça** :

- Si l'utilisateur fournit seulement `discretizer=CollocationDiscretizer()`, on doit compléter avec un modeler et solver par défaut
- Pour choisir les bons par défaut, on utilise `CTBase.complete()` qui trouve une méthode compatible

**Alternative plus simple** :

```julia
# Just use first available method as default
method = AVAILABLE_METHODS[1]  # (:collocation, :adnlp, :ipopt)

discretizer = parsed.discretizer !== nothing ? parsed.discretizer :
              build_strategy_from_method(method, STRATEGY_FAMILIES.discretizer, OCP_REGISTRY)
```

**Problème avec l'alternative** :

- ❌ Pas de garantie de compatibilité
- ❌ Si user fournit `modeler=ExaModeler()`, on pourrait choisir une méthode incompatible

**Recommandation** : ✅ **Garder la construction de description**. C'est nécessaire pour la compatibilité.

---

## Proposition : Architecture à 3 Modules

> **Note** : Cette architecture a été validée et documentée dans [13_module_dependencies_architecture.md](../reference/13_module_dependencies_architecture.md)

### Module 1: **Options**

**Responsabilité** : Gestion générique des options (valeurs, sources, validation, aliases)

```julia
module Options

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

# Generic option handling
function extract_option(kwargs, schema::OptionSchema)
    # Handle aliases
    for alias in (schema.name, schema.aliases...)
        if haskey(kwargs, alias)
            value = kwargs[alias]
            # Validate
            if schema.validator !== nothing
                schema.validator(value)
            end
            return OptionValue(value, :user), delete(kwargs, alias)
        end
    end
    return OptionValue(schema.default, :default), kwargs
end

end
```

---

### Module 2: **Strategies**

**Responsabilité** : Gestion des stratégies (registre, construction, contrat)

```julia
module Strategies

using ..Options

abstract type AbstractStrategy end

# Strategy contract (unchanged)
symbol(::Type{<:AbstractStrategy})::Symbol
metadata(::Type{<:AbstractStrategy})::StrategyMetadata
options(strategy::AbstractStrategy)::OptionSet

# Registry (unchanged)
struct StrategyRegistry
    families::Dict{Type{<:AbstractStrategy}, Vector{Type}}
end

create_registry(pairs...)
build_strategy(id, family, registry; kwargs...)
# ...

end
```

---

### Module 3: **Orchestration**

**Responsabilité** : Orchestration des actions, routing, construction de stratégies

> **⚠️ Concepts Abandonnés** : Les concepts `AbstractAction` et `dispatch_action()` générique ont été **abandonnés** après analyse approfondie.
>
> **Raison** : Comme expliqué dans [14_action_genericity_analysis.md](14_action_genericity_analysis.md), le dispatch multi-modes ne peut pas être complètement générique car :
>
> - Les signatures des modes diffèrent entre actions
> - Julia ne permet pas de dispatch sur le nombre d'arguments de manière générique
> - Chaque action doit gérer manuellement ses propres modes

**Architecture finale** :

```julia
module Orchestration

using ..Options
using ..Strategies

# Pas d'AbstractAction - chaque action gère ses propres modes

# Outils génériques pour le routing
function route_all_options(
    kwargs::NamedTuple,
    registry::StrategyRegistry
)::Tuple{NamedTuple, NamedTuple}
    # Sépare options d'action et options de stratégies
    # ...
end

function extract_action_options(
    kwargs::NamedTuple,
    registry::StrategyRegistry,
    action_option_schemas::Vector{OptionSchema}
)::NamedTuple
    # Extrait et valide les options d'action
    # ...
end

function build_strategies_from_method(
    description::Tuple{Vararg{Symbol}},
    kwargs::NamedTuple,
    registry::StrategyRegistry
)::Vector{AbstractStrategy}
    # Construit les stratégies depuis une description
    # ...
end

end
```

**Utilisation** : Chaque action (solve, describe, etc.) utilise ces outils mais gère son propre dispatch :

```julia
# Chaque action gère manuellement ses modes
function solve(ocp, description...; kwargs...)
    if has_explicit_strategies(kwargs)
        return _solve_explicit_mode(...)
    else
        return _solve_description_mode(...)
    end
end
```

Voir [solve_ideal.jl](../solve_ideal.jl) pour l'exemple complet.

---

## Modes d'Action - Clarification

### Mode 1: **Standard**

**Syntaxe** : `action(object, strategy1, strategy2, ...; action_options...)`

**Exemple** :

```julia
solve(ocp, discretizer, modeler, solver; initial_guess=ig, display=true)
```

**Caractéristiques** :

- Stratégies déjà construites
- Seulement options d'action en kwargs
- Pas de routing nécessaire

---

### Mode 2: **Description**

**Syntaxe** : `action(object, description...; strategy_options..., action_options...)`

**Exemple** :

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    grid_size=100,           # Strategy option (discretizer)
    backend=:sparse,         # Strategy option (modeler)
    max_iter=1000,           # Strategy option (solver)
    initial_guess=ig,        # Action option
    display=true             # Action option
)
```

**Caractéristiques** :

- Description partielle ou complète
- Mix d'options de stratégies et d'action
- **Routing nécessaire** pour séparer les options

---

### Mode 3: **Explicit**

**Syntaxe** : `action(object; strategy1=..., strategy2=..., action_options...)`

**Exemple** :

```julia
solve(ocp; 
    discretizer=CollocationDiscretizer(grid_size=100),
    modeler=ADNLPModeler(backend=:sparse),
    solver=IpoptSolver(max_iter=1000),
    initial_guess=ig,
    display=true
)
```

**Caractéristiques** :

- Stratégies fournies explicitement (instances ou nothing)
- Seulement options d'action en kwargs (pas d'options de stratégies)
- Stratégies manquantes complétées avec défauts

---

## Réponses aux Questions

### Q1: Signature de `_solve()`

**Réponse** : ✅ Changer pour :

```julia
function _solve(
    ocp, discretizer, modeler, solver; 
    initial_guess=nothing, 
    display=true
)
```

---

### Q2: Routing des Options

**Réponse** : ❌ **Incomplet actuellement**. Il faut :

1. Extraire les options d'action **avant** le routing
2. Router seulement les options de stratégies
3. Valider qu'il n'y a pas de conflit

**Code corrigé** :

```julia
function _solve_from_description(ocp, method, parsed)
    # parsed.other_kwargs contient SEULEMENT les options de stratégies
    # (initial_guess et display déjà extraits)
    
    routed = route_options(method, STRATEGY_FAMILIES, parsed.other_kwargs, OCP_REGISTRY)
    # ...
end
```

**C'est déjà correct !** Les options d'action sont extraites dans `_parse_kwargs()`.

---

### Q3: Aliases

**Réponse** : ⚠️ **Créer un module Options** pour le concept générique, mais les aliases spécifiques restent dans chaque action.

---

### Q4: Construction de Description

**Réponse** : ✅ **Nécessaire** pour garantir la compatibilité des stratégies.

---

## Architecture Finale Validée

> **Voir** : [13_module_dependencies_architecture.md](../reference/13_module_dependencies_architecture.md) pour l'architecture complète

```
CTModels/
├── src/
│   ├── options/
│   │   ├── option_value.jl
│   │   ├── option_schema.jl
│   │   └── extraction.jl
│   ├── strategies/
│   │   ├── abstract_strategy.jl
│   │   ├── metadata.jl
│   │   ├── registry.jl
│   │   └── builders.jl
│   └── orchestration/
│       ├── routing.jl
│       └── method_builders.jl
```

**Note** : Pas de module `actions/` générique - chaque action (solve, describe, etc.) gère ses propres modes manuellement.

---

## Statut des Questions

| Question | Statut | Résolution |
|----------|--------|------------|
| Q1: Signature `_solve()` | ✅ Résolu | Options d'action en kwargs |
| Q2: Routing | ✅ Résolu | Séparation dans Orchestration (doc 13) |
| Q3: Aliases | ✅ Résolu | Module Options générique (doc 13) |
| Q4: Construction description | ✅ Résolu | Nécessaire pour compatibilité |

## Documents Liés

- [13_module_dependencies_architecture.md](../reference/13_module_dependencies_architecture.md) - Architecture finale des 3 modules
- [14_action_genericity_analysis.md](14_action_genericity_analysis.md) - Analyse de la généricité des actions
- [11_explicit_registry_architecture.md](../reference/11_explicit_registry_architecture.md) - Architecture du registre explicite
- [solve_ideal.jl](../solve_ideal.jl) - Exemple complet avec les 3 modes
