# Projet Idempotence et Optimisation de la Sérialisation

**Date de création**: 2026-01-29  
**Dernière mise à jour**: 2026-01-30  
**Issue GitHub**: [#217](https://github.com/control-toolbox/CTModels.jl/issues/217)

---

## Vue d'ensemble

Ce répertoire contient l'ensemble de la documentation relative au projet d'amélioration de la sérialisation des solutions OCP dans CTModels.jl. Le projet se décompose en plusieurs phases :

1. ✅ **Phase 1** : Tests d'idempotence (Complétée)
2. ✅ **Phase 2** : Réduction des warnings JLD2 pour les fonctions (Complétée)
3. 🔍 **Phase 3** : Réduction des warnings JLD2 pour le champ `model` (En analyse)

---

## Structure du répertoire

```
reports/2026-01-29_Idempotence/
├── README.md                          # Ce fichier
├── walkthrough.md                     # Historique complet du projet
├── PR_DESCRIPTION.md                  # Description de la PR
│
├── analysis/                          # Analyses techniques détaillées
│   ├── 01_serialization_idempotence_analysis.md
│   ├── 02_vector_conversion_investigation.md
│   ├── 03_ocp_field_analysis.md              # ⭐ Analyse du champ model
│   ├── 04_plotting_metadata_investigation.md  # ⭐ Métadonnées pour plotting
│   └── 05_bounds_metadata_analysis.md         # ⭐ Bornes de contraintes
│
├── reference/                         # Plans et spécifications
│   └── 01_serialization_idempotence_plan.md
│
└── progress/                          # Suivi de progression
    └── phase2_discretization_progress.md
```

---

## Phase 3 : Optimisation du champ `model` dans `Solution`

### Contexte

Le champ `model::ModelType` dans la structure `Solution` stocke une référence complète au problème OCP, incluant :
- Les fonctions (dynamique, contraintes, objectif)
- Les structures complexes imbriquées
- Des closures potentiellement non sérialisables

Cela génère des **warnings lors de l'export JLD2**.

### Objectif

Remplacer le champ `model` par une structure `OCPMetadata` minimale et sérialisable contenant uniquement les métadonnées nécessaires pour :
- Afficher une solution
- Tracer une solution
- Reconstruire une solution depuis des données discrètes

### Documents d'analyse (Phase 3)

#### 1. `03_ocp_field_analysis.md` ⭐ **Document principal**

**Contenu** :
- Inventaire complet des 16 usages de `model(sol)` dans le code
- Analyse détaillée de chaque usage
- Liste des métadonnées OCP nécessaires (6 dimensions)
- Proposition de structure `OCPMetadata`
- 3 stratégies de migration (A, B, C)
- Plan d'action détaillé en 5 phases

**Sections clés** :
- Section 1 : Inventaire des usages
- Section 3 : Métadonnées minimales nécessaires
- Section 4 : Proposition de structure `OCPMetadata`
- Section 5 : Stratégie de migration (Option C recommandée)
- Section 8 : Plan d'action détaillé

#### 2. `04_plotting_metadata_investigation.md`

**Contenu** :
- Analyse approfondie des fonctions de plotting
- `__size_plot`, `__initial_plot`, `do_decorate`
- Découverte : Le modèle est **optionnel** pour le plotting
- Une seule métadonnée utilisée : `dim_path_constraints_nl`
- Les noms de composants proviennent de `sol`, pas de `model`

**Conclusion** : Le modèle OCP est largement optionnel pour le plotting.

#### 3. `05_bounds_metadata_analysis.md`

**Contenu** :
- Analyse de l'utilisation des bornes de contraintes
- `state_constraints_box(model)`, `control_constraints_box(model)`
- Décision : **Ne pas inclure les bornes** dans `OCPMetadata`
- Justification : Optionnelles, volumineuses, déjà comportement actuel

**Conclusion** : `OCPMetadata` reste minimal (6 entiers, 48 bytes).

---

## Structure `OCPMetadata` recommandée

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

**Taille** : 48 bytes (6 × 8 bytes)

**Fonctionnalités supportées** :
- ✅ Affichage complet (`show(io, sol)`)
- ✅ Plotting sans bornes (`plot(sol)`)
- ✅ Reconstruction depuis données discrètes
- ✅ Export/import JLD2 sans warnings
- ❌ Plotting avec bornes (nécessite `model=ocp`)

---

## Stratégie de migration recommandée

**Option C : Champ additionnel** (Non-breaking change)

### Implémentation

```julia
struct Solution{
    # ... autres types ...
    ModelType<:Union{AbstractModel,Nothing},  # ← Devient optionnel
    MetadataType<:OCPMetadata,
} <: AbstractSolution
    # ... autres champs ...
    model::ModelType      # ← Peut être nothing après import
    metadata::MetadataType  # ← Toujours présent
end
```

### Accesseurs compatibles

```julia
# Nouvelle fonction (préférée)
metadata(sol::Solution) = sol.metadata

# Ancienne fonction (dépréciée progressivement)
function model(sol::Solution)
    if !isnothing(sol.model)
        return sol.model
    else
        @warn "model(sol) is deprecated, use metadata(sol)" maxlog=1
        return sol.metadata
    end
end

# Fonctions de dimension (marchent avec les deux)
state_dimension(sol::Solution) = state_dimension(sol.metadata)
```

### Timeline

- **v0.x (actuelle)** : Ajouter `metadata` en parallèle de `model`
- **v0.x+1** : Déprécier `model(sol)`, recommander `metadata(sol)`
- **v1.0** : Supprimer `model`, garder uniquement `metadata`

---

## Plan d'action pour implémentation

### Phase 1 : Analyse complémentaire (✅ Complétée)

- [x] Analyser toutes les fonctions de plotting
- [x] Identifier les métadonnées nécessaires
- [x] Décider du contenu de `OCPMetadata`
- [x] Documenter les résultats

### Phase 2 : Design de `OCPMetadata` (À faire)

- [ ] Créer `src/OCP/Types/metadata.jl`
- [ ] Définir la structure `OCPMetadata`
- [ ] Créer constructeur depuis `Model`
- [ ] Définir fonctions d'accès compatibles

### Phase 3 : Modification de `Solution` (À faire)

- [ ] Modifier `src/OCP/Types/solution.jl`
- [ ] Ajouter champ `metadata::OCPMetadata`
- [ ] Garder `model::Union{AbstractModel,Nothing}`
- [ ] Adapter `build_solution`

### Phase 4 : Adaptation de la sérialisation (À faire)

- [ ] Modifier `_serialize_solution` pour utiliser `metadata`
- [ ] Modifier `ext/CTModelsJLD.jl` pour sauver `metadata`
- [ ] Tester export/import sans warnings

### Phase 5 : Tests et documentation (À faire)

- [ ] Tests unitaires pour `OCPMetadata`
- [ ] Tests d'export/import
- [ ] Tests de plotting
- [ ] Documentation utilisateur

---

## Prochaines étapes

### Pour continuer le travail

1. **Lire les documents d'analyse** dans l'ordre :
   - `03_ocp_field_analysis.md` (document principal)
   - `04_plotting_metadata_investigation.md`
   - `05_bounds_metadata_analysis.md`

2. **Suivre le plan d'action** dans `03_ocp_field_analysis.md` section 8

3. **Commencer par Phase 2** : Créer `src/OCP/Types/metadata.jl`

### Points d'attention

- **Compatibilité** : Option C garantit pas de breaking change
- **Tests** : Vérifier que tous les tests existants passent
- **Plotting** : Tester avec et sans `model`
- **Documentation** : Documenter la dépréciation progressive

---

## Références

### Fichiers sources clés

- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Types/solution.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/src/OCP/Building/solution.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/CTModelsJLD.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot.jl`
- `@/Users/ocots/Research/logiciels/dev/control-toolbox/CTModels.jl/ext/plot_utils.jl`

### Documents connexes

- `walkthrough.md` - Historique complet du projet
- `analysis/01_serialization_idempotence_analysis.md` - Phase 1
- `progress/phase2_discretization_progress.md` - Phase 2

---

## Contacts et support

**Équipe** : CTModels Development Team  
**Issue GitHub** : [#217](https://github.com/control-toolbox/CTModels.jl/issues/217)  
**Dernière révision** : 2026-01-30

---

## Résumé exécutif

### Problème

Le champ `model::ModelType` dans `Solution` génère des warnings JLD2 car il contient des fonctions et structures complexes non sérialisables.

### Solution

Remplacer par `OCPMetadata` contenant uniquement 6 dimensions (48 bytes), suffisant pour affichage, plotting et reconstruction.

### Impact

- ✅ Pas de breaking change (Option C)
- ✅ Élimine les warnings JLD2
- ✅ Réduit la taille des fichiers sérialisés
- ✅ Maintient toutes les fonctionnalités essentielles

### Prochaine étape

Implémenter Phase 2 : Créer `src/OCP/Types/metadata.jl` avec la structure `OCPMetadata`.
