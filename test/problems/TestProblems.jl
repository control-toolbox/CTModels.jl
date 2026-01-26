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

    export OptimizationProblem, DummyProblem
    export Rosenbrock, rosenbrock_objective, rosenbrock_constraint
end
