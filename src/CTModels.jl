"""
[`CTModels`](@ref) module.

Lists all the imported modules and packages:

$(IMPORTS)

List of all the exported names:

$(EXPORTS)
"""
module CTModels

# imports
using Base
using CTBase: CTBase
using DocStringExtensions
using Interpolations
using MLStyle
using Parameters # @with_kw: to have default values in struct
using MacroTools: striplines
using RecipesBase: plot, plot!, RecipesBase
using OrderedCollections: OrderedDict
using SolverCore
using ADNLPModels
using ExaModels
using KernelAbstractions
using NLPModels

# aliases

"""
Type alias for a dimension. This is used to define the dimension of the state space, 
the costate space, the control space, etc.

```@example
julia> const Dimension = Integer
```
"""
const Dimension = Int

"""
Type alias for a real number.

```@example
julia> const ctNumber = Real
```
"""
const ctNumber = Real

"""
Type alias for a time.

```@example
julia> const Time = ctNumber
```

See also: [`ctNumber`](@ref), [`Times`](@ref), [`TimesDisc`](@ref).
"""
const Time = ctNumber

"""
Type alias for a vector of real numbers.

```@example
julia> const ctVector = AbstractVector{<:ctNumber}
```

See also: [`ctNumber`](@ref).
"""
const ctVector = AbstractVector{<:ctNumber}

"""
Type alias for a vector of times.

```@example
julia> const Times = AbstractVector{<:Time}
```

See also: [`Time`](@ref), [`TimesDisc`](@ref).
"""
const Times = AbstractVector{<:Time}

"""
Type alias for a grid of times. This is used to define a discretization of time interval given to solvers.

```@example
julia> const TimesDisc = Union{Times, StepRangeLen}
```

See also: [`Time`](@ref), [`Times`](@ref).
"""
const TimesDisc = Union{Times,StepRangeLen}

"""
Type alias for a dictionary of constraints. This is used to store constraints before building the model.

```@example
julia> const TimesDisc = Union{Times, StepRangeLen}
```

See also: [`ConstraintsModel`](@ref), [`PreModel`](@ref) and [`Model`](@ref).
"""
const ConstraintsDictType = OrderedDict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}

#
include(joinpath(@__DIR__, "core", "default.jl"))

#
include(joinpath(@__DIR__, "core", "utils.jl"))
include(joinpath(@__DIR__, "core", "types.jl"))

# export / import
"""
$(TYPEDEF)

Abstract type for export/import functions, used to choose between JSON or JLD extensions.
"""
abstract type AbstractTag end

"""
$(TYPEDEF)

JLD tag for export/import functions.
"""
struct JLD2Tag <: AbstractTag end

"""
$(TYPEDEF)

JSON tag for export/import functions.
"""
struct JSON3Tag <: AbstractTag end

# -----------------------------
# to be extended
"""
$(TYPEDSIGNATURES)

Plot an optimal control solution.

This method requires the Plots extension to be loaded.
Throws `CTBase.ExtensionError` if Plots is not available.
"""
function RecipesBase.plot(sol::AbstractSolution, description::Symbol...; kwargs...)
    throw(CTBase.ExtensionError(:Plots))
end

"""
$(TYPEDSIGNATURES)

Export an optimal control solution to a JLD2 file.

This method requires the JLD2 extension to be loaded.
Throws `CTBase.ExtensionError` if JLD2 is not available.
"""
function export_ocp_solution(::JLD2Tag, ::AbstractSolution; filename::String)
    throw(CTBase.ExtensionError(:JLD2))
end

"""
$(TYPEDSIGNATURES)

Import an optimal control solution from a JLD2 file.

This method requires the JLD2 extension to be loaded.
Throws `CTBase.ExtensionError` if JLD2 is not available.
"""
function import_ocp_solution(::JLD2Tag, ::AbstractModel; filename::String)
    throw(CTBase.ExtensionError(:JLD2))
end

"""
$(TYPEDSIGNATURES)

Export an optimal control solution to a JSON file.

This method requires the JSON3 extension to be loaded.
Throws `CTBase.ExtensionError` if JSON3 is not available.
"""
function export_ocp_solution(::JSON3Tag, ::AbstractSolution; filename::String)
    throw(CTBase.ExtensionError(:JSON3))
end

"""
$(TYPEDSIGNATURES)

Import an optimal control solution from a JSON file.

This method requires the JSON3 extension to be loaded.
Throws `CTBase.ExtensionError` if JSON3 is not available.
"""
function import_ocp_solution(::JSON3Tag, ::AbstractModel; filename::String)
    throw(CTBase.ExtensionError(:JSON3))
end

"""
$(TYPEDSIGNATURES)

Export a solution in JLD or JSON formats. Redirect to one of the methods:

- [`export_ocp_solution(JLD2Tag(), sol, filename=filename)`](@ref export_ocp_solution(::CTModels.JLD2Tag, ::CTModels.Solution))
- [`export_ocp_solution(JSON3Tag(), sol, filename=filename)`](@ref export_ocp_solution(::CTModels.JSON3Tag, ::CTModels.Solution))

# Examples

```julia-repl
julia> using JSON3
julia> export_ocp_solution(sol; filename="solution", format=:JSON)
julia> using JLD2
julia> export_ocp_solution(sol; filename="solution", format=:JLD)  # JLD is the default
```
"""
function export_ocp_solution(
    sol::AbstractSolution;
    format::Symbol=__format(),
    filename::String=__filename_export_import(),
)
    if format == :JLD
        return export_ocp_solution(JLD2Tag(), sol; filename=filename)
    elseif format == :JSON
        return export_ocp_solution(JSON3Tag(), sol; filename=filename)
    else
        throw(
            CTBase.IncorrectArgument(
                "unknown format (should be :JLD or :JSON): " * string(format)
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Import a solution from a JLD or JSON file. Redirect to one of the methods:

- [`import_ocp_solution(JLD2Tag(), ocp, filename=filename)`](@ref import_ocp_solution(::CTModels.JLD2Tag, ::CTModels.Model))
- [`import_ocp_solution(JSON3Tag(), ocp, filename=filename)`](@ref import_ocp_solution(::CTModels.JSON3Tag, ::CTModels.Model))

# Examples

```julia-repl
julia> using JSON3
julia> sol = import_ocp_solution(ocp; filename="solution", format=:JSON)
julia> using JLD2
julia> sol = import_ocp_solution(ocp; filename="solution", format=:JLD)  # JLD is the default
```
"""
function import_ocp_solution(
    ocp::AbstractModel;
    format::Symbol=__format(),
    filename::String=__filename_export_import(),
)
    if format == :JLD
        return import_ocp_solution(JLD2Tag(), ocp; filename=filename)
    elseif format == :JSON
        return import_ocp_solution(JSON3Tag(), ocp; filename=filename)
    else
        throw(
            CTBase.IncorrectArgument(
                "unknown format (should be :JLD or :JSON): " * string(format)
            ),
        )
    end
end

#
#include("init.jl")
include(joinpath(@__DIR__, "ocp", "dual_model.jl"))
include(joinpath(@__DIR__, "ocp", "state.jl"))
include(joinpath(@__DIR__, "ocp", "control.jl"))
include(joinpath(@__DIR__, "ocp", "variable.jl"))
include(joinpath(@__DIR__, "ocp", "times.jl"))
include(joinpath(@__DIR__, "ocp", "dynamics.jl"))
include(joinpath(@__DIR__, "ocp", "objective.jl"))
include(joinpath(@__DIR__, "ocp", "constraints.jl"))
include(joinpath(@__DIR__, "ocp", "time_dependence.jl"))
include(joinpath(@__DIR__, "ocp", "definition.jl"))
include(joinpath(@__DIR__, "ocp", "print.jl"))
include(joinpath(@__DIR__, "ocp", "model.jl"))
include(joinpath(@__DIR__, "ocp", "solution.jl"))

# new from CTSolvers
"""
Type alias for [`AbstractModel`](@ref).

Provides compatibility with CTSolvers naming conventions.
"""
const AbstractOptimalControlProblem = CTModels.AbstractModel

"""
Type alias for [`AbstractSolution`](@ref).

Provides compatibility with CTSolvers naming conventions.
"""
const AbstractOptimalControlSolution = CTModels.AbstractSolution
include(joinpath(@__DIR__, "nlp", "options_schema.jl"))
include(joinpath(@__DIR__, "nlp", "problem_core.jl"))
include(joinpath(@__DIR__, "nlp", "nlp_backends.jl"))
include(joinpath(@__DIR__, "nlp", "discretized_ocp.jl"))
include(joinpath(@__DIR__, "nlp", "model_api.jl"))
include(joinpath(@__DIR__, "init", "initial_guess.jl"))

#
export plot, plot!

end