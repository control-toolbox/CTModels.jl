module TestProblems
    using CTModels
    using SolverCore
    using ADNLPModels
    using ExaModels

    include("problems_definition.jl")
    include("solution_example.jl")
    include("rosenbrock.jl")     
    include("max1minusx2.jl")
    include("elec.jl")
    include("beam.jl")
    include("solution_example_dual.jl")

# From problems_definition.jl
export OptimizationProblem, DummyProblem

# From solution_example.jl
export solution_example

# From rosenbrock.jl
export Rosenbrock, rosenbrock_objective, rosenbrock_constraint

# From beam.jl
export Beam

# From solution_example_dual.jl
export solution_example_dual
end
