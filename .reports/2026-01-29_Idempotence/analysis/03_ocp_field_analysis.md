# Analyse du champ `model::ModelType` dans `Solution`

**Version**: 1.0  
**Date**: 2026-01-30  
**Status**: 🔍 En cours d'analyse  
**Contexte**: Réduction des warnings JLD2 lors de l'export de solutions

---

## Contexte et Problématique

### Situation actuelle

Dans la structure `Solution`, le champ `model::ModelType` stocke une référence complète au problème OCP :

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Types/solution.jl:210-232
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
    ModelType<:AbstractModel,
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
    model::ModelType  # ← Problématique pour la sérialisation JLD2
end
```

### Problème identifié

Lors de l'export JLD2, le champ `model` génère des warnings car il contient :
- Des fonctions (dynamique, contraintes, objectif)
- Des structures complexes imbriquées
- Des closures potentiellement non sérialisables

### Objectifs de l'analyse

1. **Identifier tous les usages** du champ `model` via l'accesseur `model(sol)`
2. **Déterminer les métadonnées OCP réellement nécessaires** pour chaque usage
3. **Concevoir une structure `OCPMetadata` minimale** sérialisable
4. **Proposer une stratégie de migration** sans rupture de compatibilité

---

## 1. Inventaire des usages de `model(sol)`

### 1.1 Localisation des appels

Recherche effectuée avec `grep -r "model(sol)"` :

| Fichier | Nombre d'occurrences | Type d'usage |
|---------|---------------------|--------------|
| `src/OCP/Building/solution.jl` | 10 | Affichage, dimensions |
| `ext/plot.jl` | 3 | Plotting, dimensions |
| `ext/plot_utils.jl` | 1 | Détection contraintes |
| `ext/CTModelsJLD.jl` | 1 | Export/sérialisation |
| `test/suite/ocp/test_solution.jl` | 1 | Tests |

**Total** : 16 occurrences dans 5 fichiers

### 1.2 Analyse détaillée par fichier

#### A. `src/OCP/Building/solution.jl`

##### Usage 1 : Affichage des contraintes variables (ligne 755)

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl:755
if dim_variable_constraints_box(model(sol)) > 0
    println(io, "  │  Var dual (lb) : ", variable_constraints_lb_dual(sol))
    println(io, "  └─ Var dual (ub) : ", variable_constraints_ub_dual(sol))
end
```

**Métadonnées nécessaires** :
- `dim_variable_constraints_box::Int` - Dimension des contraintes boîte sur les variables

##### Usage 2 : Affichage des contraintes frontières (ligne 762)

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl:762
if dim_boundary_constraints_nl(model(sol)) > 0
    println(io, "\n• Boundary duals: ", boundary_constraints_dual(sol))
end
```

**Métadonnées nécessaires** :
- `dim_boundary_constraints_nl::Int` - Dimension des contraintes frontières non-linéaires

#### B. `ext/plot_utils.jl`

##### Usage 3 : Détection des contraintes de chemin (lignes 77-81)

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot_utils.jl:77-81
ocp = CTModels.model(sol)
do_plot_path =
    :path ∈ description &&
    path_style != :none &&
    CTModels.dim_path_constraints_nl(ocp) > 0
```

**Métadonnées nécessaires** :
- `dim_path_constraints_nl::Int` - Dimension des contraintes de chemin non-linéaires

#### C. `ext/plot.jl`

##### Usage 4 : Calcul de la taille du plot (lignes 1124-1138)

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot.jl:1124-1138
model = CTModels.model(sol)

# check if the plot is empty
if isempty(p.series_list)
    attr = NamedTuple((Symbol(key), value) for (key, value) in p.attr if key != :layout)

    pnew = __initial_plot(
        sol,
        description...;
        layout=layout,
        control=control,
        model=model,  # ← Passé à __initial_plot
        size=__size_plot(
            sol,
            model,  # ← Passé à __size_plot
            control,
            layout,
            description...;
```

**Métadonnées nécessaires** : À déterminer (dépend de `__initial_plot` et `__size_plot`)

##### Usage 5 : Décoration du plot (lignes 1330-1353)

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot.jl:1330-1353
size::Tuple=__size_plot(
    sol,
    CTModels.model(sol),  # ← Passé à __size_plot
    control,
    layout,
    description...;
    state_style=state_style,
    control_style=control_style,
    costate_style=costate_style,
    path_style=path_style,
    dual_style=dual_style,
),
# ...
do_decorate(;
    state_style=state_style,
    control_style=control_style,
    costate_style=costate_style,
    model=CTModels.model(sol),  # ← Passé à do_decorate
    state_bounds_style=state_bounds_style,
    control_bounds_style=control_bounds_style,
    time_style=time_style,
```

**Métadonnées nécessaires** : À déterminer (dépend de `do_decorate`)

#### D. `ext/CTModelsJLD.jl`

##### Usage 6 : Export JLD2 (lignes 39-42)

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/CTModelsJLD.jl:39-42
ocp = CTModels.model(sol)

# Serialize solution to discrete data
data = CTModels.OCP._serialize_solution(sol, ocp)
```

**Métadonnées nécessaires** :
- `state_dimension(ocp)::Int`
- `control_dimension(ocp)::Int`
- Utilisées dans `_serialize_solution` pour la discrétisation

---

## 2. Fonctions de dimension appelées sur le modèle

### 2.1 Fonctions identifiées

D'après l'analyse du code, les fonctions suivantes sont appelées sur `model(sol)` :

| Fonction | Fichier source | Retour | Usage |
|----------|---------------|--------|-------|
| `state_dimension` | `src/OCP/Components/state.jl` | `Int` | Discrétisation, construction |
| `control_dimension` | `src/OCP/Components/control.jl` | `Int` | Discrétisation, construction |
| `variable_dimension` | `src/OCP/Components/variable.jl` | `Int` | Discrétisation, construction |
| `dim_path_constraints_nl` | `src/OCP/Components/constraints.jl` | `Int` | Affichage, plotting |
| `dim_boundary_constraints_nl` | `src/OCP/Components/constraints.jl` | `Int` | Affichage, plotting |
| `dim_variable_constraints_box` | `src/OCP/Components/constraints.jl` | `Int` | Affichage, plotting |

### 2.2 Définitions des fonctions

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Components/constraints.jl:555-557
function dim_path_constraints_nl(model::ConstraintsModel)::Dimension
    return length(path_constraints_nl(model)[1])
end

# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Components/constraints.jl:580-582
function dim_boundary_constraints_nl(model::ConstraintsModel)::Dimension
    return length(boundary_constraints_nl(model)[1])
end

# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Components/constraints.jl:655-657
function dim_variable_constraints_box(model::ConstraintsModel)::Dimension
    return length(variable_constraints_box(model)[1])
end
```

**Note importante** : Ces fonctions retournent des dimensions calculées à partir des contraintes, pas stockées directement.

---

## 3. Métadonnées OCP minimales nécessaires

### 3.1 Liste des métadonnées identifiées

D'après l'analyse des usages, les métadonnées suivantes sont nécessaires :

#### Dimensions principales (toujours nécessaires)

1. **`dim_state::Int`** - Dimension de l'état
   - Utilisé dans : `build_solution`, `_serialize_solution`, plotting
   - Source : `state_dimension(ocp)`

2. **`dim_control::Int`** - Dimension du contrôle
   - Utilisé dans : `build_solution`, `_serialize_solution`, plotting
   - Source : `control_dimension(ocp)`

3. **`dim_variable::Int`** - Dimension de la variable d'optimisation
   - Utilisé dans : `build_solution`, `_serialize_solution`
   - Source : `variable_dimension(ocp)`

#### Dimensions des contraintes (pour affichage/plotting)

4. **`dim_path_constraints::Int`** - Dimension des contraintes de chemin
   - Utilisé dans : Affichage, plotting
   - Source : `dim_path_constraints_nl(ocp)`

5. **`dim_boundary_constraints::Int`** - Dimension des contraintes frontières
   - Utilisé dans : Affichage
   - Source : `dim_boundary_constraints_nl(ocp)`

6. **`dim_variable_constraints_box::Int`** - Dimension des contraintes boîte sur variables
   - Utilisé dans : Affichage
   - Source : `dim_variable_constraints_box(ocp)`

#### Métadonnées optionnelles (pour plotting avancé)

7. **Noms des composants** (si disponibles)
   - Noms des états, contrôles, variables
   - Pour les labels dans les plots
   - **À investiguer** : Actuellement utilisés ?

8. **Bornes des contraintes** (si disponibles)
   - Pour tracer les limites dans les plots
   - **À investiguer** : Actuellement utilisés dans `do_decorate` ?

### 3.2 Métadonnées actuellement stockées dans `build_solution`

Dans `build_solution`, les dimensions sont extraites de l'OCP :

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl:72-76
# get dimensions
dim_x = state_dimension(ocp)
dim_u = control_dimension(ocp)
dim_v = variable_dimension(ocp)
```

Ces dimensions sont utilisées pour :
- Construire les fonctions interpolées
- Valider les tailles des matrices
- **Mais ne sont pas stockées dans la Solution !**

---

## 4. Proposition de structure `OCPMetadata`

### 4.1 Design de la structure

```julia
"""
$(TYPEDEF)

Métadonnées minimales d'un problème OCP, sérialisables et suffisantes pour
l'affichage et le plotting de solutions.

Cette structure stocke uniquement les dimensions et informations structurelles
du problème, sans les fonctions (dynamique, contraintes, objectif).

# Fields

- `dim_state::Int`: Dimension de l'état
- `dim_control::Int`: Dimension du contrôle
- `dim_variable::Int`: Dimension de la variable d'optimisation
- `dim_path_constraints::Int`: Dimension des contraintes de chemin non-linéaires
- `dim_boundary_constraints::Int`: Dimension des contraintes frontières non-linéaires
- `dim_variable_constraints_box::Int`: Dimension des contraintes boîte sur variables

# Example

```julia
metadata = OCPMetadata(
    dim_state = 2,
    dim_control = 1,
    dim_variable = 0,
    dim_path_constraints = 0,
    dim_boundary_constraints = 2,
    dim_variable_constraints_box = 0
)
```

# Notes

- Cette structure est **sérialisable** (pas de fonctions)
- Elle contient **uniquement** les informations nécessaires pour :
  - Afficher une solution (`show(io, sol)`)
  - Tracer une solution (`plot(sol)`)
  - Reconstruire une solution depuis des données discrètes
- Elle **ne permet pas** de résoudre à nouveau le problème
"""
struct OCPMetadata
    dim_state::Int
    dim_control::Int
    dim_variable::Int
    dim_path_constraints::Int
    dim_boundary_constraints::Int
    dim_variable_constraints_box::Int
end
```

### 4.2 Constructeur depuis un `Model`

```julia
"""
$(TYPEDSIGNATURES)

Extrait les métadonnées minimales d'un modèle OCP complet.

# Arguments
- `ocp::Model`: Modèle OCP complet

# Returns
- `OCPMetadata`: Métadonnées sérialisables
"""
function OCPMetadata(ocp::Model)::OCPMetadata
    return OCPMetadata(
        state_dimension(ocp),
        control_dimension(ocp),
        variable_dimension(ocp),
        dim_path_constraints_nl(ocp),
        dim_boundary_constraints_nl(ocp),
        dim_variable_constraints_box(ocp)
    )
end
```

### 4.3 Fonctions d'accès compatibles

Pour maintenir la compatibilité avec le code existant, définir :

```julia
# Dimensions principales
state_dimension(meta::OCPMetadata)::Int = meta.dim_state
control_dimension(meta::OCPMetadata)::Int = meta.dim_control
variable_dimension(meta::OCPMetadata)::Int = meta.dim_variable

# Dimensions des contraintes
dim_path_constraints_nl(meta::OCPMetadata)::Int = meta.dim_path_constraints
dim_boundary_constraints_nl(meta::OCPMetadata)::Int = meta.dim_boundary_constraints
dim_variable_constraints_box(meta::OCPMetadata)::Int = meta.dim_variable_constraints_box
```

---

## 5. Stratégie de migration

### 5.1 Option A : Remplacement complet (Breaking change)

**Avantages** :
- Solution la plus propre
- Réduit la taille des solutions sérialisées
- Élimine complètement les warnings JLD2

**Inconvénients** :
- **Breaking change** : nécessite une version majeure (v1.0)
- Incompatibilité avec les solutions existantes
- Nécessite migration des utilisateurs

**Implémentation** :

```julia
struct Solution{
    # ... autres types ...
    MetadataType<:OCPMetadata,  # ← Remplace ModelType<:AbstractModel
} <: AbstractSolution
    # ... autres champs ...
    metadata::MetadataType  # ← Remplace model::ModelType
end
```

### 5.2 Option B : Ajout progressif (Non-breaking)

**Avantages** :
- **Pas de breaking change**
- Migration progressive possible
- Compatibilité ascendante

**Inconvénients** :
- Redondance temporaire (stockage de `model` ET `metadata`)
- Nécessite deux phases de migration
- Code de transition plus complexe

**Implémentation Phase 1** :

```julia
struct Solution{
    # ... autres types ...
    ModelType<:Union{AbstractModel,OCPMetadata},  # ← Type union
} <: AbstractSolution
    # ... autres champs ...
    model::ModelType  # ← Peut être Model ou OCPMetadata
end
```

**Implémentation Phase 2** (version majeure future) :

```julia
struct Solution{
    # ... autres types ...
    MetadataType<:OCPMetadata,  # ← Uniquement OCPMetadata
} <: AbstractSolution
    # ... autres champs ...
    metadata::MetadataType  # ← Renommage du champ
end
```

### 5.3 Option C : Champ additionnel (Recommandée)

**Avantages** :
- **Pas de breaking change**
- Permet migration douce
- Compatibilité totale
- Peut déprécier progressivement `model`

**Inconvénients** :
- Redondance (deux champs)
- Nécessite gestion de la cohérence

**Implémentation** :

```julia
struct Solution{
    # ... autres types ...
    ModelType<:Union{AbstractModel,Nothing},  # ← Devient optionnel
    MetadataType<:OCPMetadata,
} <: AbstractSolution
    # ... autres champs ...
    model::ModelType  # ← Peut être nothing après import
    metadata::MetadataType  # ← Toujours présent
end
```

**Accesseurs compatibles** :

```julia
# Nouvelle fonction préférée
metadata(sol::Solution) = sol.metadata

# Ancienne fonction (dépréciée)
function model(sol::Solution)
    if !isnothing(sol.model)
        return sol.model
    else
        @warn "model(sol) is deprecated, use metadata(sol) instead" maxlog=1
        return sol.metadata  # Retourne metadata comme fallback
    end
end

# Fonctions de dimension (marchent avec les deux)
state_dimension(sol::Solution) = state_dimension(sol.metadata)
control_dimension(sol::Solution) = control_dimension(sol.metadata)
# etc.
```

---

## 6. Impact sur la sérialisation

### 6.1 Export JLD2 actuel

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/CTModelsJLD.jl:39-45
ocp = CTModels.model(sol)

# Serialize solution to discrete data
data = CTModels.OCP._serialize_solution(sol, ocp)

# Save both the serialized data and the OCP model
jldsave(filename * ".jld2"; solution_data=data, ocp=ocp)  # ← ocp génère warnings
```

**Problème** : `ocp` contient des fonctions → warnings JLD2

### 6.2 Export JLD2 avec `OCPMetadata`

```julia
# Nouvelle version
metadata = CTModels.metadata(sol)  # ou OCPMetadata(CTModels.model(sol))

# Serialize solution to discrete data
data = CTModels.OCP._serialize_solution(sol, metadata)  # ← Adapter signature

# Save both the serialized data and the metadata
jldsave(filename * ".jld2"; solution_data=data, metadata=metadata)  # ← Pas de warnings !
```

**Avantage** : `metadata` est purement numérique → pas de warnings

### 6.3 Modifications nécessaires dans `_serialize_solution`

Actuellement :

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl:807-810
function _serialize_solution(sol::Solution, ocp::Model)::Dict{String, Any}
    # Utiliser les getters publics
    T = time_grid(sol)
    dim_x = state_dimension(ocp)  # ← Appelle ocp
    dim_u = control_dimension(ocp)  # ← Appelle ocp
```

Proposition :

```julia
function _serialize_solution(sol::Solution, meta::OCPMetadata)::Dict{String, Any}
    # Utiliser les getters publics
    T = time_grid(sol)
    dim_x = state_dimension(meta)  # ← Appelle metadata
    dim_u = control_dimension(meta)  # ← Appelle metadata
```

Ou mieux, utiliser directement les dimensions de la solution :

```julia
function _serialize_solution(sol::Solution)::Dict{String, Any}
    # Utiliser les getters publics
    T = time_grid(sol)
    meta = metadata(sol)  # ← Récupère metadata depuis sol
    dim_x = state_dimension(meta)
    dim_u = control_dimension(meta)
```

---

## 7. Investigations complémentaires nécessaires

### 7.1 Fonctions de plotting à analyser

Les fonctions suivantes utilisent `model` et doivent être analysées :

1. **`__size_plot`** - Calcul de la taille du plot
   - Fichier : `ext/plot.jl` ou `ext/plot_utils.jl`
   - **Question** : Quelles métadonnées OCP utilise-t-elle ?

2. **`__initial_plot`** - Initialisation du plot
   - Fichier : `ext/plot.jl`
   - **Question** : Quelles métadonnées OCP utilise-t-elle ?

3. **`do_decorate`** - Décoration du plot (bornes, temps)
   - Fichier : `ext/plot_utils.jl:117-`
   - **Question** : Utilise-t-elle les bornes des contraintes ?

### 7.2 Questions ouvertes

1. **Noms des composants** :
   - Les noms des états/contrôles sont-ils utilisés dans le plotting ?
   - Sont-ils stockés dans `Model` ?
   - Faut-il les inclure dans `OCPMetadata` ?

2. **Bornes des contraintes** :
   - Les bornes sont-elles tracées dans les plots ?
   - Si oui, faut-il les stocker dans `OCPMetadata` ?
   - Format : vecteurs de bornes inf/sup ?

3. **Informations temporelles** :
   - Les noms `t0`, `tf` sont-ils utilisés ?
   - Sont-ils déjà dans `TimesModel` ?

4. **Compatibilité avec `build_solution`** :
   - `build_solution` prend actuellement `ocp::Model` en argument
   - Faut-il créer une surcharge `build_solution(...; metadata::OCPMetadata)` ?
   - Ou extraire automatiquement `metadata` de `ocp` ?

---

## 8. Plan d'action détaillé

### Phase 1 : Analyse complémentaire (1-2h)

- [ ] **Tâche 1.1** : Lire `ext/plot.jl` et identifier tous les usages de `model` dans :
  - `__size_plot`
  - `__initial_plot`
  - Autres fonctions de plotting

- [ ] **Tâche 1.2** : Lire `ext/plot_utils.jl` et analyser :
  - `do_decorate` (ligne 117+)
  - Vérifier si les bornes des contraintes sont utilisées

- [ ] **Tâche 1.3** : Vérifier si les noms des composants sont utilisés :
  - Chercher `state_name`, `control_name`, etc. dans le code de plotting
  - Déterminer si nécessaire dans `OCPMetadata`

- [ ] **Tâche 1.4** : Documenter les résultats dans ce fichier (section 9)

### Phase 2 : Design de `OCPMetadata` (30min)

- [ ] **Tâche 2.1** : Finaliser la structure `OCPMetadata` avec tous les champs nécessaires

- [ ] **Tâche 2.2** : Définir les constructeurs et accesseurs

- [ ] **Tâche 2.3** : Documenter la structure complète

### Phase 3 : Implémentation (2-3h)

- [ ] **Tâche 3.1** : Créer `src/OCP/Types/metadata.jl` avec :
  - Structure `OCPMetadata`
  - Constructeur depuis `Model`
  - Fonctions d'accès (`state_dimension`, etc.)

- [ ] **Tâche 3.2** : Modifier `src/OCP/Types/solution.jl` :
  - Ajouter champ `metadata::OCPMetadata`
  - Garder `model::Union{AbstractModel,Nothing}` pour compatibilité

- [ ] **Tâche 3.3** : Modifier `src/OCP/Building/solution.jl` :
  - Adapter `build_solution` pour créer `metadata` depuis `ocp`
  - Adapter `_serialize_solution` pour utiliser `metadata`
  - Ajouter accesseur `metadata(sol::Solution)`

- [ ] **Tâche 3.4** : Modifier `ext/CTModelsJLD.jl` :
  - Export : sauver `metadata` au lieu de `ocp`
  - Import : reconstruire avec `metadata`

- [ ] **Tâche 3.5** : Adapter le code de plotting si nécessaire

### Phase 4 : Tests (1-2h)

- [ ] **Tâche 4.1** : Créer tests unitaires pour `OCPMetadata`

- [ ] **Tâche 4.2** : Vérifier que tous les tests existants passent

- [ ] **Tâche 4.3** : Tester export/import JLD2 sans warnings

- [ ] **Tâche 4.4** : Vérifier que le plotting fonctionne

### Phase 5 : Documentation (30min)

- [ ] **Tâche 5.1** : Documenter `OCPMetadata` dans la doc utilisateur

- [ ] **Tâche 5.2** : Ajouter exemple d'utilisation

- [ ] **Tâche 5.3** : Mettre à jour CHANGELOG.md

---

## 9. Résultats des investigations complémentaires

### 9.1 Analyse de `__size_plot`

**À compléter après investigation**

### 9.2 Analyse de `__initial_plot`

**À compléter après investigation**

### 9.3 Analyse de `do_decorate`

**À compléter après investigation**

### 9.4 Utilisation des noms de composants

**À compléter après investigation**

### 9.5 Utilisation des bornes de contraintes

**À compléter après investigation**

---

## 10. Recommandations finales

### 10.1 Stratégie recommandée

**Option C (Champ additionnel)** est recommandée car :

1. **Pas de breaking change** - Compatible avec les versions existantes
2. **Migration douce** - Les utilisateurs peuvent migrer progressivement
3. **Dépréciation progressive** - `model(sol)` peut être déprécié sur plusieurs versions
4. **Sérialisation propre** - Export JLD2 sans warnings dès maintenant

### 10.2 Timeline suggérée

- **v0.x (actuelle)** : Ajouter `metadata` en parallèle de `model`
- **v0.x+1** : Déprécier `model(sol)`, recommander `metadata(sol)`
- **v1.0** : Supprimer `model` de `Solution`, garder uniquement `metadata`

### 10.3 Bénéfices attendus

1. **Réduction des warnings JLD2** - Objectif principal ✅
2. **Réduction de la taille des fichiers** - Solutions plus légères
3. **Sérialisation plus rapide** - Moins de données à écrire
4. **Meilleure séparation des responsabilités** - Solution ≠ Problème

---

## Références

### Fichiers sources analysés

- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Types/solution.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/CTModelsJLD.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot_utils.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Components/constraints.jl`

### Documents connexes

- [`reports/2026-01-29_Idempotence/walkthrough.md`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-29_Idempotence/walkthrough.md)
- [`reports/2026-01-29_Idempotence/analysis/01_serialization_idempotence_analysis.md`](file:///Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/reports/2026-01-29_Idempotence/analysis/01_serialization_idempotence_analysis.md)

---

**Auteur** : CTModels Development Team  
**Date de création** : 2026-01-30  
**Dernière mise à jour** : 2026-01-30  
**Statut** : 🔍 Analyse en cours - Phase 1 à compléter
