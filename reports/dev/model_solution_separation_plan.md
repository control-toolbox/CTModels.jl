# Plan : séparation Model / Solution (éclatement du module OCP)

> Suite de [`philosophy_compliance_plan.md`](philosophy_compliance_plan.md) (phases A–F
> faites, 3521/3521 verts). Réfère à
> [`dev/philosophy/PHILOSOPHY.md`](../../dev/philosophy/PHILOSOPHY.md).
> Statut : **en attente de validation humaine** (décisions S1–S4 à trancher).

---

# Partie 1 — État des lieux

## Le constat : OCP porte 4 responsabilités (+ 2 fuites)

`src/OCP/` ≈ 7 000 lignes, soit plus de la moitié du package. Mesuré :

| Responsabilité | Fichiers | ~lignes |
|---|---|---|
| **Socle partagé** : aliases, `TimeDependence`, types abstraits, composants communs (`TimesModel`, `StateModel`, …), defaults `__*` | `aliases.jl`, `Types/components.jl`, `Core/defaults.jl` | ~800 |
| **Modèle** : `Model` immuable + ~60 accesseurs | `Types/model.jl` (partie), `Building/model.jl:560-1662` | ~1 400 |
| **Construction** : `PreModel`, mutateurs `state!`/`control!`/…, validation, `build_model` | `Types/model.jl` (partie), `Components/*.jl`, `Validation/`, `Core/time_dependence.jl`, `Building/model.jl:1-560` | ~2 800 |
| **Solution** : `Solution`, `TimeGridModel`, `DualModel`, `SolverInfos`, `build_solution`, accesseurs, duals, interpolation/discrétisation | `Types/solution.jl`, `Building/solution.jl`, `Building/dual_model.jl`, `Building/{discretization_utils,interpolation_helpers}.jl` | ~2 800 |
| ⚠️ **Fuite affichage** : `Base.show(io, ::MIME, sol::Solution)` | `Building/solution.jl:1328-1500` | ~180 |
| ⚠️ **Fuite sérialisation** : `_serialize_solution` (3 méthodes) + defaults `__format`, `__filename_export_import` | `Building/solution.jl:1503-1721`, `Core/defaults.jl` | ~220 |

Violations du **tenet 1** (« one module per responsibility ») :

1. Modèle, construction et solution cohabitent dans un seul module.
2. Le `show` de `Solution` est dans OCP alors que `Display` (qui prétend le fournir
   dans sa docstring, `Display.jl:14`) ne contient que `show(::Model)` et
   `show(::PreModel)`. Incohérence existante.
3. `_serialize_solution` (solution → `Dict`) est de la responsabilité de
   `Serialization` ; les extensions l'appellent déjà via `CTModels.OCP._serialize_solution`
   (2 sites dans `ext/`).

## Dépendances mesurées (grep)

- `Solution` → `Model` : champ `model::ModelType<:AbstractModel`
  (`Types/solution.jl:400`), `build_solution(ocp::Model, …)`. **Sens unique** :
  `Building/model.jl` ne référence jamais `Solution`. Le DAG Model → Solution est sain.
- **Composants partagés** par les deux mondes : `TimesModel`, `FixedTimeModel`,
  `FreeTimeModel`, `TimeDependence`/`Autonomous`/`NonAutonomous`, tous les
  `Abstract*Model`, les aliases (`Dimension`, `ctNumber`, …).
- **Composants côté solution uniquement** : `StateModelSolution`,
  `ControlModelSolution`, `VariableModelSolution` (dans `Types/components.jl`,
  mélangés avec les composants modèle).
- **Fonctions génériques partagées** : `state`, `control`, `variable`,
  `state_dimension`, `time_name`, `initial_time`, … ont des méthodes sur `Model`
  **et** `Solution` (et `Init` les étend pour `InitialGuess`). C'est **une seule
  function object** par nom — après éclatement, elle doit appartenir à un module
  *en dessous* de Models et Solutions, sinon collision de noms au top-level.
  C'est exactement le cas « extract the shared concept into a lower module » de
  `modules.md` § DAG.

## Surface d'impact

| Consommateur | Usage actuel | Après |
|---|---|---|
| `ext/` | 2 sites `CTModels.OCP._serialize_solution` | `CTModels.Serialization._serialize_solution` |
| `test/` | 20 fichiers, 66 symboles `OCP.*` distincts | requalification mécanique |
| `docs/src` | 16 fichiers référencent `CTModels.OCP` | à faire avec G2 (docs déjà en réécriture) |
| Aval (CTDirect, OptimalControl, CTParser) | `CTModels.sym` (exports top-level) — **inchangé** ; risque seulement sur d'éventuels `CTModels.OCP.*` qualifiés | ⛔ grep aval avant exécution |

Les exports publics transitent par `using .Sub` au top-level : tant que les noms
exportés ne changent pas, `CTModels.state_dimension(…)` etc. restent valides en aval.

---

# Partie 2 — Architecture cible et décisions

## Architecture proposée

```text
Components   ← new : aliases, TimeDependence, types abstraits,
  ↓            composants partagés, defaults __*,
  ↓            fonctions génériques partagées (contrats, tenet 4)
Models       ← new : struct Model + accesseurs
  ↓
Building     ← new (si S2b) : PreModel, mutateurs state!/…, validation, build_model
  ↓
Solutions    ← new : Solution, TimeGrid*, DualModel, SolverInfos,
  ↓            composants *Solution, build_solution, accesseurs, duals
Display      ← + show(::Solution) déplacé depuis OCP
  ↓
Serialization ← + _serialize_solution, __format, __filename_export_import déplacés
  ↓
Init          (requalification seule)
```

Le module `OCP` disparaît. Les fonctions génériques (`state`, `state_dimension`, …)
sont **possédées et exportées par `Components`** ; `Models`, `Building`, `Solutions`
ajoutent leurs méthodes (`Components.state(sol::Solution) = …`) et n'exportent que
leurs types et fonctions propres (`build_model`, `build_solution`, …).

## Décisions à trancher avant exécution ⛔

| # | Question | Options | Recommandation |
|---|---|---|---|
| **S1** | Noms des nouveaux modules. Contrainte Julia : un module `Model` ne peut pas contenir `struct Model` (le nom du module est lié dans son propre scope). | (a) pluriels : `Components`, `Models`, `Solutions` ; (b) garder `OCP` comme nom du module socle au lieu de `Components` (moins de churn sur les chemins privés qualifiés) ; (c) autres noms (`Problem`, …, même contrainte) | (a) — cohérent, lisible ; les chemins `CTModels.OCP.*` privés changent de toute façon |
| **S2** | Sépare-t-on la construction (PreModel) du modèle ? | (a) un seul module `Models` (Model + PreModel + mutateurs + build) ; (b) `Models` (type + accesseurs, ~1 400 l.) et `Building` (PreModel + mutateurs + validation + build_model, ~2 800 l.) séparés | (b) — « définir un problème » et « interroger un modèle » sont deux responsabilités ; Display les affiche déjà séparément (`model.jl` vs `pre_model.jl`) ; le DAG reste simple (Building dépend de Models). Coût : un module de plus |
| **S3** | Où vivent les `show` ? | (a) tout l'affichage dans `Display` : on y **déplace** `show(::Solution)` ; fichiers par type affiché (`model.jl`, `pre_model.jl`, `solution.jl` ← new) ; (b) helpers communs dans un module bas + chaque module définit son `show` | (a) — tenet 1 : le formatage est *une* responsabilité ; (b) mettrait ~480 lignes de formatage dans Models/Building et forcerait les helpers ANSI sous Models. La symétrie souhaitée s'obtient par **un fichier par type** dans Display |
| **S4** | `_serialize_solution` + `__format` + `__filename_export_import` → `Serialization` ? | (a) oui (adapter les 2 sites `ext/`, grep aval) ; (b) statu quo dans Solutions | (a) — c'est de la sérialisation ; les ext qualifient déjà |

Note S3 : la proposition (b) « méthodes communes dans Display, displays particuliers
dans les modules associés » a un mérite (le `show` près de son type, idiome Julia),
mais elle disperse la responsabilité formatage sur 3 modules et inverse le DAG
(les helpers devraient descendre sous Models). La philosophie tranche pour (a).

---

# Partie 3 — Plan d'exécution

## What and why

Éclater `OCP` (~7 000 l., 4 responsabilités) en `Components` / `Models` / `Building` /
`Solutions`, et rapatrier les fuites : `show(::Solution)` → `Display`,
`_serialize_solution` + defaults d'export → `Serialization`. Aucun changement de
comportement ; API publique top-level (`CTModels.sym`) inchangée ; seuls les chemins
qualifiés `CTModels.OCP.*` (privés) changent.

## Scope

- Files added : 4 manifests (`src/Components/`, `src/Models/`, `src/Building/`,
  `src/Solutions/`) + fichiers déplacés/scindés ; `src/Display/solution.jl`.
- Files deleted : `src/OCP/` (tout le répertoire, contenu redistribué).
- Files modified : `src/CTModels.jl`, manifests `Display`/`Serialization`/`Init`,
  `ext/CTModelsJSON.jl`, `ext/CTModelsJLD.jl`, ~20 fichiers de tests, docs (avec G2).
- Public API changes : **non** au sens exports top-level ; **oui** pour les chemins
  qualifiés internes (`CTModels.OCP.*` → `CTModels.<New>.*`).

## Pré-requis

- ⛔ Trancher S1–S4.
- ⛔ Grep aval : `grep -rn "CTModels\.OCP" ~/…/CTDirect.jl ~/…/OptimalControl.jl ~/…/CTParser.jl`
  — si des privés sont utilisés, coordonner.
- Partir d'un état propre : merger `refactor-follow-philosophy` d'abord (ou brancher
  dessus), pour ne pas empiler deux refactors dans une même branche.

## Step 0 — Branche

- `mcp__git__git_create_branch` → `refactor/split-ocp-model-solution` ;
  `mcp__git__git_checkout`.

## Phase A — `Components` (socle)

Steps :

1. Créer `src/Components/Components.jl` (manifest conforme au template).
2. Déplacer `aliases.jl` tel quel.
3. Scinder `OCP/Types/components.jl` :
   - → `Components/` : `TimeDependence`, `Autonomous`, `NonAutonomous`, tous les
     `abstract type Abstract*`, `StateModel`, `ControlModel`, `EmptyControlModel`,
     `VariableModel`, `EmptyVariableModel`, `FixedTimeModel`, `FreeTimeModel`,
     `TimesModel`, objectifs, `ConstraintsModel`, définitions ;
   - les `*ModelSolution` partent en Phase D (Solutions).
4. Déplacer `Core/defaults.jl` (sauf `__format`, `__filename_export_import` →
   Phase F) ; déplacer les accesseurs de composants purs (`name(::StateModel)`, …
   depuis `OCP/Components/*.jl`).
5. Déclarer les fonctions génériques partagées (contrats) :

   ```julia
   # Components/api.jl — owner unique des noms partagés
   function state end
   function state_dimension end
   function initial_time end
   # … (liste exacte = intersection des exports OCP avec méthodes Model & Solution)
   ```

6. Exports : aliases + types + fonctions génériques (reprendre la liste d'exports
   d'`OCP.jl` qui relève du socle).
7. `src/CTModels.jl` : inclure `Components` en premier ; pendant la transition,
   `OCP` réduit fait `using ..Components`.

Checkpoint : `get_test_command test_args=["suite/ocp"]` (les tests qualifieront
encore `OCP.*` via le réexport transitoire — adapter au fil des phases).

## Phase B — `Models`

Steps :

1. Créer `src/Models/Models.jl` (`using ..Components`).
2. Déplacer `struct Model` (depuis `Types/model.jl`) et les accesseurs
   (`Building/model.jl:560-1662`) ; chaque méthode partagée s'écrit
   `Components.state_dimension(ocp::Model) = …`.
3. Exports : `Model` + fonctions propres au modèle (ex. `get_build_examodel`).

Checkpoint : `get_test_command test_args=["suite/ocp"]`.

## Phase C — `Building` (si S2b ; sinon fusionner dans Phase B)

Steps :

1. Créer `src/Building/Building.jl` (`using ..Components`, `using ..Models`).
2. Déplacer : `PreModel` + helpers `__is_*` (`Types/model.jl`), mutateurs
   (`OCP/Components/*.jl` : `state!`, `control!`, `variable!`, `time!`, `dynamics!`,
   `objective!`, `constraint!`, `definition!`), `time_dependence!`,
   `Validation/name_validation.jl`, `build`/`build_model`
   (`Building/model.jl:1-560`).
3. Exports : `PreModel`, mutateurs, `build_model`, `build`.

Checkpoint : `get_test_command test_args=["suite/ocp"]`.

## Phase D — `Solutions`

Steps :

1. Créer `src/Solutions/Solutions.jl` (`using ..Components`, `using ..Models`).
2. Déplacer : `Types/solution.jl` entier, les `*ModelSolution` de
   `Types/components.jl`, `Building/solution.jl` (build + accesseurs, **sans**
   `Base.show` ni `_serialize_solution`), `dual_model.jl`,
   `discretization_utils.jl`, `interpolation_helpers.jl`,
   `__control_interpolation`, `__time_grid_default_component`.
3. Méthodes partagées : `Components.state(sol::Solution, …) = …`, etc.
4. Exports : `Solution`, `TimeGridModel` & co, `DualModel`, `SolverInfos`,
   `build_solution`, accesseurs propres (`iterations`, `status`, duals, …).
5. Supprimer `src/OCP/` ; retirer le réexport transitoire de `src/CTModels.jl`.

Checkpoint : `get_test_command test_args=["suite/ocp", "suite/initial_guess"]`.

## Phase E — `Display`

Steps :

1. Manifest : `using ..OCP` → `using ..Components`, `using ..Models`,
   `using ..Building`, `using ..Solutions` ; requalifier les ~35 sites
   (`OCP.Model` → `Models.Model`, `OCP.name` → `Components.name`, …).
2. Créer `Display/solution.jl` : y déplacer `Base.show(io, ::MIME, sol::Solution)`
   et `Base.show_default` associé depuis l'ex-`Building/solution.jl:1328-1500`.
3. Mettre à jour la docstring du module (qui devient enfin exacte).

Checkpoint : `get_test_command test_args=["suite/display"]`.

## Phase F — `Serialization` + `ext/`

Steps :

1. Déplacer `_serialize_solution` (3 méthodes) + `_discretize_all_components` →
   `src/Serialization/` ; déplacer `__format`, `__filename_export_import` depuis
   les defaults.
2. Manifest : `using ..Components`, `using ..Solutions` (+ `..Models` si besoin) ;
   requalifier les ~10 sites.
3. `ext/CTModelsJSON.jl`, `ext/CTModelsJLD.jl` : `CTModels.OCP._serialize_solution`
   → `CTModels.Serialization._serialize_solution` (2 sites) ; vérifier les autres
   qualifications `CTModels.*`.

Checkpoint : `get_test_command test_args=["suite/serialization", "suite/extensions"]`.

## Phase G — `Init`

Steps :

1. Manifest : `using ..OCP` → `using ..Components`, `using ..Models` (+ `..Solutions`
   pour les builders depuis une solution).
2. Requalifier ~50 sites : `OCP.state_dimension` → `Components.state_dimension`,
   `OCP.AbstractModel` → `Components.AbstractModel`, extensions
   `OCP.state(init)` → `Components.state(init)`.

Checkpoint : `get_test_command test_args=["suite/initial_guess"]`.

## Phase H — Tests, suite complète, docs

Steps :

1. Requalifier les 20 fichiers de tests (66 symboles `OCP.*`) vers
   `Components.*` / `Models.*` / `Building.*` / `Solutions.*` ; envisager de
   réorganiser `test/suite/ocp/` en `suite/models/`, `suite/solutions/` (optionnel,
   décision au fil de l'eau).
2. Suite complète : `get_test_command` (sans `test_args`) → `generate_report`.
3. Docs : traiter avec G2 du plan précédent (16 fichiers référencent
   `CTModels.OCP`) — build draft-first selon `dev/RULES.md`.
4. Docstrings (G3) : en dernier, API stabilisée.

## Human checkpoints

- ⛔ Décisions S1–S4 + grep aval avant Step 0.
- ⛔ Demander avant tout commit (proposition : un commit par phase).
- ⛔ Demander avant push.
- ⛔ Toute décision de design non prévue → stop.

## Out of scope

- G2/G3 du plan précédent (docs + docstrings) — séquencés après ce refactor.
- Renommages de symboles publics (aucun).
- Audit types/traits (tenet 3) — inchangé.
- Réorganisation de `test/suite/` au-delà des requalifications (optionnelle).

## File summary

**Added** : `src/Components/` (manifest + ~5 fichiers), `src/Models/` (manifest + 2),
`src/Building/` (manifest + ~10), `src/Solutions/` (manifest + ~6),
`src/Display/solution.jl`.
**Deleted** : `src/OCP/` (contenu intégralement redistribué).
**Modified** : `src/CTModels.jl`, `src/Display/*`, `src/Serialization/*`,
`src/Init/Init.jl` + fichiers, `ext/CTModelsJSON.jl`, `ext/CTModelsJLD.jl`,
~20 fichiers `test/suite/`, docs (avec G2).
