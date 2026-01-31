# Règles d'Export pour CTModels.jl

## Règle Absolue

### Ne rien exporter depuis CTModels.jl

Les exports doivent se faire **uniquement depuis les sous-modules** (OCP, Utils, Display, Serialization, InitialGuess, etc.).

## Principe

CTModels.jl est un module d'orchestration qui :

- Charge les sous-modules avec `include()` et `using .Module`
- Ne fait **aucun export** directement
- Rend les exports des sous-modules accessibles via `CTModels.function_name()`

## Architecture des Exports

```julia
# ❌ INCORRECT - Ne jamais faire ceci dans CTModels.jl
export function_name

# ✅ CORRECT - Dans CTModels.jl
using .OCP  # Les exports d'OCP deviennent accessibles via CTModels.OCP.function_name()
            # et aussi via CTModels.function_name() grâce au using

# ✅ CORRECT - Dans src/OCP/OCP.jl
export function_name  # Export depuis le sous-module
```

## Cas Particuliers

### RecipesBase.plot

Pour les fonctions externes comme `plot` et `plot!` de RecipesBase :

```julia
# Dans CTModels.jl
import RecipesBase: RecipesBase, plot, plot!
export plot, plot!
```

Cette exception est nécessaire car :

- `plot` est défini dans RecipesBase (package externe)
- Display définit `RecipesBase.plot(sol::AbstractSolution, ...)` pour l'extension
- L'import/export dans CTModels.jl rend `CTModels.plot()` accessible

### Surcharge de Fonctions

Quand un sous-module surcharge une fonction d'un autre sous-module :

```julia
# Dans src/OCP/OCP.jl
import ..Optimization: build_solution  # Import pour surcharge
# Puis définir la méthode spécifique
function build_solution(ocp::Model, ...)
    # ...
end
```

## Modules et leurs Exports

### OCP (~50 exports)

- Types et aliases
- Fonctions de construction (`state!`, `control!`, `dynamics!`, etc.)
- Accesseurs de modèle et solution
- Prédicats (`has_*`, `is_*`)

### Utils

- `ctinterpolate`
- `matrix2vec`
- `@ensure` (macro)

### Display

- Pas d'export direct (Base.show est automatique)
- `plot` et `plot!` exportés via CTModels.jl

### Serialization

- `export_ocp_solution`
- `import_ocp_solution`
- `JLD2Tag`, `JSON3Tag`, `AbstractTag`

### InitialGuess

- `initial_guess`
- `build_initial_guess`
- `validate_initial_guess`
- Types associés

## Vérification

Pour vérifier qu'une fonction est accessible :

```julia
using CTModels
println(isdefined(CTModels, :function_name))  # doit retourner true
```

## Avantages de cette Architecture

1. **Clarté** : Chaque module contrôle ses propres exports
2. **Modularité** : Les modules peuvent être utilisés indépendamment
3. **Extensibilité** : Facile d'ajouter de nouveaux modules
4. **Maintenance** : Les exports sont localisés dans leurs modules respectifs
5. **Pas de conflits** : Les sous-modules gèrent leurs propres namespaces

## Date de Mise à Jour

Dernière mise à jour : 27 janvier 2026
