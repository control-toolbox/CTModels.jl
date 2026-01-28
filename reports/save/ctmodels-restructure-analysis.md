# Analyse Complète : Restructuration de `src/CTModels.jl`

## Problème Actuel

Le fichier `src/CTModels.jl` contient 285 lignes qui mélangent plusieurs responsabilités :

1. **Définition du module** (lignes 1-13)
2. **Imports et dépendances** (lignes 14-29)
3. **Sous-modules** (lignes 30-38)
4. **Alias de types** (lignes 42-118) - **À EXTRAIRE**
5. **Fonctions par défaut** (lignes 119-126) - **Déjà bien organisé**
6. **Types export/import** (lignes 128-244) - **À EXTRAIRE**
7. **Includes OCP** (lignes 247-260) - **À GROUPER**
8. **Alias CTSolvers** (lignes 264-272)
9. **Includes NLP et init** (lignes 274-282)

## Proposition de Restructuration

### Structure Cible

```
src/
├── CTModels.jl                    # Fichier principal minimal (20-30 lignes)
├── types/
│   ├── aliases.jl                # Alias de types (Dimension, ctNumber, etc.)
│   └── export_import.jl          # Types pour export/import (AbstractTag, etc.)
├── ocp/
│   ├── ocp.jl                    # Fichier d'inclusion pour tous les fichiers OCP
│   └── [fichiers existants...]
└── [autres fichiers...]
```

### Actions Requises

#### 1. Extraire les alias de types (lignes 42-118)
**Fichier cible : `src/types/aliases.jl`**
- `Dimension`, `ctNumber`, `Time`, `ctVector`, `Times`, `TimesDisc`, `ConstraintsDictType`
- Ces alias sont fondamentaux et utilisés partout

#### 2. Extraire les types export/import (lignes 128-244)
**Fichier cible : `src/types/export_import.jl`**
- `AbstractTag`, `JLD2Tag`, `JSON3Tag`
- Fonctions `export_ocp_solution` et `import_ocp_solution`
- Extensions pour les packages externes

#### 3. Grouper les includes OCP (lignes 247-260)
**Fichier cible : `src/ocp/ocp.jl`**
- Inclure tous les fichiers OCP dans un seul fichier
- Simplifier le fichier principal

#### 4. Simplifier le fichier principal
**Fichier cible : `src/CTModels.jl`**
- Garder uniquement : définition du module, imports, sous-modules
- Inclure les nouveaux fichiers organisés

### Avantages

1. **Clarté** : chaque fichier a une responsabilité unique
2. **Maintenabilité** : facile de trouver et modifier des types spécifiques
3. **Lisibilité** : le fichier principal devient lisible et compréhensible
4. **Cohérence** : respecte le principe de séparation des préoccupations

### Impact sur la Documentation

- Mettre à jour `docs/api_reference.jl` pour référencer les nouveaux fichiers
- Assurer que les liens dans les docstrings fonctionnent toujours

### Validation

- Tester que `using CTModels` fonctionne toujours
- Vérifier que tous les types et fonctions sont accessibles
- Confirmer que la compilation est réussie
