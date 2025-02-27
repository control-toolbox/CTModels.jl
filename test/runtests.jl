using Test
using Aqua
using CTBase
using CTModels
using Plots

#
@testset verbose = true showtiming = true "CTModels tests" begin
    for name in (
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
        :plot,
        :init,       
    )
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            println("testing: ", string(name))
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end
