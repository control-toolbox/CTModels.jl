# Hamiltonians

```@meta
CurrentModule = CTModels
```

The pseudo-Hamiltonian of an optimal control problem depends only on the model: its
dynamics ``f``, its Lagrange cost ``\ell`` and its criterion. CTModels builds it, and the
Hamiltonians derived from it, as methods of the generic functions
`CTBase.Data.pseudo_hamiltonian` and `CTBase.Data.hamiltonian`, re-exported by
[`CTModels.Models`](@ref CTModels.Models). CTFlows uses them to build the flows of the
indirect method.

| Call | Problem | Returns |
| :--- | :--- | :--- |
| `pseudo_hamiltonian(ocp; p0)` | with a control | ``\tilde H(t, x, p, u, v)`` |
| `pseudo_hamiltonian(ocp; p0, constraints)` | with a control | ``H(t, x, p, u, \mu, v)`` |
| `hamiltonian(ocp, u; p0)` | with a control | ``h(t, x, p, v)``, control in feedback form |
| `hamiltonian(ocp, u; p0, multipliers)` | with a control | ``h(t, x, p, v)``, control and multipliers in feedback form |
| `hamiltonian(ocp; p0)` | control-free | ``H(t, x, p, v)`` |

Each object is callable with its **natural** signature, which follows the time and
variable dependence of the problem (`H̃(x, p, u)` for an autonomous problem without
variable, `H̃(t, x, p, u, v)` for a non-autonomous one with a variable), and with a
**uniform** signature that takes every argument. A one-dimensional state, control,
variable or multiplier is a number.

## The pseudo-Hamiltonian

```math
\tilde H(t, x, p, u, v) = p \cdot f(t, x, u, v) + p^0\, \ell(t, x, u, v).
```

The example of this page is the problem with a state constraint of order one of
Bonnard, Faubourg, Launay and Trélat: minimise ``\int_0^2 x^2`` for ``\dot x = u``,
``|u| \le 1``, under the constraint ``x \ge l_b = 0.1``.

```@example ham
using CTModels
const Models = CTModels.Models

lb = 0.1
pre = CTModels.PreModel()
CTModels.time!(pre; t0=0.0, tf=2.0)
CTModels.state!(pre, 1)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
CTModels.constraint!(pre, :path;
    f=(r, t, x, u, v) -> (r[1] = x - lb; nothing), lb=[0.0], ub=[Inf], label=:x_con)
CTModels.constraint!(pre, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:u_box)
CTModels.time_dependence!(pre; autonomous=true)
CTModels.definition!(pre, quote end)
ocp = CTModels.build(pre)

H̃ = Models.pseudo_hamiltonian(ocp)
```

```@example ham
x, p, u = 1.0, 2.0, 0.5
H̃(x, p, u)                     # natural call: p·u − x²
```

```@example ham
H̃(0.0, x, p, u, nothing)       # uniform call H̃(t, x, p, u, v)
```

### The sign of ``p^0``

The pseudo-Hamiltonian is always **maximised**, for a minimisation and for a maximisation;
only ``p^0`` depends on the criterion (ct-conventions `SGN4`):

| Criterion | Normal case (default) | Abnormal case | Allowed |
| :--- | :--- | :--- | :--- |
| `:min` | ``p^0 = -1`` | ``p^0 = 0`` | ``p^0 \le 0`` |
| `:max` | ``p^0 = +1`` | ``p^0 = 0`` | ``p^0 \ge 0`` |

So ``\min \int \ell`` and ``\max \int (-\ell)`` have the same pseudo-Hamiltonian, hence the
same control, costate and multipliers. A ``p^0`` whose sign contradicts the criterion is
rejected.

```@example ham
Models.pseudo_hamiltonian(ocp; p0=0)(x, p, u)        # abnormal case: p·u
```

```@example ham
try
    Models.pseudo_hamiltonian(ocp; p0=1)
catch e
    println(e.msg, ": ", e.got)
end
```

## The Hamiltonian for a control law

Given a control law in feedback form ``u(t, x, p, v)``, the Hamiltonian is

```math
h(t, x, p, v) = \tilde H(t, x, p, u(t, x, p, v), v).
```

The law is a `CTBase.Data.DynClosedLoop` law, or a plain function with the natural arity
of the problem: `u(x, p)`, `u(t, x, p)`, `u(x, p, v)` or `u(t, x, p, v)`. On the first arc
of the example, ``u = -1``:

```@example ham
h = Models.hamiltonian(ocp, (x, p) -> -1.0)
h(x, p)                        # −p − x²
```

A plain function with a single method is checked against the arity of the problem; a
function with several methods, or with a variable number of arguments, is not.

## Constraints

### Constraints by label

The constraints active on an arc are adjoined by **label**, with their multipliers ``\mu``:

```math
H(t, x, p, u, \mu, v) = \tilde H(t, x, p, u, v) + \sum_k \mu_k \cdot g_k(t, x, u, v),
```

where each constraint ``l_b \le c \le u_b`` enters on its active side, ``g \ge 0``, and the
multiplier ``\mu`` is an **explicit argument**, like the control. This is the
pseudo-Hamiltonian of the maximum principle with constraints.

```@example ham
H = Models.pseudo_hamiltonian(ocp; constraints=:x_con)
```

```@example ham
μ = 3.0
H(x, p, u, μ)                  # p·u − x² + μ (x − lb)
```

Several labels are given as a tuple; ``\mu`` then stacks their multipliers in that order,
each with the components of its constraint. Labels not given are inactive.

### The sign convention of the multipliers

The multipliers are given in the sign convention of the **duals of a solution**
(ct-conventions `SGN2`, `SGN3`), so that the dual of a label read in a solution of a
direct method, `dual(sol, :label)`, can be used as is. Component by component:

| Bounds of the component | Term adjoined | Multiplier ``y`` |
| :--- | :--- | :--- |
| lower only, ``l_b \le c`` | ``y\,(c - l_b)`` | ``y \ge 0`` |
| upper only, ``c \le u_b`` | ``y\,(u_b - c)`` | ``y \ge 0`` |
| both, or ``c = l_b = u_b`` | ``-y\,(c - b)``, ``b = u_b`` if ``y > 0``, ``l_b`` otherwise | signed |

For a constraint with two bounds, the active side is read on the sign of the multiplier,
so it never has to be given: ``y > 0`` on the upper side, ``y < 0`` on the lower side. The
term is continuous at ``y = 0``. With the control box of the example, ``-1 \le u \le 1``:

```@example ham
Hu = Models.pseudo_hamiltonian(ocp; constraints=:u_box)
Hu(x, p, 1.0, 0.5) - H̃(x, p, 1.0), Hu(x, p, -1.0, -0.5) - H̃(x, p, -1.0)   # both vanish on the bound
```

### Which constraints

| Kind | Enters the Hamiltonian | |
| :--- | :--- | :--- |
| path constraint (state, control or mixed) | yes | |
| state box, e.g. `x₁(t) ≤ 1` | yes | the same term as the path constraint `x₁(t) - 1 ≤ 0` |
| control box | yes | inert in the flow, see below |
| boundary constraint | no | gives the transversality conditions |
| variable box | no | gives the transversality condition on ``v`` |

A constraint written as a box or as a path constraint has the same term, and the same
multiplier (ct-conventions `SGN5`).

The bounds of a box are the **effective** bounds of its components: when a component is
bounded under several labels, its bounds are intersected, and each of these labels gives
the same box, and the same dual in the solution. With `x₁(t) ≥ 0, (a)` and
`x₁(t) ≤ 1, (b)`, the label `:a` gives the two-sided term of ``0 \le x_1 \le 1``, whose
multiplier is signed: ``y < 0`` when the lower bound is active. Adjoin one of the two
labels; giving both would add the term twice, and is rejected.

A **control box** is inert in the flow: on an arc where the control is saturated,
``u = u_b``, the term ``\mu\,(u_b - u)`` vanishes, and so do its derivatives in ``x`` and
``p`` (with ``u`` fixed, or with ``u`` constant along the arc). Its multiplier is given by
the stationarity ``\partial \tilde H / \partial u - \mu = 0``; this is why it is usually
left out, but adjoining it gives the dual of the control box, to compare with a direct
method.

```@example ham
try
    CTModels.Models.pseudo_hamiltonian(ocp; constraints=:unknown)
catch e
    println(e.msg)
end
```

### Multipliers in feedback form

With a control law, the multipliers of the active constraints are given in feedback form,
as `label => μ` pairs (a `Pair`, a tuple of pairs, a `NamedTuple` or a `Dict`):

```math
h(t, x, p, v) = H(t, x, p, u(t, x, p, v), \mu(t, x, p, v), v).
```

On the boundary arc of the example, ``x = l_b`` so ``u = 0``; the maximisation condition
gives ``p = 0`` and ``\dot p = 2x - \mu = 0``, so ``\mu = 2x``:

```@example ham
hb = Models.hamiltonian(ocp, (x, p) -> 0.0; multipliers=(:x_con => (x, p) -> 2x))
```

```@example ham
hb(x, p), hb(lb, 0.0)          # on the arc, g = 0: h = −lb²
```

Each multiplier is a `CTBase.Data.Multiplier`, or a function with the natural arity of
the problem: `μ(x, p)`, `μ(t, x, p)`, `μ(x, p, v)` or `μ(t, x, p, v)`. Its value must have
the dimension of its constraint (a number for a one-dimensional constraint).

## Partial and total derivatives

The extremals of the maximum principle are given by the **partial** derivatives of
``H(t, x, p, u, \mu, v)`` with respect to ``x`` and ``p``, at fixed ``u`` and ``\mu``:

```math
\dot x = \frac{\partial H}{\partial p}, \qquad \dot p = -\frac{\partial H}{\partial x}.
```

`CTBase.Data.freeze_multiplier(H, μ)` returns the pseudo-Hamiltonian at a fixed value of
``\mu``, whose gradients are these partial derivatives.

Differentiating ``h(t, x, p, v)`` instead gives the **total** derivative, through the
control law and the multipliers:

```math
\frac{\mathrm{d} h}{\mathrm{d} x} = \frac{\partial H}{\partial x}
+ \frac{\partial H}{\partial u} \frac{\partial u}{\partial x}
+ g \cdot \frac{\partial \mu}{\partial x}.
```

The two agree on an optimal arc, where the constraint is active (``g = 0``) and the law is
stationary or constant, but not elsewhere, for instance during the iterations of a
shooting method. In the example, the total derivative of ``h_b`` in ``x`` is
``2(x - l_b)``, while the partial one is ``-2x + \mu = 0``. The flows of CTFlows offer both
(`hamiltonian_type=:partial` or `:total`).

## Control-free problems

A problem without control has a Hamiltonian, and no pseudo-Hamiltonian:

```math
H(t, x, p, v) = p \cdot f(t, x, v) + p^0\, \ell(t, x, v).
```

```@example ham
pre = CTModels.PreModel()
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = -x[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> x[1]^2)
CTModels.time_dependence!(pre; autonomous=true)
CTModels.definition!(pre, quote end)
ocp_cf = CTModels.build(pre)

H_cf = Models.hamiltonian(ocp_cf)
H_cf([1.0, 2.0], [3.0, 4.0])   # p₁x₂ − p₂x₁ − x₁²
```

Constraints are not adjoined to the Hamiltonian of a control-free problem: such a
problem is easily ill-posed, and these conditions are rather boundary conditions.
`pseudo_hamiltonian(ocp_cf)` and `hamiltonian(ocp_cf; multipliers=…)` raise a
`CTBase.Exceptions.PreconditionError`, as does `hamiltonian(ocp)` for a problem with a
control, which needs a control law.

## Errors

| Situation | Exception |
| :--- | :--- |
| `pseudo_hamiltonian` or `hamiltonian(ocp, u)` of a control-free problem | `PreconditionError` |
| `hamiltonian(ocp)` of a problem with a control | `PreconditionError` |
| multipliers for a control-free problem | `PreconditionError` |
| ``p^0`` with the wrong sign, or not finite | `IncorrectArgument` |
| open-loop or closed-loop control law; wrong arity of a plain function | `IncorrectArgument` |
| unknown label, label given twice, two labels of the same box component, boundary constraint or variable box | `IncorrectArgument` |
| multiplier without the dimension of its constraint (at the call) | `IncorrectArgument` |
