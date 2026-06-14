module TestOCPState

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_state()
    Test.@testset "State Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - State Model
        # ====================================================================

        # some checks
        ocp = Building.PreModel()
        Test.@test isnothing(ocp.state)
        Test.@test !Building.__is_state_set(ocp)
        Building.state!(ocp, 1)
        Test.@test Building.__is_state_set(ocp)

        # state!
        ocp = Building.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument Building.state!(ocp, 0)

        ocp = Building.PreModel()
        Building.state!(ocp, 1)
        Test.@test Components.dimension(ocp.state) == 1
        Test.@test Components.name(ocp.state) == "x"
        Test.@test Components.components(ocp.state) == ["x"]

        ocp = Building.PreModel()
        Building.state!(ocp, 1, "y")
        Test.@test Components.dimension(ocp.state) == 1
        Test.@test Components.name(ocp.state) == "y"
        Test.@test Components.components(ocp.state) == ["y"]

        ocp = Building.PreModel()
        Building.state!(ocp, 2)
        Test.@test Components.dimension(ocp.state) == 2
        Test.@test Components.name(ocp.state) == "x"
        Test.@test Components.components(ocp.state) == ["x₁", "x₂"]

        ocp = Building.PreModel()
        Building.state!(ocp, 2, :y)
        Test.@test Components.dimension(ocp.state) == 2
        Test.@test Components.name(ocp.state) == "y"
        Test.@test Components.components(ocp.state) == ["y₁", "y₂"]

        ocp = Building.PreModel()
        Building.state!(ocp, 2, "y", ["u", "v"])
        Test.@test Components.dimension(ocp.state) == 2
        Test.@test Components.name(ocp.state) == "y"
        Test.@test Components.components(ocp.state) == ["u", "v"]

        ocp = Building.PreModel()
        Building.state!(ocp, 2, "y", [:u, :v])
        Test.@test Components.dimension(ocp.state) == 2
        Test.@test Components.name(ocp.state) == "y"
        Test.@test Components.components(ocp.state) == ["u", "v"]

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        # set twice
        ocp = Building.PreModel()
        Building.state!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError Building.state!(ocp, 1)

        # wrong number of components
        ocp = Building.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument Building.state!(ocp, 2, "y", ["u"])

        # NEW: Internal name validation tests
        Test.@testset "state! - Internal name validation" begin
            # Empty name
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(ocp, 1, "")

            # Empty component name
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(
                ocp, 2, "x", ["", "y"]
            )

            # Name in components (multiple components) - should fail
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(
                ocp, 2, "x", ["x", "y"]
            )

            # Name == component (single) - should PASS (default behavior)
            ocp = Building.PreModel()
            Test.@test_nowarn Building.state!(ocp, 1, "x", ["x"])

            # Duplicate components
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(
                ocp, 2, "x", ["y", "y"]
            )
        end

        # NEW: Inter-component conflicts tests
        Test.@testset "state! - Inter-component conflicts" begin
            # state.name vs control.name
            ocp = Building.PreModel()
            Building.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(ocp, 1, "u")

            # state.component vs control.name
            ocp = Building.PreModel()
            Building.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(
                ocp, 2, "x", ["u", "v"]
            )

            # state.name vs time_name
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(ocp, 1, "t")

            # state.component vs time_name
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(
                ocp, 2, "x", ["t", "y"]
            )

            # state.name vs variable.name
            ocp = Building.PreModel()
            Building.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(ocp, 1, "v")

            # state.component vs variable.name
            ocp = Building.PreModel()
            Building.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument Building.state!(
                ocp, 2, "x", ["v", "y"]
            )
        end

        # ====================================================================
        # QUALITY TESTS
        # ====================================================================

        Test.@testset "state! - Type stability" begin
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test_nowarn Test.@inferred Components.name(ocp.state)
            Test.@test_nowarn Test.@inferred Components.components(ocp.state)
            Test.@test_nowarn Test.@inferred Components.dimension(ocp.state)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_state() = TestOCPState.test_state()
