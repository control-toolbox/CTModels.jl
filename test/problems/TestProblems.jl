module TestProblems
using CTModels

include("solution_example.jl")
include("beam.jl")
include("solution_example_dual.jl")
include("solution_example_free_final_time.jl")

# From solution_example.jl
export solution_example

# From beam.jl
export Beam

# From solution_example_dual.jl
export solution_example_dual

# From solution_example_free_final_time.jl
export solution_example_free_final_time
end
