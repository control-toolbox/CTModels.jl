# OCP Components - Defensive Validation Enhancement

**Date**: 2026-01-28  
**Version**: 1.0  
**Status**: ✅ **REFERENCE** - Specification & Action Plan

---

## Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Règles de Validation](#règles-de-validation)
3. [Architecture de Solution](#architecture-de-solution)
4. [Spécifications Détaillées](#spécifications-détaillées)
5. [Plan d'Action](#plan-daction)
6. [Références](#références)

---

## Vue d'Ensemble

### Objectif

Améliorer la robustesse des composants OCP (Optimal Control Problem) en ajoutant des **validations défensives complètes** pour garantir l'unicité et la cohérence des noms à travers tous les composants du modèle.

### Problèmes Identifiés

L'audit complet a révélé **deux catégories critiques** de validations manquantes :

#### 1. Validations Internes (par composant)

- ❌ Conflit `name` vs `components_names` non détecté
- ❌ Doublons dans `components_names` non détectés
- ❌ Noms vides acceptés

#### 2. Validations Inter-Composants (globales)

- ❌ Conflit entre `state.name` et `control.name`
- ❌ Conflit entre composants de différents types (ex: `state.components[1]` vs `control.name`)
- ❌ Conflit avec `time_name`
- ❌ Aucune garantie d'unicité globale des noms

### Fichiers Concernés

| Fichier | Priorité | Validations Manquantes |
| --- | --- | --- |
| [`src/OCP/Components/state.jl`](../../../src/OCP/Components/state.jl) | **CRITIQUE** | Internes + Inter-composants |
| [`src/OCP/Components/control.jl`](../../../src/OCP/Components/control.jl) | **CRITIQUE** | Internes + Inter-composants |
| [`src/OCP/Components/variable.jl`](../../../src/OCP/Components/variable.jl) | **CRITIQUE** | Internes + Inter-composants |
| [`src/OCP/Components/times.jl`](../../../src/OCP/Components/times.jl) | **HAUTE** | Inter-composants + t0 < tf |
| [`src/OCP/Components/objective.jl`](../../../src/OCP/Components/objective.jl) | **BASSE** | Validation criterion |
| [`src/OCP/Components/constraints.jl`](../../../src/OCP/Components/constraints.jl) | **BASSE** | Validation lb ≤ ub |

### Documents d'Analyse

- [Audit Complet](../analysis/00_audit_report.md) - Analyse détaillée par fichier
- [Conflits Inter-Composants](../analysis/01_inter_component_conflicts_analysis.md) - Analyse spécifique des conflits globaux

---

## Règles de Validation

### Règle 1: Unicité Globale des Noms

**Principe**: Tous les noms utilisés dans le modèle OCP doivent être **globalement uniques**.

**Scope**: 
- `time_name` (si défini)
- `state.name` + `state.components`
- `control.name` + `control.components`
- `variable.name` + `variable.components` (si non vide)

**Justification**:
- Évite les ambiguïtés dans l'affichage et les références
- Prévient les conflits dans les solveurs
- Assure la cohérence de l'interface utilisateur

**Exemples de violations**:

```julia
# ❌ INTERDIT: state.name = control.name
state!(ocp, 2, "x", ["x₁", "x₂"])
control!(ocp, 1, "x")  # Erreur!

# ❌ INTERDIT: state.component = control.name
state!(ocp, 2, "x", ["u", "v"])
control!(ocp, 1, "u")  # Erreur!

# ❌ INTERDIT: time_name = state.name
time!(ocp, t0=0, tf=1, time_name="x")
state!(ocp, 2, "x")  # Erreur!
```

### Règle 2: Unicité Interne des Composants

**Principe**: Au sein d'un même composant, `name` et `components_names` doivent être distincts et sans doublons.

**Validations**:
1. `name ∉ components_names`
2. `components_names` sans doublons
3. Tous les noms non vides

**Exemples de violations**:

```julia
# ❌ INTERDIT: name dans components
state!(ocp, 2, "x", ["x", "y"])  # Erreur!

# ❌ INTERDIT: doublons dans components
state!(ocp, 2, "x", ["y", "y"])  # Erreur!

# ❌ INTERDIT: noms vides
state!(ocp, 1, "")  # Erreur!
state!(ocp, 2, "x", ["", "y"])  # Erreur!
```

### Règle 3: Cohérence des Valeurs Temporelles

**Principe**: Quand `t0` et `tf` sont tous deux fixes, on doit avoir `t0 < tf`.

**Validation**:

```julia
# ❌ INTERDIT: t0 ≥ tf
time!(ocp, t0=1.0, tf=0.0)  # Erreur!
time!(ocp, t0=1.0, tf=1.0)  # Erreur!
```

### Règle 4: Validité des Bornes

**Principe**: Pour les contraintes, `lb ≤ ub` élément par élément.

**Validation**:

```julia
# ❌ INTERDIT: lb > ub
constraint!(ocp, :state, lb=[1.0, 2.0], ub=[0.0, 3.0])  # Erreur sur premier élément!
```

### Règle 5: Validité du Critère

**Principe**: Le critère d'optimisation doit être `:min` ou `:max`.

**Validation**:

```julia
# ❌ INTERDIT: critère invalide
objective!(ocp, :minimize, mayer=f)  # Erreur! Doit être :min
```

---

## Architecture de Solution

### Nouveau Module: Name Validation

**Fichier**: `src/OCP/Validation/name_validation.jl`

Ce module centralisera toute la logique de validation des noms.

#### Fonction 1: Collecter les Noms Existants

````julia
"""
    __collect_used_names(ocp::PreModel)::Vector{String}

Collect all names already used in the PreModel across all components.

Returns a vector containing:
- Time name (if set)
- State name and components (if set)
- Control name and components (if set)
- Variable name and components (if set and non-empty)

# Example

```julia-repl
julia> ocp = PreModel()
julia> state!(ocp, 2, "x", ["x₁", "x₂"])
julia> control!(ocp, 1, "u")
julia> __collect_used_names(ocp)
3-element Vector{String}:
 "x"
 "x₁"
 "x₂"
 "u"
```

See also: [`__has_name_conflict`](@ref), [`__validate_name_uniqueness`](@ref)
"""
function __collect_used_names(ocp::PreModel)::Vector{String}
    names = String[]
    
    # Time name
    if __is_times_set(ocp)
        push!(names, time_name(ocp.times))
    end
    
    # State name and components
    if __is_state_set(ocp)
        push!(names, name(ocp.state))
        append!(names, components(ocp.state))
    end
    
    # Control name and components
    if __is_control_set(ocp)
        push!(names, name(ocp.control))
        append!(names, components(ocp.control))
    end
    
    # Variable name and components (if not empty)
    if __is_variable_set(ocp)
        var_model = ocp.variable
        if !isa(var_model, EmptyVariableModel)
            push!(names, name(var_model))
            append!(names, components(var_model))
        end
    end
    
    return names
end
````

#### Fonction 2: Vérifier les Conflits

````julia
"""
    __has_name_conflict(ocp::PreModel, new_name::String, exclude_component::Symbol=:none)::Bool

Check if a name conflicts with existing names in the PreModel.

# Arguments

- `ocp::PreModel`: The model to check against
- `new_name::String`: The new name to check
- `exclude_component::Symbol`: Component type to exclude from check (`:state`, `:control`, `:variable`, `:time`, `:none`)

The `exclude_component` parameter allows checking for conflicts while updating a component,
excluding the component's own current names from the check.

# Returns

- `Bool`: `true` if conflict exists, `false` otherwise

# Example

```julia-repl
julia> ocp = PreModel()
julia> state!(ocp, 2, "x", ["x₁", "x₂"])
julia> __has_name_conflict(ocp, "x", :none)
true

julia> __has_name_conflict(ocp, "y", :none)
false
```

See also: [`__collect_used_names`](@ref), [`__validate_name_uniqueness`](@ref)
"""
function __has_name_conflict(ocp::PreModel, new_name::String, exclude_component::Symbol=:none)::Bool
    existing_names = __collect_used_names(ocp)
    
    # Remove names from the component being updated
    if exclude_component == :state && __is_state_set(ocp)
        filter!(x -> x != name(ocp.state), existing_names)
        filter!(x -> x ∉ components(ocp.state), existing_names)
    elseif exclude_component == :control && __is_control_set(ocp)
        filter!(x -> x != name(ocp.control), existing_names)
        filter!(x -> x ∉ components(ocp.control), existing_names)
    elseif exclude_component == :variable && __is_variable_set(ocp)
        var_model = ocp.variable
        if !isa(var_model, EmptyVariableModel)
            filter!(x -> x != name(var_model), existing_names)
            filter!(x -> x ∉ components(var_model), existing_names)
        end
    elseif exclude_component == :time && __is_times_set(ocp)
        filter!(x -> x != time_name(ocp.times), existing_names)
    end
    
    return new_name ∈ existing_names
end
````

#### Fonction 3: Valider l'Unicité (Helper de haut niveau)

````julia
"""
    __validate_name_uniqueness(ocp::PreModel, name::String, components::Vector{String}, 
                               component_type::Symbol)

Validate that a name and its components don't conflict with existing names.

Performs comprehensive validation:
1. Name is not empty
2. Components are not empty
3. Name not in components (internal conflict)
4. No duplicates in components
5. No conflicts with existing names in other components (global uniqueness)

# Arguments

- `ocp::PreModel`: The model to validate against
- `name::String`: The component name
- `components::Vector{String}`: The component names
- `component_type::Symbol`: Type of component (`:state`, `:control`, `:variable`, `:time`)

# Throws

- `CTBase.IncorrectArgument`: If any validation fails

# Example

```julia-repl
julia> ocp = PreModel()
julia> state!(ocp, 2, "x", ["x₁", "x₂"])
julia> __validate_name_uniqueness(ocp, "x", ["u"], :control)  # Would throw if "x" conflicts
```

See also: [`__has_name_conflict`](@ref), [`__collect_used_names`](@ref)
"""
function __validate_name_uniqueness(
    ocp::PreModel, 
    name::String, 
    components::Vector{String}, 
    component_type::Symbol
)
    component_label = String(component_type)
    
    # 1. Name is not empty
    @ensure !isempty(name) CTBase.IncorrectArgument(
        "The $component_label name cannot be empty"
    )
    
    # 2. Components are not empty
    @ensure all(!isempty(c) for c in components) CTBase.IncorrectArgument(
        "Component names cannot be empty for $component_label"
    )
    
    # 3. Name not in components (internal conflict)
    @ensure !(name ∈ components) CTBase.IncorrectArgument(
        "The $component_label name '$name' cannot be one of the component names: $components"
    )
    
    # 4. No duplicates in components
    @ensure length(unique(components)) == length(components) CTBase.IncorrectArgument(
        "Component names must be unique for $component_label. Found duplicates in: $components"
    )
    
    # 5. No conflicts with existing names (global uniqueness)
    @ensure !__has_name_conflict(ocp, name, component_type) CTBase.IncorrectArgument(
        "The $component_label name '$name' conflicts with existing names: $(__collect_used_names(ocp))"
    )
    
    for comp_name in components
        @ensure !__has_name_conflict(ocp, comp_name, component_type) CTBase.IncorrectArgument(
            "The $component_label component '$comp_name' conflicts with existing names: $(__collect_used_names(ocp))"
        )
    end
end
````

---

## Spécifications Détaillées

### 1. state.jl

**Fichier**: [`src/OCP/Components/state.jl`](../../../src/OCP/Components/state.jl)

#### Modifications à Apporter

```julia
function state!(
    ocp::PreModel,
    n::Dimension,
    name::T1=__state_name(),
    components_names::Vector{T2}=__state_components(n, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}

    # Existing checks
    @ensure !__is_state_set(ocp) CTBase.UnauthorizedCall("the state has already been set.")
    @ensure n > 0 CTBase.IncorrectArgument("the state dimension must be greater than 0")
    @ensure size(components_names, 1) == n CTBase.IncorrectArgument(
        "the number of state names must be equal to the state dimension"
    )

    # NEW: Comprehensive name validation
    __validate_name_uniqueness(ocp, string(name), string.(components_names), :state)

    # Set the state
    ocp.state = StateModel(string(name), string.(components_names))

    return nothing
end
```

#### Documentation à Ajouter

```julia
# Throws
- `CTBase.UnauthorizedCall`: If state has already been set
- `CTBase.IncorrectArgument`: If n ≤ 0
- `CTBase.IncorrectArgument`: If number of component names ≠ n
- `CTBase.IncorrectArgument`: If name is empty
- `CTBase.IncorrectArgument`: If any component name is empty
- `CTBase.IncorrectArgument`: If name is one of the component names
- `CTBase.IncorrectArgument`: If component names contain duplicates
- `CTBase.IncorrectArgument`: If name conflicts with existing names in other components
- `CTBase.IncorrectArgument`: If any component name conflicts with existing names
```

#### Tests à Ajouter

**Fichier**: [`test/suite/ocp/test_state.jl`](../../../test/suite/ocp/test_state.jl)

```julia
@testset "state! - Internal name validation" begin
    # Empty name
    ocp = CTModels.PreModel()
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 1, "")
    
    # Empty component name
    ocp = CTModels.PreModel()
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 2, "x", ["", "y"])
    
    # Name in components
    ocp = CTModels.PreModel()
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 2, "x", ["x", "y"])
    
    # Duplicate components
    ocp = CTModels.PreModel()
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 2, "x", ["y", "y"])
end

@testset "state! - Inter-component conflicts" begin
    # state.name vs control.name
    ocp = CTModels.PreModel()
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    CTModels.control!(ocp, 1, "u")
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 1, "u")  # Conflict!
    
    # state.component vs control.name
    ocp = CTModels.PreModel()
    CTModels.control!(ocp, 1, "u")
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 2, "x", ["u", "v"])
    
    # state.name vs time_name
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="t")
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 1, "t")
end

@testset "state! - Type stability" begin
    ocp = CTModels.PreModel()
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    @inferred CTModels.name(ocp.state)
    @inferred CTModels.components(ocp.state)
    @inferred CTModels.dimension(ocp.state)
end
```

### 2. control.jl

**Fichier**: [`src/OCP/Components/control.jl`](../../../src/OCP/Components/control.jl)

#### Modifications

Identiques à `state.jl`, en remplaçant `:state` par `:control`.

```julia
# NEW: Comprehensive name validation
__validate_name_uniqueness(ocp, string(name), string.(components_names), :control)
```

#### Tests

**Fichier**: [`test/suite/ocp/test_control.jl`](../../../test/suite/ocp/test_control.jl) (à créer)

Similaires à `test_state.jl`.

### 3. variable.jl

**Fichier**: [`src/OCP/Components/variable.jl`](../../../src/OCP/Components/variable.jl)

#### Modifications

```julia
function variable!(
    ocp::PreModel,
    q::Dimension,
    name::T1=__variable_name(q),
    components_names::Vector{T2}=__variable_components(q, string(name)),
)::Nothing where {T1<:Union{String,Symbol},T2<:Union{String,Symbol}}
    
    # Existing checks
    @ensure !__is_variable_set(ocp) CTBase.UnauthorizedCall(
        "the variable has already been set."
    )
    @ensure (q ≤ 0) || (size(components_names, 1) == q) CTBase.IncorrectArgument(
        "the number of variable names must be equal to the variable dimension"
    )
    @ensure !__is_objective_set(ocp) CTBase.UnauthorizedCall(
        "the objective must be set after the variable."
    )
    @ensure !__is_dynamics_set(ocp) CTBase.UnauthorizedCall(
        "the dynamics must be set after the variable."
    )

    # NEW: Comprehensive name validation (only if q > 0)
    if q > 0
        __validate_name_uniqueness(ocp, string(name), string.(components_names), :variable)
    end

    ocp.variable = if q == 0
        EmptyVariableModel()
    else
        VariableModel(string(name), string.(components_names))
    end

    return nothing
end
```

#### Tests

**Fichier**: [`test/suite/ocp/test_variable.jl`](../../../test/suite/ocp/test_variable.jl) (à créer)

### 4. times.jl

**Fichier**: [`src/OCP/Components/times.jl`](../../../src/OCP/Components/times.jl)

#### Modifications

```julia
function time!(
    ocp::PreModel;
    t0::Union{Time,Nothing}=nothing,
    tf::Union{Time,Nothing}=nothing,
    ind0::Union{Int,Nothing}=nothing,
    indf::Union{Int,Nothing}=nothing,
    time_name::Union{String,Symbol}=__time_name(),
)::Nothing
    
    # ... existing checks ...
    
    time_name = time_name isa String ? time_name : string(time_name)
    
    # NEW: Validate time_name is not empty
    @ensure !isempty(time_name) CTBase.IncorrectArgument(
        "Time name cannot be empty"
    )
    
    # NEW: Validate time_name doesn't conflict with existing names
    @ensure !__has_name_conflict(ocp, time_name, :time) CTBase.IncorrectArgument(
        "The time name '$time_name' conflicts with existing names: $(__collect_used_names(ocp))"
    )

    (initial_time, final_time) = MLStyle.@match (t0, ind0, tf, indf) begin
        # ... existing pattern matching ...
    end
    
    # NEW: Validate t0 < tf when both are fixed
    if initial_time isa FixedTimeModel && final_time isa FixedTimeModel
        t0_val = time(initial_time)
        tf_val = time(final_time)
        @ensure t0_val < tf_val CTBase.IncorrectArgument(
            "Initial time t0=$t0_val must be less than final time tf=$tf_val"
        )
    end

    ocp.times = TimesModel(initial_time, final_time, time_name)
    return nothing
end
```

#### Tests

**Fichier**: [`test/suite/ocp/test_times.jl`](../../../test/suite/ocp/test_times.jl)

```julia
@testset "time! - Name validation" begin
    # Empty time_name
    ocp = CTModels.PreModel()
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, t0=0, tf=1, time_name="")
    
    # time_name conflicts with state
    ocp = CTModels.PreModel()
    CTModels.state!(ocp, 1, "x")
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, t0=0, tf=1, time_name="x")
end

@testset "time! - Temporal validation" begin
    # t0 > tf
    ocp = CTModels.PreModel()
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, t0=1.0, tf=0.0)
    
    # t0 = tf
    ocp = CTModels.PreModel()
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, t0=1.0, tf=1.0)
end
```

### 5. objective.jl

**Fichier**: [`src/OCP/Components/objective.jl`](../../../src/OCP/Components/objective.jl)

#### Modifications

```julia
function objective!(
    ocp::PreModel,
    criterion::Symbol=__criterion_type();
    mayer::Union{Function,Nothing}=nothing,
    lagrange::Union{Function,Nothing}=nothing,
)::Nothing

    # ... existing checks ...
    
    # NEW: Validate criterion
    @ensure criterion ∈ (:min, :max) CTBase.IncorrectArgument(
        "Criterion must be :min or :max, got: $criterion"
    )

    # ... rest of function ...
end
```

### 6. constraints.jl

**Fichier**: [`src/OCP/Components/constraints.jl`](../../../src/OCP/Components/constraints.jl)

#### Modifications

```julia
function __constraint!(
    ocp_constraints::ConstraintsDictType,
    type::Symbol,
    n::Dimension,
    m::Dimension,
    q::Dimension;
    # ... parameters ...
)
    # ... existing checks ...
    
    # bounds
    isnothing(lb) && (lb = -Inf * ones(eltype(ub), length(ub)))
    isnothing(ub) && (ub = Inf * ones(eltype(lb), length(lb)))

    # lb and ub must have the same length
    @ensure(
        length(lb) == length(ub),
        CTBase.IncorrectArgument(
            "the lower bound `lb` and the upper bound `ub` must have the same length."
        ),
    )
    
    # NEW: Validate lb ≤ ub
    violations = findall(lb .> ub)
    @ensure isempty(violations) CTBase.IncorrectArgument(
        "Lower bounds must be ≤ upper bounds. Found violations at indices: $violations"
    )

    # ... rest of function ...
end
```

---

## Plan d'Action

### Phase 1: Infrastructure (Semaine 1, Jours 1-2)

**Branche**: `feat/enhance-defensive-validation`

#### Étape 1.1: Créer le Module de Validation

- [ ] Créer `src/OCP/Validation/name_validation.jl`
- [ ] Implémenter `__collect_used_names`
- [ ] Implémenter `__has_name_conflict`
- [ ] Implémenter `__validate_name_uniqueness`
- [ ] Ajouter tests unitaires pour les helpers

**Fichiers**:
- `src/OCP/Validation/name_validation.jl` (nouveau)
- `test/suite/validation/test_name_validation.jl` (nouveau)

#### Étape 1.2: Intégrer le Module

- [ ] Ajouter `include("Validation/name_validation.jl")` dans `src/OCP/OCP.jl`
- [ ] Vérifier que les helpers sont accessibles

### Phase 2: Composants Critiques (Semaine 1, Jours 3-5)

#### Étape 2.1: state.jl

- [ ] Ajouter appel à `__validate_name_uniqueness`
- [ ] Mettre à jour la documentation (section Throws)
- [ ] Créer tests internes (noms vides, doublons, etc.)
- [ ] Créer tests inter-composants
- [ ] Ajouter tests `@inferred`

**Fichiers**:
- `src/OCP/Components/state.jl`
- `test/suite/ocp/test_state.jl`

#### Étape 2.2: control.jl

- [ ] Ajouter appel à `__validate_name_uniqueness`
- [ ] Mettre à jour la documentation
- [ ] Créer `test/suite/ocp/test_control.jl`
- [ ] Créer tests complets (internes + inter-composants + @inferred)

**Fichiers**:
- `src/OCP/Components/control.jl`
- `test/suite/ocp/test_control.jl` (nouveau)

#### Étape 2.3: variable.jl

- [ ] Ajouter appel à `__validate_name_uniqueness` (si q > 0)
- [ ] Mettre à jour la documentation
- [ ] Créer `test/suite/ocp/test_variable.jl`
- [ ] Créer tests complets

**Fichiers**:
- `src/OCP/Components/variable.jl`
- `test/suite/ocp/test_variable.jl` (nouveau)

### Phase 3: Composants Secondaires (Semaine 2, Jours 1-2)

#### Étape 3.1: times.jl

- [ ] Ajouter validation `time_name` non vide
- [ ] Ajouter validation conflits inter-composants
- [ ] Ajouter validation `t0 < tf`
- [ ] Mettre à jour la documentation
- [ ] Compléter les tests

**Fichiers**:
- `src/OCP/Components/times.jl`
- `test/suite/ocp/test_times.jl`

#### Étape 3.2: objective.jl

- [ ] Ajouter validation `criterion ∈ (:min, :max)`
- [ ] Mettre à jour la documentation
- [ ] Ajouter tests

**Fichiers**:
- `src/OCP/Components/objective.jl`
- `test/suite/ocp/test_objective.jl`

#### Étape 3.3: constraints.jl

- [ ] Ajouter validation `lb ≤ ub`
- [ ] Mettre à jour la documentation
- [ ] Ajouter tests

**Fichiers**:
- `src/OCP/Components/constraints.jl`
- `test/suite/ocp/test_constraints.jl`

### Phase 4: Tests d'Intégration (Semaine 2, Jours 3-4)

#### Étape 4.1: Tests de Scénarios Complexes

- [ ] Créer `test/suite/ocp/test_name_conflicts_integration.jl`
- [ ] Tester tous les scénarios de conflits possibles
- [ ] Tester l'ordre d'appel (indépendance)

**Fichier**:
- `test/suite/ocp/test_name_conflicts_integration.jl` (nouveau)

#### Étape 4.2: Vérification de Non-Régression

- [ ] Exécuter toute la suite de tests
- [ ] Vérifier que les tests existants passent
- [ ] Corriger les régressions éventuelles

### Phase 5: Documentation (Semaine 2, Jour 5)

#### Étape 5.1: Documentation des Fonctions

- [ ] Vérifier que toutes les sections `# Throws` sont complètes
- [ ] Vérifier que tous les exemples fonctionnent
- [ ] Ajouter des notes sur l'unicité globale

#### Étape 5.2: Documentation Générale

- [ ] Mettre à jour le CHANGELOG.md
- [ ] Créer une note de migration si nécessaire
- [ ] Documenter les nouvelles règles de validation

### Phase 6: Revue et Merge (Semaine 3)

#### Étape 6.1: Revue de Code

- [ ] Auto-revue complète
- [ ] Vérifier le respect des standards
- [ ] Vérifier la couverture de tests

#### Étape 6.2: PR et Merge

- [ ] Créer la Pull Request
- [ ] Adresser les commentaires de revue
- [ ] Merger dans develop

---

## Métriques de Succès

### Avant

| Métrique | Valeur |
| --- | --- |
| Validations défensives | ~40% |
| Documentation Throws | ~10% |
| Tests @inferred | ~5% |
| Tests validations | ~50% |

### Objectif Après

| Métrique | Valeur |
| --- | --- |
| Validations défensives | **95%+** |
| Documentation Throws | **100%** |
| Tests @inferred | **80%+** |
| Tests validations | **95%+** |

### Critères de Validation

- ✅ Tous les tests passent
- ✅ Aucune régression détectée
- ✅ Couverture de code > 90% pour les nouvelles fonctions
- ✅ Documentation complète et à jour
- ✅ Revue de code approuvée

---

## Références

### Documents d'Analyse

- [Audit Complet](../analysis/00_audit_report.md) - Analyse détaillée par fichier avec exemples de code
- [Conflits Inter-Composants](../analysis/01_inter_component_conflicts_analysis.md) - Architecture de solution pour l'unicité globale

### Standards de Développement

- [Development Standards Reference](./00_development_standards_reference.md) - Standards généraux du projet
  - Exception Handling (CTBase)
  - Documentation (DocStringExtensions)
  - Type Stability
  - Testing Standards

### Fichiers Source Concernés

#### Composants OCP

- [`src/OCP/Components/state.jl`](../../../src/OCP/Components/state.jl)
- [`src/OCP/Components/control.jl`](../../../src/OCP/Components/control.jl)
- [`src/OCP/Components/variable.jl`](../../../src/OCP/Components/variable.jl)
- [`src/OCP/Components/times.jl`](../../../src/OCP/Components/times.jl)
- [`src/OCP/Components/objective.jl`](../../../src/OCP/Components/objective.jl)
- [`src/OCP/Components/constraints.jl`](../../../src/OCP/Components/constraints.jl)

#### Types et Helpers

- [`src/OCP/Types/model.jl`](../../../src/OCP/Types/model.jl) - PreModel, helpers `__is_*_set`

#### Tests

- [`test/suite/ocp/test_state.jl`](../../../test/suite/ocp/test_state.jl)
- [`test/suite/ocp/test_times.jl`](../../../test/suite/ocp/test_times.jl)
- [`test/suite/ocp/test_objective.jl`](../../../test/suite/ocp/test_objective.jl)
- [`test/suite/ocp/test_constraints.jl`](../../../test/suite/ocp/test_constraints.jl)

### Exemples de Référence

Pour la structure et le style de documentation, voir :

- [Strategies Contract Specification](../../2026-01-22_tools/reference/08_complete_contract_specification.md) - Exemple de spécification complète
- [Strategies Initial Analysis](../../2026-01-22_tools/reference/01_strategies_initial_analysis_archived.md) - Exemple d'analyse archivée

---

## Notes de Mise en Œuvre

### Ordre d'Implémentation

L'ordre proposé est **critique** car :

1. **Infrastructure d'abord** : Les helpers doivent être en place avant les validations
2. **Composants critiques ensuite** : state, control, variable sont les plus utilisés
3. **Tests en parallèle** : Chaque modification doit être testée immédiatement
4. **Documentation continue** : Mettre à jour la doc au fur et à mesure

### Points d'Attention

#### 1. Performance

Les validations ajoutent un léger overhead. Cependant :
- Les validations ne s'exécutent qu'à la construction du modèle (une fois)
- Le coût est négligeable comparé au temps de résolution
- La robustesse justifie largement ce coût

#### 2. Compatibilité

Les nouvelles validations peuvent **casser du code existant** qui :
- Utilisait des noms vides
- Avait des doublons
- Avait des conflits inter-composants

**Solution** : Documenter clairement dans le CHANGELOG et fournir des messages d'erreur explicites.

#### 3. Extensibilité

L'architecture proposée facilite l'ajout de nouveaux composants :
- Ajouter le composant dans `__collect_used_names`
- Utiliser `__validate_name_uniqueness` dans la fonction de définition
- Ajouter les tests correspondants

---

**Prochaine Étape** : Créer la branche `feat/enhance-defensive-validation` et commencer la Phase 1.
