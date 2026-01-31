# Enhanced Error Handling System - CTModels.jl

**Date**: 2026-01-28  
**Version**: 1.0  
**Status**: ✅ **IMPLEMENTED** - System Ready for Use

---

## Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Fonctionnalités](#fonctionnalités)
4. [Guide d'Utilisation](#guide-dutilisation)
5. [Migration depuis CTBase](#migration-depuis-ctbase)
6. [Prochaines Étapes](#prochaines-étapes)

---

## Vue d'Ensemble

### Objectif

Créer un système d'exceptions enrichies pour CTModels qui améliore significativement l'expérience utilisateur en fournissant :

1. **Messages d'erreur clairs** avec contexte et suggestions
2. **Affichage user-friendly** sans stacktraces intimidantes
3. **Mode debug** avec stacktraces complètes quand nécessaire
4. **Compatibilité CTBase** pour migration future

### Problème Résolu

**Avant** :
```
ERROR: IncorrectArgument: criterion must be either :min or :max, got :invalid
Stacktrace:
 [1] macro expansion @ macros.jl:21 [inlined]
 [2] objective! @ objective.jl:64
 [3] objective! @ objective.jl:40 [inlined]
 ... (20+ lignes de stacktrace interne)
```

**Après** :
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ ERROR in CTModels
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Problem:
   Invalid optimization criterion

🔍 Details:
   Got:      :invalid
   Expected: :min, :max, :MIN, or :MAX

💡 Suggestion:
   Use objective!(ocp, :min, ...) for minimization
   Use objective!(ocp, :max, ...) for maximization

💬 Note:
   For full Julia stacktrace, run:
   CTModels.set_show_full_stacktrace!(true)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Architecture

### Structure des Fichiers

```
src/Exceptions/
├── Exceptions.jl      # Définitions des exceptions enrichies
└── module.jl          # Module wrapper

test/suite/exceptions/
└── test_exceptions.jl # Tests complets (49 tests)

examples/
└── error_handling_demo.jl  # Démonstration du système
```

### Hiérarchie des Exceptions

```julia
Exception (Julia Base)
    └── CTModelsException (Abstract)
        ├── IncorrectArgument
        ├── UnauthorizedCall
        ├── NotImplemented
        └── ParsingError
```

### Compatibilité CTBase

Le système est **100% compatible** avec CTBase :

- Même sémantique que `CTBase.CTException`
- Fonction `to_ctbase()` pour conversion
- Prêt pour migration future vers CTBase

---

## Fonctionnalités

### 1. Exceptions Enrichies

#### `IncorrectArgument`

Pour les arguments invalides ou violations de préconditions.

**Champs** :
- `msg::String` : Message principal
- `got::Union{String, Nothing}` : Valeur reçue (optionnel)
- `expected::Union{String, Nothing}` : Valeur attendue (optionnel)
- `suggestion::Union{String, Nothing}` : Comment corriger (optionnel)
- `context::Union{String, Nothing}` : Contexte de l'erreur (optionnel)

**Exemple** :
```julia
throw(IncorrectArgument(
    "Invalid criterion",
    got=":invalid",
    expected=":min or :max",
    suggestion="Use objective!(ocp, :min, ...) or objective!(ocp, :max, ...)",
    context="objective! function"
))
```

#### `UnauthorizedCall`

Pour les appels non autorisés dans le contexte actuel.

**Champs** :
- `msg::String` : Message principal
- `reason::Union{String, Nothing}` : Pourquoi non autorisé (optionnel)
- `suggestion::Union{String, Nothing}` : Comment corriger (optionnel)
- `context::Union{String, Nothing}` : Contexte (optionnel)

**Exemple** :
```julia
throw(UnauthorizedCall(
    "Cannot call state! twice",
    reason="state has already been defined for this OCP",
    suggestion="Create a new OCP instance or use a different component"
))
```

#### `NotImplemented`

Pour les interfaces non implémentées.

**Champs** :
- `msg::String` : Description
- `type_info::Union{String, Nothing}` : Info de type (optionnel)

#### `ParsingError`

Pour les erreurs de parsing.

**Champs** :
- `msg::String` : Description
- `location::Union{String, Nothing}` : Localisation (optionnel)

### 2. Contrôle de l'Affichage

#### Variable de Module : `SHOW_FULL_STACKTRACE`

```julia
# Mode user-friendly (défaut)
CTModels.set_show_full_stacktrace!(false)

# Mode debug avec stacktraces complètes
CTModels.set_show_full_stacktrace!(true)

# Vérifier l'état actuel
CTModels.get_show_full_stacktrace()
```

**Avantages** :
- ✅ Affichage propre par défaut pour les utilisateurs
- ✅ Stacktraces complètes disponibles pour le debug
- ✅ Contrôle global au niveau du module
- ✅ Facile à activer/désactiver

### 3. Affichage User-Friendly

Le système affiche automatiquement les erreurs de manière structurée :

**Sections** :
- 📋 **Problem** : Description du problème
- 🔍 **Details** : Valeurs reçues vs attendues
- 📂 **Context** : Où l'erreur s'est produite
- 💡 **Suggestion** : Comment corriger
- 💬 **Note** : Comment activer les stacktraces complètes

**Emojis** : Rendent les messages plus lisibles et moins intimidants

### 4. Compatibilité CTBase

```julia
# Créer une exception CTModels
e = IncorrectArgument("Invalid input", got="x", expected="y")

# Convertir en exception CTBase
ctbase_e = CTModels.Exceptions.to_ctbase(e)

# ctbase_e est maintenant un CTBase.IncorrectArgument
# avec un message complet incluant tous les champs
```

---

## Guide d'Utilisation

### Pour les Utilisateurs

#### Mode Normal (Recommandé)

```julia
using CTModels

# Les erreurs s'affichent automatiquement en mode user-friendly
ocp = CTModels.PreModel()
CTModels.objective!(ocp, :invalid, mayer=...)  # Erreur claire et lisible
```

#### Mode Debug

```julia
using CTModels

# Activer les stacktraces complètes
CTModels.set_show_full_stacktrace!(true)

# Maintenant les erreurs montrent la stacktrace Julia complète
ocp = CTModels.PreModel()
CTModels.objective!(ocp, :invalid, mayer=...)  # Stacktrace complète

# Désactiver quand terminé
CTModels.set_show_full_stacktrace!(false)
```

### Pour les Développeurs

#### Créer une Exception Enrichie

```julia
using CTModels.Exceptions

# Simple
throw(IncorrectArgument("Invalid input"))

# Enrichie avec tous les champs
throw(IncorrectArgument(
    "Dimension mismatch",
    got="vector of length 3",
    expected="vector of length 2",
    suggestion="Provide a vector matching the state dimension",
    context="initial_guess for state"
))
```

#### Pattern Recommandé

```julia
function my_function(ocp, value)
    # Validation
    if !is_valid(value)
        throw(IncorrectArgument(
            "Invalid value for parameter",
            got=string(value),
            expected="positive number",
            suggestion="Provide a value > 0",
            context="my_function"
        ))
    end
    
    # ... reste du code
end
```

#### Catch et Enrichissement

```julia
function high_level_function(ocp)
    try
        low_level_function(ocp)
    catch e
        if e isa CTModelsException
            # Ajouter du contexte supplémentaire si nécessaire
            rethrow()
        else
            # Erreur non-CTModels : laisser passer
            rethrow()
        end
    end
end
```

---

## Migration depuis CTBase

### Étape 1 : Utilisation Actuelle

Le système est **déjà intégré** dans CTModels et prêt à l'emploi.

### Étape 2 : Remplacement Progressif

Pour migrer les exceptions existantes :

**Avant** (CTBase direct) :
```julia
throw(CTBase.IncorrectArgument("Invalid input"))
```

**Après** (CTModels enrichi) :
```julia
throw(CTModels.Exceptions.IncorrectArgument(
    "Invalid input",
    got="x",
    expected="y",
    suggestion="Use y instead"
))
```

### Étape 3 : Migration vers CTBase (Future)

Quand CTBase supportera les champs enrichis :

1. Modifier `CTBase.IncorrectArgument` pour accepter les champs optionnels
2. Remplacer `CTModels.Exceptions.IncorrectArgument` par `CTBase.IncorrectArgument`
3. Supprimer le module `Exceptions` de CTModels

La fonction `to_ctbase()` facilite cette transition.

---

## Prochaines Étapes

### Phase 1 : Refactoring des Messages (Prioritaire)

**Objectif** : Améliorer tous les messages d'erreur existants dans CTModels

**Fichiers à Refactorer** (par priorité) :

1. **HAUTE** : `src/InitialGuess/initial_guess.jl` (57 erreurs)
   - Ajouter suggestions pour dimension mismatches
   - Enrichir les messages de type incompatible

2. **MOYENNE** : `src/OCP/Building/model.jl` (22 erreurs)
   - Améliorer les messages de composants manquants
   - Ajouter contexte pour les erreurs de build

3. **MOYENNE** : `src/OCP/Components/constraints.jl` (21 erreurs)
   - Enrichir les validations de bornes
   - Ajouter suggestions pour les contraintes invalides

4. **MOYENNE** : `src/Strategies/api/validation.jl` (20 erreurs)
   - Améliorer les messages de validation de stratégies

**Template de Refactoring** :

```julia
# Avant
if !valid
    throw(CTBase.IncorrectArgument("Invalid input"))
end

# Après
if !valid
    throw(CTModels.Exceptions.IncorrectArgument(
        "Invalid input parameter",
        got=string(input),
        expected="description of valid input",
        suggestion="How to fix the problem",
        context="function_name"
    ))
end
```

### Phase 2 : Guidelines et Documentation

**Créer** :
1. Guidelines pour les messages d'erreur
2. Template de messages standardisés
3. Documentation utilisateur
4. Exemples pour chaque type d'erreur

### Phase 3 : Helpers de Validation

**Créer des helpers** qui génèrent automatiquement des messages cohérents :

```julia
module ValidationHelpers

function validate_in_set(value, allowed, param_name)
    if value ∉ allowed
        throw(IncorrectArgument(
            "Invalid $param_name",
            got=string(value),
            expected=join(string.(allowed), ", "),
            suggestion="Use one of: $(join(string.(allowed), ", "))"
        ))
    end
end

function validate_dimension(got, expected, component)
    if got != expected
        throw(IncorrectArgument(
            "Dimension mismatch for $component",
            got="$got",
            expected="$expected",
            suggestion="Provide a vector of length $expected"
        ))
    end
end

end
```

### Phase 4 : Tests et Validation

**Ajouter** :
1. Tests pour tous les nouveaux messages
2. Tests de régression pour les messages existants
3. Validation que les suggestions sont actionnables

---

## Statistiques

### Implémentation Actuelle

- ✅ **4 types d'exceptions** enrichies
- ✅ **49 tests** (100% passent)
- ✅ **1 exemple** de démonstration
- ✅ **Variable de module** pour contrôle stacktrace
- ✅ **Compatibilité CTBase** complète

### Messages à Refactorer

- 📊 **277 occurrences** d'erreurs dans 35 fichiers
- 🎯 **~150 messages** prioritaires à améliorer
- ⏱️ **Estimation** : 2-3 jours de travail pour refactoring complet

---

## Exemples Concrets

### Exemple 1 : Validation de Critère

```julia
# Code utilisateur
ocp = CTModels.PreModel()
CTModels.objective!(ocp, :minimize, mayer=...)

# Erreur affichée
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ ERROR in CTModels
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Problem:
   Invalid optimization criterion

🔍 Details:
   Got:      :minimize
   Expected: :min, :max, :MIN, or :MAX

💡 Suggestion:
   Use :min for minimization or :max for maximization
   Example: objective!(ocp, :min, mayer=...)

💬 Note:
   For full Julia stacktrace, run:
   CTModels.set_show_full_stacktrace!(true)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Exemple 2 : Conflit de Noms

```julia
# Code utilisateur
ocp = CTModels.PreModel()
CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
CTModels.control!(ocp, 1, "x")  # Erreur !

# Erreur affichée
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ ERROR in CTModels
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Problem:
   Name conflict detected

🔍 Details:
   Got:      "x"
   Expected: unique name not already used

📂 Context:
   control! function - name conflicts with existing state name

💡 Suggestion:
   Choose a different name for the control
   Existing names: ["t", "x", "x₁", "x₂"]

💬 Note:
   For full Julia stacktrace, run:
   CTModels.set_show_full_stacktrace!(true)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Exemple 3 : Dimension Mismatch

```julia
# Code utilisateur
ocp = CTModels.PreModel()
CTModels.state!(ocp, 2, "x")
init = (state = [1.0, 2.0, 3.0], ...)  # 3 éléments au lieu de 2

# Erreur affichée
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ ERROR in CTModels
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Problem:
   State dimension mismatch in initial guess

🔍 Details:
   Got:      vector of length 3
   Expected: vector of length 2

📂 Context:
   initial_guess for state component

💡 Suggestion:
   Provide an initial state with 2 elements:
   init = (state = [x1_init, x2_init], ...)
   
   Or use a function:
   init = (state = t -> [x1(t), x2(t)], ...)

💬 Note:
   For full Julia stacktrace, run:
   CTModels.set_show_full_stacktrace!(true)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Conclusion

Le système d'exceptions enrichies est **opérationnel et prêt à l'emploi**. Il améliore significativement l'expérience utilisateur tout en restant compatible avec CTBase pour une migration future.

**Prochaine étape recommandée** : Commencer le refactoring progressif des messages d'erreur existants en suivant le plan de la Phase 1.

---

**Statut** : ✅ Système implémenté et testé - Prêt pour utilisation et refactoring progressif
