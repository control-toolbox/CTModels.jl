module TestProblems
    using CTModels

    include("solution_example.jl")
    include("beam.jl")
    include("solution_example_dual.jl")

    # From solution_example.jl
    export solution_example

    # From beam.jl
    export Beam

    # From solution_example_dual.jl
    export solution_example_dual
end
