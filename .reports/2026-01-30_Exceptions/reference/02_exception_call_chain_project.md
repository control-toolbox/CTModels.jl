# Guide de Référence - Projet de Système de Chaîne d'Appels d'Exceptions

**Version**: 1.0  
**Date**: 2026-01-31  
**Statut**: 📋 Projet en Planification  
**Auteur**: Équipe de Développement CTModels

---

## Table des Matières

1. [Vue d'Ensemble du Projet](#vue-densemble-du-projet)
2. [Contexte et Motivation](#contexte-et-motivation)
3. [Problématique Identifiée](#problématique-identifiée)
4. [Solution Proposée](#solution-proposée)
5. [Architecture Technique](#architecture-technique)
6. [Fonctions Prioritaires](#fonctions-prioritaires)
7. [Plan d'Implémentation](#plan-dimplémentation)
8. [Exemples Concrets](#exemples-concrets)
9. [Bénéfices Attendus](#bénéfices-attendus)
10. [Critères de Succès](#critères-de-succès)
11. [Références](#références)

---

## Vue d'Ensemble du Projet

### Objectif Principal

Implémenter un système de chaîne d'appels (call chain) qui contextualise les exceptions au niveau API, permettant aux utilisateurs de comprendre le chemin complet d'exécution qui a mené à une erreur, depuis leur appel initial jusqu'à la validation interne qui a échoué.

### Lien avec le Projet de Migration

Ce projet s'appuie sur la migration des exceptions terminée à 100% pour les exceptions actives (124/140 exceptions migrées vers le système enrichi). Il représente la prochaine évolution du système d'exceptions de CTModels.

**Projet précédent** : Migration des exceptions CTBase vers Exceptions enrichies
- Statut : ✅ Terminé (100% des exceptions actives)
- Documentation : `01_exception_migration_reference.md`
- Rapport final : `/reports/2026-01-30_Exceptions/progress/04_complete_migration_report.md`

**Nouveau projet** : Système de chaîne d'appels pour contextualisation API
- Statut : 📋 En planification
- Ce document : Guide de référence complet

### Chiffres Clés

- **Fonctions API à wrapper** : ~20-25 fonctions (4 tiers de priorité)
- **Modules concernés** : OCP, InitialGuess, Serialization, Strategies, Orchestration
- **Durée estimée** : 8-11 heures (4 phases)
- **Impact utilisateur** : Maximum (toutes les fonctions API publiques)

---

## Contexte et Motivation

### État Actuel du Système d'Exceptions

Après la migration complète, CTModels dispose d'un système d'exceptions enrichi avec :
- Messages structurés et clairs
- Champs optionnels (`got`, `expected`, `suggestion`, `context`)
- Affichage utilisateur-friendly
- Localisation précise (fichier, ligne, fonction)

**Exemple d'exception actuelle** :
```julia
throw(Exceptions.IncorrectArgument(
    "Invalid dimension: must be positive",
    got="n=-1",
    expected="n > 0 (positive integer)",
    suggestion="Use state!(ocp, n=3) with n > 0",
    context="state!(ocp, n=-1, name=\"x\") - validating dimension parameter"
))
```

### Limitation Identifiée

Le champ `context` montre actuellement le contexte **interne** (nom de fonction interne, type de validation), mais pas le contexte **API** (quelle fonction publique l'utilisateur a appelée, quelle action de haut niveau était en cours).

Pour les appels API imbriqués, cette limitation devient problématique.

---

## Problématique Identifiée

### Cas 1 : Appel API Simple

**Code utilisateur** :
```julia
ocp = PreModel()
state!(ocp, -1)  # Dimension invalide
```

**Exception actuelle** :
```
ERROR: IncorrectArgument: Invalid dimension: must be positive
Context: state!(ocp, n=-1, name="x") - validating dimension parameter
```

**Problème** : Le contexte montre la fonction interne, pas l'action utilisateur de haut niveau.

### Cas 2 : Appels API Imbriqués (Problème Principal)

**Code utilisateur** :
```julia
ocp = PreModel()
state!(ocp, 2)
control!(ocp, 1)
time!(ocp, t0=0, tf=1)
dynamics!(ocp, (dx, t, x, u, v) -> dx .= x + u)
objective!(ocp, :min, mayer=(x0, xf, v) -> xf[1])
definition!(ocp)
time_dependence!(ocp, autonomous=true)
model = build(ocp)

# Essayer de créer un initial guess avec mauvaises dimensions
init = build_initial_guess(model, (state=t -> [1.0, 2.0, 3.0], control=t -> [0.5]))
```

**Exception actuelle** :
```
ERROR: IncorrectArgument: State dimension mismatch
Got: 3 components in initial state
Expected: 2 components (matching state dimension)
Context: initial_state validation - dimension check

Stacktrace:
 [1] _validate_state_dimension(ocp::Model, state_fun::Function)
   @ CTModels.InitialGuess ~/CTModels.jl/src/InitialGuess/validation.jl:45
 [2] initial_state(ocp::Model, state_data::Function)
   @ CTModels.InitialGuess ~/CTModels.jl/src/InitialGuess/state.jl:78
 [3] _initial_guess_from_namedtuple(ocp::Model, data::NamedTuple)
   @ CTModels.InitialGuess ~/CTModels.jl/src/InitialGuess/builders.jl:156
 [4] build_initial_guess(ocp::Model, init_data::NamedTuple)
   @ CTModels.InitialGuess ~/CTModels.jl/src/InitialGuess/api.jl:113
```

**Problèmes** :
1. L'utilisateur voit une stacktrace Julia technique
2. Le contexte montre `initial_state validation` (fonction interne)
3. Pas clair que l'erreur vient de `build_initial_guess` (fonction API)
4. Le chemin complet `build_initial_guess → initial_guess → initial_state` n'est pas évident
5. Difficile de comprendre quelle action de haut niveau a échoué

### Cas 3 : Wrapper Patterns

Certaines fonctions API sont des wrappers minces :
```julia
function build_model(pre_ocp::PreModel; build_examodel=nothing)::Model
    return build(pre_ocp; build_examodel=build_examodel)
end
```

Si on wrappe les deux fonctions indépendamment, on aurait :
```
API Function: build_model
API Function: build    # Duplication !
```

**Besoin** : Un système qui évite la duplication et montre clairement la hiérarchie.

---

## Solution Proposée

### Concept : Call Chain Tracking

Au lieu de wrapper chaque exception individuellement, on crée un système qui **track la chaîne d'appels API** et l'affiche hiérarchiquement quand une exception se produit.

### Composants Clés

#### 1. Nouveaux Types d'Exceptions

```julia
# Information sur un appel API dans la chaîne
struct APICallInfo
    function_name::String      # "build_initial_guess"
    call_signature::String     # "build_initial_guess(model, (state=..., control=...))"
    user_action::String        # "Building initial guess from named tuple specification"
end

# Exception wrappée avec la chaîne d'appels
struct APICallChain <: CTModelsException
    original::CTModelsException  # Exception originale enrichie
    call_stack::Vector{APICallInfo}  # Chaîne d'appels API
end
```

#### 2. Stack Thread-Local

```julia
# Stack global (thread-local) pour tracker les appels API
const API_CALL_STACK = Ref{Union{Nothing, Vector{APICallInfo}}}(nothing)

function push_api_call!(func_name::String, signature::String, action::String)
    # Ajouter un appel à la stack
end

function pop_api_call!()
    # Retirer le dernier appel de la stack
end

function get_api_call_stack()::Vector{APICallInfo}
    # Obtenir une copie de la stack actuelle
end
```

#### 3. Macro de Wrapping

```julia
macro api_function(func_name_expr, user_action_expr, func_def)
    # Wrapper la fonction avec :
    # 1. Push sur la stack au début
    # 2. Try-catch pour capturer les exceptions
    # 3. Pop de la stack dans finally
    # 4. Wrapping de l'exception si nécessaire
end
```

**Usage** :
```julia
@api_function "state!" "Defining state dimension for optimal control problem" function state!(
    ocp::PreModel,
    n::Dimension,
    name::T1=__state_name(),
    components_names::Vector{T2}=__state_components(n, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}
    # Implementation existante inchangée
end
```

#### 4. Display Hiérarchique

```julia
function Base.showerror(io::IO, e::APICallChain)
    println(io, "ERROR: APICallChain wrapping ", typeof(e.original))
    println(io)
    
    # Afficher la chaîne d'appels
    if !isempty(e.call_stack)
        println(io, "API Call Chain:")
        for (i, call_info) in enumerate(e.call_stack)
            println(io, "  ", i, ". ", call_info.function_name)
            println(io, "     ", call_info.user_action)
            if i < length(e.call_stack)
                println(io)
            end
        end
        println(io)
    end
    
    # Afficher l'exception originale
    println(io, "Internal Error:")
    # ... afficher les détails de e.original
end
```

### Flux d'Exécution

**Exemple : `build_initial_guess(model, data)` avec erreur**

1. Utilisateur appelle `build_initial_guess(model, (state=..., control=...))`
2. Macro push : `["build_initial_guess", "...", "Building initial guess from named tuple"]`
3. Fonction appelle `initial_guess(model, ...)`
4. Macro push : `["initial_guess", "...", "Constructing validated initial guess"]`
5. Fonction appelle `initial_state(model, state_data)`
6. Macro push : `["initial_state", "...", "Processing state initialization"]`
7. Validation échoue → `throw(IncorrectArgument(...))`
8. Catch dans `initial_state` :
   - Wrap avec `APICallChain(exception, get_api_call_stack())`
   - Pop de la stack
   - Re-throw wrapped exception
9. Catch dans `initial_guess` :
   - Exception déjà wrapped → ne pas re-wrapper
   - Pop de la stack
   - Re-throw
10. Catch dans `build_initial_guess` :
    - Exception déjà wrapped → ne pas re-wrapper
    - Pop de la stack
    - Re-throw
11. Utilisateur voit l'exception avec la chaîne complète

### Gestion du Double Wrapping

Pour éviter de wrapper plusieurs fois :
```julia
function wrap_with_call_chain(e::Exception)
    if e isa APICallChain
        # Déjà wrapped, retourner tel quel
        return e
    elseif e isa CTModelsException
        # Première fois, wrapper avec la stack actuelle
        stack = get_api_call_stack()
        if !isempty(stack)
            return APICallChain(e, stack)
        end
    end
    # Pas une exception CTModels ou stack vide
    return e
end
```

---

## Architecture Technique

### Structure des Fichiers

#### Nouveaux Fichiers à Créer

```
src/Exceptions/
├── call_chain.jl      # Gestion de la stack d'appels API
└── wrapping.jl        # Utilitaires de wrapping d'exceptions

src/Utils/
└── macros.jl          # Étendre avec @api_function (fichier existe déjà)
```

#### Modifications aux Fichiers Existants

```
src/Exceptions/
├── types.jl           # Ajouter APICallChain et APICallInfo
├── display.jl         # Ajouter showerror pour APICallChain
└── Exceptions.jl      # Include nouveaux fichiers, export nouveaux types
```

### Détails d'Implémentation

#### `src/Exceptions/call_chain.jl`

````julia
"""
Call chain management for API exception contextualization.

This module provides a thread-local stack to track API function calls,
enabling rich error messages that show the complete call path from user
code to internal validation failures.
"""

# Thread-local storage for the API call stack
const API_CALL_STACK = Ref{Union{Nothing, Vector{APICallInfo}}}(nothing)

"""
    _ensure_stack_initialized()

Ensure the API call stack is initialized for the current task.
"""
function _ensure_stack_initialized()
    if API_CALL_STACK[] === nothing
        API_CALL_STACK[] = Vector{APICallInfo}()
    end
end

"""
    push_api_call!(func_name::String, signature::String, action::String)

Push an API call onto the call stack.

# Arguments
- `func_name`: Name of the API function (e.g., "state!")
- `signature`: Call signature (e.g., "state!(ocp, 2)")
- `action`: User-facing description of the action
"""
function push_api_call!(func_name::String, signature::String, action::String)
    _ensure_stack_initialized()
    push!(API_CALL_STACK[], APICallInfo(func_name, signature, action))
    return nothing
end

"""
    pop_api_call!()

Remove the most recent API call from the stack.
"""
function pop_api_call!()
    _ensure_stack_initialized()
    if !isempty(API_CALL_STACK[])
        pop!(API_CALL_STACK[])
    end
    return nothing
end

"""
    get_api_call_stack()::Vector{APICallInfo}

Get a copy of the current API call stack.
"""
function get_api_call_stack()::Vector{APICallInfo}
    _ensure_stack_initialized()
    return copy(API_CALL_STACK[])
end

"""
    clear_api_call_stack!()

Clear the API call stack. Useful for testing.
"""
function clear_api_call_stack!()
    _ensure_stack_initialized()
    empty!(API_CALL_STACK[])
    return nothing
end
````

#### `src/Exceptions/wrapping.jl`

````julia
"""
Exception wrapping utilities for API call chain system.
"""

"""
    wrap_with_call_chain(e::Exception)

Wrap an exception with the current API call chain if applicable.

# Arguments
- `e`: The exception to potentially wrap

# Returns
- `APICallChain` if `e` is a CTModelsException and stack is non-empty
- Original exception otherwise

# Notes
- Already wrapped exceptions (APICallChain) are returned unchanged
- Non-CTModels exceptions are returned unchanged
- Empty call stacks result in no wrapping
"""
function wrap_with_call_chain(e::Exception)
    if e isa APICallChain
        # Already wrapped, return as-is to avoid double wrapping
        return e
    elseif e isa CTModelsException
        # First time wrapping, use current call stack
        stack = get_api_call_stack()
        if !isempty(stack)
            return APICallChain(e, stack)
        end
    end
    # Not a CTModels exception or empty stack, return unchanged
    return e
end
````

#### `src/Utils/macros.jl` (extension)

````julia
"""
    @api_function func_name user_action function_definition

Wrap an API function to track calls in the exception call chain.

# Arguments
- `func_name`: String literal with the function name (e.g., "state!")
- `user_action`: String describing what the user is trying to do
- `function_definition`: The complete function definition

# Example
```julia
@api_function "state!" "Defining state dimension for optimal control problem" function state!(
    ocp::PreModel,
    n::Dimension,
    name::T1=__state_name(),
    components_names::Vector{T2}=__state_components(n, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}
    # Implementation
end
```

# Notes
- The macro automatically manages the call stack (push/pop)
- Exceptions are caught and wrapped with call chain context
- The finally block ensures stack cleanup even on errors
"""
macro api_function(func_name_expr, user_action_expr, func_def)
    # Extract function name and signature
    func_name = string(func_name_expr)
    user_action = user_action_expr
    
    # Parse function definition
    # This is simplified - real implementation needs proper AST parsing
    
    return quote
        function $(esc(func_def.args[1]))
            # Build signature string
            # (simplified - real version would capture actual argument values)
            signature = $(esc(func_name))
            
            # Push to call stack
            push_api_call!($(esc(func_name)), signature, $(esc(user_action)))
            
            try
                # Execute original function body
                result = $(esc(func_def.args[2]))
                return result
            catch e
                # Wrap exception with call chain if needed
                wrapped = wrap_with_call_chain(e)
                rethrow(wrapped)
            finally
                # Always pop from stack, even on error
                pop_api_call!()
            end
        end
    end
end
````

#### `src/Exceptions/types.jl` (ajouts)

````julia
"""
    APICallInfo

Information about a single API function call in the call chain.

# Fields
- `function_name::String`: Name of the API function (e.g., "state!")
- `call_signature::String`: How the function was called
- `user_action::String`: User-facing description of the action
"""
struct APICallInfo
    function_name::String
    call_signature::String
    user_action::String
end

"""
    APICallChain <: CTModelsException

Exception wrapper that includes the API call chain leading to the error.

This exception type wraps an original CTModelsException and adds context
about the sequence of API function calls that led to the error, making it
easier for users to understand the path from their code to the validation
failure.

# Fields
- `original::CTModelsException`: The original exception that was thrown
- `call_stack::Vector{APICallInfo}`: The API call chain at the time of error

# Example
```julia
# User calls: build_initial_guess(model, data)
# Which calls: initial_guess(model, ...)
# Which calls: initial_state(model, state_data)
# Which throws: IncorrectArgument(...)
# Result: APICallChain with 3-level call stack
```

# See Also
- [`APICallInfo`](@ref): Information about individual calls
- [`wrap_with_call_chain`](@ref): Wrapping utility
"""
struct APICallChain <: CTModelsException
    original::CTModelsException
    call_stack::Vector{APICallInfo}
end
````

#### `src/Exceptions/display.jl` (ajouts)

````julia
"""
Display function for APICallChain exceptions.
"""
function Base.showerror(io::IO, e::APICallChain)
    println(io, "ERROR: APICallChain wrapping ", typeof(e.original))
    println(io)
    
    # Display call chain if non-empty
    if !isempty(e.call_stack)
        println(io, "API Call Chain:")
        for (i, call_info) in enumerate(e.call_stack)
            println(io, "  ", i, ". ", call_info.function_name, "(", call_info.call_signature, ")")
            println(io, "     ", call_info.user_action)
            if i < length(e.call_stack)
                println(io)
            end
        end
        println(io)
    end
    
    # Display original exception details
    println(io, "Internal Error:")
    println(io, "  Message: ", e.original.msg)
    
    # Display type-specific fields
    if e.original isa IncorrectArgument
        if e.original.got !== nothing
            println(io, "  Got: ", e.original.got)
        end
        if e.original.expected !== nothing
            println(io, "  Expected: ", e.original.expected)
        end
        if e.original.suggestion !== nothing
            println(io, "  Suggestion: ", e.original.suggestion)
        end
        if e.original.context !== nothing
            println(io, "  Context: ", e.original.context)
        end
    elseif e.original isa UnauthorizedCall
        if e.original.reason !== nothing
            println(io, "  Reason: ", e.original.reason)
        end
        if e.original.suggestion !== nothing
            println(io, "  Suggestion: ", e.original.suggestion)
        end
        if e.original.context !== nothing
            println(io, "  Context: ", e.original.context)
        end
    elseif e.original isa NotImplemented
        if e.original.type_info !== nothing
            println(io, "  Type: ", e.original.type_info)
        end
        if e.original.suggestion !== nothing
            println(io, "  Suggestion: ", e.original.suggestion)
        end
        if e.original.context !== nothing
            println(io, "  Context: ", e.original.context)
        end
    elseif e.original isa ParsingError
        if e.original.location !== nothing
            println(io, "  Location: ", e.original.location)
        end
        if e.original.suggestion !== nothing
            println(io, "  Suggestion: ", e.original.suggestion)
        end
    end
end
````

---

## Fonctions Prioritaires

### Tier 1 : Core OCP (Priorité Maximale)

**Component Builders (5 fonctions)** :
- `state!(ocp, n, ...)` - Définir la dimension d'état
- `control!(ocp, n, ...)` - Définir la dimension de contrôle
- `time!(ocp, t0, tf, ...)` - Définir l'horizon temporel
- `dynamics!(ocp, f)` - Définir la dynamique
- `objective!(ocp, criterion, ...)` - Définir l'objectif

**Model Building (2 fonctions)** :
- `build(pre_ocp)` - Construire le modèle final
- `build_model(pre_ocp)` - Alias pour build

**Justification** : Ces fonctions sont utilisées dans 100% des workflows OCP. Ce sont les points d'entrée principaux de l'API.

### Tier 2 : OCP Additionnel (Priorité Haute)

**Component Builders Additionnels (4 fonctions)** :
- `variable!(ocp, n, ...)` - Définir la dimension de variable
- `constraint!(ocp, type, ...)` - Ajouter des contraintes
- `definition!(ocp)` - Définir le problème
- `time_dependence!(ocp, ...)` - Définir l'autonomie

**Justification** : Fonctions fréquemment utilisées, complètent le workflow OCP de base.

### Tier 3 : InitialGuess (Priorité Moyenne)

**Initial Guess Functions (3 fonctions)** :
- `initial_guess(ocp, ...)` - Créer un initial guess validé
- `build_initial_guess(ocp, data)` - Construire depuis divers formats
- `validate_initial_guess(ocp, init)` - Valider un initial guess

**Justification** : Utilisées pour warm-start, souvent avec imbrication complexe.

### Tier 4 : Serialization (Priorité Basse)

**Serialization Functions (2 fonctions)** :
- `export_ocp_solution(sol, ...)` - Exporter une solution
- `import_ocp_solution(ocp, ...)` - Importer une solution

**Justification** : Moins fréquemment utilisées, mais bénéficient du contexte API.

### Résumé

| Tier | Module | Nombre de Fonctions | Priorité |
|------|--------|---------------------|----------|
| 1 | OCP Core | 7 | Maximum |
| 2 | OCP Additionnel | 4 | Haute |
| 3 | InitialGuess | 3 | Moyenne |
| 4 | Serialization | 2 | Basse |
| **Total** | | **16** | |

---

## Plan d'Implémentation

### Phase 1 : Infrastructure (2-3 heures)

**Objectif** : Créer tous les composants de base du système.

**Fichiers à créer** :
- `src/Exceptions/call_chain.jl` - Gestion de la stack
- `src/Exceptions/wrapping.jl` - Wrapping d'exceptions

**Fichiers à modifier** :
- `src/Exceptions/types.jl` - Ajouter `APICallChain` et `APICallInfo`
- `src/Exceptions/display.jl` - Ajouter `showerror` pour `APICallChain`
- `src/Exceptions/Exceptions.jl` - Include nouveaux fichiers, exports
- `src/Utils/macros.jl` - Ajouter macro `@api_function`

**Tests à créer** :
- `test/suite/exceptions/test_call_chain.jl` - Tests de la stack
- `test/suite/exceptions/test_api_wrapping.jl` - Tests du wrapping

**Validation** :
- Tests unitaires pour push/pop/get stack
- Tests de wrap_with_call_chain
- Tests de display pour APICallChain
- Pas de régression sur tests existants

### Phase 2 : Tier 1 Functions (2-3 heures)

**Objectif** : Wrapper les 7 fonctions core OCP.

**Fichiers à modifier** :
- `src/OCP/Components/state.jl` - Wrapper `state!`
- `src/OCP/Components/control.jl` - Wrapper `control!`
- `src/OCP/Components/times.jl` - Wrapper `time!`
- `src/OCP/Components/dynamics.jl` - Wrapper `dynamics!`
- `src/OCP/Components/objective.jl` - Wrapper `objective!`
- `src/OCP/Building/model.jl` - Wrapper `build` et `build_model`

**Tests** :
- Test chaque fonction wrappée individuellement
- Test appels imbriqués (e.g., build appelle validations)
- Vérifier affichage de la call chain
- Vérifier que tests existants passent

**Validation** :
- Toutes les fonctions Tier 1 wrappées
- Call chain correcte pour appels imbriqués
- Pas de régression

### Phase 3 : Tiers 2-4 (2-3 heures)

**Objectif** : Wrapper les fonctions des autres modules.

**Tier 2 - OCP Additionnel** :
- `src/OCP/Components/variable.jl` - Wrapper `variable!`
- `src/OCP/Components/constraints.jl` - Wrapper `constraint!`
- `src/OCP/Core/definition.jl` - Wrapper `definition!`
- `src/OCP/Core/time_dependence.jl` - Wrapper `time_dependence!`

**Tier 3 - InitialGuess** :
- `src/InitialGuess/api.jl` - Wrapper `initial_guess`, `build_initial_guess`, `validate_initial_guess`

**Tier 4 - Serialization** :
- `src/Serialization/export_import.jl` - Wrapper `export_ocp_solution`, `import_ocp_solution`

**Tests** :
- Tests cross-module (e.g., build → initial_guess)
- Tests de scénarios complexes d'imbrication
- Vérifier cohérence des call chains

**Validation** :
- Toutes les fonctions prioritaires wrappées
- Call chains correctes pour tous les scénarios
- Tests passent

### Phase 4 : Polish et Documentation (1-2 heures)

**Objectif** : Finaliser, documenter, optimiser.

**Tâches** :
- Raffiner le format d'affichage basé sur exemples réels
- Ajouter docstrings pour tous les nouveaux types et fonctions
- Mettre à jour la documentation du module Exceptions
- Créer des exemples dans la documentation
- Tests de performance (vérifier overhead < 1%)
- Vérifier que tous les tests existants passent
- Créer rapport final de projet

**Validation** :
- Documentation complète
- Exemples clairs
- Performance acceptable
- Tous tests passent
- Code review ready

### Estimation Totale

| Phase | Durée | Cumul |
|-------|-------|-------|
| Phase 1 | 2-3h | 2-3h |
| Phase 2 | 2-3h | 4-6h |
| Phase 3 | 2-3h | 6-9h |
| Phase 4 | 1-2h | 7-11h |

**Total** : 7-11 heures de développement

---

## Exemples Concrets

### Exemple 1 : Appel Simple avec Erreur de Validation

**Code utilisateur** :
```julia
using CTModels

ocp = PreModel()
state!(ocp, -1)  # Dimension invalide
```

**Sortie actuelle (sans call chain)** :
```
ERROR: IncorrectArgument: Invalid dimension: must be positive

Message: Invalid dimension: must be positive
Got: n=-1
Expected: n > 0 (positive integer)
Suggestion: Use state!(ocp, n=3) with n > 0
Context: state!(ocp, n=-1, name="x") - validating dimension parameter
```

**Sortie avec call chain** :
```
ERROR: APICallChain wrapping IncorrectArgument

API Call Chain:
  1. state!(ocp, -1)
     Defining state dimension for optimal control problem

Internal Error:
  Message: Invalid dimension: must be positive
  Got: n=-1
  Expected: n > 0 (positive integer)
  Suggestion: Use state!(ocp, n=3) with n > 0
  Context: state!(ocp, n=-1, name="x") - validating dimension parameter
```

**Amélioration** : Même pour un appel simple, le contexte API est clair.

### Exemple 2 : Validation build() Sans definition!

**Code utilisateur** :
```julia
using CTModels

ocp = PreModel()
state!(ocp, 2)
control!(ocp, 1)
time!(ocp, t0=0, tf=1)
dynamics!(ocp, (dx, t, x, u, v) -> dx .= x + u)
objective!(ocp, :min, mayer=(x0, xf, v) -> xf[1])
# Oublié : definition!(ocp)
model = build(ocp)
```

**Sortie actuelle** :
```
ERROR: UnauthorizedCall: Definition must be set before building model

Message: Definition must be set before building model
Reason: definition has not been set yet
Suggestion: Call definition!(pre_ocp) before building
Context: build function - definition validation
```

**Sortie avec call chain** :
```
ERROR: APICallChain wrapping UnauthorizedCall

API Call Chain:
  1. build(ocp)
     Building final optimal control model from PreModel

Internal Error:
  Message: Definition must be set before building model
  Reason: definition has not been set yet
  Suggestion: Call definition!(pre_ocp) before building
  Context: build function - definition validation
```

**Amélioration** : Clair que l'erreur vient du build, pas d'une fonction interne.

### Exemple 3 : Imbrication Profonde - InitialGuess

**Code utilisateur** :
```julia
using CTModels

# Créer un OCP valide
ocp = PreModel()
state!(ocp, 2)
control!(ocp, 1)
time!(ocp, t0=0, tf=1)
dynamics!(ocp, (dx, t, x, u, v) -> dx .= x + u)
objective!(ocp, :min, mayer=(x0, xf, v) -> xf[1])
definition!(ocp)
time_dependence!(ocp, autonomous=true)
model = build(ocp)

# Initial guess avec mauvaises dimensions
init = build_initial_guess(model, (state=t -> [1.0, 2.0, 3.0], control=t -> [0.5]))
```

**Sortie actuelle** :
```
ERROR: IncorrectArgument: State dimension mismatch

Message: State dimension mismatch
Got: 3 components in initial state
Expected: 2 components (matching state dimension)
Suggestion: Provide initial state with correct dimension: state=t -> [x1, x2]
Context: initial_state validation - dimension check

Stacktrace:
 [1] _validate_state_dimension(ocp::Model, state_fun::Function)
   @ CTModels.InitialGuess ~/CTModels.jl/src/InitialGuess/validation.jl:45
 [2] initial_state(ocp::Model, state_data::Function)
   @ CTModels.InitialGuess ~/CTModels.jl/src/InitialGuess/state.jl:78
 [3] _initial_guess_from_namedtuple(ocp::Model, data::NamedTuple)
   @ CTModels.InitialGuess ~/CTModels.jl/src/InitialGuess/builders.jl:156
 [4] build_initial_guess(ocp::Model, init_data::NamedTuple)
   @ CTModels.InitialGuess ~/CTModels.jl/src/InitialGuess/api.jl:113
```

**Sortie avec call chain** :
```
ERROR: APICallChain wrapping IncorrectArgument

API Call Chain:
  1. build_initial_guess(model, (state=..., control=...))
     Building initial guess from named tuple specification
  
  2. initial_guess(model; state=..., control=...)
     Constructing validated initial guess for optimal control problem
  
  3. initial_state(model, state_data)
     Processing state initialization data

Internal Error:
  Message: State dimension mismatch
  Got: 3 components in initial state
  Expected: 2 components (matching state dimension)
  Suggestion: Provide initial state with correct dimension: state=t -> [x1, x2]
  Context: initial_state validation - dimension check
```

**Amélioration** : Le chemin complet est visible :
1. L'utilisateur a appelé `build_initial_guess` avec un named tuple
2. Qui a appelé `initial_guess` pour construire le guess
3. Qui a appelé `initial_state` pour traiter les données d'état
4. Où la validation a échoué

### Exemple 4 : Serialization avec Format Invalide

**Code utilisateur** :
```julia
using CTModels

# Assumer qu'on a une solution
sol = solve(model, ...)

# Essayer d'exporter avec format invalide
export_ocp_solution(sol, format=:INVALID, filename="my_solution")
```

**Sortie actuelle** :
```
ERROR: IncorrectArgument: Invalid export format specified

Message: Invalid export format specified
Got: format=INVALID
Expected: :JLD or :JSON
Suggestion: Use format=:JLD for binary files or format=:JSON for text files
Context: export_ocp_solution - validating export format
```

**Sortie avec call chain** :
```
ERROR: APICallChain wrapping IncorrectArgument

API Call Chain:
  1. export_ocp_solution(sol, format=:INVALID, filename="my_solution")
     Exporting optimal control solution to file

Internal Error:
  Message: Invalid export format specified
  Got: format=INVALID
  Expected: :JLD or :JSON
  Suggestion: Use format=:JLD for binary files or format=:JSON for text files
  Context: export_ocp_solution - validating export format
```

**Amélioration** : Contexte cohérent même pour appel simple.

### Exemple 5 : Warm-Start avec Solution Incompatible

**Code utilisateur** :
```julia
using CTModels

ocp = PreModel()
state!(ocp, 2)
control!(ocp, 1)
time!(ocp, t0=0, tf=1)
dynamics!(ocp, (dx, t, x, u, v) -> dx .= x + u)
objective!(ocp, :min, mayer=(x0, xf, v) -> xf[1])
definition!(ocp)
time_dependence!(ocp, autonomous=true)
model = build(ocp)

# Solution d'un autre OCP avec dimensions différentes
old_sol = Solution(...)  # control dimension = 2
init = build_initial_guess(model, old_sol)
```

**Sortie actuelle** :
```
ERROR: IncorrectArgument: Control dimension mismatch in solution

Message: Control dimension mismatch in solution
Got: control dimension 2 in solution
Expected: control dimension 1 (matching model)
Suggestion: Ensure solution comes from compatible OCP
Context: _initial_guess_from_solution - dimension validation
```

**Sortie avec call chain** :
```
ERROR: APICallChain wrapping IncorrectArgument

API Call Chain:
  1. build_initial_guess(model, old_sol)
     Building initial guess from previous solution (warm start)
  
  2. validate_solution_dimensions(model, old_sol)
     Validating solution dimensions match model requirements

Internal Error:
  Message: Control dimension mismatch in solution
  Got: control dimension 2 in solution
  Expected: control dimension 1 (matching model)
  Suggestion: Ensure solution comes from compatible OCP
  Context: _initial_guess_from_solution - dimension validation
```

**Amélioration** : Clair que l'utilisateur essayait de warm-start et que la validation a détecté une incompatibilité.

---

## Bénéfices Attendus

### 1. Expérience Utilisateur Améliorée

**Avant** : Messages d'erreur techniques avec stacktraces Julia
**Après** : Chemin clair de l'action utilisateur à l'erreur

### 2. Clarté du Chemin d'Erreur

**Avant** : Contexte interne uniquement (`initial_state validation`)
**Après** : Contexte API complet (`build_initial_guess → initial_guess → initial_state`)

### 3. Pas de Duplication

**Problème évité** : Afficher "API Function" plusieurs fois pour appels imbriqués
**Solution** : Chaîne hiérarchique claire

### 4. Contexte Complet

**Niveau API** : Quelle fonction publique l'utilisateur a appelée
**Niveau interne** : Quelle validation a échoué et pourquoi

### 5. Aide au Débogage

**Pour l'utilisateur** : Comprendre rapidement ce qui a mal tourné
**Pour le développeur** : Voir le chemin d'exécution complet

### 6. Cohérence

**Tous les appels** : Format uniforme (simple ou imbriqué)
**Tous les modules** : Même système de call chain

### 7. Rétrocompatibilité

**Exceptions existantes** : Toujours fonctionnelles
**Code existant** : Pas de breaking changes
**Tests existants** : Doivent tous passer

---

## Critères de Succès

### Critères Fonctionnels

- [ ] Toutes les fonctions Tier 1 wrappées et testées
- [ ] Call chain affichée correctement pour appels imbriqués
- [ ] Format cohérent pour appels simples et imbriqués
- [ ] Pas de duplication "API Function" dans les chaînes
- [ ] Exceptions non-CTModels passent sans modification

### Critères de Qualité

- [ ] Tous les tests existants passent (4311 tests)
- [ ] Nouveaux tests pour call chain (>20 tests)
- [ ] Couverture de code maintenue (>85%)
- [ ] Pas de warnings Julia
- [ ] Code review approuvé

### Critères de Performance

- [ ] Overhead < 1% pour les chemins d'exception
- [ ] Pas d'impact sur chemins sans exception
- [ ] Stack management efficace (O(1) push/pop)

### Critères de Documentation

- [ ] Docstrings pour tous les nouveaux types
- [ ] Docstrings pour toutes les nouvelles fonctions
- [ ] Exemples dans la documentation
- [ ] Guide d'utilisation mis à jour
- [ ] Rapport final de projet créé

### Critères de Déploiement

- [ ] Branche feature créée
- [ ] Commits atomiques et bien documentés
- [ ] Pull request avec description complète
- [ ] CI/CD passe (tests, linting, docs)
- [ ] Review approuvée par au moins 2 reviewers

---

## Références

### Documents de Planification

- **Architecture détaillée** : `/Users/ocots/.windsurf/plans/exception-call-chain-system-859bd8.md`
- **Plan d'implémentation** : `/Users/ocots/.windsurf/plans/exception-call-chain-implementation-859bd8.md`
- **Exemples concrets** : `/Users/ocots/.windsurf/plans/exception-chain-examples-859bd8.md`

### Documents du Projet de Migration

- **Guide de référence** : `01_exception_migration_reference.md` (ce répertoire)
- **Rapport final** : `/reports/2026-01-30_Exceptions/progress/04_complete_migration_report.md`
- **Standards de développement** : `00_development_standards_reference.md` (ce répertoire)

### Code Source Pertinent

- **Module Exceptions** : `/src/Exceptions/`
- **Module Utils** : `/src/Utils/macros.jl`
- **Composants OCP** : `/src/OCP/Components/`
- **InitialGuess** : `/src/InitialGuess/`
- **Serialization** : `/src/Serialization/`

### Tests

- **Tests exceptions** : `/test/suite/exceptions/`
- **Tests OCP** : `/test/suite/ocp/`
- **Tests InitialGuess** : `/test/suite/initial_guess/`

---

## Checklist de Validation

### Phase 1 : Infrastructure

- [ ] Fichier `call_chain.jl` créé avec stack management
- [ ] Fichier `wrapping.jl` créé avec wrapping utilities
- [ ] Types `APICallChain` et `APICallInfo` ajoutés
- [ ] Display pour `APICallChain` implémenté
- [ ] Macro `@api_function` créée
- [ ] Tests unitaires pour stack (push/pop/get/clear)
- [ ] Tests pour wrapping (wrap/no-wrap/double-wrap)
- [ ] Tests pour display
- [ ] Tous tests existants passent

### Phase 2 : Tier 1 Functions

- [ ] `state!` wrappée
- [ ] `control!` wrappée
- [ ] `time!` wrappée
- [ ] `dynamics!` wrappée
- [ ] `objective!` wrappée
- [ ] `build` wrappée
- [ ] `build_model` wrappée
- [ ] Tests pour chaque fonction
- [ ] Tests pour appels imbriqués
- [ ] Tous tests existants passent

### Phase 3 : Tiers 2-4

- [ ] Tier 2 : `variable!`, `constraint!`, `definition!`, `time_dependence!`
- [ ] Tier 3 : `initial_guess`, `build_initial_guess`, `validate_initial_guess`
- [ ] Tier 4 : `export_ocp_solution`, `import_ocp_solution`
- [ ] Tests cross-module
- [ ] Tests scénarios complexes
- [ ] Tous tests existants passent

### Phase 4 : Polish

- [ ] Format d'affichage raffiné
- [ ] Docstrings complets
- [ ] Documentation mise à jour
- [ ] Exemples ajoutés
- [ ] Tests de performance
- [ ] Rapport final créé
- [ ] Code review ready

---

**Note** : Ce document est un guide de référence vivant. Il sera mis à jour au fur et à mesure de l'avancement du projet avec les retours d'expérience et les ajustements nécessaires.
