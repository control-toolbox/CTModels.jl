# Implementing new OCP tools

This page explains how to implement new *tools* in CTModels that follow the
`AbstractOCPTool` interface. Tools are configurable components such as
backends, modelers, discretizers, or solvers that expose a common options
API.

The interface is defined by the abstract type
[`AbstractOCPTool`](@ref CTModels.AbstractOCPTool) and the helper functions in
`nlp/options_schema.jl`.

## Overview

All concrete tools `T <: AbstractOCPTool` are expected to:

- store their configuration in two fields
  - `options_values::NamedTuple`  — effective option values.
  - `options_sources::NamedTuple` — provenance for each option (`:ct_default`
    or `:user`).
- optionally describe their options via
  [`_option_specs(::Type{T})`](@ref CTModels._option_specs), returning a
  `NamedTuple` of [`OptionSpec`](@ref CTModels.OptionSpec) values.
- provide a keyword-only constructor `T(; kwargs...)` that uses
  [`_build_ocp_tool_options`](@ref CTModels._build_ocp_tool_options) to
  validate and merge user-supplied keyword arguments with tool defaults.

High-level helpers such as
[`get_option_value`](@ref CTModels.get_option_value),
[`get_option_source`](@ref CTModels.get_option_source),
[`get_option_default`](@ref CTModels.get_option_default) and
[`show_options`](@ref CTModels.show_options) then work uniformly on any
`AbstractOCPTool` subtype.

## Defining a new tool type

1. **Choose an abstract specialization**

   Depending on the role of your tool, you will typically subtype one of the
   following interfaces, all of which inherit from
   [`AbstractOCPTool`](@ref CTModels.AbstractOCPTool):

   - [`AbstractOptimizationModeler`](@ref CTModels.AbstractOptimizationModeler)
     for OCP→NLP modelers (e.g. `ADNLPModeler`, `ExaModeler`).
   - `AbstractOptimizationSolver` (from CTSolvers) for NLP solvers
     (e.g. `IpoptSolver`).
   - `AbstractOptimalControlDiscretizer` (from CTSolvers) for OCP discretizers
     (e.g. `Collocation`).

2. **Define the concrete struct**

   A minimal tool definition looks like:

   ```julia
   struct MyTool{Vals,Srcs} <: AbstractOptimizationModeler
       options_values::Vals
       options_sources::Srcs
   end
   ```

   The field names `options_values` and `options_sources` are required by the
   generic helpers [`_options_values`](@ref CTModels._options_values) and
   [`_option_sources`](@ref CTModels._option_sources).

## Describing options with `OptionSpec`

To expose metadata for your tool's options, specialize
[`_option_specs(::Type{T})`](@ref CTModels._option_specs) on your concrete
type. The function should return a `NamedTuple` whose fields are option names
and whose values are [`OptionSpec`](@ref CTModels.OptionSpec) instances.

```julia
function CTModels._option_specs(::Type{<:MyTool})
    return (
        tol = CTModels.OptionSpec(;
            type = Real,
            default = 1e-6,
            description = "Optimality tolerance.",
        ),
        max_iter = CTModels.OptionSpec(;
            type = Integer,
            default = 1000,
            description = "Maximum number of iterations.",
        ),
    )
end
```

If `_option_specs` returns `missing` for a tool type, then functions like
[`options_keys`](@ref CTModels.options_keys) and
[`default_options`](@ref CTModels.default_options) will report that no
metadata is available.

## Implementing the constructor with `_build_ocp_tool_options`

The recommended pattern for constructing tools is to delegate keyword
processing to [`_build_ocp_tool_options`](@ref CTModels._build_ocp_tool_options):

```julia
function MyTool(; kwargs...)
    values, sources = CTModels._build_ocp_tool_options(
        MyTool; kwargs..., strict_keys = true,
    )
    return MyTool{typeof(values),typeof(sources)}(values, sources)
end
```

This helper:

- normalizes `kwargs` to a `NamedTuple`;
- validates keys and types against `_option_specs` (when available);
- merges defaults from [`default_options`](@ref CTModels.default_options) with
  user overrides (user wins);
- builds the parallel `options_sources` NamedTuple, marking each entry as
  `:ct_default` or `:user`.

Once defined, your tool automatically works with
[`get_option_value`](@ref CTModels.get_option_value),
[`get_option_source`](@ref CTModels.get_option_source),
[`get_option_default`](@ref CTModels.get_option_default) and
[`show_options`](@ref CTModels.show_options).

## Registering tools and assigning symbols

For some categories of tools, CTModels or CTSolvers maintain registries that
map symbolic identifiers to concrete types. For example, modelers are
registered in `REGISTERED_MODELERS` in `nlp_backends.jl`, and solvers and
\discretizers are registered similarly in CTSolvers.

To integrate a new tool into such a registry, you typically:

1. Specialize [`get_symbol`](@ref CTModels.get_symbol) on the tool type:

   ```julia
   CTModels.get_symbol(::Type{<:MyTool}) = :mytool
   ```

2. Optionally specialize [`tool_package_name`](@ref CTModels.tool_package_name)
   to indicate which external package provides the implementation:

   ```julia
   CTModels.tool_package_name(::Type{<:MyTool}) = "MyBackendPackage"
   ```

3. Add the tool type to the appropriate `REGISTERED_*` constant and use the
   helper that builds a tool from a symbol (e.g.
   `build_modeler_from_symbol(:mytool; kwargs...)`).

## Examples

### ADNLPModeler (CTModels)

`ADNLPModeler` is a concrete
[`AbstractOptimizationModeler`](@ref CTModels.AbstractOptimizationModeler)
that wraps `ADNLPModels.jl`:

- it subtypes `AbstractOptimizationModeler <: AbstractOCPTool`;
- it defines `options_values` and `options_sources` fields;
- it specializes `_option_specs(::Type{<:ADNLPModeler})` to describe its
  options (`show_time`, `backend`, etc.);
- it has a keyword-only constructor implemented via
  `_build_ocp_tool_options(ADNLPModeler; kwargs...)`.

### Collocation (CTSolvers)

In CTSolvers, `Collocation` is a concrete discretizer implementing
`AbstractOptimalControlDiscretizer <: AbstractOCPTool`:

- it stores `options_values` and `options_sources`;
- it defines `_option_specs(::Type{<:Collocation})` with options such as
  `grid`, `lagrange_to_mayer` and `scheme`;
- its constructor
  `Collocation(; kwargs...) = Collocation{typeof(values.scheme)}(values, sources)`
  is built on `_build_ocp_tool_options(Collocation; ...)`.

These examples can be used as templates when adding new tools that follow the
`AbstractOCPTool` interface.
