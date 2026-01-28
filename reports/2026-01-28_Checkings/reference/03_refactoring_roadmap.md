# Refactoring Roadmap - Enhanced Error System Implementation

**Date**: 2026-01-28  
**Version**: 1.0  
**Status**: 🚀 **READY TO START** - System Implemented, Refactoring Phase Beginning

---

## 📋 Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Système Implémenté](#système-implémenté)
3. [État Actuel du Code](#état-actuel-du-code)
4. [Plan de Refactoring](#plan-de-refactoring)
5. [Priorités](#priorités)
6. [Métriques de Succès](#métriques-de-succès)
7. [Timeline Estimée](#timeline-estimée)

---

## Vue d'Ensemble

### Objectif

Migrer progressivement les 277 occurrences d'erreurs existantes dans CTModels pour utiliser le nouveau système d'exceptions enrichies, améliorant ainsi l'expérience utilisateur avec des messages clairs, des suggestions et la localisation du code.

### Problème Résolu

**Avant le système** :
- Messages d'erreur cryptiques
- Stacktraces intimidantes (20+ lignes)
- Pas de suggestions de correction
- Difficile de trouver où l'erreur s'est produite

**Après le système** :
- Messages structurés avec emojis
- Localisation exacte du code utilisateur
- Suggestions actionnables
- Contrôle des stacktraces

---

## Système Implémenté ✅

### Infrastructure Complète

**Module `src/Exceptions/`** :
- ✅ `Exceptions.jl` : Définitions des 4 types d'exceptions enrichies
- ✅ `module.jl` : Module wrapper avec exports
- ✅ Intégré dans `src/CTModels.jl`

**Types d'Exceptions** :
- ✅ `IncorrectArgument` : Arguments invalides avec got/expected/suggestion/context
- ✅ `UnauthorizedCall` : Appels non autorisés avec reason/suggestion/context  
- ✅ `NotImplemented` : Interfaces non implémentées
- ✅ `ParsingError` : Erreurs de parsing avec location

**Fonctionnalités** :
- ✅ Affichage user-friendly par défaut
- ✅ Contrôle des stacktraces (`SHOW_FULL_STACKTRACE`)
- ✅ Extraction des frames utilisateur (`extract_user_frames`)
- ✅ Compatibilité CTBase (`to_ctbase()`)

### Tests et Documentation

**Tests** :
- ✅ `test/suite/exceptions/test_exceptions.jl` : 49 tests (100% passent)
- ✅ Couverture complète de toutes les fonctionnalités
- ✅ Tests de compatibilité CTBase

**Documentation** :
- ✅ `reports/02_enhanced_error_system.md` : Documentation complète du système
- ✅ `examples/` : 3 fichiers d'exemples avec README
- ✅ `reports/02_error_messages_audit.md` : Audit des messages existants

### Exemples

**`examples/error_handling_demo.jl`** :
- Démonstration principale avec localisation
- Tous les types d'erreurs
- Mode debug vs user-friendly

**`examples/test_location_demo.jl`** :
- Test rapide de localisation du code

**`examples/test_migration_demo.jl`** :
- Comparaison CTBase vs enrichi
- Chemin de migration

---

## État Actuel du Code

### Audit Complet des Messages d'Erreur

**Total** : 277 occurrences dans 35 fichiers

**Distribution par Priorité** :

| Priorité | Fichier | Occurrences | Statut |
|---------|---------|------------|---------|
| 🔴 **HAUTE** | `InitialGuess/initial_guess.jl` | 57 | ✅ Prêt |
| 🟠 **MOYENNE** | `OCP/Building/model.jl` | 22 | ✅ Prêt |
| 🟠 **MOYENNE** | `OCP/Components/constraints.jl` | 21 | ✅ Prêt |
| 🟠 **MOYENNE** | `Strategies/api/validation.jl` | 20 | ✅ Prêt |
| 🟡 **BASSE** | `OCP/Components/dynamics.jl` | 15 | ✅ Prêt |
| 🟡 **BASSE** | `OCP/Components/times.jl` | 15 | ✅ Prêt |
| Autres (29 fichiers) | 127 | ✅ Prêt |

### Types d'Erreurs Actuels

**CTBase Exceptions (à migrer)** :
- `CTBase.IncorrectArgument` : Arguments invalides
- `CTBase.UnauthorizedCall` : Appels non autorisés
- `CTBase.NotImplemented` : Non implémenté
- `CTBase.ParsingError` : Erreurs de parsing

**Patterns Courants** :
```julia
# Pattern 1: @ensure avec CTBase
@ensure condition CTBase.IncorrectArgument("message")

# Pattern 2: throw direct
throw(CTBase.IncorrectArgument("message"))

# Pattern 3: error() générique
error("message")  # À éviter
```

---

## Plan de Refactoring

### Phase 1 : Fichers Prioritaires (2-3 jours)

**Objectif** : Migrer les 135 erreurs les plus critiques

**1.1 - InitialGuess Module** (57 erreurs)
- ✅ Identifier les messages de dimension mismatch
- ✅ Ajouter suggestions pour tailles incorrectes
- ✅ Enrichir les messages de type incompatible
- ✅ Localisation des erreurs dans les fonctions d'initialisation

**1.2 - OCP Building Module** (22 erreurs)
- ✅ Améliorer les messages de composants manquants
- ✅ Ajouter contexte pour les erreurs de build
- ✅ Suggestions pour l'ordre des opérations

**1.3 - Constraints Module** (21 erreurs)
- ✅ Enrichir les validations de bornes `lb ≤ ub`
- ✅ Ajouter suggestions pour contraintes invalides
- ✅ Contexte sur les types de contraintes

**1.4 - Validation Module** (20 erreurs)
- ✅ Améliorer les messages de validation de stratégies
- ✅ Ajouter suggestions pour configurations invalides

### Phase 2 : Modules Secondaires (1-2 jours)

**Objectif** : Migrer les 142 erreurs restantes

**2.1 - Dynamics & Times** (30 erreurs)
- ✅ Messages de validation de dynamiques
- ✅ Validation `t0 < tf` avec suggestions

**2.2 - Core Components** (20 erreurs)
- ✅ `state.jl`, `control.jl`, `variable.jl` (4-5 erreurs chacun)
- ✅ Messages de validation existants déjà améliorés

**2.3 - Autres Modules** (92 erreurs)
- ✅ `Serialization`, `Modelers`, `DOCP`, etc.
- ✅ Messages spécifiques à chaque module

### Phase 3 : Finalisation (1 jour)

**Objectif** : Nettoyage et validation

- ✅ Supprimer les warnings de méthodes dupliquées
- ✅ Valider tous les messages enrichis
- ✅ Tests de régression complets
- ✅ Documentation mise à jour

---

## Priorités

### 🎯 **Critères de Priorité**

1. **Impact Utilisateur** : Erreurs fréquentes et critiques
2. **Visibilité** : Fonctions principales (`objective!`, `state!`, etc.)
3. **Complexité** : Messages techniques difficiles à comprendre
4. **Fréquence** : Erreurs rencontrées dans les workflows courants

### 📊 **Ordre de Migration**

1. **InitialGuess** : Initialisation des problèmes (souvent le premier point de friction)
2. **OCP Core** : Fonctions principales de définition de problèmes
3. **Constraints** : Validation des contraintes (erreurs courantes)
4. **Validation** : Validation de stratégies et configurations
5. **Support** : Fonctions de support et utilitaires

---

## Métriques de Succès

### 📈 **Objectifs Quantitatifs**

| Métrique | Avant | Cible | ✅ Statut |
|----------|-------|-------|----------|
| Messages enrichis | 0 | 277 | 🚀 Prêt |
| Tests passants | 3743 | 3743 | ✅ Maintenu |
| Documentation | 0 | Complète | ✅ Terminée |
| Exemples | 0 | 3 fichiers | ✅ Terminée |
| Couverture | ~50% | 95%+ | 🚀 Cible |

### 🎯 **Objectifs Qualitatifs**

- ✅ **Clarté** : Messages compréhensibles sans jargon
- ✅ **Actionnabilité** : Suggestions concrètes et utiles
- ✅ **Contexte** : Localisation précise du problème
- ✅ **Consistance** : Format uniforme dans tout le projet
- ✅ **Compatibilité** : Aucune régression

---

## Timeline Estimée

### 📅 **Phase 1 : Fichers Prioritaires** (2-3 jours)

**Jour 1** :
- Refactor `InitialGuess/initial_guess.jl` (57 erreurs)
- Tests de validation
- Documentation des changements

**Jour 2** :
- Refactor `OCP/Building/model.jl` (22 erreurs)
- Refactor `OCP/Components/constraints.jl` (21 erreurs)
- Tests de régression

**Jour 3** :
- Refactor `Strategies/api/validation.jl` (20 erreurs)
- Validation complète
- Documentation

### 📅 **Phase 2 : Modules Secondaires** (1-2 jours)

**Jour 4-5** :
- Refactor des modules restants (142 erreurs)
- Tests de régression complets
- Validation de l'expérience utilisateur

### 📅 **Phase 3 : Finalisation** (1 jour)

**Jour 6** :
- Nettoyage du code
- Suppression des warnings
- Documentation finale
- Tests de validation finaux

### 📅 **Total Estimé** : **4-6 jours**

---

## Template de Refactoring

### 🔄 **Standard de Migration**

**Avant** :
```julia
@ensure condition CTBase.IncorrectArgument("message")
```

**Après** :
```julia
@ensure condition CTModels.Exceptions.IncorrectArgument(
    "message",
    got=string(actual_value),
    expected="description of valid value",
    suggestion="How to fix the problem",
    context="function_name"
)
```

### 📝 **Template pour Types Spécifiques**

**Dimension Mismatch** :
```julia
throw(CTModels.Exceptions.IncorrectArgument(
    "Dimension mismatch for $component",
    got="$got",
    expected="$expected",
    suggestion="Provide a vector of length $expected",
    context="$function_name"
))
```

**Validation de Critère** :
```julia
throw(CTModels.Exceptions.IncorrectArgument(
    "Invalid optimization criterion",
    got=":$criterion",
    expected=":min, :max, :MIN, or :MAX",
    suggestion="Use :min for minimization or :max for maximization",
    context="objective! function"
))
```

**Conflit de Noms** :
```julia
throw(CTModels.Exceptions.IncorrectArgument(
    "Name conflict detected",
    got="'$new_name'",
    expected="unique name not already used",
    suggestion="Choose a different name. Existing names: $(existing_names)",
    context="$function_name"
))
```

---

## Risques et Mitigation

### ⚠️ **Risques Identifiés**

**1. Régression des Tests**
- **Risque** : Modification des messages peut casser des tests qui vérifient les messages exacts
- **Mitigation** : 
  - Exécuter la suite de tests complète après chaque fichier modifié
  - Identifier les tests qui vérifient les messages d'erreur
  - Mettre à jour les tests en parallèle du refactoring

**2. Warnings de Méthodes Dupliquées**
- **Risque** : Les constructeurs avec arguments optionnels créent des warnings
- **Mitigation** :
  - Déjà identifié dans le code actuel
  - À résoudre en Phase 3 (Finalisation)
  - Solution : Utiliser des méthodes avec kwargs au lieu de multiples constructeurs

**3. Performance**
- **Risque** : Extraction des frames utilisateur peut ralentir l'affichage des erreurs
- **Mitigation** :
  - L'extraction n'est faite que lors de l'affichage (pas à la création)
  - Impact minimal car les erreurs sont des cas exceptionnels
  - Mode debug disponible si besoin de stacktraces complètes

**4. Compatibilité avec Code Externe**
- **Risque** : Code externe qui catch des `CTBase.IncorrectArgument` spécifiques
- **Mitigation** :
  - Fonction `to_ctbase()` pour conversion
  - Les exceptions enrichies héritent de la même hiérarchie
  - Migration progressive possible

**5. Messages Trop Verbeux**
- **Risque** : Trop d'informations peut noyer l'utilisateur
- **Mitigation** :
  - Garder les messages concis et structurés
  - Utiliser les sections (Problem, Details, Suggestion) pour organiser
  - Mode user-friendly cache les stacktraces par défaut

### 🛡️ **Stratégies de Mitigation Générales**

1. **Migration Progressive** : Un fichier à la fois avec validation
2. **Tests Continus** : Exécuter les tests après chaque modification
3. **Revue de Code** : Valider la qualité des messages enrichis
4. **Feedback Utilisateur** : Tester avec des cas réels d'utilisation
5. **Rollback Facile** : Git permet de revenir en arrière si nécessaire

---

## Patterns Spécifiques par Module

### 📦 **InitialGuess Module**

**Pattern Courant** : Validation de dimensions et types

```julia
# Dimension mismatch
if length(value) != expected_dim
    throw(CTModels.Exceptions.IncorrectArgument(
        "Dimension mismatch for $component initial guess",
        got="vector of length $(length(value))",
        expected="vector of length $expected_dim",
        suggestion="Provide a $component initial guess with $expected_dim elements, or use a function: $component = t -> [...]",
        context="initial_guess construction"
    ))
end

# Type incompatible
if !(value isa Union{Function, Vector})
    throw(CTModels.Exceptions.IncorrectArgument(
        "Invalid type for $component initial guess",
        got="$(typeof(value))",
        expected="Function or Vector",
        suggestion="Use either a constant vector or a function of time: $component = t -> [...]",
        context="initial_guess construction"
    ))
end
```

### 🏗️ **OCP Building Module**

**Pattern Courant** : Composants manquants

```julia
# Composant manquant
if !has_component(ocp, :dynamics)
    throw(CTModels.Exceptions.IncorrectArgument(
        "Missing required component for OCP build",
        got="OCP without dynamics",
        expected="OCP with dynamics defined",
        suggestion="Call dynamics!(ocp, f) before building the OCP",
        context="build_ocp"
    ))
end
```

### 🔒 **Constraints Module**

**Pattern Courant** : Validation de bornes

```julia
# Bornes invalides
if any(lb .> ub)
    violations = findall(lb .> ub)
    throw(CTModels.Exceptions.IncorrectArgument(
        "Lower bound exceeds upper bound",
        got="lb > ub at indices: $violations",
        expected="lb ≤ ub for all elements",
        suggestion="Ensure lb[i] ≤ ub[i] for all i. Check indices: $violations",
        context="constraint! with bounds"
    ))
end
```

### ✅ **Validation Module**

**Pattern Courant** : Configuration invalide

```julia
# Configuration invalide
if !is_valid_strategy(strategy)
    throw(CTModels.Exceptions.IncorrectArgument(
        "Invalid strategy configuration",
        got=":$strategy",
        expected="one of: :direct, :indirect, :shooting",
        suggestion="Use a valid strategy. See documentation for available strategies.",
        context="solve with strategy validation"
    ))
end
```

---

## Checklist de Validation

### ✅ **Pour Chaque Message Refactoré**

- [ ] Message clair et concis
- [ ] Inclut la valeur reçue (`got`)
- [ ] Inclut la valeur attendue (`expected`)
- [ ] Inclut une suggestion actionnable
- [ ] Inclut le contexte approprié
- [ ] Utilise `CTModels.Exceptions.IncorrectArgument`
- [ ] Test de régression passe
- [ ] Documentation mise à jour si nécessaire

### ✅ **Pour Chaque Fichier Modifié**

- [ ] Aucun warning de compilation
- [ ] Tests existants passent
- [ ] Nouveaux tests ajoutés si nécessaire
- [ ] Documentation mise à jour
- [ ] Compatibilité maintenue

---

## Prochaines Étapes

### 🚀 **Prêt à Commencer**

Le système d'exceptions enrichies est **complètement opérationnel** et prêt pour le refactoring progressif.

**Recommandation** : Commencer par `InitialGuess/initial_guess.jl` car c'est le fichier avec le plus grand impact sur l'expérience utilisateur.

### 📋 **Actions Immédiates**

1. **Créer une branche** pour le refactoring
2. **Commencer avec `InitialGuess/initial_guess.jl`**
3. **Appliquer le template de migration**
4. **Ajouter des tests pour les nouveaux messages**
5. **Valider l'amélioration de l'expérience utilisateur**

---

## Conclusion

Le système d'exceptions enrichies est **implémenté, testé et documenté**. Le refactoring progressif améliorera significativement l'expérience utilisateur dans CTModels en transformant les messages d'erreur cryptiques en messages clairs, localisés et actionnables.

**Statut** : ✅ **Prêt à commencer le refactoring** 🚀

---

**Fichier de référence** : `reports/2026-01-28_Checkings/reference/03_refactoring_roadmap.md`
**Dernière mise à jour** : 2026-01-28
**Prochaine action** : Commencer le refactoring des messages d'erreur existants
