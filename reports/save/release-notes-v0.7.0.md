@JuliaRegistrator register

Release notes:

## CTModels v0.7.0

### Highlights

- **New typed core for OCP models and solutions**  
  Split the old monolithic [`src/types.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/src/types.jl) into a structured [`src/core/types/`](https://github.com/control-toolbox/CTModels.jl/tree/main/src/core/types) hierarchy (`ocp_components`, `ocp_model`, `ocp_solution`, `nlp`, `initial_guess`, …). This clarifies the representation of models, solutions, constraints, and related metadata, and adds the alias `AbstractOptimalControlProblem = CTModels.AbstractModel` for better interop.

- **New NLP modelling layer**  
  Introduced a dedicated [`src/nlp/`](https://github.com/control-toolbox/CTModels.jl/tree/main/src/nlp) layer (`problem_core.jl`, `discretized_ocp.jl`, `model_api.jl`, `options_schema.jl`, `nlp_backends.jl`, …) to build NLP models from optimisation problems and OCP models, and to map NLP solutions back to `CTModels.Solution`. Adds support for ADNLPModels- and ExaModels-based backends as first-class CTModels components.

- **Initial guess utilities**  
  New, typed initial-guess layer in [`src/init/initial_guess.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/src/init/initial_guess.jl): `pre_initial_guess` builds an `OptimalControlPreInit` container from raw user data (functions, vectors, scalars), and `initial_guess` builds and validates an `OptimalControlInitialGuess` against an `AbstractOptimalControlProblem`. Dedicated tests cover the new types and constructors.

- **JSON / JLD I/O improvements**  
  Reworked JSON export/import in [`ext/CTModelsJSON.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/ext/CTModelsJSON.jl) to handle `infos::Dict{Symbol,Any}` more robustly and predictably, with improved tests for JSON and JLD round-trips in [`test/io/test_export_import.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/test/io/test_export_import.jl).

- **Plotting and examples**  
  Small improvements in the plot extension ([`ext/plot.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/ext/plot.jl), `plot_default.jl`, `plot_utils.jl`) and additional examples/tests for plotting and printing solutions in [`test/plot/test_plot.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/test/plot/test_plot.jl).

- **Documentation overhaul**  
  New, more didactic index page in [`docs/src/index.md`](https://github.com/control-toolbox/CTModels.jl/blob/main/docs/src/index.md) explaining CTModels' role in the OptimalControl/control-toolbox ecosystem, a new **Interfaces** section (`docs/src/interfaces/`), and reorganised API reference pages with improved automatic API doc generation using [`docs/docutils/DocumenterReference.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/docs/docutils/DocumenterReference.jl).

- **Extensive test suite**  
  Many new tests for core types, initial guesses, the NLP layer, I/O, OCP building blocks, and plotting (see the new subdirectories [`test/core/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/core), [`test/nlp/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/nlp), [`test/io/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/io), [`test/ocp/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/ocp), [`test/plot/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/plot), [`test/problems/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/problems)). `test/runtests.jl` was refactored into a more modular structure.

---

### Breaking Changes / Compatibility Notes

- **CTBase compatibility bump**  
  `compat` for CTBase was raised from `0.16` to `0.17` in [`Project.toml`](https://github.com/control-toolbox/CTModels.jl/blob/main/Project.toml). Downstream packages must be able to use CTBase ≥ 0.17 to upgrade to CTModels v0.7.0.

- **New hard dependencies**  
  CTModels now declares additional dependencies in `Project.toml`:
  - `ADNLPModels = "0.8"`
  - `ExaModels = "0.9"`
  - `NLPModels = "0.21"`
  - `SolverCore = "0.3"`
  - `KernelAbstractions = "0.9"`  
  Projects with tight compat bounds on these packages may need to update their compat entries.

- **Internal file/layout refactor**  
  The internal layout of the source tree changed significantly:
  - `src/types.jl` was split into multiple files under [`src/core/types/`](https://github.com/control-toolbox/CTModels.jl/tree/main/src/core/types),
  - `src/init.jl` was replaced by [`src/init/initial_guess.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/src/init/initial_guess.jl),
  - most OCP-related files were moved under [`src/ocp/`](https://github.com/control-toolbox/CTModels.jl/tree/main/src/ocp),
  - NLP-related code was moved under [`src/nlp/`](https://github.com/control-toolbox/CTModels.jl/tree/main/src/nlp).  
  Publicly exported names have been kept as stable as possible, but code that relied on internal file structure or non-exported implementation details may break.

- **JSON export/import behaviour**  
  JSON I/O has been tightened and made more structured. The intent is to be more robust, but very low-level consumers of the previous JSON format may see behavioural differences and should re-check their pipelines.

### New Features

- Added a typed OCP core in [`src/core/types/`](https://github.com/control-toolbox/CTModels.jl/tree/main/src/core/types), including `ocp_components.jl`, `ocp_model.jl`, `ocp_solution.jl`, and `nlp.jl`, to model optimal control problems and their solutions more explicitly.
- Added a new NLP layer in [`src/nlp/`](https://github.com/control-toolbox/CTModels.jl/tree/main/src/nlp) with `problem_core.jl`, `discretized_ocp.jl`, `model_api.jl`, `options_schema.jl`, and `nlp_backends.jl` to interface CTModels with ADNLPModels and ExaModels backends.
- Introduced typed initial-guess types and constructors in [`src/core/types/initial_guess.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/src/core/types/initial_guess.jl) and [`src/init/initial_guess.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/src/init/initial_guess.jl).
- Added JSON and JLD solution I/O helpers in [`ext/CTModelsJSON.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/ext/CTModelsJSON.jl) and `CTModelsJLD.jl` to persist and reload solutions.

### Enhancements

- Improved organisation of OCP-related code by moving files under [`src/ocp/`](https://github.com/control-toolbox/CTModels.jl/tree/main/src/ocp) and sharpening the separation between core types, OCP model components, NLP layer, and I/O.
- Refined plotting support in the CTModelsPlots extension (`plot.jl`, `plot_default.jl`, `plot_utils.jl`) and aligned examples with the new types and solution structures.

### Bug Fixes

- No additional user-facing bug fixes are explicitly highlighted in this release beyond those implied by the refactors and new tests. Please refer to the full changelog for low-level details.

### Documentation

- Added a new, explanatory index page at [`docs/src/index.md`](https://github.com/control-toolbox/CTModels.jl/blob/main/docs/src/index.md) describing CTModels' role and main concepts.
- Introduced an **Interfaces** section in [`docs/src/interfaces/`](https://github.com/control-toolbox/CTModels.jl/tree/main/docs/src/interfaces) covering OCP tools, optimisation problems, optimisation modelers, and solution builders.
- Added a custom API reference generator in [`docs/docutils/DocumenterReference.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/docs/docutils/DocumenterReference.jl) and updated `docs/make.jl` to improve API documentation structure.

### Tests

- Added extensive tests for core types in [`test/core/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/core),
  including OCP components, models, solutions, NLP types, and utilities.
- Added tests for initial guesses in [`test/init/test_initial_guess.jl`](https://github.com/control-toolbox/CTModels.jl/blob/main/test/init/test_initial_guess.jl).
- Added tests for the NLP layer in [`test/nlp/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/nlp), covering discretised OCPs, model API, backends, options schema, and problem core.
- Added I/O tests in [`test/io/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/io) for export/import behaviour and extension errors.
- Added OCP-level tests in [`test/ocp/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/ocp) and problem examples in [`test/problems/`](https://github.com/control-toolbox/CTModels.jl/tree/main/test/problems).

### Internal

- Updated CI configuration in [`.github/workflows/`](https://github.com/control-toolbox/CTModels.jl/tree/main/.github/workflows) and added `formatter.lock` to track formatting state.
- Ignored profiling scripts via `.gitignore` and removed them from the tracked files.
- Reorganised the test suite to mirror the new `core/`, `ocp/`, `nlp/`, `io/`, `meta/`, and `problems/` structure.
