# Module Dependencies and Routing Architecture

**Date**: 2026-01-22  
**Status**: Architecture Design - Module Boundaries

---

## TL;DR

**Architecture** : 3 modules avec dépendances unidirectionnelles

```
Options (outils) → Strategies (stratégies) → Orchestration (coordination)
```

**Principe clé** : Options ne fait PAS le routing. Orchestration orchestre tout en utilisant les outils d'Options et Strategies.

**Responsabilités** :

- **Options** : Extraction, validation, aliases (aucune dépendance)
- **Strategies** : Registre, construction, métadonnées (dépend d'Options)
- **Orchestration** : Routing, coordination, modes (dépend d'Options + Strategies)

**Pour commencer** :

1. Lire cette architecture (13)
2. Voir le registre (11)
3. Voir le contrat (08)
4. Voir l'exemple (solve_ideal.jl)

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

**Fonctionnalités clés** :

- Extraction d'options avec gestion des aliases
- Validation des valeurs
- Traçabilité de la source (défaut, utilisateur, calculé)
- **Aucune connaissance** des stratégies ou de l'orchestration

**Types principaux** :

- `OptionValue{T}` : Valeur d'option avec source
- `OptionSchema` : Schéma de définition d'option (nom, type, défaut, aliases, validateur)

**API publique** :

- `extract_option(kwargs, schema)` : Extrait une option avec gestion des aliases
- `extract_options(kwargs, schemas)` : Extrait plusieurs options

> **Implémentation détaillée** : Voir les annexes de code
>
> - [option_value.jl](code/Options/contract/option_value.jl) - Type `OptionValue`
> - [option_schema.jl](code/Options/contract/option_schema.jl) - Type `OptionSchema`
> - [extraction.jl](code/Options/api/extraction.jl) - Fonctions d'extraction

**Clé** : Options ne sait RIEN sur les stratégies. Il fournit juste des outils.

---

### Module 2: **Strategies** (Dépend de Options)

**Responsabilité** : Gestion des stratégies, registre, construction

**Fonctionnalités clés** :

- Définition du contrat `AbstractStrategy`
- Registre explicite des stratégies
- Construction de stratégies à partir de descriptions
- Métadonnées (noms d'options, descriptions)
- **Utilise** Options pour gérer les options des stratégies

**Types principaux** :

- `AbstractStrategy` : Type abstrait pour toutes les stratégies
- `StrategyRegistry` : Registre explicite des stratégies
- `StrategyMetadata` : Métadonnées des stratégies

**API publique** :

- `create_registry(pairs...)` : Crée un registre
- `build_strategy(name, kwargs, registry)` : Construit une stratégie
- `build_strategy_from_method(name, kwargs, registry)` : Construit depuis une méthode
- `option_names_from_method(name, registry)` : Obtient les noms d'options

> **Implémentation détaillée** : Voir les annexes de code
>
> - [abstract_strategy.jl](code/Strategies/contract/abstract_strategy.jl) - Contrat `AbstractStrategy`
> - [metadata.jl](code/Strategies/contract/metadata.jl) - Types de métadonnées
> - [registry.jl](code/Strategies/api/registry.jl) - Implémentation du registre
> - [builders.jl](code/Strategies/api/builders.jl) - Fonctions de construction

**Clé** : Strategies utilise Options pour gérer les options des stratégies, mais ne fait pas de routing multi-stratégies.

---

### Module 3: **Orchestration** (Dépend de Options et Strategies)

**Responsabilité** : Orchestration des actions, routing, dispatch multi-modes

**Fonctionnalités clés** :

- Routing des options entre action et stratégies
- Extraction des options d'action
- Construction de stratégies depuis des méthodes
- Gestion de la désambiguïsation
- **C'est ici** que le routing se fait

**API publique** :

- `route_all_options(kwargs, registry)` : Route toutes les options
- `extract_action_options(kwargs, registry, schemas)` : Extrait les options d'action
- `build_strategies_from_method(description, kwargs, registry)` : Construit les stratégies

**Algorithme de routing** :

1. Collecter tous les noms d'options connus depuis le registre
2. Partitionner les kwargs en options d'action vs options de stratégies
3. Retourner deux NamedTuples séparés

> **Implémentation détaillée** : Voir les annexes de code
>
> - [routing.jl](code/Orchestration/api/routing.jl) - Logique de routing
> - [method_builders.jl](code/Orchestration/api/method_builders.jl) - Construction depuis méthodes

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

---

## Voir Aussi

**Documents de référence** :

- **[11_explicit_registry_architecture.md](11_explicit_registry_architecture.md)** - Détails du registre et signatures complètes
- **[08_complete_contract_specification.md](08_complete_contract_specification.md)** - Contrat des stratégies (symbol, options, metadata)
- **[solve_ideal.jl](solve_ideal.jl)** - Exemple complet d'utilisation

**Documents d'analyse** :

- **[../analysis/14_action_genericity_analysis.md](../analysis/14_action_genericity_analysis.md)** - Pourquoi pas de dispatch générique
- **[../analysis/12_action_pattern_analysis.md](../analysis/12_action_pattern_analysis.md)** - Analyse du pattern action
