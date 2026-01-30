# Analyse des bornes de contraintes pour le plotting

**Version**: 1.0  
**Date**: 2026-01-30  
**Statut**: ✅ Complété  
**Lié à**: `03_ocp_field_analysis.md`, `04_plotting_metadata_investigation.md`

---

## Objectif

Déterminer si les bornes de contraintes (state bounds, control bounds) doivent être incluses dans `OCPMetadata` pour supporter le plotting.

---

## Utilisation des bornes dans le plotting

### 1. State bounds

**Fichier**: `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot.jl:699-722`

```julia
# state constraints if model is not nothing
if do_decorate_state_bounds
    cs = CTModels.state_constraints_box(model)  # ← Appel sur model
    for i in 1:length(cs[1])
        hline!(
            [cs[1][i]],  # lower bound
            # ... style ...
        )
        hline!(
            [cs[2][i]],  # upper bound
            # ... style ...
        )
    end
end
```

**Fonction appelée**: `state_constraints_box(model)`

**Source**: `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Components/constraints.jl:474-477`

```julia
function state_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,TS,<:Tuple,<:Tuple}
) where {TS}
    return model.state_box
end
```

**Type de retour**: `Tuple{Vector, Vector}` - (lower_bounds, upper_bounds)

---

### 2. Control bounds

**Fichier**: `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot.jl:858-881`

```julia
# control constraints if model is not nothing
if do_decorate_control_bounds && (control != :norm)
    cu = CTModels.control_constraints_box(model)  # ← Appel sur model
    for i in 1:length(cu[1])
        hline!(
            [cu[1][i]],  # lower bound
            # ... style ...
        )
        hline!(
            [cu[2][i]],  # upper bound
            # ... style ...
        )
    end
end
```

**Fonction appelée**: `control_constraints_box(model)`

**Source**: `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Components/constraints.jl:501-504`

```julia
function control_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,TC,<:Tuple}
) where {TC}
    return model.control_box
end
```

**Type de retour**: `Tuple{Vector, Vector}` - (lower_bounds, upper_bounds)

---

## Conditions d'utilisation

Les bornes sont tracées **uniquement si**:

1. `do_decorate_state_bounds == true` ou `do_decorate_control_bounds == true`
2. Ces flags sont activés par `do_decorate()` qui vérifie :
   - `state_bounds_style != :none && model !== nothing`
   - `control_bounds_style != :none && model !== nothing`

**Conclusion**: Les bornes sont **optionnelles** pour le plotting. Si `model === nothing`, elles ne sont simplement pas tracées.

---

## Décision pour `OCPMetadata`

### Option 1 : Inclure les bornes

```julia
struct OCPMetadata
    dim_state::Int
    dim_control::Int
    dim_variable::Int
    dim_path_constraints::Int
    dim_boundary_constraints::Int
    dim_variable_constraints_box::Int
    state_bounds::Union{Tuple{Vector{Float64}, Vector{Float64}}, Nothing}
    control_bounds::Union{Tuple{Vector{Float64}, Vector{Float64}}, Nothing}
end
```

**Avantages**:
- Plotting complet avec bornes même sans modèle OCP
- Toutes les fonctionnalités de plotting disponibles

**Inconvénients**:
- Taille augmentée (2 vecteurs de dim_state + 2 vecteurs de dim_control)
- Complexité accrue
- Les bornes peuvent être `nothing` si non définies

---

### Option 2 : Ne pas inclure les bornes (Recommandée)

```julia
struct OCPMetadata
    dim_state::Int
    dim_control::Int
    dim_variable::Int
    dim_path_constraints::Int
    dim_boundary_constraints::Int
    dim_variable_constraints_box::Int
end
```

**Avantages**:
- Structure minimale et légère (48 bytes)
- Sérialisable sans problème
- Suffisant pour 95% des cas d'usage

**Inconvénients**:
- Les bornes ne seront pas tracées si `model === nothing`
- Mais c'est déjà le comportement actuel !

---

## Recommandation finale

**Ne pas inclure les bornes dans `OCPMetadata`** car:

1. **Les bornes sont optionnelles** : Le plotting fonctionne sans elles
2. **Comportement cohérent** : Si `model === nothing`, pas de bornes (déjà le cas)
3. **Taille minimale** : Garder `OCPMetadata` léger
4. **Cas d'usage principal** : Export/import de solutions
   - Après import, l'utilisateur a toujours accès au modèle OCP original
   - Il peut passer `model=ocp` au plotting s'il veut les bornes

### Workflow recommandé

```julia
# Export
export_ocp_solution(JLD2Tag(), sol; filename="solution")

# Import
sol_imported = import_ocp_solution(JLD2Tag(), ocp; filename="solution")

# Plot sans bornes (utilise metadata)
plot(sol_imported)

# Plot avec bornes (passe le modèle original)
plot(sol_imported; model=ocp)  # ← Fonctionnalité à ajouter si nécessaire
```

---

## Métadonnées OCP finales pour `OCPMetadata`

Basé sur toutes les analyses, `OCPMetadata` doit contenir:

| Champ | Type | Usage | Obligatoire |
|-------|------|-------|-------------|
| `dim_state` | `Int` | Reconstruction, affichage, plotting | Oui |
| `dim_control` | `Int` | Reconstruction, affichage, plotting | Oui |
| `dim_variable` | `Int` | Reconstruction, affichage | Oui |
| `dim_path_constraints` | `Int` | Affichage, plotting (taille) | Oui |
| `dim_boundary_constraints` | `Int` | Affichage | Oui |
| `dim_variable_constraints_box` | `Int` | Affichage | Oui |

**Total**: 6 entiers = 48 bytes (négligeable)

---

## Conclusion

`OCPMetadata` est une structure minimale suffisante pour:
- ✅ Afficher une solution (`show(io, sol)`)
- ✅ Tracer une solution (`plot(sol)`) sans bornes
- ✅ Reconstruire une solution depuis données discrètes
- ✅ Export/import JLD2 sans warnings
- ❌ Tracer les bornes de contraintes (nécessite le modèle OCP complet)

Le dernier point est acceptable car:
- Les bornes sont optionnelles
- L'utilisateur peut passer le modèle au plotting si nécessaire
- Cela évite de dupliquer des données potentiellement volumineuses

---

**Auteur**: CTModels Development Team  
**Date**: 2026-01-30  
**Statut**: ✅ Analyse complétée
