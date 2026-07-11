# Constraints

```@meta
CurrentModule = CTModels
```

[`constraint!`](@ref CTModels.Building.constraint!) adds one constraint at a time to the
pre-model. The first positional argument is the **kind**; the keywords give the bounds, the
function or range, and a `label` used later to read back the constraint and its dual.

| Kind | Form | Keywords |
|---|---|---|
| `:path` | nonlinear ``\ell \le c(t,x,u,v) \le u`` | `f`, `lb`, `ub`, `label` |
| `:boundary` | nonlinear ``\ell \le b(x_0,x_f,v) \le u`` | `f`, `lb`, `ub`, `label` |
| `:state` | box on state components | `rg`, `lb`, `ub`, `label` |
| `:control` | box on control components | `rg`, `lb`, `ub`, `label` |
| `:variable` | box on variable components | `rg`, `lb`, `ub`, `label` |

Nonlinear constraint functions are written **in place** like the dynamics: `f(r, t, x, u, v)`
for `:path`, `f(r, x0, xf, v)` for `:boundary`.

```@example cons
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 2, "v")
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u[1]^2)

# Nonlinear path and boundary constraints
CTModels.constraint!(pre, :path;
    f=(r, t, x, u, v) -> (r[1] = x[1] + u[1]; nothing), lb=[0.0], ub=[1.0], label=:p)
CTModels.constraint!(pre, :boundary;
    f=(r, x0, xf, v) -> (r[1] = x0[1]; r[2] = xf[1]; nothing),
    lb=[0.0, 0.0], ub=[0.0, 0.0], label=:bc)

# Box constraints on state, control and variable components
CTModels.constraint!(pre, :state;    rg=1:1, lb=[-1.0], ub=[1.0], label=:x1)
CTModels.constraint!(pre, :control;  rg=1:1, lb=[-10.0], ub=[10.0], label=:u)
CTModels.constraint!(pre, :variable; rg=1:2, lb=[0.0, 0.0], ub=[1.0, 1.0], label=:vbox)

CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)
```

## Reading constraints back

On the built [`Model`](@ref CTModels.Models.Model), the constraints are grouped in a
[`ConstraintsModel`](@ref CTModels.Components.ConstraintsModel) and queried by dimension or by label:

```@repl cons
CTModels.dim_path_constraints_nl(ocp)
CTModels.dim_boundary_constraints_nl(ocp)
CTModels.dim_state_constraints_box(ocp)
CTModels.dim_control_constraints_box(ocp)
CTModels.dim_variable_constraints_box(ocp)
```

The raw constraint tuples can also be retrieved:

```@repl cons
CTModels.path_constraints_nl(ocp)
CTModels.boundary_constraints_nl(ocp)
CTModels.state_constraints_box(ocp)
CTModels.control_constraints_box(ocp)
CTModels.variable_constraints_box(ocp)
```

Use [`isempty_constraints`](@ref CTModels.Models.isempty_constraints) to check whether the
model has any constraints at all, and [`constraint`](@ref CTModels.Models.constraint) to
retrieve a single constraint by label.

## Labels and aliases

Before building, constraints live in a [`ConstraintsDictType`](@ref CTModels.Components.ConstraintsDictType)
keyed by `label`. Box constraints obey a **per-component uniqueness invariant**: if several
declarations touch the same component, their bounds are intersected and **all** their labels
are kept as *aliases*. This is what lets [`constraint`](@ref CTModels.Models.constraint) and
[`dual`](@ref CTModels.Solutions.dual) resolve any of the original labels to the merged component —
see the [Duals](../solution/duals.md) guide.

!!! note "One declaration, one label"

    Always pass an explicit `label`. It is the stable handle for the constraint across
    `build`, solution reconstruction, and dual extraction; auto-generated labels are harder
    to track in downstream packages.

## Error cases

Passing the same `label` twice raises a `PreconditionError` immediately:

```@example cons
pre_dup = CTModels.PreModel()
CTModels.variable!(pre_dup, 0)
CTModels.time!(pre_dup; t0=0.0, tf=1.0)
CTModels.state!(pre_dup, 2)
CTModels.control!(pre_dup, 1)
CTModels.constraint!(pre_dup, :state; rg=1:1, lb=[-1.0], ub=[1.0], label=:x1)
nothing # hide
```

```@repl cons
try # hide
CTModels.constraint!(pre_dup, :control; rg=1:1, lb=[-10.0], ub=[10.0], label=:x1)  # duplicate
catch e # hide
showerror(IOContext(stdout, :color => false), e) # hide
end # hide
```

Bounds with `lb > ub` are rejected on the spot:

```@repl cons
try # hide
CTModels.constraint!(pre_dup, :state; rg=2:2, lb=[1.0], ub=[0.0], label=:bad)
catch e # hide
showerror(IOContext(stdout, :color => false), e) # hide
end # hide
```
