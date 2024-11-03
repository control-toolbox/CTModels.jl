module CTModels

# imports
import CTBase
using DocStringExtensions
using Parameters # @with_kw: to have default values in struct


# aliases
const Dimension = Int

#
include("types.jl")
include("control.jl")
include("state.jl")

#

end
