module TestTypes

import Test: Test
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Solutions: Solutions
import CTModels.Building: Building
import CTModels.Init: Init

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_types()
    Test.@testset "CTModels.jl Type System Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - OCP Model and Solution Core Types
        # ====================================================================

        Test.@testset "OCP model and solution core types" begin
            # Abstract/model hierarchy
            Test.@test isabstracttype(Models.AbstractModel)
            Test.@test Models.Model <: Models.AbstractModel
            Test.@test Building.PreModel <: Models.AbstractModel

            # Solution hierarchy
            Test.@test isabstracttype(Solutions.AbstractSolution)
            Test.@test Solutions.Solution <: Solutions.AbstractSolution

            # Time grid and dual/infos hierarchy
            Test.@test isabstracttype(Solutions.AbstractTimeGridModel)
            Test.@test Solutions.TimeGridModel <: Solutions.AbstractTimeGridModel

            Test.@test isabstracttype(Solutions.AbstractDualModel)
            Test.@test Solutions.DualModel <: Solutions.AbstractDualModel

            Test.@test isabstracttype(Solutions.AbstractSolverInfos)
            Test.@test Solutions.SolverInfos <: Solutions.AbstractSolverInfos
        end

        # ====================================================================
        # UNIT TESTS - Initial Guess Core Types
        # ====================================================================

        Test.@testset "Initial guess core types" begin
            Test.@test isabstracttype(Init.AbstractInitialGuess)
            Test.@test Init.InitialGuess <: Init.AbstractInitialGuess

            Test.@test isabstracttype(Init.AbstractPreInitialGuess)
            Test.@test Init.PreInitialGuess <: Init.AbstractPreInitialGuess
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_types() = TestTypes.test_types()
