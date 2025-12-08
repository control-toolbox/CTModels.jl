# Print

## Index

```@index
Pages   = ["print.md"]
Modules = [CTModels, Base]
Order = [:module, :constant, :type, :function, :macro]
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
```

## Documentation

```@autodocs
Modules = [CTModels]
Order = [:module, :constant, :type, :function, :macro]
Pages = ["print.jl"]
```
