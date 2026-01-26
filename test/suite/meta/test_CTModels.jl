struct CTMDummySol <: CTModels.AbstractSolution end
struct CTMDummyModelTop <: CTModels.AbstractModel end

function test_CTModels()
    # TODO: add tests for the CTModels.jl top-level module file.

    # ========================================================================
    # Unit tests – basic aliases and tags
    # ========================================================================

    Test.@testset "type aliases and tags" verbose=VERBOSE showtiming=SHOWTIMING begin
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
        Test.@test CTModels.AbstractOptimalControlProblem === CTModels.AbstractModel
        Test.@test CTModels.AbstractOptimalControlSolution === CTModels.AbstractSolution
    end

    # ========================================================================
    # Integration-style tests – export/import format guards
    # ========================================================================

    Test.@testset "export/import format guards" verbose=VERBOSE showtiming=SHOWTIMING begin
        sol = CTMDummySol()
        ocp = CTMDummyModelTop()

        # Unknown format should trigger an IncorrectArgument without touching extensions.
        Test.@test_throws CTBase.IncorrectArgument CTModels.export_ocp_solution(
            sol; format=:FOO
        )
        Test.@test_throws CTBase.IncorrectArgument CTModels.import_ocp_solution(
            ocp; format=:FOO
        )
    end
end
