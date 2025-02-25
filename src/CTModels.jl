module CTModels

# imports
using CTBase: CTBase
using DocStringExtensions
using MLStyle
using Parameters # @with_kw: to have default values in struct
using MacroTools: striplines

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
include("types.jl")
include("dual_model.jl")
include("state.jl")
include("control.jl")
include("variable.jl")
include("times.jl")
include("dynamics.jl")
include("objective.jl")
include("constraints.jl")
include("definition.jl")
include("model.jl")
include("solution.jl")

end
