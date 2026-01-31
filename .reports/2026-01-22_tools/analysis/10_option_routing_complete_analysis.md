# Option Routing System - Final Design (Breaking)

**Date**: 2026-01-22  
**Status**: ✅ **IMPLEMENTED** in Code Annexes

> [!IMPORTANT]
> This document describes the **breaking** design for option routing.
> Strategy-based disambiguation is the only supported syntax.
> Family-based disambiguation is deprecated.
>
> **Registry Approach**: This document uses **explicit registry** (passed as argument).
> See [11_explicit_registry_architecture.md](../reference/11_explicit_registry_architecture.md) for complete registry specification.

---

## TL;DR

**Fonctionnalités implémentées** :

- ✅ **Désambiguïsation par stratégies** : `backend = (:sparse, :adnlp)` au lieu de `(:sparse, :modeler)`
- ✅ **Support multi-stratégies** : `backend = ((:sparse, :adnlp), (:cpu, :ipopt))`
- ✅ **Messages d'erreur améliorés** : Montrent les stratégies disponibles et des exemples

**Implémentation** : Voir les annexes de code

- [disambiguation.jl](../reference/code/Orchestration/api/disambiguation.jl) - Fonctions helper
- [routing.jl](../reference/code/Orchestration/api/routing.jl) - Routing complet
- [README.md](../reference/code/Orchestration/README.md) - Documentation et exemples

**Changement breaking** : Syntaxe basée sur les IDs de stratégies (`:adnlp`) au lieu des noms de familles (`:modeler`)\

**Voir aussi** :

- [solve_ideal.jl](../reference/solve_ideal.jl) - Exemple d'utilisation
- [13_module_dependencies_architecture.md](../reference/13_module_dependencies_architecture.md) - Architecture globale

---

## Executive Summary

Le système de routing d'options d'OptimalControl supporte maintenant :

1. **Désambiguïsation par stratégies** : `key=(value, :strategy_id)` pour résoudre les ambiguïtés
2. **Modes source** : `:description` vs `:explicit` pour différents messages d'erreur
3. **Gestion multi-propriétaires** : Options appartenant à plusieurs familles
4. **Routing multi-stratégies** : Définir la même option avec différentes valeurs pour plusieurs stratégies

---

## Problèmes Identifiés (Ancien Système)

### 1. Noms de Familles vs IDs de Stratégies

**Problème** : L'ancien système utilisait des noms de familles (`:modeler`) au lieu d'IDs de stratégies (`:adnlp`)

**Ancien** :

```julia
solve(ocp, :collocation, :adnlp, :ipopt; backend = (:sparse, :modeler))
```

**Nouveau** :

```julia
solve(ocp, :collocation, :adnlp, :ipopt; backend = (:sparse, :adnlp))
```

**Avantages** :

- ✅ Cohérent avec les tuples de méthode
- ✅ Plus spécifique (utilise l'ID réel de la stratégie)
- ✅ Valide que la stratégie est dans la méthode

### 2. Pas de Support Multi-Stratégies

**Manquant** : Impossible de définir la même option pour plusieurs stratégies

**Maintenant supporté** :

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))
)
```

### 3. Messages d'Erreur Peu Clairs

**Ancien** : "Disambiguate it by writing backend = (value, :tool)"

**Nouveau** : Messages détaillés montrant les stratégies disponibles et des exemples concrets

---

## ✅ Améliorations Implémentées

> **Implémentation** : Voir [code/Orchestration/](../reference/code/Orchestration/) pour le code complet

### 1. Désambiguïsation par Stratégies ✅

**Fichier** : [disambiguation.jl](../reference/code/Orchestration/api/disambiguation.jl)

**Fonction clé** : `extract_strategy_ids(raw, method)`

- Extrait les IDs de stratégies depuis la syntaxe de désambiguïsation
- Supporte single: `(value, :id)` et multiple: `((v1, :id1), (v2, :id2))`
- Valide que les IDs sont dans la méthode

**Exemple** :

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = (:sparse, :adnlp)  # Route to :adnlp strategy
)
```

### 2. Support Multi-Stratégies ✅

**Fichier** : [routing.jl](../reference/code/Orchestration/api/routing.jl)

**Fonctionnalité** : `route_all_options()` supporte le routing multi-stratégies

- Détecte automatiquement la syntaxe multi-stratégies
- Route chaque paire (value, id) à la famille correspondante
- Valide que chaque famille possède bien l'option

**Exemple** :

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))  # Set for both
)
```

### 3. Messages d'Erreur Améliorés ✅

**Fichier** : [routing.jl](../reference/code/Orchestration/api/routing.jl)

**Fonctions** : `_error_unknown_option()` et `_error_ambiguous_option()`

**Option inconnue** :

```
Error: Option :unknown_key doesn't belong to any strategy in method (:collocation, :adnlp, :ipopt).

Available options:
  discretizer (:collocation): grid_size, scheme
  modeler (:adnlp): backend, show_time
  solver (:ipopt): max_iter, tol, print_level
```

**Option ambiguë** :

```
Error: Option :backend is ambiguous between strategies: :adnlp, :ipopt.

Disambiguate by specifying the strategy ID:
  backend = (:sparse, :adnlp)    # Route to modeler
  backend = (:cpu, :ipopt)       # Route to solver

Or set for multiple strategies:
  backend = ((:sparse, :adnlp), (:cpu, :ipopt))
```

---

## Syntaxe de Désambiguïsation

### 1. Auto-Routing (Non Ambigu)

**Syntaxe** : `key = value`

**Quand** : L'option appartient à exactement UNE stratégie

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    grid_size = 100  # Only discretizer → auto-route
)
```

### 2. Désambiguïsation Simple

**Syntaxe** : `key = (value, :strategy_id)`

**Quand** : L'option appartient à PLUSIEURS stratégies, l'utilisateur en choisit une

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = (:sparse, :adnlp)  # Both modeler and solver have backend → disambiguate
)
```

### 3. Routing Multi-Stratégies

**Syntaxe** : `key = ((value1, :id1), (value2, :id2), ...)`

**Quand** : L'utilisateur veut définir la MÊME option avec des VALEURS DIFFÉRENTES pour PLUSIEURS stratégies

```julia
solve(ocp, :collocation, :adnlp, :ipopt; 
    backend = ((:sparse, :adnlp), (:cpu, :ipopt))  # Set backend for both
)
```

---

## Algorithme de Routing

### Étapes

1. **Extraire les options d'action** (en premier)
2. **Construire les mappings** :
   - Strategy ID → Family name
   - Option name → Set{Family name}
3. **Router chaque option** :
   - Si désambiguïsée : valider et router vers les stratégies spécifiées
   - Sinon : auto-router si non ambigu, erreur si ambigu
4. **Retourner** les options d'action et les options de stratégies routées

### Implémentation

Voir [routing.jl](../reference/code/Orchestration/api/routing.jl) pour l'implémentation complète de `route_all_options()`.

---

## Impact de Migration

### Changement Breaking

**Ancien** (basé sur familles) :

```julia
solve(ocp, :collocation, :adnlp, :ipopt; backend = (:sparse, :modeler))
```

**Nouveau** (basé sur stratégies) :

```julia
solve(ocp, :collocation, :adnlp, :ipopt; backend = (:sparse, :adnlp))
```

### Bénéfices

1. ✅ **Cohérence** : Utilise les mêmes IDs que les tuples de méthode
2. ✅ **Flexibilité** : Support multi-stratégies pour les cas avancés
3. ✅ **Clarté** : Meilleurs messages d'erreur avec les IDs de stratégies
4. ✅ **Robustesse** : Valide les IDs de stratégies contre la méthode

---

## Références

### Code Annexes

- [disambiguation.jl](../reference/code/Orchestration/api/disambiguation.jl) - Fonctions helper pour désambiguïsation
- [routing.jl](../reference/code/Orchestration/api/routing.jl) - Fonction complète de routing
- [README.md](../reference/code/Orchestration/README.md) - Documentation et exemples

### Documentation

- [solve_ideal.jl](../reference/solve_ideal.jl) - Exemple d'utilisation complète
- [13_module_dependencies_architecture.md](../reference/13_module_dependencies_architecture.md) - Architecture des 3 modules
- [11_explicit_registry_architecture.md](../reference/11_explicit_registry_architecture.md) - Architecture du registre

### Documents Connexes

- [12_action_pattern_analysis.md](12_action_pattern_analysis.md) - Analyse des patterns d'action
- [14_action_genericity_analysis.md](14_action_genericity_analysis.md) - Analyse de la généricité

---

## Résumé

**Fonctionnalités implémentées** :

- ✅ Désambiguïsation par stratégies (`:adnlp` au lieu de `:modeler`)
- ✅ Support multi-stratégies (`((v1, :id1), (v2, :id2))`)
- ✅ Messages d'erreur améliorés avec exemples

**Changement breaking** : Syntaxe de désambiguïsation basée sur les IDs de stratégies

**Implémentation** : Code complet dans [code/Orchestration/](../reference/code/Orchestration/)
