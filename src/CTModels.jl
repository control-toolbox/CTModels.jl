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
using PrettyTables # To print a table
using RecipesBase: plot, plot!, RecipesBase
using OrderedCollections: OrderedDict

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
Type alias for a dictionnary of constraints. This is used to store constraints before building the model.

```@example
julia> const TimesDisc = Union{Times, StepRangeLen}
```

See also: [`ConstraintsModel`](@ref), [`PreModel`](@ref) and [`Model`](@ref).
"""
const ConstraintsDictType = OrderedDict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}

#
include("default.jl")

#
include("utils.jl")
include("types.jl")

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
# to be extended: no docstrings
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
include("init.jl")
include("dual_model.jl")
include("state.jl")
include("control.jl")
include("variable.jl")
include("times.jl")
include("dynamics.jl")
include("objective.jl")
include("constraints.jl")
include("time_dependence.jl")
include("definition.jl")
include("print.jl")
include("model.jl")
include("solution.jl")

#
export plot, plot!

end
