using Test
using Aqua
using CTBase
using CTModels

#
include("solution_example.jl")

#
@testset verbose = true showtiming = true "CTModels tests" begin
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
        :init,
        :utils,
        :solution,
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

using CTDirect
using NLPModelsIpopt
using ADNLPModels
import CTParser: CTParser, @def

#
include("solution_example_path_constraints.jl")

@testset verbose = true showtiming = true "CTModels tests" begin
    for name in (:plot, :export_import)
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            println("testing: ", string(name))
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end
