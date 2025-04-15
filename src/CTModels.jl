"""
[`CTModels`](@ref) module.

Lists all the imported modules and packages:

$(IMPORTS)
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
import RecipesBase: plot, plot!, RecipesBase

# aliases
const Dimension = Int
const ctNumber = Real
const Time = ctNumber
const ctVector = AbstractVector{<:ctNumber}
const ConstraintsDictType = Dict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}
const Times = AbstractVector{<:Time}
const TimesDisc = Union{Times,StepRangeLen}

#
include("default.jl")

# export / import
abstract type AbstractTag end
struct JLD2Tag <: AbstractTag end
struct JSON3Tag <: AbstractTag end

# to be extended
export_ocp_solution(::JLD2Tag, args...; kwargs...) = throw(CTBase.ExtensionError(:JLD2))
import_ocp_solution(::JLD2Tag, args...; kwargs...) = throw(CTBase.ExtensionError(:JLD2))
export_ocp_solution(::JSON3Tag, args...; kwargs...) = throw(CTBase.ExtensionError(:JSON3))
import_ocp_solution(::JSON3Tag, args...; kwargs...) = throw(CTBase.ExtensionError(:JSON3))

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
function RecipesBase.plot(sol::AbstractSolution; kwargs...)
    throw(CTBase.ExtensionError(:Plots))
end
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
