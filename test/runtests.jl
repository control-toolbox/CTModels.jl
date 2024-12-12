using Test
using Aqua
using CheckConcreteStructs
using CTBase
using CTModels

#
@testset verbose = true showtiming = true "CTModels tests" begin
    for name in (:times, :ocp, :control, :state, :variable, :dynamics, :objective, :constraints)
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            println("testing: ", string(name))
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end
