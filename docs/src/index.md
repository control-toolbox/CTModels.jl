# CTModels.jl

```@meta
CurrentModule = CTModels
```

The `CTModels.jl` package is part of the [control-toolbox ecosystem](https://github.com/control-toolbox).
It provides the **mathematical model layer** for optimal control problems:

- **types and building blocks** for states, controls, variables, time grids, and constraints;
- an `AbstractModel`/`Model` and `AbstractSolution`/`Solution` hierarchy for optimal control problems;
- tools to build **initial guesses** for optimization;
- optional extensions for **exporting/importing solutions** (JSON/JLD) and **plotting**.

!!! info "CTModels vs CTSolvers"

    **CTModels** focuses on **defining** optimal control problems and representing their solutions.
    For **solving** these problems (discretization, NLP backends, optimization strategies),
    see [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl).

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
- **Providing utilities** for initial guesses, export/import, and plotting of solutions.

Most of the public API is organized in a way that closely mirrors the mathematical
objects you manipulate when formulating an optimal control problem.

## Module overview

| Module | Responsibility |
|--------|---------------|
| `CTModels.OCP` | Types and builders for optimal control problems and solutions |
| `CTModels.Utils` | Interpolation, matrix utilities, `@ensure` validation macro |
| `CTModels.Display` | `Base.show` extensions for models and solutions |
| `CTModels.Serialization` | `export_ocp_solution` / `import_ocp_solution` (JLD2, JSON) |
| `CTModels.Init` | Initial guess construction and validation |

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
CTModels provides a layer to organize them:

- `pre_initial_guess` builds an `PreInitialGuess` object from raw user data
  (functions, vectors, or constants for state, control, and variables).
- `initial_guess` turns this into an `InitialGuess`, checking consistency
  with the chosen `AbstractModel`.
- `build_initial_guess` constructs initial guess objects from various input formats.
- `validate_initial_guess` ensures consistency with the problem dimensions.

The corresponding API is documented in the *InitialGuess* section of the API reference.

## Solving optimal control problems

CTModels defines the **problem structure** but does **not** solve it.
For solving optimal control problems, use [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl),
which provides:

- **Discretization strategies** (direct collocation, multiple shooting, etc.)
- **NLP backends** (ADNLPModels, ExaModels, etc.)
- **Optimization modelers** to connect problems to solvers
- **Strategy architecture** for configurable components

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

The documentation consists of:

- **Introduction** (this page): Overview of CTModels and its role in the control-toolbox ecosystem.

- **Developer guides** — narrative, architecture-oriented walkthroughs aimed at
  control-toolbox contributors:
  - [Optimal control problems](model/index.md): the `PreModel → build → Model` pipeline,
    types & traits, components, dynamics, objective, constraints.
  - [Solutions](solution/index.md): the `Solution` anatomy, time grids, trajectories, duals.
  - [Initial guesses](initial_guess/index.md): the `Init` pipeline and warm-starting.
  - [Serialization & extensions](serialization/index.md): export/import and plotting.

- **API Reference**: Auto-generated, exhaustive documentation of every module and symbol
  (public *and* private), one page per submodule and loaded extension.

Use the **guides** to learn how the pieces fit together, and the **API Reference** to look up
the details of a particular function or type.

## Quick start guide

- **I want to define an optimal control problem**  
  See the [Optimal control problems](model/index.md) guide for `state!`, `control!`,
  `dynamics!`, `objective!`, `constraint!`, and `build`.

- **I want to read a solution**  
  See the [Solutions](solution/index.md) guide for `state`, `control`, `costate`, `dual`, and
  the solver diagnostics.

- **I want to build initial guesses**  
  See the [Initial guesses](initial_guess/index.md) guide for `pre_initial_guess`,
  `initial_guess`, and `build_initial_guess`.

- **I want to save/load or plot solutions**  
  See the [Serialization & extensions](serialization/index.md) guide for `export_ocp_solution`,
  `import_ocp_solution`, and `plot(sol)`.

- **I want to solve an optimal control problem**  
  Use [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl) which provides discretization, NLP backends, and optimization strategies.

- **I use OptimalControl.jl**  
  CTModels provides the underlying types and building blocks. OptimalControl.jl offers a higher-level interface.
