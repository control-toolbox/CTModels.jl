# Plan d'Action pour l'Enrichissement des Exceptions

**Date**: 2026-01-30
**Basé sur**: Audit des oublis du 30/01/2026

## Objectif

Migrer 100% des exceptions restantes (`CTBase.*`) vers le système enrichi (`Exceptions.*`), en priorisant l'expérience utilisateur sur les composants principaux (`OCP`).

---

## 📅 Phase 0 : Amélioration des Définitions (NOUVEAU)

**Objectif** : Enrichir uniformément toutes les exceptions avant de migrer les usages.

### 0.1 Enrichir `NotImplemented`

- [ ] Ajouter les champs `suggestion` et `context` à `struct NotImplemented`.
- [ ] Mettre à jour `display.jl` pour afficher ces nouveaux champs.
- [ ] Exemple visé :

  ```julia
  Exceptions.NotImplemented(
      "Method solve! not implemented",
      type_info="MyStrategy",
      context="solve call",
      suggestion="Import the relevant package (e.g. CTDirect) or implement solve!(::MyStrategy, ...)"
  )
  ```

### 0.2 Enrichir `ParsingError`

- [ ] Ajouter le champ `suggestion` à `struct ParsingError`.
- [ ] Mettre à jour `display.jl`.

---

## 📅 Phase 1 : Composants Critiques (Immédiat)

**Cible** : `src/OCP/Components/constraints.jl` et autres composants OCP.
**Rationale** : Ces fichiers sont les plus utilisés par les utilisateurs finaux et contiennent actuellement un mélange incohérent d'exceptions.

### 1.1 `constraints.jl` (Priorité Absolue)

- [ ] Remplacer les 6 occurrences de `CTBase.UnauthorizedCall`.
- [ ] Utiliser `Exceptions.UnauthorizedCall` avec :
  - `reason`: explication de pourquoi l'appel est interdit (ex: "State is not defined yet").
  - `suggestion`: suggestion explicite (ex: "Call state!(ocp, ...) first").
  - `context`: nom de la fonction (`constraint!`).

### 1.2 Autres Composants (`UnauthorizedCall`)

- [ ] Migrer `objective.jl`, `times.jl`, `control.jl`, `state.jl`, `variable.jl`, `dynamics.jl`.
- [ ] Standardiser les messages pour les appels hors ordre (Ex: "X must be set before Y").

---

## 📅 Phase 2 : Stratégies et Orchestration (Court Terme)

**Cible** : `src/Strategies/`, `src/Orchestration/`
**Rationale** : Erreurs souvent rencontrées lors de la configuration avancée ou de la résolution.

### 2.1 Validation des Stratégies

- [ ] Migrer les `CTBase.IncorrectArgument` dans `api/validation.jl` et `registry.jl`.
- [ ] Enrichir les messages pour aider à comprendre pourquoi une stratégie est invalide.

### 2.2 Messages `NotImplemented`

- [ ] Migrer `CTBase.NotImplemented` vers `Exceptions.NotImplemented`.
- [ ] Ajouter des suggestions sur quel package charger ou quelle méthode implémenter.

---

## 📅 Phase 3 : Nettoyage Final (Moyen Terme)

**Cible** : Le reste des fichiers (`Serialization`, `Options`, `Modelers`).

- [ ] Migrer les exceptions isolées restantes.
- [ ] Vérifier qu'il ne reste aucun `CTBase.IncorrectArgument` ou `CTBase.UnauthorizedCall` direct dans le code source (`grep` final).

---

## 📝 Standards de Migration

Pour chaque exception migrée, respecter le template suivant :

### UnauthorizedCall

```julia
Exceptions.UnauthorizedCall(
    "Cannot add constraint",
    reason="state has not been defined yet",
    suggestion="Call state!(ocp, n) before adding constraints",
    context="constraint! function check"
)
```

### NotImplemented

```julia
Exceptions.NotImplemented(
    "Method not implemented for this strategy",
    type_info="StrategyType",
    context="validation check",
    suggestion="Implement the required method or check imports"
)
```

## Vérification

- Exécuter les tests existants pour s'assurer qu'aucune régression n'est introduite.
- Ajouter des cas de tests pour vérifier que les messages enrichis apparaissent bien.
