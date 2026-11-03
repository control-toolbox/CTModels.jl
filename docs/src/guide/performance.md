# Performance & Type Stability

```@meta
CurrentModule = CTModels
```

This guide explains **how CTModels keeps its runtime-critical code fast**, and how a
contributor can check that a change has not introduced a regression.

The whole approach rests on one distinction.

## The one principle: hot path vs. setup path

CTModels code falls into two categories:

- **Hot path** — code called *repeatedly* while reading a solution: evaluating a
  [`Components.ConstantInTime`](@ref) or [`Components.CoercedTrajectory`](@ref) at
  each time point, extracting a dual by label with
  [`Solutions.DualSlice`](@ref)/[`Solutions.BoxDualDiff`](@ref), evaluating the path
  duals given by label ([`Solutions.StackedDuals`](@ref)), projecting a box
  constraint with [`Models.BoxProjection`](@ref), or reading a component accessor
  inside an inner loop. This code **must be type-stable** — an instability here
  multiplies over thousands of calls.
- **Setup path** — code called *once per problem*, before the solve: incrementally
  filling in a [`Building.PreModel`](@ref) (whose fields are `Union{T,Nothing}` by
  design, validated as the problem is built up), then freezing it with
  [`Building.build`](@ref), or assembling a `Solution` with
  [`Solutions.build_solution`](@ref). Here dispatch on `Nothing`-guarded fields is
  **acceptable and by design** — the cost is paid once, not per iteration.

The rule of thumb for contributors: **keep the hot path inferable; do not worry
about the mutable builder's dynamism.** When in doubt, the tools below tell you
which side of the line you are on.

## The toolbox

| Tool | What it does | When to reach for it |
| --- | --- | --- |
| `@code_warntype f(args...)` | Colored dump of inferred types for one call; red marks instability. | First local look at a single function in the REPL. |
| `Cthulhu.@descend f(args...)` | Interactive, navigable version of the above; descend into callees. | Finding *where* deep in a call chain an instability originates. |
| `JET.@report_opt f(args...)` | Reports runtime-dispatch / optimization failures for one concrete call. | The at-a-glance stability check used on this page. |
| `JET.report_package(CTModels)` | Whole-package *correctness* scan (undefined names, method errors). | Catching latent bugs; run manually (see below) — **not** wired into the test suite as a gate. |
| `Test.@inferred f(args...)` | Fails unless the call is type-stable. | Locking a fixed hot-path function against future regressions in a test. |

`JET` is a dev/test/docs dependency only — it is **not** a runtime dependency of
CTModels.

## Checking the hot path at a glance

[`JET.@report_opt`](https://aviatesk.github.io/JET.jl/stable/optanalysis/) inspects a
concrete call and prints `No errors detected` when the call is free of runtime
dispatch. The blocks below run **live at documentation build time**, so if a change
ever destabilises one of these hot-path entry points, this page's build surfaces it.

First, build the objects we will exercise:

```@example perf
using CTModels
using JET

f_const = CTModels.Components.ConstantInTime(1.0)
f_coerced = CTModels.Components.CoercedTrajectory(t -> [2t], only)
duals_fn = t -> [10.0 * t, 20.0 * t, 30.0 * t]
f_slice = CTModels.Solutions.DualSlice(duals_fn, 2)
f_proj = CTModels.Models.BoxProjection{:state}(2)
# The path duals given by label to `build_solution(...; duals=...)` when one of them is
# a function: each label fills its rows, the rows of the labels not given hold NaN.
f_stacked = CTModels.Solutions.StackedDuals(4, ((1:2, t -> [t, 2t]), (4:4, t -> 3t)))
# The callable that `build` assembles when the dynamics is declared range by
# range (`dynamics!(pre, i, f)` per component — the shape CTParser's `@def`
# emits for `∂(xᵢ)(t) == …`).
dyn_parts = CTModels.Building.__build_dynamics_from_parts(
    Tuple{UnitRange{Int},Function}[
        (1:1, (r, t, x, u, v) -> (r[1] = x[2]; nothing)),
        (2:2, (r, t, x, u, v) -> (r[1] = u[1]; nothing)),
    ],
)
nothing # hide
```

**Evaluating a constant-in-time function** (state/control interpolant baseline):

```@example perf
JET.@report_opt f_const(0.5)
```

**Evaluating a coerced trajectory** (the wrapper behind every `sol.state`,
`sol.control`, `sol.costate` call):

```@example perf
JET.@report_opt f_coerced(0.5)
```

**Extracting a dual by label** (called at many time points when plotting or
post-processing a solution's multipliers):

```@example perf
JET.@report_opt f_slice(0.5)
```

**Evaluating the path duals given by label** (the function behind
`path_constraints_dual(sol)` and `dual(sol, model, :label)` when a producer gives a path
dual as a function of time; see
[CTModels.jl#492](https://github.com/control-toolbox/CTModels.jl/issues/492)):

```@example perf
JET.@report_opt f_stacked(0.5)
```

**Projecting a box constraint** (state/control/variable slot selection):

```@example perf
JET.@report_opt f_proj(nothing, [10.0, 20.0, 30.0], nothing, nothing)
```

**Evaluating a dynamics assembled from coordinate parts** (called once per solver
step by direct methods; see [CTModels.jl#496](https://github.com/control-toolbox/CTModels.jl/issues/496)):

```@example perf
JET.@report_opt dyn_parts(zeros(2), 0.0, [0.3, 0.7], [0.5], Float64[])
```

All six report `No errors detected`: the repeated-call path is stable.

## What is enforced automatically

Rather than a whole-package `JET.test_package` gate, the test suite locks in
stability precisely on the hot-path calls shown above, via `JET.@test_opt`:

```julia
# test/suite/meta/test_code_quality.jl
JET.@test_opt target_modules = (CTModels,) f_const(0.5)
JET.@test_opt target_modules = (CTModels,) f_coerced(0.5)
JET.@test_opt target_modules = (CTModels,) dyn_parts(zeros(2), 0.0, x, u, v)
JET.@test_opt target_modules = (CTModels,) f_stacked(0.5)
# ... and so on for the other hot-path calls
```

The complementary *allocation* contract — a wrapper call must allocate exactly what
the raw computation it wraps allocates, and accessor reads must allocate nothing —
lives in `test/suite/meta/test_performance.jl` (`BenchmarkTools.@ballocated`
guards), and `Test.@inferred` guards sit next to each fixture in the ordinary test
files (e.g. `test/suite/components/test_components.jl`).

### Writing the raw side of an allocation guard

A wrapper-vs-raw guard (`PERF5`) is only as good as its raw side. The raw
equivalent must be written so the compiler **cannot fold or elide what the wrapper
provably performs**; otherwise the comparison measures an optimiser artifact, not a
defect. Two traps have already bitten:

- **Stitched calls.** Benchmarking two raw calls independently and adding the
  results (`lb(t)[i] - ub(t)[i]` as two separate `@ballocated`) measured 160 B
  against the wrapper's real 80 B: a single specialised method body gets escape
  analysis, two separate calls do not. Write the raw side as **one specialised
  function** performing the whole sequence.
- **Fresh-vector inputs.** With a base returning a fresh vector, `collect(base(t))`
  is elided on the raw side (a fresh array cannot escape, so `collect` may return
  it), while the wrapper's call boundary cannot elide the same copy: `160 == 80`.
  Use a **shared `const` input**, which makes the required copy explicit on both
  sides.

Verify at the REPL that the raw side allocates what you expect before freezing the
guard in `test/suite/meta/test_performance.jl`.

To run a whole-package correctness scan interactively on a fresh checkout:

```julia
using CTModels, JET
JET.report_package(CTModels; target_modules=(CTModels,))
```

## Known, acceptable dynamism

Running `report_package` on CTModels reports a number of "no matching method"
findings. **These are expected and do not indicate a regression** — they are not
wired into the test suite as a gate for exactly this reason:

- **`PreModel` field access.** [`Building.PreModel`](@ref) is a mutable struct whose
  `state`, `times`, `dynamics`, … fields are typed `Union{T,Nothing}` — filled in
  incrementally as `state!`, `time!`, `dynamics!`, etc. are called, and validated
  with precondition checks (`Core.@ensure`) before being read. JET's union-split
  analysis reports a `Nothing` branch for every such read; that branch is never
  reached at runtime because the precondition check throws first. This is setup-path
  code, deliberately dynamic by construction — not a defect.
- **`build`/`build_solution` composition.** The functions that assemble a `Model` or
  `Solution` from a `PreModel`/raw solver output inherit the same `Union{T,Nothing}`
  dynamism while validating and normalising their inputs. Once a `Model`/`Solution`
  is built, its accessors return concrete, non-`Nothing`-parameterised types — the
  dynamism never reaches the hot path.

## Investigating a regression

If a hot-path check above starts reporting dispatch, drill in locally:

```julia
using CTModels
f_coerced = CTModels.Components.CoercedTrajectory(t -> [2t], only)

# 1. Quick look
using InteractiveUtils
@code_warntype f_coerced(0.5)

# 2. Navigate the call chain to the root cause
using Cthulhu
@descend f_coerced(0.5)
```

Once fixed, lock the result with a stability test so it cannot silently regress:

```julia
using Test
@inferred f_coerced(0.5)
```

## See Also

- [Getting Started](../getting-started.md): the `PreModel → build → Model` pipeline
  this guide's "hot path vs. setup path" distinction is built on.
