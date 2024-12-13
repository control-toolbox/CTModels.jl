module CTModels

# imports
import CTBase
using DocStringExtensions
using MLStyle
using Parameters # @with_kw: to have default values in struct
using MacroTools: striplines

# aliases
const Dimension = Int
const ctNumber = Real
const Time = ctNumber
const ctVector = AbstractVector{<:ctNumber}
const Variable = ctVector
const ConstraintsDictType = Dict{Symbol, Tuple{Symbol, Union{Function, OrdinalRange{<:Int}}, ctVector, ctVector}}
const Times = AbstractVector{<:Time}
const TimesDisc = Union{Times, StepRangeLen}

#
include("types.jl")
include("state.jl")
include("control.jl")
include("variable.jl")
include("times.jl")
include("dynamics.jl")
include("objective.jl")
include("constraints.jl")
include("definition.jl")
include("model.jl")

end
