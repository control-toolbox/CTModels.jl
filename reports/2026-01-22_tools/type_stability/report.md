# Rapport de Stabilité de Type : Options & Strategies

Ce rapport analyse la stabilité de type des modules `src/Options` et `src/Strategies` de `CTModels.jl`, en se concentrant sur les impacts des structures de données (`Dict` vs `NamedTuple`) et les optimisations récentes.

## 1. Contexte : Dict vs NamedTuple

L'usage des deux structures est motivé par des besoins différents :

| Structure | Usage dans le code | Justification | Stabilité de Type |
| :--- | :--- | :--- | :--- |
| **Dict** | `StrategyRegistry` | Clés de types (`Type`). | Faible (valeurs de type `Any` ou `Vector{Type}`). |
| **NamedTuple** | `StrategyOptions` | Clés symboliques (`Symbol`). | Excellente (si paramétré). |

### Analyse du Registre (`StrategyRegistry`)
Le registre utilise un `Dict{Type{<:AbstractStrategy}, Vector{Type}}`. C'est **nécessaire** car Julia ne supporte pas de types comme clés dans les `NamedTuple`. Comme le registre est principalement utilisé pour la recherche au démarrage ou lors de la construction, l'impact sur les performances des boucles calculatoires est négligeable.

---

## 2. Améliorations Récentes

Suite à l'analyse, deux structures critiques ont été paramétrées pour garantir que le compilateur Julia puisse inférer les types exacts.

### StrategyOptions
Passage d'un champ `options::NamedTuple` (abstrait) à un type paramétré `StrategyOptions{NT <: NamedTuple}`.
- **Impact** : Accès direct aux options sans "boxing".
- **Bonus** : Ajout de `get(opts, Val(:key))` pour un accès stable garanti par le compilateur.

### OptionDefinition
Passage à `OptionDefinition{T}`.
- **Impact** : Le champ `default` passe de `Any` à `T`. Lors de l'extraction des options par défaut, le compilateur connaît maintenant le type exact de la valeur retournée.

---

## 3. Goulots d'étranglement restants

Malgré ces avancées, deux points de friction subsistent lors de la phase de *construction* et d' *introspection*.

### Construction : `extract_options`
Dans `extraction.jl`, la méthode qui prend un `NamedTuple` de définitions utilise un accumulateur `Pair{Symbol, OptionValue}[]`.
- **Problème** : Les vecteurs de `Pair` perdent la spécificité des types. Le `NamedTuple` final est construit à partir d'un objet opaque pour le compilateur.
- **Solution recommandée** : Réimplémenter via une récursion sur les types ou un `map` sur le `NamedTuple` de définitions.

### Introspection : `StrategyMetadata`
Actuellement, `StrategyMetadata` encapsule un `Dict{Symbol, OptionDefinition}`.
- **Problème** : Toute fonction interrogeant les métadonnées (comme `option_defaults` ou `option_type`) passe par un dictionnaire, ce qui casse l'inférence.
- **Solution recommandée** : Remplacer le `Dict` par un `NamedTuple` dans `StrategyMetadata`.

---

## 4. Synthèse et Recommandations

Pour atteindre une performance maximale (zéro overhead) dans les solveurs :

1.  **Prioriser les accès stables** : Utiliser la nouvelle interface `get(opts, Val(:key))` dans les zones critiques.
2.  **Figer les métadonnées** : Migrer `StrategyMetadata` vers une structure basée sur `NamedTuple`.
3.  **Tests de non-régression** : Ajouter systématiquement des tests `Test.@inferred` pour l'accès aux options des nouvelles stratégies.

---
*Rapport généré le 24 Janvier 2026.*
