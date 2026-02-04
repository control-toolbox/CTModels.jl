# CTModels.jl

```@meta
CurrentModule = CTModels
```

The `CTModels.jl` package is part of the [control-toolbox ecosystem](https://github.com/control-toolbox).
It provides the **mathematical model layer** for optimal control problems:

- **types and building blocks** for states, controls, variables, time grids, and constraints;
- an `AbstractModel`/`Model` and `AbstractSolution`/`Solution` hierarchy for optimal control problems;
- tools to build **initial guesses**, connect to **NLP backends**, and interpret their solutions;
- optional extensions for **exporting solutions** (JSON/JLD) and **plotting**.

!!! note

    The root package is [OptimalControl.jl](https://github.com/control-toolbox/OptimalControl.jl) which aims
    to provide tools to model and solve optimal control problems with ordinary differential equations
    by direct and indirect methods, both on CPU and GPU.

!!! warning

    In some examples in the documentation, private methods are shown without the module prefix.
    This is done for the sake of clarity and readability.

    ```julia-repl
    julia> using CTModels
    julia> x = 1
    julia> private_fun(x) # throws an error
    ```

    This should instead be written as:

    ```julia-repl
    julia> using CTModels
    julia> x = 1
    julia> CTModels.private_fun(x)
    ```

    If the method is re-exported by another package,

    ```julia
    module OptimalControl
        import CTModels: private_fun
        export private_fun
    end
    ```

    then there is no need to prefix it with the original module name:

    ```julia-repl
    julia> using OptimalControl
    julia> x = 1
    julia> private_fun(x)
    ```

## What CTModels provides

At a high level, CTModels is responsible for:

- **Defining optimal control problems**:
  `AbstractModel` / `Model` store dynamics, objective, constraints, time structure, and metadata.
- **Representing numerical solutions**:
  `AbstractSolution` / `Solution` store state, control, dual variables, and solver information.
- **Managing time grids and dimensions** through convenient type aliases.
- **Structuring constraints** (path, boundary, box constraints on state, control, and variables).
- **Connecting to NLP backends** (ADNLPModels, ExaModels, etc.) via modelers and builders.
- **Strategy architecture** (NEW):
  - **Options**: Generic option handling with aliases and validation
  - **Strategies**: Configurable components (modelers, solvers, discretizers)
- **Providing utilities** for initial guesses, export/import, and plotting of solutions.

Most of the public API is organized in a way that closely mirrors the mathematical
objects you manipulate when formulating an optimal control problem.

## Strategy Architecture

CTModels provides a modern, type-stable architecture for configurable components:

- **Options Module**: Low-level option extraction, validation, and alias resolution.
- **Strategies Module**: Strategy contract, metadata, registry, and builders.

This architecture replaces the legacy `AbstractOCPTool` interface with a cleaner,
more maintainable design. See the **Developer Guide → Interfaces → Strategies** section for details.

## Time grids and basic aliases

CTModels defines a few central type aliases that appear throughout the API:

- `Dimension`: integer dimensions used for state, control, and variables.
- `ctNumber` and `ctVector`: real numbers and vectors of reals.
- `Time`, `Times`, `TimesDisc`: continuous time, time vectors, and discrete time grids.

These aliases make type signatures more readable while remaining flexible enough
to accept a variety of numeric types.

## Models, solutions, and constraints

The core **optimal control model** is expressed via:

- `AbstractModel` / `Model`: store the structure of the OCP
  (dynamics, objective, constraints, time dependence, etc.).
- `ConstraintsModel`: a structured representation of all constraints
  (path constraints, boundary constraints, and box constraints on state, control, and variables).

In practice you typically:

1. Specify **time dependence** and **time models** (fixed or free final time, etc.).
2. Describe **state, control, and variable spaces**.
3. Provide **dynamics** and **objective** functions.
4. Add **constraints**, either programmatically or via a `ConstraintsDictType` dictionary.

The numerical **solution** of an OCP is represented by:

- `AbstractSolution` / `Solution`: contain time grids, state and control trajectories,
  path and boundary dual variables, solver status, and diagnostics.
- `DualModel` and related types: organize dual variables associated with constraints.

These objects are the main bridge between the mathematical problem and the NLP backends.

## Initial guesses

Good initial guesses are crucial for challenging optimal control problems.
CTModels provides a small layer to organize them:

- `pre_initial_guess` builds an `OptimalControlPreInit` object from raw user data
  (functions, vectors, or constants for state, control, and variables).
- `initial_guess` turns this into an `OptimalControlInitialGuess`, checking consistency
  with the chosen `AbstractOptimalControlProblem`.

The corresponding API is implemented in `src/init/initial_guess.jl` and is documented
in the *Initial Guess* section of the API reference.

## NLP backends and modelers

CTModels does **not** solve the NLP itself. Instead, it connects to external NLP
backends via modelers and builders defined in `src/nlp/`:

- `ADNLPModeler` (based on `ADNLPModels.jl`),
- `ExaModeler` (based on `ExaModels.jl`),
- additional builder types and helper functions.

These modelers:

- expose options through the generic `AbstractOCPTool` interface from CTBase
  (see the *Interfaces → OCP Tools* page),
- build backend-specific NLP models from an `AbstractOptimizationProblem`,
- optionally map NLP solutions back to `CTModels.Solution` objects.

The *Interfaces* section of the documentation contains detailed guides for:

- implementing new **optimization problems**,
- implementing new **optimization modelers**, and
- implementing new **OCP solution builders**.

## Extensions: JSON, JLD, and plotting

Several optional extensions live in the `ext/` directory and are loaded on demand
by the corresponding packages:

- **CTModelsJSON.jl** (requires `JSON3.jl`):
  helpers to serialize/deserialize the `infos::Dict{Symbol,Any}` carried by solutions,
  and methods for
  `export_ocp_solution(CTModels.JSON3Tag(), ::Solution)` /
  `import_ocp_solution(CTModels.JSON3Tag(), ::Model)`.

- **CTModelsJLD.jl** (requires `JLD2.jl`):
  methods to export and import a `Solution` as a `.jld2` file using
  `export_ocp_solution(CTModels.JLD2Tag(), ::Solution)` and
  `import_ocp_solution(CTModels.JLD2Tag(), ::Model)`.

- **CTModelsPlots.jl** (requires `Plots.jl`):
  plot recipes and helpers that make
  `Plots.plot(sol::CTModels.Solution, ...)`
  and
  `Plots.plot!(sol::CTModels.Solution, ...)`
  display the trajectories of state, control, costate, constraints, and dual
  variables in a consistent, configurable way.

If the corresponding extension package is not loaded, the public wrappers
`export_ocp_solution`, `import_ocp_solution`, and the generic `RecipesBase.plot`
throw a descriptive `CTBase.ExtensionError`.

## How this documentation is organized

The documentation is split into two main parts:

- **Interfaces**
  - *OCP Tools*: how to implement new configurable tools (backends, discretizers, solvers).
  - *Optimization Problems*: how to define `AbstractOptimizationProblem` types.
  - *Optimization Modelers*: how to map optimization problems to specific NLP backends.
  - *Solution Builders*: how to turn NLP execution statistics into `CTModels.Solution` objects.

- **API Reference**
  - *Types*: core types for models, solutions, and internal structures.
  - *Model / Times / Dynamics / Objective / Constraints*: detailed API for building OCP models.
  - *Solution & Dual*: how solutions and dual variables are represented.
  - *Initial Guess*: utilities to build and validate initial guesses.
  - *NLP Backends*: ADNLPModels/ExaModels-based backends and related options.
  - *Extensions*: Plot, JSON, and JLD extensions.

You can start by reading the **Interfaces** pages to understand the high-level
design, then use the **API Reference** to look up the details of particular
functions and types.

## I am X, I want to do Y → read…

### User Guide

- **I want to formulate a new optimal control / optimization problem**  
  Read **User Guide → Optimization Problems**, then **API Reference → Model / Times / Dynamics / Objective / Constraints**
  for details about fields and conventions.
- **I want to build good initial guesses for my problems**  
  Read **User Guide → Solution Builders** for the overall philosophy, then **API Reference → Initial Guess**
  for the `pre_initial_guess` and `initial_guess` functions.
- **I want to save / reload solutions (for example for numerical experiments)**  
  Read **API Reference → Extensions (JSON & JLD)** and the pages associated with the `CTModelsJSON` and `CTModelsJLD` modules.
- **I want to plot solution trajectories nicely**  
  Read **API Reference → Extensions (Plot Extension)**, and look at the examples using `Plots.plot(sol)` and `Plots.plot!(sol)`.
- **I use OptimalControl.jl and I just want to understand what CTModels does in the background**  
  Read this introduction page, then skim through the **User Guide** section to see how
  problems, modelers, and builders fit together.

### Developer Guide

- **I want to create a new strategy (modeler, solver, discretizer)**  
  Read **Developer Guide → Tutorials → Creating a Strategy**, then **Developer Guide → Interfaces → Strategies**
  for the complete contract specification.
- **I want to create a family of related strategies**  
  Read **Developer Guide → Tutorials → Creating a Strategy Family**, then **Developer Guide → Interfaces → Strategy Families**
  for registry integration and best practices.
- **I want to migrate from AbstractOCPTool to AbstractStrategy**  
  Read **Developer Guide → Interfaces → Strategies → Migration Guide** for step-by-step instructions.
- **I want to connect a new NLP backend or tweak an existing backend**  
  Read **Developer Guide → Interfaces → Optimization Modelers** (updated) and the **API Reference → NLP Backends** section.
- **I want to contribute to the core of CTModels (types, constraints, dual variables, etc.)**  
  Start with **API Reference → Types**, then **Solution & Dual** and **Constraints** to understand the internal structures
  before modifying or adding new fields.
