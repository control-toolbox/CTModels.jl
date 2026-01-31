# Audit des Messages d'Erreur - CTModels.jl

**Date**: 2026-01-28  
**Version**: 1.0  
**Status**: 🔍 **ANALYSE EN COURS**

---

## Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Analyse Quantitative](#analyse-quantitative)
3. [Patterns de Gestion d'Erreur](#patterns-de-gestion-derreur)
4. [Analyse Qualitative des Messages](#analyse-qualitative-des-messages)
5. [Problèmes Identifiés](#problèmes-identifiés)
6. [Recommandations](#recommandations)

---

## Vue d'Ensemble

### Objectifs de l'Audit

1. **Clarté des messages** : Les messages d'erreur sont-ils compréhensibles ?
2. **Contexte suffisant** : Les messages fournissent-ils assez d'information pour déboguer ?
3. **Patterns de gestion** : Comment les erreurs sont-elles propagées dans le code ?
4. **Opportunités d'amélioration** : Peut-on améliorer la lisibilité des stacktraces ?

### Méthodologie

- Analyse de 277 occurrences d'erreurs dans 35 fichiers
- Classification par type d'erreur (CTBase.IncorrectArgument, CTBase.UnauthorizedCall, etc.)
- Évaluation de la qualité des messages
- Identification des patterns de throw/rethrow

---

## Analyse Quantitative

### Distribution des Erreurs par Fichier

| Fichier | Nombre d'erreurs | Priorité |
|---------|------------------|----------|
| `InitialGuess/initial_guess.jl` | 57 | 🔴 HAUTE |
| `OCP/Building/model.jl` | 22 | 🟠 MOYENNE |
| `OCP/Components/constraints.jl` | 21 | 🟠 MOYENNE |
| `Strategies/api/validation.jl` | 20 | 🟠 MOYENNE |
| `OCP/Components/dynamics.jl` | 15 | 🟡 BASSE |
| `OCP/Components/times.jl` | 15 | 🟡 BASSE |
| Autres (29 fichiers) | 127 | 🟡 BASSE |

### Types d'Exceptions Utilisées

```julia
# CTBase exceptions (recommandé)
CTBase.IncorrectArgument     # Arguments invalides
CTBase.UnauthorizedCall      # Appels non autorisés

# Julia standard (à éviter si possible)
error()                      # Erreur générique
ArgumentError()              # Erreur d'argument
```

---

## Patterns de Gestion d'Erreur

### Pattern 1: Validation Directe avec @ensure

**Fichiers**: `state.jl`, `control.jl`, `variable.jl`, `times.jl`, `objective.jl`, `constraints.jl`

```julia
# ✅ BON: Message clair avec contexte
@ensure criterion ∈ (:min, :max, :MIN, :MAX) CTBase.IncorrectArgument(
    "criterion must be either :min, :max, :MIN, or :MAX, got :$criterion"
)

# ✅ BON: Validation avec détails
@ensure(
    all(lb .<= ub),
    CTBase.IncorrectArgument(
        "the lower bound `lb` must be less than or equal to the upper bound `ub` element-wise. Found violations where lb > ub."
    ),
)
```

**Avantages**:
- Message clair et contextualisé
- Exception appropriée (CTBase)
- Facile à déboguer

**Inconvénients**:
- Stacktrace peut être longue si imbrication profonde

### Pattern 2: Throw Direct avec Construction de Message

**Fichiers**: `initial_guess.jl`, `model.jl`

```julia
# ⚠️ MOYEN: Message clair mais construction manuelle
if dim != 1
    msg = "Initial state dimension mismatch: got scalar for state dimension $dim"
    throw(CTBase.IncorrectArgument(msg))
end

# ⚠️ MOYEN: Message avec interpolation complexe
msg = string(
    "Initial state dimension mismatch: got ",
    length(state),
    " instead of ",
    dim
)
throw(CTBase.IncorrectArgument(msg))
```

**Avantages**:
- Flexibilité dans la construction du message
- Peut inclure beaucoup de contexte

**Inconvénients**:
- Code verbeux
- Duplication de patterns
- Stacktrace peut être difficile à lire

### Pattern 3: Error() Générique

**Fichiers**: Quelques fichiers legacy

```julia
# ❌ MAUVAIS: Message peu clair, exception non typée
error("Something went wrong")
```

**Problèmes**:
- Pas d'exception typée (difficile à catcher)
- Message souvent trop vague
- Pas de convention

---

## Analyse Qualitative des Messages

### Catégorie A: Messages Excellents ✅

**Caractéristiques**:
- Indiquent clairement le problème
- Fournissent la valeur reçue
- Suggèrent la valeur attendue
- Utilisent CTBase exceptions

**Exemples**:

```julia
// 1. Validation de critère (objective.jl)
"criterion must be either :min, :max, :MIN, or :MAX, got :$criterion"
// ✅ Clair, complet, actionnable

// 2. Validation de bornes (constraints.jl)
"the lower bound `lb` must be less than or equal to the upper bound `ub` element-wise. Found violations where lb > ub."
// ✅ Explique le problème et la règle

// 3. Validation de noms (name_validation.jl)
"Name conflict detected: '$new_name' is already used in the model. Existing names: [...]"
// ✅ Identifie le conflit et liste les noms existants
```

### Catégorie B: Messages Bons mais Améliorables 🟡

**Caractéristiques**:
- Message clair mais pourrait être plus actionnable
- Manque parfois de contexte sur comment corriger

**Exemples**:

```julia
// 1. Dimension mismatch (initial_guess.jl)
"Initial state dimension mismatch: got scalar for state dimension $dim"
// 🟡 Clair mais pourrait suggérer: "Use a vector of length $dim instead"

// 2. Type non supporté (initial_guess.jl)
"Unsupported initial guess type: $(typeof(init_data))"
// 🟡 Pourrait lister les types supportés

// 3. Composant non défini (model.jl)
"the state must be set before the objective."
// 🟡 Pourrait dire: "Call state!(ocp, ...) before objective!(...)"
```

### Catégorie C: Messages à Améliorer ⚠️

**Caractéristiques**:
- Messages trop techniques
- Manque de contexte
- Difficile de comprendre comment corriger

**Exemples à identifier** (nécessite analyse approfondie):

```julia
// Messages avec jargon technique sans explication
// Messages sans indication de la valeur problématique
// Messages sans suggestion de correction
```

---

## Problèmes Identifiés

### Problème 1: Stacktraces Longues et Difficiles à Lire

**Symptôme**: Quand une erreur est levée profondément dans le code, la stacktrace peut contenir 20-30 lignes de code interne avant d'arriver au code utilisateur.

**Exemple typique**:

```
ERROR: IncorrectArgument: criterion must be either :min or :max, got :invalid
Stacktrace:
 [1] macro expansion
   @ ~/CTModels.jl/src/Utils/macros.jl:21 [inlined]
 [2] objective!(ocp::PreModel, criterion::Symbol; mayer::Function)
   @ CTModels.OCP ~/CTModels.jl/src/OCP/Components/objective.jl:64
 [3] objective!
   @ ~/CTModels.jl/src/OCP/Components/objective.jl:40 [inlined]
 [4] macro expansion
   @ ~/.julia/.../Test/src/Test.jl:677 [inlined]
 [5] macro expansion
   @ ~/CTModels.jl/test/suite/ocp/test_objective.jl:132 [inlined]
 ... (15 more lines)
```

**Impact**: L'utilisateur doit parcourir beaucoup de lignes pour trouver où est le problème dans SON code.

### Problème 2: Manque de Contexte Hiérarchique

**Symptôme**: Quand une erreur se produit dans une fonction appelée par une autre, on perd le contexte de l'appel parent.

**Exemple**:

```julia
# L'utilisateur appelle:
build(ocp)

# Qui appelle:
__validate_model(ocp)

# Qui lève:
throw(IncorrectArgument("state not set"))

# Le message ne dit pas que c'était pendant build()
```

### Problème 3: Messages Techniques pour Utilisateurs Non-Experts

**Symptôme**: Certains messages utilisent du jargon Julia ou des termes techniques sans explication.

**Exemples**:
- "MethodError: no method matching..."
- "UndefVarError: variable not defined"
- Messages avec types Julia complexes

---

## Recommandations

### Recommandation 1: Système de Context-Aware Error Handling

**Proposition**: Créer un système qui enrichit les erreurs avec du contexte au fur et à mesure qu'elles remontent la stack.

**Concept**:

```julia
# Niveau bas: erreur technique
function __validate_criterion(criterion)
    if criterion ∉ (:min, :max, :MIN, :MAX)
        throw(CTBase.IncorrectArgument(
            "Invalid criterion: $criterion",
            context="criterion_validation"
        ))
    end
end

# Niveau intermédiaire: ajoute contexte
function objective!(ocp, criterion; kwargs...)
    try
        __validate_criterion(criterion)
        # ... rest of code
    catch e
        if e isa CTBase.IncorrectArgument
            rethrow(CTBase.IncorrectArgument(
                "Error in objective! function: $(e.msg)",
                context="objective_definition",
                caused_by=e
            ))
        else
            rethrow()
        end
    end
end

# Niveau haut: contexte utilisateur
function build(ocp)
    try
        # ... validation calls
    catch e
        if e isa CTBase.IncorrectArgument
            # Afficher un message user-friendly
            println("❌ Error building OCP model:")
            println("   $(e.msg)")
            if !isnothing(e.caused_by)
                println("   Caused by: $(e.caused_by.msg)")
            end
            println("\n💡 Suggestion: Check your objective! call")
            rethrow()
        else
            rethrow()
        end
    end
end
```

**Avantages**:
- Messages progressivement plus contextualisés
- Stacktrace enrichie sans perdre l'info technique
- Possibilité d'afficher des suggestions

**Inconvénients**:
- Nécessite modification de CTBase.IncorrectArgument
- Overhead de performance (minimal)
- Plus de code

### Recommandation 2: Error Message Guidelines

**Proposition**: Établir des guidelines claires pour les messages d'erreur.

**Template recommandé**:

```julia
"[WHAT WENT WRONG]. [WHAT WAS RECEIVED]. [WHAT WAS EXPECTED]. [SUGGESTION]"

# Exemples:
"Invalid criterion. Got :invalid. Expected :min, :max, :MIN, or :MAX. Use one of the valid criterion symbols."

"Dimension mismatch. Got vector of length 3. Expected length 2 (state dimension). Provide a vector matching the state dimension."

"Name conflict detected. Name 'x' is already used by state component. Choose a different name for the control."
```

**Éléments clés**:
1. **WHAT**: Quel est le problème
2. **GOT**: Quelle valeur a été reçue
3. **EXPECTED**: Quelle valeur était attendue
4. **SUGGESTION**: Comment corriger (optionnel mais recommandé)

### Recommandation 3: User-Friendly Error Display

**Proposition**: Créer une fonction qui affiche les erreurs de manière plus lisible.

```julia
function display_user_error(e::Exception)
    println("\n" * "="^60)
    println("❌ ERROR in CTModels")
    println("="^60)
    
    if e isa CTBase.IncorrectArgument
        println("\n📋 Problem:")
        println("   $(e.msg)")
        
        if hasfield(typeof(e), :suggestion)
            println("\n💡 Suggestion:")
            println("   $(e.suggestion)")
        end
        
        println("\n📍 Location:")
        # Afficher seulement les 3 premières lignes de stacktrace
        st = stacktrace(catch_backtrace())
        for (i, frame) in enumerate(st[1:min(3, length(st))])
            println("   $i. $(frame.func) at $(frame.file):$(frame.line)")
        end
        
        println("\n📚 Documentation:")
        println("   See: https://control-toolbox.org/docs/ctmodels/...")
    else
        # Affichage standard pour autres erreurs
        showerror(stdout, e)
    end
    
    println("\n" * "="^60 * "\n")
end
```

### Recommandation 4: Validation Helper avec Messages Standardisés

**Proposition**: Créer des helpers de validation qui génèrent automatiquement des messages cohérents.

```julia
module ErrorHelpers

"""
Validate that a value is in a set of allowed values.
Automatically generates a clear error message.
"""
function validate_in_set(value, allowed_values, param_name::String)
    if value ∉ allowed_values
        allowed_str = join(map(x -> ":$x", allowed_values), ", ")
        throw(CTBase.IncorrectArgument(
            "Invalid $param_name. Got :$value. Expected one of: $allowed_str."
        ))
    end
end

"""
Validate dimension match.
Automatically generates a clear error message.
"""
function validate_dimension(got::Int, expected::Int, component_name::String)
    if got != expected
        throw(CTBase.IncorrectArgument(
            "Dimension mismatch for $component_name. Got $got. Expected $expected. " *
            "Provide a vector of length $expected."
        ))
    end
end

"""
Validate bounds relationship.
"""
function validate_bounds(lb, ub, component_name::String)
    if !all(lb .<= ub)
        violations = findall(lb .> ub)
        throw(CTBase.IncorrectArgument(
            "Invalid bounds for $component_name. Lower bound must be ≤ upper bound. " *
            "Violations at indices: $violations."
        ))
    end
end

end # module
```

**Usage**:

```julia
# Au lieu de:
if criterion ∉ (:min, :max, :MIN, :MAX)
    throw(CTBase.IncorrectArgument("criterion must be..."))
end

# On écrit:
ErrorHelpers.validate_in_set(criterion, (:min, :max, :MIN, :MAX), "criterion")
```

---

## Prochaines Étapes

### Phase 1: Analyse Approfondie (EN COURS)
- [ ] Cataloguer tous les messages d'erreur existants
- [ ] Classifier par qualité (A/B/C)
- [ ] Identifier les patterns problématiques

### Phase 2: Proposition de Solution
- [ ] Concevoir le système d'enrichissement d'erreurs
- [ ] Créer les guidelines de messages
- [ ] Prototyper les helpers de validation

### Phase 3: Implémentation
- [ ] Implémenter le système d'erreurs enrichies
- [ ] Refactorer les messages prioritaires
- [ ] Ajouter la documentation

### Phase 4: Validation
- [ ] Tester avec des cas d'usage réels
- [ ] Recueillir feedback utilisateurs
- [ ] Ajuster selon retours

---

## Questions Ouvertes

1. **Modification de CTBase**: Est-il possible/souhaitable de modifier `CTBase.IncorrectArgument` pour supporter des champs additionnels (context, suggestion, caused_by) ?

2. **Performance**: Quel est l'overhead acceptable pour l'enrichissement d'erreurs ?

3. **Rétrocompatibilité**: Comment gérer les codes existants qui catchent les exceptions actuelles ?

4. **Internationalisation**: Faut-il prévoir des messages en plusieurs langues ?

5. **Niveau de détail**: Jusqu'où aller dans les suggestions ? Risque de messages trop longs ?

---

## Annexes

### Annexe A: Exemples de Messages Avant/Après

#### Exemple 1: Criterion Validation

**Avant**:
```
ERROR: IncorrectArgument: criterion must be either :min or :max, got :invalid
```

**Après (avec enrichissement)**:
```
❌ ERROR in CTModels
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Problem:
   Invalid optimization criterion in objective! function

🔍 Details:
   Got: :invalid
   Expected: :min, :max, :MIN, or :MAX

💡 Suggestion:
   Change your objective! call to use one of the valid criteria:
   objective!(ocp, :min, mayer=...)  # For minimization
   objective!(ocp, :max, mayer=...)  # For maximization

📍 Your code:
   objective! at my_script.jl:42

📚 Documentation:
   https://control-toolbox.org/docs/ctmodels/objective
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Exemple 2: Dimension Mismatch

**Avant**:
```
ERROR: IncorrectArgument: Initial state dimension mismatch: got 3 instead of 2
```

**Après (avec enrichissement)**:
```
❌ ERROR in CTModels
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Problem:
   State dimension mismatch in initial guess

🔍 Details:
   Your initial state has 3 elements
   Your OCP state has 2 dimensions
   
💡 Suggestion:
   Provide an initial state with 2 elements:
   init = (state = [x1_init, x2_init], ...)
   
   Or use a function:
   init = (state = t -> [x1(t), x2(t)], ...)

📍 Your code:
   initial_guess at my_script.jl:15
   build at my_script.jl:50

📚 Documentation:
   https://control-toolbox.org/docs/ctmodels/initial-guess
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Annexe B: Statistiques Détaillées

*À compléter avec analyse exhaustive*

---

**Statut**: 🔍 Analyse en cours - Document vivant mis à jour au fur et à mesure de l'audit
