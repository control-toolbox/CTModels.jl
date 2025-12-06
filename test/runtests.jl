using Test
using Aqua
using CTBase
using CTModels
using ADNLPModels
using SolverCore
using NLPModels
using ExaModels

# Tests parameters
const VERBOSE = true
const SHOWTIMING = true

#
include(joinpath("problems", "solution_example.jl"))
include(joinpath("problems", "problems_definition.jl"))
include(joinpath("problems", "rosenbrock.jl"))
include(joinpath("problems", "max1minusx2.jl"))
include(joinpath("problems", "elec.jl"))
include(joinpath("problems", "beam.jl"))

#
@testset verbose=VERBOSE showtiming=SHOWTIMING "CTModels tests" begin
    for name in (
        :ext_exceptions,
        :aqua,
        :times,
        :control,
        :state,
        :variable,
        :dynamics,
        :objective,
        :constraints,
        :model,
        :ocp,
        :utils,
        :solution,
        :problem_core,
        :options_schema,
        :nlp_backends,
        :discretized_ocp,
        :model_api,
        :initial_guess,
    )
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            println("testing: ", string(name))
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end

# test with CTDirect and CTParser: must be commented if new version of CTModels, that is breaking

# using CTDirect
# using NLPModelsIpopt
# using ADNLPModels
# import CTParser: CTParser, @def

# #
# include(joinpath("problems", "solution_example_path_constraints.jl"))

# @testset verbose=VERBOSE showtiming=SHOWTIMING "CTModels tests" begin
#     for name in (
#         :plot,
#         # :export_import,
#     )
#         @testset "$(name)" begin
#             test_name = Symbol(:test_, name)
#             println("testing: ", string(name))
#             include("$(test_name).jl")
#             @eval $test_name()
#         end
#     end
# end
