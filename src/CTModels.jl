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

See also: [`ctNumber`](@ref), [`Times`](@ref CTModels.Times), [`TimesDisc`](@ref).
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

See also: [`Time`](@ref), [`Times`](@ref CTModels.Times).
"""
const TimesDisc = Union{Times,StepRangeLen}

"""
Type alias for a dictionary of constraints. This is used to store constraints before building the model.

```@example
julia> const TimesDisc = Union{Times, StepRangeLen}
```

See also: [`ConstraintsModel`](@ref), [`PreModel`](@ref) and [`Model`](@ref CTModels.Model).
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
function RecipesBase.plot(sol::AbstractSolution, description::Symbol...; kwargs...)
    throw(CTBase.ExtensionError(:Plots))
end

function export_ocp_solution(::JLD2Tag, ::AbstractSolution; filename::String)
    throw(CTBase.ExtensionError(:JLD2))
end

function import_ocp_solution(::JLD2Tag, ::AbstractModel; filename::String)
    throw(CTBase.ExtensionError(:JLD2))
end

function export_ocp_solution(::JSON3Tag, ::AbstractSolution; filename::String)
    throw(CTBase.ExtensionError(:JSON3))
end

function import_ocp_solution(::JSON3Tag, ::AbstractModel; filename::String)
    throw(CTBase.ExtensionError(:JSON3))
end

"""
    export_ocp_solution(sol; format=:JLD, filename="solution")

Export an optimal control solution to a file.

# Arguments
- `sol::AbstractSolution`: The solution to export.

# Keyword Arguments
- `format::Symbol=:JLD`: Export format, either `:JLD` or `:JSON`.
- `filename::String="solution"`: Base filename (extension added automatically).

# Notes
Requires loading the appropriate package (`JLD2` or `JSON3`) before use.

See also: [`import_ocp_solution`](@ref)
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
    import_ocp_solution(ocp; format=:JLD, filename="solution")

Import an optimal control solution from a file.

# Arguments
- `ocp::AbstractModel`: The model associated with the solution.

# Keyword Arguments
- `format::Symbol=:JLD`: Import format, either `:JLD` or `:JSON`.
- `filename::String="solution"`: Base filename (extension added automatically).

# Returns
- `Solution`: The imported solution.

# Notes
Requires loading the appropriate package (`JLD2` or `JSON3`) before use.

See also: [`export_ocp_solution`](@ref)
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

end
