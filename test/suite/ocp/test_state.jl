module TestOCPState

using Test: Test
import CTBase.Exceptions
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_state()
    Test.@testset "State Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for state functionality
        end

        # ====================================================================
        # UNIT TESTS - State Model
        # ====================================================================

        # StateModel

        # some checks
        ocp = CTModels.PreModel()
        Test.@test isnothing(ocp.state)
        Test.@test !CTModels.OCP.__is_state_set(ocp)
        CTModels.state!(ocp, 1)
        Test.@test CTModels.OCP.__is_state_set(ocp)

        # state!
        ocp = CTModels.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 0)

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 1)
        Test.@test CTModels.dimension(ocp.state) == 1
        Test.@test CTModels.name(ocp.state) == "x"
        Test.@test CTModels.components(ocp.state) == ["x"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 1, "y")
        Test.@test CTModels.dimension(ocp.state) == 1
        Test.@test CTModels.name(ocp.state) == "y"
        Test.@test CTModels.components(ocp.state) == ["y"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2)
        Test.@test CTModels.dimension(ocp.state) == 2
        Test.@test CTModels.name(ocp.state) == "x"
        Test.@test CTModels.components(ocp.state) == ["x₁", "x₂"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2, :y)
        Test.@test CTModels.dimension(ocp.state) == 2
        Test.@test CTModels.name(ocp.state) == "y"
        Test.@test CTModels.components(ocp.state) == ["y₁", "y₂"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2, "y", ["u", "v"])
        Test.@test CTModels.dimension(ocp.state) == 2
        Test.@test CTModels.name(ocp.state) == "y"
        Test.@test CTModels.components(ocp.state) == ["u", "v"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2, "y", [:u, :v])
        Test.@test CTModels.dimension(ocp.state) == 2
        Test.@test CTModels.name(ocp.state) == "y"
        Test.@test CTModels.components(ocp.state) == ["u", "v"]

        # set twice
        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.state!(ocp, 1)

        # wrong number of components
        ocp = CTModels.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 2, "y", ["u"])

        # NEW: Internal name validation tests
        Test.@testset "state! - Internal name validation" begin
            # Empty name
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 1, "")

            # Empty component name
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(
                ocp, 2, "x", ["", "y"]
            )

            # Name in components (multiple components) - should fail
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(
                ocp, 2, "x", ["x", "y"]
            )

            # Name == component (single) - should PASS (default behavior)
            ocp = CTModels.PreModel()
            Test.@test_nowarn CTModels.state!(ocp, 1, "x", ["x"])

            # Duplicate components
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(
                ocp, 2, "x", ["y", "y"]
            )
        end

        # NEW: Inter-component conflicts tests
        Test.@testset "state! - Inter-component conflicts" begin
            # state.name vs control.name
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 1, "u")  # Conflict!

            # state.component vs control.name
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(
                ocp, 2, "x", ["u", "v"]
            )

            # state.name vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 1, "t")

            # state.component vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(
                ocp, 2, "x", ["t", "y"]
            )

            # state.name vs variable.name
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 1, "v")

            # state.component vs variable.name
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.state!(
                ocp, 2, "x", ["v", "y"]
            )
        end

        # NEW: Type stability tests
        Test.@testset "state! - Type stability" begin
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@inferred CTModels.name(ocp.state)
            Test.@inferred CTModels.components(ocp.state)
            Test.@inferred CTModels.dimension(ocp.state)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_state() = TestOCPState.test_state()
