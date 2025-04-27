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

# to be extended
"""
$(TYPEDSIGNATURES)

Export a solution in JLD format.
"""
export_ocp_solution(::JLD2Tag, args...; kwargs...) = throw(CTBase.ExtensionError(:JLD2))

"""
$(TYPEDSIGNATURES)

Import a solution from a JLD file.
"""
import_ocp_solution(::JLD2Tag, args...; kwargs...) = throw(CTBase.ExtensionError(:JLD2))

"""
$(TYPEDSIGNATURES)

Export a solution in JSON format.
"""
export_ocp_solution(::JSON3Tag, args...; kwargs...) = throw(CTBase.ExtensionError(:JSON3))

"""
$(TYPEDSIGNATURES)

Import a solution from a JLD file.
"""
import_ocp_solution(::JSON3Tag, args...; kwargs...) = throw(CTBase.ExtensionError(:JSON3))

"""
$(TYPEDSIGNATURES)

Export a solution in JLD or JSON formats.

# Examples

```julia-repl
julia> CTModels.export_ocp_solution(sol; filename_prefix="solution", format=:JSON)
julia> CTModels.export_ocp_solution(sol; filename_prefix="solution", format=:JLD)
```
"""
function export_ocp_solution(args...; format=__format(), kwargs...)
    if format == :JLD
        return export_ocp_solution(JLD2Tag(), args...; kwargs...)
    elseif format == :JSON
        return export_ocp_solution(JSON3Tag(), args...; kwargs...)
    else
        throw(
            CTBase.IncorrectArgument(
                "Export_ocp_solution: unknown format (should be :JLD or :JSON): ", format
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Import a solution from a JLD or JSON file.

# Examples

```julia-repl
julia> sol = CTModels.import_ocp_solution(ocp; filename_prefix="solution", format=:JSON)
julia> sol = CTModels.import_ocp_solution(ocp; filename_prefix="solution", format=:JLD)
```
"""
function import_ocp_solution(args...; format=__format(), kwargs...)
    if format == :JLD
        return import_ocp_solution(JLD2Tag(), args...; kwargs...)
    elseif format == :JSON
        return import_ocp_solution(JSON3Tag(), args...; kwargs...)
    else
        throw(
            CTBase.IncorrectArgument(
                "Import_ocp_solution: unknown format (should be :JLD or :JSON): ", format
            ),
        )
    end
end

#
include("utils.jl")
include("types.jl")

# to be extended
"""
$(TYPEDSIGNATURES)

Plot a solution.
"""
function RecipesBase.plot(sol::AbstractSolution; kwargs...)
    throw(CTBase.ExtensionError(:Plots))
end

"""
$(TYPEDSIGNATURES)

Plot a solution on an existing plot.
"""
function RecipesBase.plot!(p::RecipesBase.AbstractPlot, sol::AbstractSolution; kwargs...)
    throw(CTBase.ExtensionError(:Plots))
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
include("print.jl")
include("model.jl")
include("solution.jl")

#
export plot, plot!

end
