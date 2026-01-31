# Analyse des Conflits Inter-Composants

**Date**: 2026-01-28  
**Statut**: 🔍 Analyse Complémentaire

---

## Problème Identifié

L'audit initial n'a pas couvert les **conflits inter-composants**. Actuellement, on vérifie seulement :
- ✅ Conflits internes: `name` vs `components_names` 
- ❌ **Manquant**: Conflits entre tous les composants

## Exemples de Conflits Non Détectés

```julia
# Scénario 1: Conflit state vs control
ocp = CTModels.PreModel()
CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
CTModels.control!(ocp, 1, "x")  # ❌ "x" déjà utilisé par state!

# Scénario 2: Conflit control vs variable
ocp = CTModels.PreModel()
CTModels.control!(ocp, 1, "u")
CTModels.variable!(ocp, 2, "u", ["u₁", "u₂"])  # ❌ "u" déjà utilisé!

# Scénario 3: Conflit time vs state
ocp = CTModels.PreModel()
CTModels.time!(ocp, t0=0, tf=1, time_name="x")
CTModels.state!(ocp, 2, "x")  # ❌ "x" déjà utilisé par time!

# Scénario 4: Conflit component vs autre composant
ocp = CTModels.PreModel()
CTModels.state!(ocp, 2, "x", ["u", "v"])
CTModels.control!(ocp, 1, "u")  # ❌ "u" déjà utilisé comme state component!
```

## Architecture de Solution

### 1. Fonction Helper: Collecter les Noms Existant

```julia
"""
Collect all names already used in the PreModel to detect conflicts.

# Returns
- `Vector{String}`: All unique names used across components
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
    if __is_variable_set(ocp) && !isempty(ocp.variable)
        push!(names, name(ocp.variable))
        append!(names, components(ocp.variable))
    end
    
    return unique(names)
end
```

### 2. Fonction Helper: Vérifier les Conflits

```julia
"""
Check if a name conflicts with existing names in the PreModel.

# Arguments
- `ocp::PreModel`: The model to check against
- `new_name::String`: The new name to check
- `exclude_component::Symbol`: Component type to exclude from check (:state, :control, :variable, :time)

# Returns
- `Bool`: true if conflict exists
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
        filter!(x -> x != name(ocp.variable), existing_names)
        filter!(x -> x ∉ components(ocp.variable), existing_names)
    elseif exclude_component == :time && __is_times_set(ocp)
        filter!(x -> x != time_name(ocp.times), existing_names)
    end
    
    return new_name ∈ existing_names
end
```

### 3. Validation dans Chaque Fonction

#### state! et control!

```julia
# Dans state! et control!
@ensure !__has_name_conflict(ocp, string(name), :state) CTBase.IncorrectArgument(
    "The state name '$(string(name))' conflicts with existing names: $(__collect_used_names(ocp))"
)

for comp_name in components_names
    @ensure !__has_name_conflict(ocp, string(comp_name), :state) CTBase.IncorrectArgument(
        "The state component '$(string(comp_name))' conflicts with existing names: $(__collect_used_names(ocp))"
    )
end
```

#### variable!

```julia
# Dans variable!
if q > 0  # seulement si variable non vide
    @ensure !__has_name_conflict(ocp, string(name), :variable) CTBase.IncorrectArgument(
        "The variable name '$(string(name))' conflicts with existing names: $(__collect_used_names(ocp))"
    )
    
    for comp_name in components_names
        @ensure !__has_name_conflict(ocp, string(comp_name), :variable) CTBase.IncorrectArgument(
            "The variable component '$(string(comp_name))' conflicts with existing names: $(__collect_used_names(ocp))"
        )
    end
end
```

#### time!

```julia
# Dans time!
@ensure !__has_name_conflict(ocp, time_name, :time) CTBase.IncorrectArgument(
    "The time name '$time_name' conflicts with existing names: $(__collect_used_names(ocp))"
)
```

## Tests Correspondants

```julia
@testset "Inter-component name conflicts" begin
    # state vs control conflict
    ocp = CTModels.PreModel()
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    @test_throws CTBase.IncorrectArgument CTModels.control!(ocp, 1, "x")
    
    # control vs state component conflict
    ocp = CTModels.PreModel()
    CTModels.state!(ocp, 2, "x", ["u", "v"])
    @test_throws CTBase.IncorrectArgument CTModels.control!(ocp, 1, "u")
    
    # state vs variable conflict
    ocp = CTModels.PreModel()
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    @test_throws CTBase.IncorrectArgument CTModels.variable!(ocp, 1, "x")
    
    # time vs state conflict
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="x")
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 2, "x")
    
    # Complex scenario: multiple components
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="t")
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    CTModels.control!(ocp, 1, "u")
    CTModels.variable!(ocp, 1, "v")
    
    # All subsequent attempts should fail
    @test_throws CTBase.IncorrectArgument CTModels.control!(ocp, 1, "x")  # vs state
    @test_throws CTBase.IncorrectArgument CTModels.variable!(ocp, 1, "u")  # vs control
    @test_throws CTBase.IncorrectArgument CTModels.state!(ocp, 1, "t")     # vs time
end
```

## Impact sur l'Audit Initial

### Modifications Requises

1. **state.jl, control.jl, variable.jl**: Ajouter validation inter-composants
2. **times.jl**: Ajouter validation inter-composants  
3. **Tests**: Ajouter tests de conflits inter-composants
4. **Documentation**: Documenter la règle d'unicité globale

### Priorité Re-évaluée

- **state.jl, control.jl, variable.jl**: **CRITIQUE** (était HAUTE)
- **times.jl**: **HAUTE** (était MOYENNE)  
- **Tests**: **CRITIQUE** (était MOYENNE)

## Avantages de cette Approche

1. **Centralisé**: Logique de détection de conflits dans des helpers
2. **Extensible**: Facile d'ajouter de nouveaux composants
3. **Clair**: Messages d'erreur informatifs avec liste des conflits
4. **Robuste**: Gère tous les cas (nom vs composant, composant vs composant)
5. **Maintenable**: Un seul endroit pour modifier la logique

## Inconvénients

1. **Complexité**: Ajoute des fonctions helper
2. **Performance**: Vérification à chaque appel (négligeable)
3. **Dépendances**: Les helpers doivent connaître tous les types de composants

## Recommandation

**Implémenter cette solution** car elle résout un problème critique de cohérence du modèle et prévient des bugs difficiles à diagnostiquer.

L'unicité globale des noms est une exigence fondamentale pour:
- Éviter les ambiguïtés dans l'affichage
- Prévenir les conflits dans les solveurs
- Assurer la cohérence de l'interface utilisateur

---

## Plan d'Action Mis à Jour

### Phase 1: Validations Défensives Critiques (Semaine 1)

**Branche:** `feat/enhance-defensive-validation`

1. **Implémenter les helpers** dans un nouveau fichier `src/OCP/Validation/name_validation.jl`
2. **Ajouter validations inter-composants** dans state!, control!, variable!, time!
3. **Conserver validations internes** (name vs components, doublons, noms vides)
4. **Ajouter tests complets** pour tous les scénarios de conflits
5. **Mettre à jour documentation** avec règle d'unicité globale

### Phase 2-4: Inchangée (documentation, tests @inferred, etc.)

---

**Conclusion**: L'unicité globale des noms est un oubli critique qui doit être corrigé en priorité absolue.
