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

## Documentation

```@autodocs
Modules = [CTModelsPlots]
Order = [:module, :constant, :type, :function, :macro]
Pages = ["plot.jl", "plot_utils.jl", "plot_default.jl", "CTModelsPlots.jl"]
```