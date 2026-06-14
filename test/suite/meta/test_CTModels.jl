module TestCTModelsTop

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Solutions: Solutions
import CTModels.Serialization: Serialization

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

struct CTMDummySol <: Solutions.AbstractSolution end
struct CTMDummyModelTop <: Models.AbstractModel end

function test_CTModels()
    Test.@testset "CTModels.jl Top-Level Module Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Basic Aliases and Tags
        # ====================================================================

        Test.@testset "type aliases and tags" begin
            Test.@test Components.Dimension == Int
            Test.@test Components.ctNumber == Real
            Test.@test Components.Time === Components.ctNumber

            # For parametric aliases, test mutual <: rather than strict identity
            Test.@test Components.ctVector <: AbstractVector{<:Components.ctNumber}
            Test.@test AbstractVector{<:Components.ctNumber} <: Components.ctVector

            Test.@test Components.Times <: AbstractVector{<:Components.Time}
            Test.@test AbstractVector{<:Components.Time} <: Components.Times

            Test.@test Serialization.JLD2Tag <: Serialization.AbstractTag
            Test.@test Serialization.JSON3Tag <: Serialization.AbstractTag

            # Aliases towards CTSolvers usage
            Test.@test Models.AbstractModel === Models.AbstractModel
            Test.@test Solutions.AbstractSolution === Solutions.AbstractSolution
        end

        # ====================================================================
        # INTEGRATION TESTS - Export/Import Format Guards
        # ====================================================================

        Test.@testset "export/import format guards" begin
            sol = CTMDummySol()
            ocp = CTMDummyModelTop()

            # Unknown format should trigger an IncorrectArgument without touching extensions.
            Test.@test_throws Exceptions.IncorrectArgument Serialization.export_ocp_solution(
                sol; format=:FOO
            )
            Test.@test_throws Exceptions.IncorrectArgument Serialization.import_ocp_solution(
                ocp; format=:FOO
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_CTModels() = TestCTModelsTop.test_CTModels()
