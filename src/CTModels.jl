module CTModels

# imports
import CTBase
using DocStringExtensions
using MLStyle
using Parameters # @with_kw: to have default values in struct
using StaticArrays

# aliases
const Dimension = Int
const ctNumber = Real
const Time = ctNumber
const Variable = Union{ctNumber, AbstractVector{<:ctNumber}}

#
include("types.jl")

#
include("state.jl")
include("control.jl")
include("variable.jl")
include("times.jl")

#

end
