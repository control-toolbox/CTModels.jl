module TestTypes

using Test
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_types()
    Test.@testset "CTModels.jl type system" begin

        Test.@testset "OCP model and solution core types" begin
            # Abstract/model hierarchy
            Test.@test isabstracttype(CTModels.AbstractModel)
            Test.@test CTModels.Model <: CTModels.AbstractModel
            Test.@test CTModels.PreModel <: CTModels.AbstractModel

            # Solution hierarchy
            Test.@test isabstracttype(CTModels.AbstractSolution)
            Test.@test CTModels.Solution <: CTModels.AbstractSolution

            # Time grid and dual/infos hierarchy
            Test.@test isabstracttype(CTModels.AbstractTimeGridModel)
            Test.@test CTModels.TimeGridModel <: CTModels.AbstractTimeGridModel

            Test.@test isabstracttype(CTModels.AbstractDualModel)
            Test.@test CTModels.DualModel <: CTModels.AbstractDualModel

            Test.@test isabstracttype(CTModels.AbstractSolverInfos)
            Test.@test CTModels.SolverInfos <: CTModels.AbstractSolverInfos
        end

        Test.@testset "Initial guess core types" begin
            Test.@test isabstracttype(CTModels.AbstractOptimalControlInitialGuess)
            Test.@test CTModels.OptimalControlInitialGuess <:
                       CTModels.AbstractOptimalControlInitialGuess

            Test.@test isabstracttype(CTModels.AbstractOptimalControlPreInit)
            Test.@test CTModels.OptimalControlPreInit <: CTModels.AbstractOptimalControlPreInit
        end
    end
end

end # module

test_types() = TestTypes.test_types()
