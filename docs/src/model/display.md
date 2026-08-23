# Displaying models and solutions

```@meta
CurrentModule = CTModels
```

The `CTModels.Display` module provides `Base.show` extensions that render
[`Model`](@ref CTModels.Models.Model) and [`PreModel`](@ref CTModels.Building.PreModel)
objects in a human-readable mathematical format. It also hosts a
`RecipesBase.plot` stub that is specialised by the `CTModelsPlots` extension
when `Plots.jl` is loaded.

## Setup

```@setup display
using CTModels
```

## Displaying a built Model

When you print a [`Model`](@ref CTModels.Models.Model) in the REPL (or any
`IO` context with `MIME"text/plain"`), CTModels renders the OCP in standard
mathematical notation — objective, dynamics, constraints, and variable spaces:

```@example display
pre = CTModels.PreModel()

CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)

function dynamics!(r, t, x, u, v)
    r[1] = x[2]
    r[2] = u[1]
    return nothing
end
CTModels.dynamics!(pre, dynamics!)

CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u[1]^2)

function boundary!(r, x0, xf, v)
    r[1] = x0[1]
    r[2] = x0[2] - 1
    r[3] = xf[1]
    r[4] = xf[2] + 1
    return nothing
end
CTModels.constraint!(pre, :boundary; f=boundary!, lb=zeros(4), ub=zeros(4), label=:bc)
CTModels.constraint!(pre, :state;   rg=1:1, lb=[0.0],   ub=[0.1],  label=:x1_box)
CTModels.constraint!(pre, :control; rg=1:1, lb=[-10.0], ub=[10.0], label=:u_box)

CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)

ocp  # displays the model
```

The output includes:

- An **(autonomous)** or **(non autonomous)** qualifier.
- The **objective** `J(x, u) = …` with Mayer and/or Lagrange terms.
- The **dynamics** `ẋ(t) = f(t, x(t), u(t))`.
- **Constraint lines** for path, boundary, and box constraints (only those
  that are present).
- A **where** clause listing the state, control, and variable spaces.

## Displaying a PreModel

A [`PreModel`](@ref CTModels.Building.PreModel) can be displayed at any stage
of construction. If the problem is not yet consistent (missing components,
incomplete declarations), only the abstract definition — if any — is shown.
Once the pre-model is consistent, the full mathematical formulation is
rendered:

```@example display
pre2 = CTModels.PreModel()
CTModels.variable!(pre2, 0)
CTModels.time!(pre2; t0=0.0, tf=1.0)
CTModels.state!(pre2, 1)
CTModels.control!(pre2, 1)
CTModels.dynamics!(pre2, (r, t, x, u, v) -> (r[1] = u[1]; return nothing))
CTModels.objective!(pre2, :min; lagrange=(t, x, u, v) -> u[1]^2)
CTModels.time_dependence!(pre2; autonomous=true)

pre2  # consistent PreModel displays the mathematical form
```

An empty `PreModel` produces no output:

```@example display
CTModels.PreModel()  # nothing is printed
```

## Abstract (symbolic) definitions

If a [`Definition`](@ref CTModels.Components.Definition) has been attached to
the model via [`definition!`](@ref CTModels.Building.definition!), its
symbolic expression is printed under an "Abstract definition:" header before
the mathematical formulation. This is useful when the OCP originates from a
macro-based DSL (e.g. OptimalControl.jl) that stores the original user code.

When no definition is set ([`EmptyDefinition`](@ref CTModels.Components.EmptyDefinition)),
this section is skipped silently.

## Displaying component types

The same display conventions are used by the concrete component types that make up a
model. The types are normally inspected through their public accessors, while `show`
provides a compact visual summary of their structure:

```@repl display
state_model = CTModels.Components.StateModel("x", ["x₁", "x₂"])
CTModels.Components.name(state_model)
CTModels.Components.components(state_model)
CTModels.Components.dimension(state_model)
```

```@example display
state_model
```

A solution component indicates that its value is a callable trajectory without expanding
the closure. The value and metadata remain available through accessors:

```@repl display
state_solution = CTModels.Components.StateModelSolution("x", ["x₁"], t -> 2t)
CTModels.Components.value(state_solution)(0.5)
CTModels.Components.name(state_solution)
CTModels.Components.dimension(state_solution)
```

```@example display
state_solution
```

Time models, objectives, and constraints follow the same pattern. Their summaries expose
semantic fields while the accessors provide the programmatic interface:

```@repl display
times_model = CTModels.Components.TimesModel(
    CTModels.Components.FixedTimeModel(0.0, "t₀"),
    CTModels.Components.FreeTimeModel(2, "tf"),
    "t",
)
CTModels.Components.initial(times_model)
CTModels.Components.final(times_model)
CTModels.Components.initial_time_name(times_model)
CTModels.Components.final_time_name(times_model)
```

```@example display
times_model
```

```@repl display
objective_model = CTModels.Components.MayerObjectiveModel((x0, xf, v) -> xf[1], :min)
CTModels.Components.criterion(objective_model)
CTModels.Components.mayer(objective_model)
```

```@example display
objective_model
```

For solution support objects, the display summarizes grid sizes, optional solver metadata,
and dual presence rather than printing all numerical data:

```@repl display
grid = CTModels.UnifiedTimeGridModel(collect(range(0.0, 1.0; length=5)))
infos = CTModels.SolverInfos(12, :first_order, "converged", true, 1e-8, Dict{Symbol,Any}())
grid
infos
```

The corresponding accessors can be used without relying on the stored fields:

```@example display
CTModels.time_grid_model(
    CTModels.build_solution(
        ocp,
        collect(range(0.0, 1.0; length=3)),
        zeros(3, 2),
        zeros(3, 1),
        Float64[],
        zeros(3, 2);
        objective=0.0,
        successful=true,
    ),
)
```

## Plotting solutions

The `Display` module registers a `RecipesBase.plot` method for
[`AbstractSolution`](@ref CTModels.Solutions.AbstractSolution). Without
`Plots.jl` loaded, calling it throws an `ExtensionError`:

```@example display
using CTModels
sol = CTModels.build_solution(
    ocp,
    collect(range(0.0, 1.0; length=10)),
    zeros(10, 2),
    zeros(10, 1),
    Float64[],
    zeros(10, 2);
    objective=0.0,
    iterations=0,
    constraints_violation=0.0,
    message="",
    status=:dummy,
    successful=true,
)

try
    CTModels.plot(sol)
catch e
    println(typeof(e))
end
```

When `Plots.jl` is loaded, the `CTModelsPlots` extension provides full plot
recipes. See [Plotting](@ref) for details.

## See also

- [Building a model](building.md) — how to assemble a `PreModel` and call `build`.
- [Plotting](../serialization/plotting.md) — plot recipes for solutions.
- [`Model`](@ref CTModels.Models.Model) — API reference for the model type.
- [`PreModel`](@ref CTModels.Building.PreModel) — API reference for the pre-model type.
