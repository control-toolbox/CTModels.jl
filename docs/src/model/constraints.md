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
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u^2)

# Nonlinear path and boundary constraints
CTModels.constraint!(pre, :path;
    f=(r, t, x, u, v) -> (r[1] = x[1] + u; nothing), lb=[0.0], ub=[1.0], label=:p)
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

Each nonlinear tuple has the form `(lb, f!, ub, labels)`: `f!` is the **stacked** in-place
function of the group, which fills the rows of all its constraints in declaration order.
It is always a [`CompositeConstraint`](@ref CTModels.Building.CompositeConstraint), even when
the group holds a single declaration, as `:p` here: its type and display do not depend on the
number of constraints. `n` counts the declarations and `dims` gives the dimension of each.

Use [`isempty_constraints`](@ref CTModels.Models.isempty_constraints) to check whether the
model has any constraints at all.

## Reading a constraint by label

[`constraint`](@ref CTModels.Models.constraint) returns one declared constraint as a tuple
`(type, f, lb, ub)`. Unlike the stacked `f!` above, `f` is **out of place**: it returns the
value of that constraint alone. It is a named functor, so it prints what it does:

```@repl cons
CTModels.constraint(ocp, :p)
CTModels.constraint(ocp, :bc)
CTModels.constraint(ocp, :x1)
CTModels.constraint(ocp, :vbox)
```

| `type` | `f` | Call |
|---|---|---|
| `:path` | [`SubPathConstraint`](@ref CTModels.Models.SubPathConstraint): rows `indices` of the stacked path constraint, which has `n` rows | `f(t, x, u, v)` |
| `:boundary` | [`SubBoundaryConstraint`](@ref CTModels.Models.SubBoundaryConstraint): same for the boundary constraint | `f(x0, xf, v)` |
| `:state`, `:control` | [`BoxProjection`](@ref CTModels.Models.BoxProjection): the bounded components | `f(t, x, u, v)` |
| `:variable` | [`BoxProjection`](@ref CTModels.Models.BoxProjection) | `f(x0, xf, v)` |

A constraint of dimension one gives a scalar, and so do its bounds:

```@repl cons
_, f, lb, ub = CTModels.constraint(ocp, :p);
f(0.0, [0.25, 0.0], 0.5, [0.0, 0.0])  # x[1] + u
(lb, ub)
_, g, _, _ = CTModels.constraint(ocp, :bc);
g([1.0, 0.0], [3.0, 0.0], [0.0, 0.0])  # [x0[1], xf[1]]
```

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
CTModels.constraint!(pre_dup, :control; rg=1:1, lb=[-10.0], ub=[10.0], label=:x1)  # duplicate
```

Bounds with `lb > ub` are rejected on the spot:

```@repl cons
CTModels.constraint!(pre_dup, :state; rg=2:2, lb=[1.0], ub=[0.0], label=:bad)
```
