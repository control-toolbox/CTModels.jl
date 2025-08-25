using Revise
using Pkg
Pkg.activate(".")

using CTBase
using CTModels

include("../solution_example.jl")

ocp, sol, pre_ocp = solution_example()

ocp

pre_ocp
