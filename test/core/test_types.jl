function test_types()
    # TODO: add tests for src/core/types.jl (type includes and basic consistency).

    Test.@testset "OCP model and solution core types" verbose=VERBOSE showtiming=SHOWTIMING begin
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

    Test.@testset "Initial guess core types" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test isabstracttype(CTModels.AbstractOptimalControlInitialGuess)
        Test.@test CTModels.OptimalControlInitialGuess <:
            CTModels.AbstractOptimalControlInitialGuess

        Test.@test isabstracttype(CTModels.AbstractOptimalControlPreInit)
        Test.@test CTModels.OptimalControlPreInit <: CTModels.AbstractOptimalControlPreInit
    end
end
