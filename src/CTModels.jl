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

# to be extended
export_ocp_solution(args...; kwargs...) = throw(CTBase.ExtensionError(:JLD2, :JSON3))
import_ocp_solution(args...; kwargs...) = throw(CTBase.ExtensionError(:JLD2, :JSON3))

#
include("default.jl")
include("utils.jl")
include("types.jl")
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

end
