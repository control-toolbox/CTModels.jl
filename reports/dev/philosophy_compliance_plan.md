# Plan : mise en conformité de CTModels avec la philosophie

> État des lieux complet + plan d'exécution. Réfère à
> [`dev/philosophy/PHILOSOPHY.md`](../../dev/philosophy/PHILOSOPHY.md) et ses annexes.
> Statut : **en attente de validation humaine** (décisions D1–D3 à trancher).

---

# Partie 1 — État des lieux

## Ce qui est déjà conforme ✅

| Tenet | État |
|---|---|
| 1. Un module par responsabilité | ✅ `OCP`, `Display`, `Serialization`, `Init` — un répertoire + un manifest chacun ; le top-level ne fait que `include` + `using .Sub` |
| 6. Erreurs structurées | ✅ à ~95 % : `Exceptions.IncorrectArgument` / `PreconditionError` / `ExtensionError` avec `got`/`expected`/`suggestion`/`context` partout dans `Init`, `OCP`, `Serialization` |
| 9. Tests : module + fonction + qualifié | ✅ les 44 fichiers `test/suite/*/test_*.jl` suivent le template (module, `import X: X`, fakes top-level, entry function redéfinie) |
| 8. Docstrings | ✅ largement présentes (`$(TYPEDSIGNATURES)`, sections structurées) |
| DAG de dépendances | ✅ `OCP → Display → Serialization → Init`, pas de cycle |

Le gros du travail porte sur le **tenet 2 (« Everything is qualified »)** : styles
d'import et qualification aux sites d'appel.

## Écarts détectés ❌

### E1 — Imports externes non qualifiés (`using Pkg` nu)

| Fichier | Ligne(s) | Problème | Correction |
|---|---|---|---|
| `src/OCP/OCP.jl` | 33 | `using DocStringExtensions` | `import DocStringExtensions: TYPEDSIGNATURES` (macro : toléré) |
| `src/OCP/OCP.jl` | 37 | `using MacroTools` | **inutilisé dans OCP** (seul Display l'utilise, et il l'importe déjà correctement) → supprimer |
| `src/OCP/OCP.jl` | 38 | `using Parameters` | seul `@with_kw` est utilisé (`Types/model.jl:142`) → `import Parameters: @with_kw` |
| `src/OCP/OCP.jl` | 39 | `using OrderedCollections: OrderedDict` | symbole non-macro → `using OrderedCollections: OrderedCollections` + qualifier les 2 sites (`aliases.jl:69,77`) |
| `src/Init/Init.jl` | 28 | `using DocStringExtensions` | idem E1.1 |
| `src/Serialization/Serialization.jl` | 33 | `using DocStringExtensions` | idem |
| `src/Display/Display.jl` | 29, 31 | `using DocStringExtensions` ; `using Base: Base` (inutile, `Base` est toujours accessible) | importer la macro ; supprimer la ligne `Base` |
| `ext/CTModelsJLD.jl` | 10–12 | `using CTModels`, `using DocStringExtensions`, `using JLD2` | `using CTModels: CTModels`, macro DSE, `using JLD2: JLD2` + qualifier `JLD2.jldsave`, `JLD2.load` |
| `ext/CTModelsJSON.jl` | 12–15 | `using CTModels`, `using JSON3` | idem + qualifier `JSON3.*` |
| `ext/CTModelsPlots.jl` | 17–20 | `using CTModels`, `using LinearAlgebra`, `using Plots`, `using Plots.Measures` | `using CTModels: CTModels`, `using LinearAlgebra: LinearAlgebra`, `using Plots: Plots`, et qualifier ; `Measures` : importer les symboles réellement utilisés (`mm`, …) explicitement |

### E2 — Imports de symboles sœurs massifs (au lieu de `using ..OCP` + qualification)

C'est l'écart principal. Trois manifests importent des dizaines de symboles de `..OCP`,
ce qui rend l'origine invisible aux sites d'appel (exactement l'anti-pattern de
`modules.md` § « Qualification at call sites »).

| Fichier | Étendue |
|---|---|
| `src/Display/Display.jl:37-51` | ~35 symboles importés de `..OCP` (types, accesseurs, helpers privés `__is_empty`, …) |
| `src/Init/Init.jl:33-43` | ~20 symboles, **dont une ligne dupliquée** (33–34 identiques) |
| `src/Serialization/Serialization.jl:37-43` | `import ..CTModels.OCP` (chemin fragile — remonter au top-level pour redescendre), `using ..OCP: AbstractModel, AbstractSolution, Solution`, `import ..OCP: __format, …` |

Correction : une seule ligne `using ..OCP` par manifest, et qualification `OCP.sym` à
chaque site d'appel (~100 sites au total : Init ~50, Display ~35, Serialization ~10).

**Cas particulier — extension de méthodes** : `Init` *étend* des fonctions d'`OCP`
(`state`, `control`, `variable`, … pour `InitialGuess`). Avec `using ..OCP`, l'extension
s'écrit `function OCP.state(init::AbstractInitialGuess)` — plus besoin d'`import`.

### E3 — Alias d'exceptions non canonique

`const Exceptions = CTBase.Exceptions` dans `OCP.jl:35`, `Init.jl:30`,
`Serialization.jl:35`, `Display.jl:28`, `ext/CTModelsPlots.jl:16`.

La forme canonique (`exceptions.md`) est :

```julia
import CTBase.Exceptions
```

Effet identique (le nom `Exceptions` entre en scope), aucun site d'appel à changer.

### E4 — Le top-level exporte des symboles

`src/CTModels.jl:42-43` :

```julia
import RecipesBase: RecipesBase, plot, plot!
export plot, plot!
```

Viole le tenet 1 (« The package manifest exports **nothing** »). → **Décision D1**.

### E5 — Exports problématiques dans `OCP.jl`

- `export … _serialize_solution` (ligne 103) : un symbole **privé** (`_`) ne s'exporte
  pas ; les extensions l'appellent déjà qualifié (`CTModels.OCP._serialize_solution`).
  → **Décision D3** (vérifier les usages aval : CTDirect, OptimalControl).
- `import Base: time` (ligne 40) + `export time` (ligne 133) : ré-exporte un nom de
  `Base` (risque de shadowing chez l'utilisateur). La forme philosophie :
  définir `Base.time(sol::Solution)` sans import ni export. → **Décision D2**.

### E6 — Exceptions : deux sites non conformes

1. `src/Serialization/reconstruction_helpers.jl:106` :

   ```julia
   error("Legacy format requires 'time_grid' key")   # ❌ non typé
   ```

   → `Exceptions.ParsingError` (structure de données importée invalide) avec
   `location` et `suggestion`.

2. `src/Display/Display.jl:62-72` : le stub `RecipesBase.plot` lance
   `IncorrectArgument` alors que la règle est : dépendance optionnelle absente →
   `ExtensionError` :

   ```julia
   throw(Exceptions.ExtensionError(:Plots; feature="plot(sol)", context="RecipesBase.plot stub"))
   ```

### E7 — Divers (cosmétique)

- `include("aliases.jl")` etc. dans `OCP.jl` : harmoniser sur
  `include(joinpath(@__DIR__, …))` (forme du template de manifest).
- `ext/CTModelsPlots.jl:27` : `export plot, plot!` depuis une extension — sans effet
  utile → supprimer ; ligne 21 : code commenté mort → supprimer.
- `test/runtests.jl` : `using Test`, `using CTBase`, `using CTModels` nus — fichier
  runner spécial, à aligner si peu coûteux (`using Test: Test`, …).

---

# Partie 2 — Plan d'exécution

## What and why

Aligner CTModels sur `dev/philosophy/` (tenet 2 surtout) : imports externes qualifiés,
`using ..OCP` + qualification aux ~100 sites d'appel, exceptions 100 % typées,
exports nettoyés. Aucun changement de comportement hors décisions D1–D3.

## Scope

- Files modified : `src/CTModels.jl`, les 4 manifests, ~15 fichiers d'implémentation
  dans `src/`, les 3 + 3 fichiers `ext/`, (option) `test/runtests.jl`.
- Files added/deleted : aucun.
- Public API changes : **uniquement selon D1–D3** ; tout le reste est mécanique.

## Décisions à trancher avant exécution ⛔

| # | Question | Options | Recommandation |
|---|---|---|---|
| **D1** | `export plot, plot!` au top-level ? | (a) retirer (conforme, **breaking** pour qui fait `using CTModels; plot(sol)`) ; (b) garder comme exception documentée | (a) si les packages aval (OptimalControl) sont coordonnés ; sinon (b) temporairement avec un commentaire `# documented exception to tenet 1` |
| **D2** | `import Base: time` + `export time` ? | (a) retirer l'export, définir `Base.time(sol)` — `time(sol)` continue de marcher (c'est `Base.time`), seul `CTModels.time` casse ; (b) statu quo | (a) |
| **D3** | `_serialize_solution` exporté ? | (a) retirer de l'export (les ext qualifient déjà) ; (b) le renommer public `serialize_solution` | (a), après grep dans CTDirect/OptimalControl |

## Step 0 — Branche

- `mcp__git__git_create_branch` → `refactor/philosophy-qualification` depuis `main` ;
  `mcp__git__git_checkout`.

```bash
git checkout main && git pull
git checkout -b refactor/philosophy-qualification
```

## Phase A — Manifests : imports externes (E1, E3, E7)

Aucun site d'appel touché sauf 2 lignes (`OrderedDict`). Risque faible.

Steps :

1. `src/OCP/OCP.jl` — bloc d'imports avant/après :

   ```julia
   # AVANT
   import CTBase.Core
   import CTBase.Interpolation
   using DocStringExtensions
   using CTBase: CTBase
   const Exceptions = CTBase.Exceptions
   using MLStyle: MLStyle
   using MacroTools
   using Parameters
   using OrderedCollections: OrderedDict
   import Base: time                        # ← traité en Phase E (D2)

   # APRÈS
   import CTBase.Core
   import CTBase.Interpolation
   import CTBase.Exceptions
   import DocStringExtensions: TYPEDSIGNATURES
   import Parameters: @with_kw
   using CTBase: CTBase
   using MLStyle: MLStyle
   using OrderedCollections: OrderedCollections
   ```

   Puis qualifier `aliases.jl:69,77` : `OrderedDict{…}` → `OrderedCollections.OrderedDict{…}`.
   Vérifier par grep les macros DSE réellement utilisées par module
   (`TYPEDSIGNATURES`, `TYPEDEF`, `TYPEDFIELDS`) et n'importer que celles-là.

2. `src/Init/Init.jl`, `src/Serialization/Serialization.jl`, `src/Display/Display.jl` :
   même traitement (`import CTBase.Exceptions`, macro DSE, suppression `using Base: Base`).
3. `src/OCP/OCP.jl` : `include("x.jl")` → `include(joinpath(@__DIR__, "x.jl"))`.

Checkpoint :

```bash
get_test_command test_args=["suite/ocp"]   # MCP, puis generate_report
```

## Phase B — Serialization : `using ..OCP` + qualification (pilote, E2)

Module le plus petit → valide la mécanique avant Init/Display.

Steps :

1. Manifest avant/après :

   ```julia
   # AVANT
   import ..CTModels.OCP
   using ..OCP: AbstractModel, AbstractSolution, Solution
   import ..OCP: __format, __filename_export_import, __control_interpolation

   # APRÈS
   using ..OCP
   ```

2. Qualifier les sites dans `types.jl`, `export_import.jl`, `reconstruction_helpers.jl` :

   ```julia
   # AVANT                                  # APRÈS
   function export_ocp_solution(sol::AbstractSolution; …)
                                            function export_ocp_solution(sol::OCP.AbstractSolution; …)
   format = __format(…)                     format = OCP.__format(…)
   ```

Checkpoint : `get_test_command test_args=["suite/serialization"]`.

## Phase C — Init : `using ..OCP` + qualification (E2)

Steps :

1. Manifest : les ~10 lignes `import ..OCP: …` (dont la dupliquée) → `using ..OCP`.
2. Qualifier ~50 sites dans `types.jl`, `utils.jl`, `state.jl`, `control.jl`,
   `variable.jl`, `builders.jl`, `validation.jl`, `api.jl` :

   ```julia
   # AVANT                                  # APRÈS
   xdim = state_dimension(model)            xdim = OCP.state_dimension(model)
   t0 = initial_time(model)                 t0 = OCP.initial_time(model)
   ```

3. Extensions de méthodes (les méthodes `state(init)`, `control(init)`,
   `variable(init)` qui étendent OCP) :

   ```julia
   # AVANT (marche grâce à `import ..OCP: state`)
   state(init::InitialGuess) = init.state

   # APRÈS
   OCP.state(init::InitialGuess) = init.state
   ```

Checkpoint : `get_test_command test_args=["suite/initial_guess"]`.

## Phase D — Display : `using ..OCP` + qualification + stub (E2, E6.2)

Steps :

1. Manifest : lignes 37–51 → `using ..OCP` ; supprimer `using Base: Base`.
2. Qualifier ~35 sites dans `ansi.jl`, `definition.jl`, `mathematical.jl`,
   `model.jl`, `pre_model.jl` (types compris : `::Model` → `::OCP.Model`).
3. Stub plot → `ExtensionError` :

   ```julia
   function RecipesBase.plot(sol::OCP.AbstractSolution, ::Symbol...; kwargs...)
       throw(Exceptions.ExtensionError(:Plots; feature="plot(sol)", context="CTModels display"))
   end
   ```

   (vérifier la signature exacte d'`ExtensionError` dans CTBase et adapter le test
   `suite/display` ou `suite/exceptions` qui attend `IncorrectArgument`).

Checkpoint : `get_test_command test_args=["suite/display", "suite/exceptions"]`.

## Phase E — Extensions `ext/` (E1, E3, E7) + exceptions (E6.1)

Steps :

1. `ext/CTModelsJLD.jl` : `using JLD2: JLD2` ; `jldsave(…)` → `JLD2.jldsave(…)`,
   `load(…)` → `JLD2.load(…)` ; `using CTModels: CTModels`.
2. `ext/CTModelsJSON.jl` : `using JSON3: JSON3` + qualification ;
   `import CTModels.OCP: __control_interpolation` → appels qualifiés
   `CTModels.OCP.__control_interpolation`.
3. `ext/CTModelsPlots.jl` + `plot*.jl` : `using Plots: Plots` + qualification
   (`plot(…)` → `Plots.plot(…)`, attributs de recettes inchangés) ; symboles de
   `Plots.Measures` importés explicitement ; `import CTBase.Exceptions` ;
   supprimer `export plot, plot!` et le code commenté.
4. `src/Serialization/reconstruction_helpers.jl:106` :

   ```julia
   throw(Exceptions.ParsingError(
       "legacy solution data is missing the 'time_grid' key";
       location="imported solution dictionary",
       suggestion="re-export the solution with a current CTModels version",
   ))
   ```

Checkpoint : `get_test_command test_args=["suite/extensions", "suite/serialization"]`.

## Phase F — Exports & API (D1, D2, D3) — selon décisions

Steps (si recommandations retenues) :

1. `src/CTModels.jl` : retirer `export plot, plot!` (D1a) — garder
   `import RecipesBase: RecipesBase` si nécessaire au stub, sinon le déplacer
   entièrement dans Display.
2. `src/OCP/OCP.jl` : retirer `import Base: time` et `export time` ; les méthodes
   deviennent `function Base.time(sol::Solution, …)` (D2a).
3. `src/OCP/OCP.jl` : retirer `_serialize_solution` de l'export (D3a), après grep
   dans les packages aval.
4. Adapter les tests qui utilisent `CTModels.time` / `CTModels.plot` le cas échéant.

Checkpoint : `get_test_command test_args=["suite/ocp", "suite/meta"]`.

## Phase G — Suite complète + docs

Steps :

1. Suite complète (MCP) :

   ```bash
   get_test_command          # sans test_args = full suite
   # fallback : julia --project=@. -e 'using Pkg; Pkg.test()' 2>&1 | tee /tmp/philo_final.log
   ```

2. Build docs draft-first (`draft = true` global, puis par fichier, puis full —
   cf. `dev/RULES.md`) : les `@ref`/`@extref` peuvent bouger si D1/D2 changent
   des symboles documentés.
3. Docstrings : derniers ajustements **après** stabilisation de l'API (tenet 8 /
   règle « docstrings last »).

## Human checkpoints

- ⛔ Décisions D1–D3 avant Phase F.
- ⛔ Demander avant tout commit (fin de chaque phase ou commit unique, au choix).
- ⛔ Demander avant push.
- ⛔ Toute décision de design non prévue → stop.

## Out of scope

- Audit profond types/traits (tenet 3) : `Autonomous`/`NonAutonomous` et les tags de
  sérialisation semblent déjà conformes ; un audit dédié pourrait suivre.
- Refactor de la structure interne d'`OCP` (sous-répertoires non-modules) — conforme.
- Renommages d'API publics autres que D1–D3.
- Harmonisation `__print` vs `_print_*` dans Display (naming privé incohérent avec la
  docstring du module) — à traiter avec les docstrings.

## File summary

**Modified** :
`src/CTModels.jl`, `src/OCP/OCP.jl`, `src/OCP/aliases.jl`,
`src/Init/Init.jl` + 8 fichiers `Init/`,
`src/Serialization/Serialization.jl` + 3 fichiers,
`src/Display/Display.jl` + 5 fichiers,
`ext/CTModelsJLD.jl`, `ext/CTModelsJSON.jl`, `ext/CTModelsPlots.jl` + 3 `plot*.jl`,
(option) `test/runtests.jl`, tests impactés par D1–D3 et E6.2.
