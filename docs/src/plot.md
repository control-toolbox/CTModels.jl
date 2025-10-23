# Plot

## Index

```@index
Pages   = ["plot.md"]
Modules = [CTModelsPlots, RecipesBase]
Order = [:module, :constant, :type, :function, :macro]
```

!!! warning

    In the examples in the documentation below, the methods are not prefixed by the module name even if they are private. 

    ```julia-repl
    julia> using CTModels
    julia> x = 1
    julia> private_fun(x) # throw an error
    ```

    must be replaced by

    ```julia-repl
    julia> using CTModels
    julia> x = 1
    julia> CTModels.private_fun(x)
    ```

    However, if the method is reexported by another package, then, there is no need of prefixing.

    ```julia-repl
    julia> module OptimalControl
               import CTModels: private_fun
               export private_fun
           end
    julia> using OptimalControl
    julia> x = 1
    julia> private_fun(x)
    ```

## Simple example

```@example
using CTModels, Plots
import CTParser: @def

t0, tf, x0 = 0.0, 1.0, -1.0

ocp = @def begin
    t ∈ [t0, tf], time
    x ∈ R, state
    u ∈ R, control
    x(t0) == x0
    -Inf ≤ x(t) + u(t) ≤ 0, (mixed_con)
    ẋ(t) == u(t)
    ∫(0.5u(t)^2) → min
end

sol = CTModels.build_solution(
    ocp,
    collect(range(t0, tf; length=201)),
    t -> x0 * exp(-t),
    t -> -x0 * exp(-t),
    Float64[],
    t -> exp(t - tf) - 1;
    objective = exp(-1) - 1,
    iterations = 0,
    constraints_violation = 0.0,
    message = "",
    status = :optimal,
    successful = true,
)

plot(sol)
```

## Documentation

```@autodocs
Modules = [CTModelsPlots]
Order = [:module, :constant, :type, :function, :macro]
Pages = ["plot.jl", "plot_utils.jl", "plot_default.jl", "CTModelsPlots.jl"]
```
