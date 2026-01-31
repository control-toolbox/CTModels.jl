# Rapport d'Analyse : Restructuration Complète de `src/core`

## Analyse Approfondie de la Structure Actuelle

### Problème Fondamental : Définition Ambiguë de "Core"

Le terme `core` est actuellement utilisé pour regrouper des éléments qui n'ont pas la même nature :

1. **Types fondamentaux OCP** (dans `core/types/`)
2. **Utilitaires génériques** (dans `core/` directement)
3. **Valeurs par défaut** (spécifiques au domaine OCP)

### Analyse Détaillée par Fichier

#### Types OCP dans `core/types/` : À DÉPLACER vers `src/ocp/`

**Arguments pour le déplacement :**
- `ocp_components.jl` : Types TimeDependence, Autonomous, NonAutonomous → logiquement dans `src/ocp/time_dependence.jl`
- `ocp_model.jl` : Types Model/PreModel → logiquement dans `src/ocp/model.jl` 
- `ocp_solution.jl` : Types Solution/Dual → logiquement dans `src/ocp/solution.jl`

**Preuve par l'existence de `src/ocp/` :**
Le répertoire `src/ocp/` contient déjà 13 fichiers spécialisés OCP, prouvant que c'est l'emplacement approprié pour tout ce qui concerne les OCP.

#### Utilitaires dans `core/` : À RENOMMER/RÉORGANISER

**`core/utils.jl` :**
- Contient `ctinterpolate()` et fonctions de manipulation de matrices
- Ce sont des **utilitaires généraux** pas spécifiques au "core"
- Proposition : créer `src/utils/` ou `src/helpers/`

**`core/default.jl` :**
- Contient des valeurs par défaut spécifiques aux OCP (`__constraints()`, `__control_name()`, etc.)
- Ce ne sont pas des "defaults du core" mais des "defaults OCP"
- Proposition : déplacer vers `src/ocp/defaults.jl`

## Proposition de Restructuration Complète

### Structure Cible

```
src/
├── ocp/                           # TOUT ce qui concerne les OCP
│   ├── types/                     # Types OCP (déplacés de core/types/)
│   │   ├── components.jl         # ex: ocp_components.jl
│   │   ├── model.jl             # ex: ocp_model.jl  
│   │   └── solution.jl          # ex: ocp_solution.jl
│   ├── components.jl              # Implémentations des composants
│   ├── model.jl                  # Implémentations des modèles
│   ├── solution.jl               # Implémentations des solutions
│   ├── defaults.jl               # Valeurs par défaut OCP (déplacé de core/)
│   └── [autres fichiers OCP...]
├── utils/                         # Utilitaires généraux
│   ├── interpolation.jl          # ctinterpolate et fonctions associées
│   ├── matrix_utils.jl           # fonctions de manipulation de matrices
│   └── utils.jl                  # inclusion des utilitaires
├── init/                         # Initialisation (inchangé)
├── nlp/                          # NLP (avec types.jl ajouté)
├── Options/                      # Options (inchangé)
├── Orchestration/                # Orchestration (inchangé)
├── Strategies/                   # Strategies (inchangé)
└── CTModels.jl                   # Fichier principal
```

### Actions Précises

#### 1. Suppression Complète de `src/core/`
- Raison : Le concept de "core" est ambigu et inutile
- Tous les fichiers seront redistribués selon leur fonction réelle

#### 2. Déplacement des Types OCP
```bash
# Types → src/ocp/types/
mv src/core/types/ocp_components.jl → src/ocp/types/components.jl
mv src/core/types/ocp_model.jl → src/ocp/types/model.jl  
mv src/core/types/ocp_solution.jl → src/ocp/types/solution.jl
```

#### 3. Réorganisation des Utilitaires
```bash
# Utils → src/utils/
mv src/core/utils.jl → src/utils/interpolation.jl
# Créer src/utils/utils.jl pour l'inclusion
```

#### 4. Déplacement des Defaults
```bash
# Defaults → src/ocp/
mv src/core/default.jl → src/ocp/defaults.jl
```

#### 5. Mise à Jour des Inclusions
```julia
# Dans src/CTModels.jl
include(joinpath(@__DIR__, "ocp", "types", "components.jl"))
include(joinpath(@__DIR__, "ocp", "types", "model.jl"))
include(joinpath(@__DIR__, "ocp", "types", "solution.jl"))
include(joinpath(@__DIR__, "ocp", "defaults.jl"))
include(joinpath(@__DIR__, "utils", "interpolation.jl"))
```

### Avantages de Cette Restructuration

1. **Clarté Sémantique** : Chaque répertoire a une responsabilité claire
2. **Cohérence** : Tout ce qui concerne les OCP est dans `src/ocp/`
3. **Maintenabilité** : Plus facile de trouver et modifier du code
4. **Scalabilité** : Structure qui peut grandir logiquement

### Impact sur la Documentation

**Mises à jour nécessaires dans `docs/api_reference.jl` :**

```julia
# Anciennes références à supprimer :
"core/types/ocp_components.jl"
"core/types/ocp_model.jl" 
"core/types/ocp_solution.jl"
"core/default.jl"
"core/utils.jl"

# Nouvelles références à ajouter :
"ocp/types/components.jl"
"ocp/types/model.jl"
"ocp/types/solution.jl"
"ocp/defaults.jl"
"utils/interpolation.jl"
```

### Validation de la Proposition

Cette structure est cohérente avec :
- **L'existence déjà prouvée de `src/ocp/`** avec 13 fichiers spécialisés
- **Les principes d'architecture logicielle** (responsabilité unique)
- **Les pratiques Julia** (séparation claire des préoccupations)

## Conclusion

La suppression complète de `src/core/` et la redistribution selon la fonctionnalité résout non seulement les problèmes identifiés initialement, mais aussi clarifie l'architecture globale du package.

Le concept de "core" était une abstraction inutile - la vraie structure est fonctionnelle : OCP, utils, init, nlp, etc.
