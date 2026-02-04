# Example: Migration

This example shows the before (AbstractOCPTool) and after (AbstractStrategy) code for the same component.

## Legacy Implementation (AbstractOCPTool)

```julia
# Old Style (conceptual)
struct OldTool <: AbstractOCPTool
    options_values::NamedTuple
    options_sources::NamedTuple
end

CTModels.get_symbol(::Type{OldTool}) = :mytool
CTModels._option_specs(::Type{OldTool}) = (
    max_iter = OptionSpec(type=Int, default=100),
)

function OldTool(; kwargs...)
    vals, srcs = CTModels._build_ocp_tool_options(OldTool; kwargs...)
    return OldTool(vals, srcs)
end
```

## Modern Implementation (AbstractStrategy)

```@example migration
using CTModels.Strategies

struct NewTool <: AbstractStrategy
    options::StrategyOptions
end

Strategies.id(::Type{NewTool}) = :mytool
Strategies.metadata(::Type{NewTool}) = StrategyMetadata(
    OptionDefinition(name=:max_iter, type=Int, default=100)
)

function NewTool(; kwargs...)
    opts = Strategies.build_strategy_options(NewTool; kwargs...)
    return NewTool(opts)
end

# Verify
t = NewTool(max_iter=200)
println("New tool created with max_iter=", Strategies.option_value(t, :max_iter))
```
