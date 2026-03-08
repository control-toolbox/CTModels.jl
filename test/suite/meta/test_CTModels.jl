module TestCTModelsTop

import Test
import CTBase.Exceptions
import CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

struct CTMDummySol <: CTModels.AbstractSolution end
struct CTMDummyModelTop <: CTModels.AbstractModel end

function test_CTModels()
    Test.@testset "CTModels.jl Top-Level Module Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for CTModels top-level functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Basic Aliases and Tags
        # ====================================================================

        Test.@testset "type aliases and tags" begin
            Test.@test CTModels.Dimension == Int
            Test.@test CTModels.ctNumber == Real
            Test.@test CTModels.Time === CTModels.ctNumber

            # For parametric aliases, test mutual <: rather than strict identity
            Test.@test CTModels.ctVector <: AbstractVector{<:CTModels.ctNumber}
            Test.@test AbstractVector{<:CTModels.ctNumber} <: CTModels.ctVector

            Test.@test CTModels.Times <: AbstractVector{<:CTModels.Time}
            Test.@test AbstractVector{<:CTModels.Time} <: CTModels.Times

            Test.@test CTModels.JLD2Tag <: CTModels.AbstractTag
            Test.@test CTModels.JSON3Tag <: CTModels.AbstractTag

            # Aliases towards CTSolvers usage
            Test.@test CTModels.AbstractModel === CTModels.AbstractModel
            Test.@test CTModels.AbstractSolution === CTModels.AbstractSolution
        end

        # ====================================================================
        # INTEGRATION TESTS - Export/Import Format Guards
        # ====================================================================

        Test.@testset "export/import format guards" begin
            sol = CTMDummySol()
            ocp = CTMDummyModelTop()

            # Unknown format should trigger an IncorrectArgument without touching extensions.
            Test.@test_throws Exceptions.IncorrectArgument CTModels.export_ocp_solution(
                sol; format=:FOO
            )
            Test.@test_throws Exceptions.IncorrectArgument CTModels.import_ocp_solution(
                ocp; format=:FOO
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_CTModels() = TestCTModelsTop.test_CTModels()
