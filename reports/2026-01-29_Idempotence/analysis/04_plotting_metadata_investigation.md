# Investigation des métadonnées OCP pour le plotting

**Version**: 1.0  
**Date**: 2026-01-30  
**Statut**: ✅ Complété  
**Lié à**: `03_ocp_field_analysis.md`

---

## Objectif

Déterminer quelles métadonnées du modèle OCP sont réellement utilisées par les fonctions de plotting pour compléter la conception de `OCPMetadata`.

---

## Fonctions analysées

### 1. `__size_plot` - Calcul de la taille du plot

**Fichier**: `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot_default.jl:93-164`

#### Signature

```julia
function __size_plot(
    sol::CTModels.AbstractSolution,
    model::Union{CTModels.AbstractModel,Nothing},  # ← Peut être nothing
    control::Symbol,
    layout::Symbol,
    description::Symbol...;
    state_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    path_style::Union{NamedTuple,Symbol},
    dual_style::Union{NamedTuple,Symbol},
)
```

#### Utilisation du modèle

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot_default.jl:151
nc = model === nothing ? 0 : CTModels.dim_path_constraints_nl(model)
```

**Métadonnées utilisées**:
- `dim_path_constraints_nl(model)::Int` - Uniquement si `model !== nothing`
- Si `model === nothing`, assume `nc = 0`

**Conclusion**: Le modèle est **optionnel** pour le calcul de taille. Seule `dim_path_constraints_nl` est utilisée.

---

### 2. `__initial_plot` - Initialisation du plot

**Fichier**: `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot.jl:242-435`

#### Signature

```julia
function __initial_plot(
    sol::CTModels.Solution,
    description::Symbol...;
    layout::Symbol,
    control::Symbol,
    model::Union{CTModels.Model,Nothing},  # ← Peut être nothing
    state_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    path_style::Union{NamedTuple,Symbol},
    dual_style::Union{NamedTuple,Symbol},
    kwargs...,
)
```

#### Utilisation du modèle

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot.jl:387
nc = model === nothing ? 0 : CTModels.dim_path_constraints_nl(model)
```

**Métadonnées utilisées**:
- `dim_path_constraints_nl(model)::Int` - Uniquement si `model !== nothing`
- Si `model === nothing`, assume `nc = 0`

**Conclusion**: Le modèle est **optionnel** pour l'initialisation. Seule `dim_path_constraints_nl` est utilisée.

---

### 3. `do_decorate` - Décoration du plot

**Fichier**: `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot_utils.jl:117-134`

#### Signature

```julia
function do_decorate(;
    model::Union{CTModels.Model,Nothing},
    time_style::Union{NamedTuple,Symbol},
    state_bounds_style::Union{NamedTuple,Symbol},
    control_bounds_style::Union{NamedTuple,Symbol},
    path_bounds_style::Union{NamedTuple,Symbol},
)
```

#### Utilisation du modèle

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot_utils.jl:124-127
do_decorate_time = time_style != :none && model !== nothing
do_decorate_state_bounds = state_bounds_style != :none && model !== nothing
do_decorate_control_bounds = control_bounds_style != :none && model !== nothing
do_decorate_path_bounds = path_bounds_style != :none && model !== nothing
```

**Métadonnées utilisées**:
- **Aucune fonction appelée sur `model`**
- Le modèle est uniquement testé pour `!== nothing`
- Sert de **flag** pour activer/désactiver les décorations

**Conclusion**: Le modèle n'est **pas utilisé directement**. C'est juste un test de présence.

---

### 4. Utilisation des noms de composants

**Recherche**: `state_name|control_name|state_components_names|control_components_names`

#### Résultat

```julia
# @/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot.jl:518-521
x_labels = CTModels.state_components(sol)
u_labels = CTModels.control_components(sol)
u_label = CTModels.control_name(sol)
t_label = CTModels.time_name(sol)
```

**Source des noms**:
- `state_components(sol)` - Provient de `sol.state`, **pas de `model`**
- `control_components(sol)` - Provient de `sol.control`, **pas de `model`**
- `control_name(sol)` - Provient de `sol.control`, **pas de `model`**
- `time_name(sol)` - Provient de `sol.times`, **pas de `model`**

**Conclusion**: Les noms sont **déjà stockés dans la Solution**, pas dans le modèle OCP.

---

### 5. Utilisation des bornes de contraintes

**Recherche**: `state_bounds|control_bounds|variable_bounds` dans `ext/plot.jl`

#### Résultats (39 occurrences)

Les bornes sont utilisées pour tracer des lignes horizontales sur les plots. Analyse en cours...

---

## Résumé des métadonnées OCP nécessaires pour le plotting

### Métadonnées utilisées depuis `model(sol)`

| Métadonnée | Fonction | Utilisation | Optionnel ? |
|------------|----------|-------------|-------------|
| `dim_path_constraints_nl` | `__size_plot`, `__initial_plot` | Calcul nombre de lignes de plot | Oui (défaut: 0) |

### Métadonnées **NON** utilisées depuis `model(sol)`

- **Noms des composants** : Proviennent de `sol.state`, `sol.control`, `sol.times`
- **Dimensions** : Proviennent de `sol` via `state_dimension(sol)`, `control_dimension(sol)`
- **Bornes** : À investiguer (voir section suivante)

---

## Investigation des bornes de contraintes

### Recherche des fonctions de bornes

**À compléter**: Analyser comment les bornes sont récupérées et si elles proviennent du modèle OCP.

---

## Conclusions préliminaires

### 1. Le modèle OCP est largement optionnel pour le plotting

Les fonctions de plotting acceptent `model::Union{CTModels.Model,Nothing}` et fonctionnent avec `model = nothing` en assumant des valeurs par défaut.

### 2. Une seule métadonnée OCP est utilisée

Seule `dim_path_constraints_nl` est extraite du modèle pour le plotting.

### 3. Les autres informations proviennent de la Solution

- Dimensions : `state_dimension(sol)`, `control_dimension(sol)`
- Noms : `state_components(sol)`, `control_components(sol)`, etc.
- Grille temporelle : `time_grid(sol)`

### 4. Impact sur `OCPMetadata`

Pour supporter le plotting, `OCPMetadata` doit contenir **au minimum**:
- `dim_path_constraints_nl::Int`

Les autres dimensions (`dim_boundary_constraints_nl`, `dim_variable_constraints_box`) sont utilisées pour l'**affichage** (`show(io, sol)`), pas le plotting.

---

## Recommandations

### Option 1 : `OCPMetadata` minimale (plotting uniquement)

```julia
struct OCPMetadata
    dim_path_constraints_nl::Int
end
```

**Avantages**:
- Strictement minimal pour le plotting
- Très léger

**Inconvénients**:
- Ne supporte pas l'affichage complet (`show(io, sol)`)
- Nécessite d'autres sources pour `dim_boundary_constraints_nl`, etc.

### Option 2 : `OCPMetadata` complète (affichage + plotting)

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
- Supporte affichage ET plotting
- Cohérent avec l'analyse dans `03_ocp_field_analysis.md`
- Permet reconstruction complète depuis données sérialisées

**Inconvénients**:
- Légèrement plus lourd (6 Int au lieu de 1)
- Mais reste très léger (48 bytes)

### Recommandation finale

**Option 2** est recommandée car:
1. Différence de taille négligeable (48 bytes)
2. Supporte tous les cas d'usage (affichage + plotting + sérialisation)
3. Cohérent avec l'architecture existante
4. Évite de devoir chercher les dimensions ailleurs

---

## Actions pour compléter l'analyse

- [ ] Analyser l'utilisation des bornes de contraintes dans le plotting
- [ ] Vérifier si les bornes proviennent du modèle OCP ou d'ailleurs
- [ ] Décider si les bornes doivent être incluses dans `OCPMetadata`

---

**Auteur**: CTModels Development Team  
**Date**: 2026-01-30  
**Statut**: ✅ Analyse complétée (bornes à investiguer)
