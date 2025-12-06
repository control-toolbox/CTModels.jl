# Implementing optimization modelers

This page explains how to implement new optimization modelers in CTModels,
that is, components that take an
[`AbstractOptimizationProblem`](@ref CTModels.AbstractOptimizationProblem) and
produce an NLP back-end model (and optionally map NLP solutions back to
OCP-related objects).

Modelers implement the
[`AbstractOptimizationModeler`](@ref CTModels.AbstractOptimizationModeler)
interface and are also
[`AbstractOCPTool`](@ref CTModels.AbstractOCPTool)s. This means they follow
both the options interface (see [`ocp_tools.md`](@ref)) and a calling
interface specific to optimization problems.

## Overview of the contract

A concrete modeler type `M` is expected to:

- subtype `AbstractOptimizationModeler`:

  ```julia
  struct MyModeler{Vals,Srcs} <: CTModels.AbstractOptimizationModeler
      options_values::Vals
      options_sources::Srcs
  end
  ```

- follow the `AbstractOCPTool` options contract (fields, `_option_specs`,
  constructor via `_build_ocp_tool_options`);
- implement at least the model-building call:

  ```julia
  (modeler::MyModeler)(prob::CTModels.AbstractOptimizationProblem,
                       initial_guess; kwargs...) = ...
  ```

  which produces the NLP model for the chosen back-end.

Optionally, the modeler can also implement a second call that maps a back-end
solution back to an OCP-related representation:

```julia
(modeler::MyModeler)(prob::CTModels.AbstractOptimizationProblem,
                     nlp_solution::SolverCore.AbstractExecutionStats;
                     kwargs...) = ...
```

Generic fallbacks for both calls are defined on
`AbstractOptimizationModeler` and throw `CTBase.NotImplemented` if they are
not specialized.

## Implementing the options interface

Because `AbstractOptimizationModeler <: AbstractOCPTool`, modelers follow the
same options pattern as other tools. See
[`ocp_tools.md`](@ref) for a detailed discussion.

In short, a typical modeler definition looks like:

```julia
struct MyModeler{Vals,Srcs} <: CTModels.AbstractOptimizationModeler
    options_values::Vals
    options_sources::Srcs
end

function CTModels._option_specs(::Type{<:MyModeler})
    return (
        show_time = CTModels.OptionSpec(;
            type = Bool,
            default = false,
            description = "Whether to print timing information while building the model.",
        ),
        # additional options...
    )
end

function MyModeler(; kwargs...)
    values, sources = CTModels._build_ocp_tool_options(
        MyModeler; kwargs..., strict_keys = true,
    )
    return MyModeler{typeof(values),typeof(sources)}(values, sources)
end
```

## Implementing the model-building call

The functional part of the interface is provided by the call overloads on the
modeler. A minimal pattern, inspired by
[`ADNLPModeler`](@ref CTModels.ADNLPModeler), is:

```julia
function (modeler::MyModeler)(
    prob::CTModels.AbstractOptimizationProblem,
    initial_guess;
    kwargs...,
)
    # Use the generic interface on `AbstractOptimizationProblem` to obtain
    # the appropriate builder for this back-end.
    builder = CTModels.get_adnlp_model_builder(prob)  # or a similar function

    # Merge modeler options with any additional keyword arguments
    vals = CTModels._options_values(modeler)
    return builder(initial_guess; vals..., kwargs...)
end
```

Concrete modelers in CTModels follow this pattern:

- `ADNLPModeler` dispatches on `get_adnlp_model_builder(prob)` and returns an
  `ADNLPModels.ADNLPModel`.
- `ExaModeler` dispatches on `get_exa_model_builder(prob)` and returns an
  `ExaModels.ExaModel{BaseType}`.

## Mapping NLP solutions back to OCP solutions

Modelers may also provide a second call that converts a back-end NLP solution
into an OCP-related representation, using the solution builders provided by
`AbstractOptimizationProblem`:

```julia
function (modeler::MyModeler)(
    prob::CTModels.AbstractOptimizationProblem,
    nlp_solution::SolverCore.AbstractExecutionStats;
    kwargs...,
)
    builder = CTModels.get_adnlp_solution_builder(prob)
    return builder(nlp_solution)
end
```

The generic fallback on `AbstractOptimizationModeler` throws
`CTBase.NotImplemented`, so if your modeler does not implement this mapping,
any attempt to call it will result in a clear error.

## Registration and symbols

Modelers are often registered in a back-end registry so that they can be
constructed from a symbolic identifier. CTModels, for instance, defines:

- `REGISTERED_MODELERS` in `nlp_backends.jl`;
- helpers such as `build_modeler_from_symbol(:adnlp; kwargs...)`.

To integrate a new modeler into such a registry, you typically:

1. Specialize [`get_symbol`](@ref CTModels.get_symbol) on the modeler type.
2. Optionally specialize
   [`tool_package_name`](@ref CTModels.tool_package_name).
3. Add the modeler type to the appropriate `REGISTERED_*` constant.

See also the `ocp_tools.md` page for the generic `AbstractOCPTool` interface
and examples such as `ADNLPModeler` and `ExaModeler`.
