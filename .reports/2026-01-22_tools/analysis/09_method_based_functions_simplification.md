# Method-Based Functions - Simplification Analysis

**Date**: 2026-01-22  
**Status**: ✅ **IMPLEMENTED** in Code Annexes

---

## TL;DR

**Fonctions implémentées** :

- ✅ `extract_id_from_method()` - Extrait l'ID d'une famille depuis un tuple de méthode
- ✅ `option_names_from_method()` - Obtient les noms d'options depuis un tuple de méthode
- ✅ `build_strategy_from_method()` - Construit une stratégie depuis un tuple de méthode

**Implémentation** : Voir [`code/Strategies/api/builders.jl`](../reference/code/Strategies/api/builders.jl)

**Routing avancé** : La fonction `route_options_to_families()` proposée a été remplacée par [`route_all_options()`](../reference/code/Orchestration/api/routing.jl) qui supporte :

- Désambiguïsation par stratégies
- Support multi-stratégies
- Séparation des options d'action

**Bénéfice** : ~150-180 lignes de boilerplate supprimées d'OptimalControl.jl

---

## Executive Summary

OptimalControl.jl contient de nombreuses fonctions helper qui opèrent sur des tuples de "méthode" (e.g., `(:collocation, :adnlp, :ipopt)`). Ces fonctions ont été **généralisées et déplacées** vers le module Strategies, réduisant le boilerplate dans OptimalControl.

**Résultat** : ~200 lignes de code OptimalControl remplacées par ~50 lignes utilisant les fonctions génériques de Strategies.

---

## ✅ Fonctions Implémentées

> **Implémentation** : Voir [`code/Strategies/api/builders.jl`](../reference/code/Strategies/api/builders.jl)

### 1. `extract_id_from_method()` ✅

**Fichier** : [builders.jl](../reference/code/Strategies/api/builders.jl) (lignes 36-57)

**Signature** :

```julia
extract_id_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry
) -> Symbol
```

**Exemple** :

```julia
method = (:collocation, :adnlp, :ipopt)
id = extract_id_from_method(method, AbstractOptimizationModeler, registry)
# => :adnlp
```

**Remplace** :

- `_get_discretizer_symbol(method)`
- `_get_modeler_symbol(method)`
- `_get_solver_symbol(method)`

---

### 2. `option_names_from_method()` ✅

**Fichier** : [builders.jl](../reference/code/Strategies/api/builders.jl) (lignes 71-79)

**Signature** :

```julia
option_names_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry
) -> Tuple{Vararg{Symbol}}
```

**Exemple** :

```julia
method = (:collocation, :adnlp, :ipopt)
keys = option_names_from_method(method, AbstractOptimizationModeler, registry)
# => (:backend, :show_time)
```

**Remplace** :

- `_discretizer_options_keys(method)`
- `_modeler_options_keys(method)`
- `_solver_options_keys(method)`

---

### 3. `build_strategy_from_method()` ✅

**Fichier** : [builders.jl](../reference/code/Strategies/api/builders.jl) (lignes 93-101)

**Signature** :

```julia
build_strategy_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry;
    kwargs...
) -> AbstractStrategy
```

**Exemple** :

```julia
method = (:collocation, :adnlp, :ipopt)
modeler = build_strategy_from_method(
    method, 
    AbstractOptimizationModeler, 
    registry; 
    backend=:sparse
)
# => ADNLPModeler(backend=:sparse)
```

**Remplace** :

- `_build_discretizer_from_method(method, options)`
- `_build_modeler_from_method(method, options)`
- `_build_solver_from_method(method, options)`

---

## ⚠️ Routing Avancé : Fonction Remplacée

### Proposition Originale : `route_options_to_families()`

**Proposée dans ce document** (lignes 269-339) : Fonction simple de routing d'options

**Remplacée par** : [`route_all_options()`](../reference/code/Orchestration/api/routing.jl)

**Pourquoi remplacée** :

- ❌ Version originale ne gérait pas la désambiguïsation
- ❌ Version originale ne séparait pas les options d'action
- ❌ Version originale ne supportait pas le multi-stratégies

**Version finale** : `route_all_options()` supporte :

- ✅ Désambiguïsation par stratégies : `backend = (:sparse, :adnlp)`
- ✅ Multi-stratégies : `backend = ((:sparse, :adnlp), (:cpu, :ipopt))`
- ✅ Séparation action/stratégies
- ✅ Messages d'erreur améliorés

**Voir** : [10_option_routing_complete_analysis.md](10_option_routing_complete_analysis.md) pour les détails

---

## Utilisation dans OptimalControl.jl

### Avant (~200 lignes)

```julia
# 3 × _get_*_symbol functions
# 3 × _*_options_keys functions
# 3 × _build_*_from_method functions
# + _get_unique_symbol helper
# + Complex routing logic
```

### Après (~50 lignes)

```julia
using CTModels.Strategies: extract_id_from_method, option_names_from_method, build_strategy_from_method
using CTModels.Orchestration: route_all_options

# Define family mapping (once)
const STRATEGY_FAMILIES = (
    discretizer = AbstractOptimalControlDiscretizer,
    modeler = AbstractOptimizationModeler,
    solver = AbstractOptimizationSolver,
)

# Building strategies (simplified)
function _solve_from_description(ocp, method, kwargs)
    # Route options with disambiguation support
    routed = route_all_options(
        method, 
        STRATEGY_FAMILIES, 
        ACTION_SCHEMAS,
        kwargs, 
        OCP_REGISTRY;
        source_mode=:description
    )
    
    # Build strategies
    discretizer = build_strategy_from_method(
        method, STRATEGY_FAMILIES.discretizer, OCP_REGISTRY;
        routed.strategies.discretizer...
    )
    modeler = build_strategy_from_method(
        method, STRATEGY_FAMILIES.modeler, OCP_REGISTRY;
        routed.strategies.modeler...
    )
    solver = build_strategy_from_method(
        method, STRATEGY_FAMILIES.solver, OCP_REGISTRY;
        routed.strategies.solver...
    )
    
    # Solve
    return _solve(ocp, discretizer, modeler, solver; routed.action...)
end
```

**Réduction** : ~150-180 lignes supprimées

---

## Bénéfices

### 1. Moins de Boilerplate

**Avant** : ~200 lignes de fonctions helper  
**Après** : ~20-50 lignes

### 2. Réutilisable

Tout projet utilisant le système de registration Strategies peut utiliser ces helpers.

### 3. Messages d'Erreur Cohérents

Tous les messages d'erreur viennent du module Strategies, assurant la cohérence.

### 4. Plus Facile à Tester

Les fonctions génériques dans Strategies peuvent être testées indépendamment.

---

## Différences avec la Proposition Originale

| Aspect | Proposition Doc 09 | Implémentation Finale |
|--------|-------------------|----------------------|
| Registre | Implicite (global) | ✅ **Explicite** (paramètre) |
| Routing | Simple | ✅ **Avancé** (désambiguïsation) |
| Options d'action | Non séparées | ✅ **Séparées** |
| Multi-stratégies | Non supporté | ✅ **Supporté** |

---

## Références

### Code Annexes

- [builders.jl](../reference/code/Strategies/api/builders.jl) - Fonctions method-based implémentées
- [routing.jl](../reference/code/Orchestration/api/routing.jl) - Routing avancé avec désambiguïsation
- [disambiguation.jl](../reference/code/Orchestration/api/disambiguation.jl) - Helpers de désambiguïsation

### Documentation

- [solve_ideal.jl](../reference/solve_ideal.jl) - Exemple d'utilisation complète
- [10_option_routing_complete_analysis.md](10_option_routing_complete_analysis.md) - Analyse du routing
- [11_explicit_registry_architecture.md](../reference/11_explicit_registry_architecture.md) - Architecture du registre

---

## Résumé

**Fonctions implémentées** :

- ✅ `extract_id_from_method()` - Dans `builders.jl`
- ✅ `option_names_from_method()` - Dans `builders.jl`
- ✅ `build_strategy_from_method()` - Dans `builders.jl`
- ✅ `route_all_options()` - Dans `routing.jl` (version améliorée)

**Résultat** : ~150-180 lignes de boilerplate supprimées d'OptimalControl.jl, meilleure séparation des responsabilités.
