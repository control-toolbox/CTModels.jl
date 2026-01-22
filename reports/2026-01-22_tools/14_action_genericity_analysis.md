# Action Concept - Clarification et Généricité

**Date**: 2026-01-22  
**Status**: Architecture Analysis - Questioning Genericity

---

## Question Centrale

**Peut-on vraiment faire un dispatch multi-mode générique pour les actions ?**

---

## Analyse de solve_ideal.jl

### Constat

Tu as raison : `solve_ideal.jl` **n'utilise PAS** de dispatch générique. Il a :

```julia
function CommonSolve.solve(ocp, description...; kwargs...)
    # Détection de mode manuelle
    has_strategy_kwargs = any(k in keys(kwargs) for k in (:discretizer, :d, ...))
    
    if has_strategy_kwargs && !isempty(description)
        error(...)
    end
    
    if has_strategy_kwargs
        return _solve_explicit_mode(ocp, (; kwargs...))
    else
        return _solve_description_mode(ocp, description, (; kwargs...))
    end
end
```

**C'est du dispatch manuel**, pas générique.

---

## Pourquoi c'est Confus

### Problème 1: Signatures Incompatibles

Les 3 modes ont des **signatures fondamentalement différentes** :

```julia
# Mode 1: Standard
solve(ocp::OCP, disc::Disc, mod::Mod, sol::Sol; initial_guess, display)

# Mode 2: Description  
solve(ocp::OCP, description::Symbol...; strategy_options..., action_options...)

# Mode 3: Explicit
solve(ocp::OCP; discretizer=..., modeler=..., solver=..., action_options...)
```

**Question** : Comment dispatcher automatiquement entre ces 3 signatures ?

### Problème 2: Multiple Dispatch de Julia

Julia dispatche sur les **types** des arguments, pas sur leur **présence/absence** ou leurs **noms**.

```julia
# Julia peut dispatcher sur ça:
solve(ocp::OCP, disc::Disc, mod::Mod, sol::Sol; kwargs...)  # Mode 1
solve(ocp::OCP, description::Symbol...; kwargs...)           # Mode 2

# Mais Mode 2 et Mode 3 ont la MÊME signature pour Julia:
solve(ocp::OCP; kwargs...)  # Mode 2 avec description vide
solve(ocp::OCP; kwargs...)  # Mode 3 avec stratégies en kwargs
```

**Impossible de dispatcher automatiquement** entre Mode 2 et Mode 3.

---

## Options de Design

### Option A: Pas de Dispatch Générique (Actuel)

**Approche** : Chaque action implémente manuellement ses modes.

```julia
function CommonSolve.solve(ocp, description...; kwargs...)
    # Détection manuelle
    if has_explicit_strategies(kwargs)
        return _solve_explicit_mode(...)
    else
        return _solve_description_mode(...)
    end
end
```

**Avantages** :
- ✅ Flexible
- ✅ Clair pour chaque action spécifique
- ✅ Pas de magie

**Inconvénients** :
- ❌ Code répétitif entre actions
- ❌ Pas de réutilisation

---

### Option B: Dispatch Générique Partiel

**Approche** : Dispatcher ce qui est possible, déléguer le reste.

```julia
# Dispatch automatique pour Mode 1 (Standard)
function solve(ocp::OCP, disc::Disc, mod::Mod, sol::Sol; kwargs...)
    action_opts = extract_action_options(kwargs, SOLVE_ACTION_OPTIONS)
    return _solve_core(ocp, disc, mod, sol; action_opts...)
end

# Dispatch manuel pour Mode 2 et 3
function solve(ocp::OCP, description::Symbol...; kwargs...)
    if has_explicit_strategies(kwargs)
        return _solve_explicit_mode(ocp, kwargs)
    else
        return _solve_description_mode(ocp, description, kwargs)
    end
end
```

**Avantages** :
- ✅ Mode Standard est propre (dispatch Julia natif)
- ✅ Mode 2/3 restent flexibles

**Inconvénients** :
- ⚠️ Toujours du code manuel pour Mode 2/3

---

### Option C: Fonctions Séparées

**Approche** : Abandonner l'idée de 3 modes dans une seule fonction.

```julia
# Mode 1: Standard (dispatch Julia)
solve(ocp, discretizer, modeler, solver; initial_guess, display)

# Mode 2: Description (fonction dédiée)
solve_with_description(ocp, description...; strategy_options..., action_options...)

# Mode 3: Explicit (fonction dédiée)
solve_with_strategies(ocp; discretizer=..., modeler=..., action_options...)
```

**Avantages** :
- ✅ Très clair
- ✅ Pas d'ambiguïté
- ✅ Chaque fonction a une responsabilité unique

**Inconvénients** :
- ❌ Perd l'API unifiée `solve()`
- ❌ Utilisateur doit choisir la bonne fonction

---

### Option D: Macro pour Générer les Modes

**Approche** : Utiliser une macro pour générer le boilerplate.

```julia
@action solve OCP begin
    strategies = (
        discretizer = AbstractOptimalControlDiscretizer,
        modeler = AbstractOptimizationModeler,
        solver = AbstractOptimizationSolver,
    )
    
    action_options = [
        OptionSchema(:initial_guess, Any, nothing, (:init, :i), nothing),
        OptionSchema(:display, Bool, true, (), nothing),
    ]
    
    core_function = _solve_core
    registry = OCP_REGISTRY
    available_methods = AVAILABLE_METHODS
end

# Génère automatiquement:
# - solve(ocp, disc, mod, sol; kwargs...)  # Mode 1
# - solve(ocp, description...; kwargs...)   # Mode 2/3 avec détection
```

**Avantages** :
- ✅ Réutilisable
- ✅ Déclaratif
- ✅ Moins de boilerplate

**Inconvénients** :
- ❌ Magie (moins transparent)
- ❌ Complexité de la macro
- ⚠️ Toujours du dispatch manuel pour Mode 2/3

---

## Recommandation

### Ce qui est Vraiment Générique

**Seulement le routing** :

```julia
# Ceci peut être générique dans Orchestration module:
function route_all_options(
    method, families, action_schemas, kwargs, registry
)
    # 1. Extract action options
    # 2. Route to strategies
    # 3. Return (action=..., strategies=...)
end
```

### Ce qui ne Peut Pas Être Générique

**Le dispatch entre modes** :

Chaque action doit implémenter :
```julia
function solve(ocp, description...; kwargs...)
    # Détection de mode (spécifique à solve)
    if has_explicit_strategies(kwargs)
        return _solve_explicit_mode(...)
    else
        return _solve_description_mode(...)
    end
end
```

**Pourquoi** : La détection de mode dépend de :
- Quels kwargs indiquent le mode explicit (`:discretizer`, `:modeler`, `:solver` pour solve)
- Quelles sont les stratégies de cette action
- Logique métier spécifique

---

## Proposition Finale : Hybrid Approach

### Générique (dans Orchestration module)

```julia
module Orchestration

# Generic routing (réutilisable)
function route_all_options(method, families, action_schemas, kwargs, registry)
    # ...
end

# Generic helpers
function extract_action_options(kwargs, schemas)
    # ...
end

function build_strategies_from_method(method, families, routed_options, registry)
    # ...
end

end
```

### Spécifique (dans chaque action)

```julia
# Dans OptimalControl.jl

function CommonSolve.solve(ocp, description...; kwargs...)
    # Détection de mode (spécifique)
    mode = detect_solve_mode(description, kwargs)
    
    if mode === :standard
        # Impossible ici, dispatch Julia gère ça
    elseif mode === :description
        return _solve_description_mode(ocp, description, kwargs)
    elseif mode === :explicit
        return _solve_explicit_mode(ocp, kwargs)
    end
end

function CommonSolve.solve(
    ocp::OCP,
    discretizer::Disc,
    modeler::Mod,
    solver::Sol;
    kwargs...
)
    # Mode standard (dispatch Julia)
    action_opts = Orchestration.extract_action_options(kwargs, SOLVE_ACTION_OPTIONS)
    return _solve_core(ocp, discretizer, modeler, solver; action_opts...)
end

function detect_solve_mode(description, kwargs)
    has_strategies = any(k in keys(kwargs) for k in (:discretizer, :modeler, :solver, :d, :m, :s))
    
    if has_strategies && !isempty(description)
        error("Cannot mix explicit strategies with description")
    end
    
    return has_strategies ? :explicit : :description
end
```

---

## Réponse à ta Question

### Peut-on faire un dispatch générique ?

**Non, pas vraiment.**

**Ce qui est générique** :
- ✅ Routing des options (`route_all_options`)
- ✅ Construction des stratégies (`build_strategies_from_method`)
- ✅ Extraction des options d'action (`extract_action_options`)

**Ce qui ne l'est pas** :
- ❌ Dispatch entre modes (dépend de chaque action)
- ❌ Détection de mode (spécifique aux kwargs de chaque action)
- ❌ Logique métier de l'action

### Conclusion

**Le module Orchestration fournit des outils génériques**, mais chaque action doit :
1. Implémenter ses propres fonctions de mode
2. Détecter le mode manuellement
3. Appeler les outils génériques pour le routing

**C'est un compromis** : on réutilise ce qui peut l'être (routing), mais on garde la flexibilité pour ce qui est spécifique (dispatch).

---

## Mise à Jour de solve_ideal.jl

Il faut clarifier que `solve_ideal.jl` montre :
- ✅ Comment **utiliser** les outils génériques d'Orchestration
- ❌ Mais **pas** un dispatch automatique magique

Le dispatch reste **manuel** et **spécifique** à solve.
