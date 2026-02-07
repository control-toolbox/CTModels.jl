# Audit des Oublis de Migration d'Exceptions

**Date**: 2026-01-30
**Statut**: 🔍 Audit Complété
**Source**: `reports/2026-01-30_Exceptions/find_unmigrated_errors.sh`

Ce document recense les exceptions qui utilisent encore l'ancien système (`CTBase.IncorrectArgument`, `CTBase.UnauthorizedCall`, `CTBase.NotImplemented`) et qui n'ont pas encore été migrées vers les exceptions enrichies de `CTModels`.

## 📊 Résumé Quantitatif

| Type d'Exception | Occurrences | Statut |
|------------------|-------------|--------|
| `IncorrectArgument` | **45** | ❌ À migrer |
| `UnauthorizedCall` | **64** | ❌ À migrer |
| `NotImplemented` | **25** | ❌ À migrer |
| `error()` génériques | **6** | ❌ À migrer |
| **TOTAL** | **140** | |

## 🔍 Analyse des Définitions d'Exceptions Actuelles

### `NotImplemented` (Insuffisant)

- **État actuel** : Champs `msg` et `type_info`.
- **Manque** : Pas de `suggestion` (comment résoudre ?) ni de `context` (où ?).
- **Problème** : Moins riche que `IncorrectArgument`. Impossible de suggérer "Please import package X" de manière structurée.

### `ParsingError` (Insuffisant)

- **État actuel** : Champs `msg` et `location`.
- **Manque** : Pas de `suggestion`.
- **Problème** : Ne peut pas suggérer la correction de syntaxe.

---

## 🔴 Priorité Haute : Composants OCP

### `src/OCP/Components/constraints.jl`

- **17 erreurs totales** (dont 6 `UnauthorizedCall` explicites)
- **Problème** : Mélange code migré/non-migré.
- **Détails** : `UnauthorizedCall` pour state/control/variable non définis.

### `src/OCP/Components/dynamics.jl`

- **11 erreurs** (`UnauthorizedCall`)
- **Problème** : Vérification d'ordre d'appels (`__is_state_set`, etc.)

### Autres Composants

- `objective.jl`: ~8 erreurs
- `variable.jl`: ~5 erreurs
- `control.jl`, `state.jl`, `times.jl`: ~2-3 erreurs chacun

## 🟠 Priorité Moyenne : Stratégies et Orchestration

### `src/Orchestration/`

- `routing.jl`: 5 erreurs
- `disambiguation.jl`: 3 erreurs
- `method_builders.jl`: 2 erreurs

### `src/Strategies/`

- `api/validation.jl`: ~14 erreurs (mélange `IncorrectArgument`/`NotImplemented`)
- `api/registry.jl`: 7 erreurs
- `contract/abstract_strategy.jl`: 4 erreurs (`NotImplemented`)

## 🟡 Priorité Basse : Support et Legacy

### Optimisation

- `src/Optimization/contract.jl`: 6 erreurs (`NotImplemented`)

### Divers

- `exceptions/display.jl`: 6 erreurs génériques (probablement légitimes/internes, à vérifier)
- `serialization/export_import.jl`: 2 erreurs

---

## 🔗 Références

- Script de génération : [find_unmigrated_errors.sh](find_unmigrated_errors.sh)
