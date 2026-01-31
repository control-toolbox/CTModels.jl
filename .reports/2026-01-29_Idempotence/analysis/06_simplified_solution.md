# Solution simplifiée : Suppression du champ `model` de `Solution`

**Date**: 2026-01-30  
**Auteur**: Analyse automatique  
**Statut**: ✅ Implémenté

## Contexte

Suite à l'analyse détaillée du champ `model` dans la struct `Solution`, une approche beaucoup plus simple a été identifiée : **toutes les informations nécessaires sont déjà disponibles dans `Solution`** sans avoir besoin de stocker le `Model` complet.

## Découverte clé

Les dimensions utilisées par les différentes fonctions peuvent être obtenues directement depuis les champs existants de `Solution` :

### Dimensions de base (déjà disponibles)

```julia
state_dimension(sol)     → dimension(sol.state)
control_dimension(sol)   → dimension(sol.control)
variable_dimension(sol)  → dimension(sol.variable)
```

### Dimensions de contraintes (calculables depuis `sol.dual`)

```julia
dim_boundary_constraints_nl(sol) → 
    boundary_constraints_dual(sol) === nothing ? 0 : length(boundary_constraints_dual(sol))

dim_variable_constraints_box(sol) →
    variable_constraints_lb_dual(sol) === nothing ? 0 : length(variable_constraints_lb_dual(sol))

dim_path_constraints_nl(sol) →
    path_constraints_dual(sol) === nothing ? 0 : length(path_constraints_dual(sol)(initial_time(sol)))
```

## Solution implémentée

Au lieu de créer une nouvelle struct `OCPMetadata`, nous avons :

1. **Ajouté des surcharges de fonctions** pour calculer les dimensions depuis `Solution`
2. **Supprimé le champ `model`** de la struct `Solution`
3. **Adapté tous les usages** dans le codebase

## Modifications apportées

### 1. Ajout de surcharges dans `src/OCP/Building/solution.jl`

```julia
function dim_boundary_constraints_nl(sol::Solution)::Dimension
    bc_dual = boundary_constraints_dual(sol)
    return bc_dual === nothing ? 0 : length(bc_dual)
end

function dim_path_constraints_nl(sol::Solution)::Dimension
    pc_dual = path_constraints_dual(sol)
    if pc_dual === nothing
        return 0
    else
        t0 = initial_time(sol)
        return length(pc_dual(t0))
    end
end

function dim_variable_constraints_box(sol::Solution)::Dimension
    vc_lb_dual = variable_constraints_lb_dual(sol)
    return vc_lb_dual === nothing ? 0 : length(vc_lb_dual)
end
```

### 2. Modification de la struct `Solution` dans `src/OCP/Types/solution.jl`

**Avant** :
```julia
struct Solution{
    TimeGridModelType<:AbstractTimeGridModel,
    TimesModelType<:AbstractTimesModel,
    StateModelType<:AbstractStateModel,
    ControlModelType<:AbstractControlModel,
    VariableModelType<:AbstractVariableModel,
    CostateModelType<:Function,
    ObjectiveValueType<:ctNumber,
    DualModelType<:AbstractDualModel,
    SolverInfosType<:AbstractSolverInfos,
    ModelType<:AbstractModel,  # ❌ Supprimé
} <: AbstractSolution
    time_grid::TimeGridModelType
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
    costate::CostateModelType
    objective::ObjectiveValueType
    dual::DualModelType
    solver_infos::SolverInfosType
    model::ModelType  # ❌ Supprimé
end
```

**Après** :
```julia
struct Solution{
    TimeGridModelType<:AbstractTimeGridModel,
    TimesModelType<:AbstractTimesModel,
    StateModelType<:AbstractStateModel,
    ControlModelType<:AbstractControlModel,
    VariableModelType<:AbstractVariableModel,
    CostateModelType<:Function,
    ObjectiveValueType<:ctNumber,
    DualModelType<:AbstractDualModel,
    SolverInfosType<:AbstractSolverInfos,
} <: AbstractSolution
    time_grid::TimeGridModelType
    times::TimesModelType
    state::StateModelType
    control::ControlModelType
    variable::VariableModelType
    costate::CostateModelType
    objective::ObjectiveValueType
    dual::DualModelType
    solver_infos::SolverInfosType
end
```

### 3. Suppression du getter `model(sol)`

La fonction `model(sol)` a été complètement supprimée de `src/OCP/Building/solution.jl`.

### 4. Adaptation de `build_solution`

**Avant** :
```julia
return Solution(
    time_grid,
    times(ocp),
    state,
    control,
    variable,
    fp,
    objective,
    dual,
    solver_infos,
    ocp,  # ❌ Supprimé
)
```

**Après** :
```julia
return Solution(
    time_grid,
    times(ocp),
    state,
    control,
    variable,
    fp,
    objective,
    dual,
    solver_infos,
)
```

### 5. Adaptation de `_serialize_solution`

**Avant** :
```julia
function _serialize_solution(sol::Solution, ocp::Model)::Dict{String, Any}
    T = time_grid(sol)
    dim_x = state_dimension(ocp)  # ❌ Utilisait ocp
    dim_u = control_dimension(ocp)  # ❌ Utilisait ocp
```

**Après** :
```julia
function _serialize_solution(sol::Solution)::Dict{String, Any}
    T = time_grid(sol)
    dim_x = state_dimension(sol)  # ✅ Utilise sol
    dim_u = control_dimension(sol)  # ✅ Utilise sol
```

### 6. Adaptation de JLD2 serialization (`ext/CTModelsJLD.jl`)

**Export** :
```julia
function CTModels.export_ocp_solution(
    ::CTModels.JLD2Tag, sol::CTModels.Solution; filename::String
)
    # Serialize solution to discrete data
    data = CTModels.OCP._serialize_solution(sol)  # ✅ Plus besoin de ocp
    
    # Save only the serialized data (no more OCP model)
    jldsave(filename * ".jld2"; solution_data=data)  # ✅ Plus de warnings !
    
    return nothing
end
```

**Import** :
```julia
function CTModels.import_ocp_solution(
    ::CTModels.JLD2Tag, ocp::CTModels.Model; filename::String
)
    file_data = load(filename * ".jld2")
    data = file_data["solution_data"]
    # Plus besoin de charger saved_ocp depuis le fichier
    
    # Reconstruct solution using build_solution with provided ocp
    sol = CTModels.build_solution(ocp, ...)  # ✅ Utilise le ocp fourni
    
    return sol
end
```

### 7. Adaptation du plotting (`ext/plot.jl`, `ext/plot_utils.jl`)

**Avant** :
```julia
model = CTModels.model(sol)
do_plot_path = ... && CTModels.dim_path_constraints_nl(model) > 0
```

**Après** :
```julia
# Plus besoin de récupérer model
do_plot_path = ... && CTModels.dim_path_constraints_nl(sol) > 0  # ✅ Directement sur sol
```

**Note** : Le paramètre `model` dans `__initial_plot` et `__size_plot` est maintenant passé à `nothing`, ce qui désactive les décorations de bornes (comportement cohérent car les bornes ne sont pas stockées dans `Solution`).

### 8. Adaptation de `show(sol)` dans `src/OCP/Building/solution.jl`

**Avant** :
```julia
if dim_variable_constraints_box(model(sol)) > 0
    println(io, "  │  Var dual (lb) : ", variable_constraints_lb_dual(sol))
    println(io, "  └─ Var dual (ub) : ", variable_constraints_ub_dual(sol))
end

if dim_boundary_constraints_nl(model(sol)) > 0
    println(io, "\n• Boundary duals: ", boundary_constraints_dual(sol))
end
```

**Après** :
```julia
if dim_variable_constraints_box(sol) > 0  # ✅ Directement sur sol
    println(io, "  │  Var dual (lb) : ", variable_constraints_lb_dual(sol))
    println(io, "  └─ Var dual (ub) : ", variable_constraints_ub_dual(sol))
end

if dim_boundary_constraints_nl(sol) > 0  # ✅ Directement sur sol
    println(io, "\n• Boundary duals: ", boundary_constraints_dual(sol))
end
```

## Avantages de cette approche

1. **✅ Plus simple** : Pas de nouvelle struct `OCPMetadata` à créer
2. **✅ Pas de duplication** : Les dimensions sont calculées à la demande depuis les données existantes
3. **✅ Élimine les warnings JLD2** : Plus de sérialisation du `Model` complet
4. **✅ Réduit la taille des fichiers** : Seules les données discrètes sont sauvegardées
5. **✅ Breaking change clair** : Force à identifier tous les usages de `model(sol)`
6. **✅ Cohérent** : Les dimensions proviennent toujours de la même source (la solution elle-même)

## Impact sur le code existant

### Breaking changes

- ❌ `model(sol)` n'existe plus
- ❌ Le champ `sol.model` n'existe plus
- ❌ Les fichiers JLD2 créés avec l'ancienne version ne contiendront plus le champ `ocp`

### Migrations nécessaires

Si du code externe utilise `model(sol)`, il faut :

1. **Pour les dimensions** : Utiliser les fonctions directement sur `sol`
   ```julia
   # Avant
   dim_x = state_dimension(model(sol))
   
   # Après
   dim_x = state_dimension(sol)
   ```

2. **Pour les contraintes** : Utiliser les nouvelles surcharges
   ```julia
   # Avant
   nb_bc = dim_boundary_constraints_nl(model(sol))
   
   # Après
   nb_bc = dim_boundary_constraints_nl(sol)
   ```

3. **Pour accéder au modèle complet** : Le garder en dehors de la solution
   ```julia
   # Avant
   ocp = model(sol)
   
   # Après
   # Garder une référence à ocp séparément si nécessaire
   ```

## Fichiers modifiés

1. `src/OCP/Types/solution.jl` - Suppression du champ `model`
2. `src/OCP/Building/solution.jl` - Ajout des surcharges `dim_*`, suppression de `model(sol)`, adaptation de `build_solution` et `_serialize_solution`
3. `ext/CTModelsJLD.jl` - Adaptation de l'export/import JLD2
4. `ext/plot.jl` - Remplacement de `model(sol)` par `nothing`
5. `ext/plot_utils.jl` - Utilisation de `dim_path_constraints_nl(sol)`

## Tests à effectuer

1. ✅ Vérifier que `build_solution` fonctionne sans passer `ocp` au constructeur
2. ✅ Vérifier que les fonctions `dim_*` sur `Solution` retournent les bonnes valeurs
3. ✅ Vérifier que l'export JLD2 ne génère plus de warnings
4. ✅ Vérifier que l'import JLD2 reconstruit correctement la solution
5. ✅ Vérifier que le plotting fonctionne sans `model(sol)`
6. ✅ Vérifier que `show(sol)` affiche correctement les informations

## Conclusion

Cette solution est **beaucoup plus élégante** que la proposition initiale d'`OCPMetadata`. Elle exploite le fait que toutes les informations nécessaires sont déjà présentes dans `Solution`, évitant ainsi toute duplication de données.

Le seul "coût" est un breaking change, mais celui-ci est justifié par :
- L'élimination des warnings JLD2
- La réduction de la taille des fichiers sérialisés
- Une architecture plus propre et cohérente
