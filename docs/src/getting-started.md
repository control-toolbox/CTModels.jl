# Getting Started

```@meta
CurrentModule = CTModels
```

## Installation

CTModels.jl is typically installed as a dependency of another package in the ecosystem
(e.g. [OptimalControl.jl](https://github.com/control-toolbox/OptimalControl.jl)).
To install it directly:

```julia
import Pkg
Pkg.add("CTModels")
```

**Requires Julia ≥ 1.10.**

## Mental Model

CTModels is the **mathematical model layer** of the control-toolbox ecosystem.
It provides:

- **Types** and **building blocks** for states, controls, variables, time grids, constraints, and cost functionals.
- An immutable `Model` / `Solution` hierarchy for optimal control problems and their numerical solutions.
- Tools to build **initial guesses** for warm-starting a solver.
- Optional extensions for **serialization** (JSON, JLD2) and **plotting**.

Two things to keep in mind:

1. **No top-level exports.** `using CTModels` loads the package but brings no symbols
   into scope. Every symbol is accessed via its qualified path:
   ```julia
   CTModels.Building.state!     # ✓ always works
   CTModels.Solutions.build_solution
   CTModels.Init.build_initial_guess
   ```
2. **`PreModel → build → Model` pipeline.** An OCP is assembled incrementally on a mutable
   `PreModel`, then frozen into an immutable `Model` by `build`. The `Model` is the object
   every downstream package (solver, initial-guess builder, serializer) consumes.

## 5-Minute Walkthrough

### Building an optimal control problem

We solve the *beam* problem: minimise ``\int_0^1 u(t)^2\,\mathrm{d}t`` subject to
``\dot{x} = (x_2, u)``, fixed boundary conditions, and box constraints.

```@example gs
using CTModels

# 1. Mutable pre-model
pre = CTModels.PreModel()

# 2. Declare the spaces (must be done before dynamics/objective)
CTModels.variable!(pre, 0)             # no optimisation variable
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)                # x ∈ ℝ²
CTModels.control!(pre, 1)              # u ∈ ℝ

# 3. Dynamics ẋ = (x₂, u) — in-place form
function beam_dynamics!(r, t, x, u, v)
    r[1] = x[2]
    r[2] = u[1]
    return nothing
end
CTModels.dynamics!(pre, beam_dynamics!)

# 4. Lagrange cost ∫ u² → min
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u[1]^2)

# 5. Constraints
function beam_boundary!(r, x0, xf, v)
    r[1] = x0[1]; r[2] = x0[2] - 1
    r[3] = xf[1]; r[4] = xf[2] + 1
    return nothing
end
CTModels.constraint!(pre, :boundary; f=beam_boundary!, lb=zeros(4), ub=zeros(4), label=:bc)
CTModels.constraint!(pre, :state;   rg=1:1, lb=[0.0],   ub=[0.1],  label=:x1_box)
CTModels.constraint!(pre, :control; rg=1:1, lb=[-10.0], ub=[10.0], label=:u_box)

# 6. Mark autonomous and freeze into an immutable Model
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)
```

The built `Model` exposes its structure through accessors:

```@example gs
(CTModels.state_dimension(ocp),
 CTModels.control_dimension(ocp),
 CTModels.is_autonomous(ocp),
 CTModels.has_lagrange_cost(ocp))
```

### Assembling a solution

`build_solution` is the bridge between a solver's raw arrays and a `Solution` object.
Here we fabricate arrays to illustrate the interface:

```@example gs
N = 101
T = collect(range(0.0, 1.0; length=N))
X = hcat(cos.(T), -sin.(T))         # N×2 state samples
U = reshape(-cos.(T), N, 1)         # N×1 control samples
P = zeros(N, 2)                     # N×2 costate samples

sol = CTModels.build_solution(ocp, T, X, U, Float64[], P;
    objective=0.5,
    iterations=10,
    constraints_violation=1e-9,
    message="Solve_Succeeded",
    status=:Solve_Succeeded,
    successful=true,
)
```

Trajectories are returned as callables (interpolated from the samples):

```@example gs
x = CTModels.state(sol)
(x(0.5),
 CTModels.objective(sol),
 CTModels.successful(sol))
```

### Building an initial guess

```@example gs
init = CTModels.build_initial_guess(ocp,
    (state=t -> [0.0, 0.0], control=t -> [0.1])
)
(init.state(0.5), init.control(0.5))
```

## Next Steps

| Topic | Guide |
| :--- | :--- |
| Types, traits, and the noun architecture | [Types & Traits](model/types_and_traits.md) |
| Declaring spaces (state, control, variable, time) | [Components](model/components.md) |
| Dynamics and objective | [Dynamics & Objective](model/dynamics_objective.md) |
| Path, boundary, and box constraints | [Constraints](model/constraints.md) |
| Freezing a `PreModel` into a `Model` | [Building a Model](model/building.md) |
| Reading state, control, costate trajectories | [Trajectories](solution/trajectories.md) |
| Dual variables and solver diagnostics | [Duals & Diagnostics](solution/duals.md) |
| Warm-starting with initial guesses | [Initial Guesses](initial_guess/index.md) |
| Saving and loading solutions | [Export & Import](serialization/export_import.md) |
| Full API reference | API Reference (left sidebar) |
