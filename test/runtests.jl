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

function _testfile_path(name::Symbol)
    if name in (
        :times,
        :control,
        :state,
        :variable,
        :dynamics,
        :objective,
        :constraints,
        :ocp,
        :model,
        :solution,
    )
        return joinpath("ocp", "test_$(name).jl")
    elseif name in (
        :definition,
        :dual_model,
        :print,
        :time_dependence,
    )
        return joinpath("ocp", "test_$(name).jl")
    elseif name in (
        :utils,
        :default,
        :types,
        :ocp_components,
        :ocp_model_types,
        :ocp_solution_types,
        :nlp_types,
        :initial_guess_types,
    )
        return joinpath("core", "test_$(name).jl")
    elseif name in (
        :problem_core,
        :options_schema,
        :nlp_backends,
        :discretized_ocp,
        :model_api,
    )
        return joinpath("nlp", "test_$(name).jl")
    elseif name in (:initial_guess,)
        return joinpath("init", "test_$(name).jl")
    elseif name in (:ext_exceptions,)
        return joinpath("io", "test_$(name).jl")
    elseif name in (:plot,)
        return joinpath("plot", "test_$(name).jl")
    elseif name in (:export_import,)
        return joinpath("io", "test_$(name).jl")
    elseif name in (:aqua, :CTModels)
        return joinpath("meta", "test_$(name).jl")
    else
        return "test_$(name).jl"
    end
end

#
@testset verbose=VERBOSE showtiming=SHOWTIMING "CTModels tests" begin
    for name in (
        # extension behavior first (no external packages loaded yet)
        :ext_exceptions,

        # meta/quality tests
        :aqua,
        :CTModels,

        # OCP continuous-time layer
        :times,
        :time_dependence,
        :state,
        :control,
        :variable,
        :dynamics,
        :objective,
        :constraints,
        :definition,
        :model,
        :ocp,
        :dual_model,
        :print,

        # Core utilities and high-level solution layer
        :utils,
        :solution,

        # NLP / backends / discretized OCP
        :problem_core,
        :options_schema,
        :nlp_backends,
        :discretized_ocp,

        # Model API and initial guesses
        :model_api,
        :initial_guess,

        # Core type aggregators (can be extended with real tests later)
        :default,
        :types,
        :ocp_components,
        :ocp_model_types,
        :ocp_solution_types,
        :nlp_types,
        :initial_guess_types,
    )
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            println("testing: ", string(name))
            include(_testfile_path(name))
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
#             include(_testfile_path(name))
#             @eval $test_name()
#         end
#     end
# end
