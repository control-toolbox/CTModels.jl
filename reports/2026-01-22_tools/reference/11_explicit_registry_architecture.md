# Explicit Registry Architecture - Final Design

**Date**: 2026-01-22  
**Status**: Final - Architecture Decision

> [!IMPORTANT]
> **Major Architecture Decision**: Use **explicit registry** instead of global mutable state.
> Registry is created once and passed explicitly to functions that need it.

---

## TL;DR

**Décision clé** : Registre **explicite** (passé en argument) au lieu de registre global mutable

**Avantages** :

- ✅ Dépendances explicites
- ✅ Testabilité (registres multiples)
- ✅ Thread-safe (pas d'état partagé)
- ✅ Pas d'effets de bord

**Impact** : Toutes les fonctions du module Strategies prennent `registry` en paramètre

**Implémentation** : Voir les annexes de code

- [registry.jl](code/Strategies/api/registry.jl) - Structure et création du registre
- [builders.jl](code/Strategies/api/builders.jl) - Fonctions de construction

**Voir aussi** :

- [13_module_dependencies_architecture.md](13_module_dependencies_architecture.md) - Architecture des 3 modules
- [08_complete_contract_specification.md](08_complete_contract_specification.md) - Contrat des stratégies

---

## Decision: Explicit Registry Passing

### Rationale

**Chosen**: Explicit registry (passed as argument)  
**Rejected**: Global mutable registry

**Why**:

- ✅ **Explicit dependencies**: Clear which functions need the registry
- ✅ **Testability**: Easy to create different registries for testing
- ✅ **No side-effects**: Pure functions, no global mutable state
- ✅ **Thread-safe**: No shared mutable state
- ✅ **Composability**: Can have multiple registries for different contexts

**Trade-offs**:

- ⚠️ More verbose (must pass registry to functions)
- ⚠️ Registry must be stored somewhere (module constant)

---

## Registry Structure

### Type Definition

**Type** : `StrategyRegistry`

**Champs** :

- `families::Dict{Type{<:AbstractStrategy}, Vector{Type}}` - Mapping famille → types de stratégies

### Creation Function

**Fonction** : `create_registry(pairs...)`

**Fonctionnalités** :

- Crée un registre depuis des paires `famille => (stratégies...)`
- Valide l'unicité des IDs dans chaque famille
- Valide que toutes les stratégies sont des sous-types de leur famille

**Exemple** :

```julia
registry = create_registry(
    AbstractOptimizationModeler => (ADNLPModeler, ExaModeler),
    AbstractOptimizationSolver => (IpoptSolver, MadNLPSolver)
)
```

> **Implémentation détaillée** : Voir [code/Strategies/api/registry.jl](code/Strategies/api/registry.jl)

---

## Functions Updated with Registry Parameter

Toutes les fonctions du module Strategies prennent maintenant le registre en paramètre explicite.

### Fonctions de Registre

**Fichier** : [code/Strategies/api/registry.jl](code/Strategies/api/registry.jl)

| Fonction | Signature | Description |
|----------|-----------|-------------|
| `strategy_ids()` | `(family, registry)` | Obtient tous les IDs d'une famille |
| `type_from_id()` | `(id, family, registry)` | Trouve le type depuis un ID |

### Fonctions de Construction

**Fichier** : [code/Strategies/api/builders.jl](code/Strategies/api/builders.jl)

| Fonction | Signature | Description |
|----------|-----------|-------------|
| `build_strategy()` | `(id, family, registry; kwargs...)` | Construit une stratégie depuis un ID |
| `extract_id_from_method()` | `(method, family, registry)` | Extrait l'ID d'une famille depuis une méthode |
| `option_names_from_method()` | `(method, family, registry)` | Obtient les noms d'options depuis une méthode |
| `build_strategy_from_method()` | `(method, family, registry; kwargs...)` | Construit depuis une méthode |

### Fonction de Routing (Orchestration)

**Fichier** : [code/Orchestration/api/routing.jl](code/Orchestration/api/routing.jl)

**Fonction utilisée** : `route_all_options(method, families, action_schemas, kwargs, registry)`

**Ce qu'elle fait** :

1. Extrait les options d'action EN PREMIER (avec `action_schemas`)
2. Route le reste aux stratégies
3. Retourne `(action=..., strategies=...)`

**Exemple d'utilisation** : Voir [solve_ideal.jl](solve_ideal.jl) ligne 205

> **Note** : La fonction `route_options()` mentionnée dans les versions antérieures de ce document a été remplacée par `route_all_options()` qui est plus claire et sépare explicitement les options d'action des options de stratégies.

---

## Usage in OptimalControl.jl

### Create Registry Once

```julia
# In OptimalControl.jl module initialization

const OCP_REGISTRY = create_registry(
    CTDirect.AbstractOptimalControlDiscretizer => (CTDirect.CollocationDiscretizer,),
    CTModels.AbstractOptimizationModeler => (CTModels.ADNLPModeler, CTModels.ExaModeler),
    CTSolvers.AbstractOptimizationSolver => (
        CTSolvers.IpoptSolver,
        CTSolvers.MadNLPSolver,
        CTSolvers.KnitroSolver,
        CTSolvers.MadNCLSolver
    ),
)
```

### Pass to Functions

```julia
function _solve_from_description(ocp, method, parsed)
    # Pass registry explicitly
    routed = route_options(
        method,
        STRATEGY_FAMILIES,
        parsed.other_kwargs,
        OCP_REGISTRY;  # ← Explicit registry
        source_mode=:description
    )
    
    # Pass registry explicitly
    discretizer = build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.discretizer,
        OCP_REGISTRY;  # ← Explicit registry
        routed.discretizer...
    )
    
    modeler = build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.modeler,
        OCP_REGISTRY;  # ← Explicit registry
        routed.modeler...
    )
    
    solver = build_strategy_from_method(
        method,
        STRATEGY_FAMILIES.solver,
        OCP_REGISTRY;  # ← Explicit registry
        routed.solver...
    )
    
    # ... solve
end
```

---

## Impact on Strategies Module

### What Changes

**File**: `src/strategies/registration.jl`

**Remove**:

- ❌ `GLOBAL_REGISTRY` constant
- ❌ `register_family!()` function
- ❌ `get_strategies_for_family()` function

**Add**:

- ✅ `StrategyRegistry` struct
- ✅ `create_registry()` function

**Update** (add `registry` parameter):

- ✅ `strategy_ids(family, registry)`
- ✅ `type_from_id(id, family, registry)`
- ✅ `build_strategy(id, family, registry; kwargs...)`
- ✅ `extract_id_from_method(method, family, registry)`
- ✅ `option_names_from_method(method, family, registry)`
- ✅ `build_strategy_from_method(method, family, registry; kwargs...)`
- ✅ `route_options(method, families, kwargs, registry; source_mode)`

---

## Impact on OptimalControl.jl

### What Changes

**Lines changed**: ~7 locations where registry is passed

**Before**:

```julia
routed = route_options(method, STRATEGY_FAMILIES, kwargs)
```

**After**:

```julia
routed = route_options(method, STRATEGY_FAMILIES, kwargs, OCP_REGISTRY)
```

**Net change**: +1 argument per call, +5 lines for registry creation

---

## Benefits Summary

1. ✅ **Explicit dependencies**: Functions clearly declare they need the registry
2. ✅ **Testability**: Easy to create test registries with different strategies
3. ✅ **No global state**: Pure functions, easier to reason about
4. ✅ **Thread-safe**: No shared mutable state
5. ✅ **Flexibility**: Can have multiple registries (e.g., for different problem types)

---

## Migration Checklist

- [ ] Update `src/strategies/registration.jl`:
  - [ ] Add `StrategyRegistry` struct
  - [ ] Add `create_registry()` function
  - [ ] Remove `GLOBAL_REGISTRY`
  - [ ] Remove `register_family!()`
  - [ ] Add `registry` parameter to all functions

- [ ] Update documentation:
  - [ ] `07_registration_final_design.md`
  - [ ] `09_method_based_functions_simplification.md`
  - [ ] `10_option_routing_complete_analysis.md`

- [ ] Update `solve_simplified.jl`:
  - [ ] Replace `register_family!()` calls with `create_registry()`
  - [ ] Pass `OCP_REGISTRY` to all functions

- [ ] Update `implementation_plan.md` with explicit registry approach
