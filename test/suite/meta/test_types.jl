module TestTypes

using Test: Test
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_types()
    Test.@testset "CTModels.jl Type System Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for CTModels type system functionality
        end

        # ====================================================================
        # UNIT TESTS - OCP Model and Solution Core Types
        # ====================================================================

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

        # ====================================================================
        # UNIT TESTS - Initial Guess Core Types
        # ====================================================================

        Test.@testset "Initial guess core types" begin
            Test.@test isabstracttype(CTModels.AbstractInitialGuess)
            Test.@test CTModels.InitialGuess <: CTModels.AbstractInitialGuess

            Test.@test isabstracttype(CTModels.AbstractPreInitialGuess)
            Test.@test CTModels.PreInitialGuess <: CTModels.AbstractPreInitialGuess
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_types() = TestTypes.test_types()
