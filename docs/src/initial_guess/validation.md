# Validation & warm-start

```@meta
CurrentModule = CTModels
```

[`build_initial_guess`](@ref CTModels.Init.build_initial_guess) always ends with a dimension
check against the model. The check can also be invoked on its own with
[`validate_initial_guess`](@ref CTModels.Init.validate_initial_guess), and a guess can be
**warm-started** from a previous [`Solution`](@ref CTModels.Solutions.Solution).

```@example val
using CTModels
import CTBase

pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u[1]^2)
CTModels.time_dependence!(pre; autonomous=true)
ocp = CTModels.build(pre)
nothing # hide
```

## Construct, then validate

[`initial_guess`](@ref CTModels.Init.initial_guess) builds an **unvalidated**
[`InitialGuess`](@ref CTModels.Init.InitialGuess); pass it to
[`validate_initial_guess`](@ref CTModels.Init.validate_initial_guess) to check it against the
model. This separation lets a caller build once and validate against several models.

```@example val
ig = CTModels.initial_guess(ocp; state = t -> [0.0, 0.0], control = t -> [0.1])
ig === CTModels.validate_initial_guess(ocp, ig)   # returns the same object when valid
```

## Dimension mismatch is rejected

Validation samples the guess and compares its shape to the problem dimensions. A state guess
of the wrong length is refused:

```@example val
try
    CTModels.build_initial_guess(ocp, (state = t -> [0.0],))   # 1 ≠ 2 states
catch e
    (e isa CTBase.Exceptions.IncorrectArgument, :rejected)
end
```

## Warm-start from a solution

Passing a [`Solution`](@ref CTModels.Solutions.Solution) reuses its trajectories as the new guess —
the standard *warm-start*. The state/control dimensions must match between the solution's model
and the target model.

```@example val
# A (fabricated) solution of the same problem
N = 51
T = collect(range(0.0, 1.0; length=N))
X = hcat(cos.(T), -sin.(T))
U = reshape(-cos.(T), N, 1)
P = zeros(N, 2)
sol = CTModels.build_solution(ocp, T, X, U, Float64[], P;
    objective=0.5, iterations=10, constraints_violation=1e-9,
    message="ok", status=:optimal, successful=true)

# Reuse it as an initial guess
warm = CTModels.build_initial_guess(ocp, sol)
warm.state(0.5)
```

The warm-started guess is a validated [`InitialGuess`](@ref CTModels.Init.InitialGuess), ready
to seed the next solve.
