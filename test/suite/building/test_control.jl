module TestOCPControl

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_control()
    Test.@testset "Control Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Control Handling
        # ====================================================================
        # ControlModel

        # some checks
        ocp = Building.PreModel()
        Test.@test ocp.control isa Components.EmptyControlModel
        Test.@test Building.__is_control_empty(ocp)
        Building.control!(ocp, 1)
        Test.@test !Building.__is_control_empty(ocp)

        # control!
        ocp = Building.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp, 0)

        ocp = Building.PreModel()
        Building.control!(ocp, 1)
        Test.@test Components.dimension(ocp.control) == 1
        Test.@test Components.name(ocp.control) == "u"
        Test.@test Components.components(ocp.control) == ["u"]

        ocp = Building.PreModel()
        Building.control!(ocp, 1, "v")
        Test.@test Components.dimension(ocp.control) == 1
        Test.@test Components.name(ocp.control) == "v"

        ocp = Building.PreModel()
        Building.control!(ocp, 2)
        Test.@test Components.dimension(ocp.control) == 2
        Test.@test Components.name(ocp.control) == "u"
        Test.@test Components.components(ocp.control) == ["u₁", "u₂"]

        ocp = Building.PreModel()
        Building.control!(ocp, 2, :v)
        Test.@test Components.dimension(ocp.control) == 2
        Test.@test Components.name(ocp.control) == "v"
        Test.@test Components.components(ocp.control) == ["v₁", "v₂"]

        ocp = Building.PreModel()
        Building.control!(ocp, 2, "v", ["a", "b"])
        Test.@test Components.dimension(ocp.control) == 2
        Test.@test Components.name(ocp.control) == "v"
        Test.@test Components.components(ocp.control) == ["a", "b"]

        ocp = Building.PreModel()
        Building.control!(ocp, 2, "v", [:a, :b])
        Test.@test Components.dimension(ocp.control) == 2
        Test.@test Components.name(ocp.control) == "v"
        Test.@test Components.components(ocp.control) == ["a", "b"]

        # set twice
        ocp = Building.PreModel()
        Building.control!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError Building.control!(ocp, 1)

        # wrong number of components
        ocp = Building.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp, 2, "v", ["a"])

        # NEW: Internal name validation tests
        Test.@testset "control! - Internal name validation" begin
            # Empty name
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp, 1, "")

            # Empty component name
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(
                ocp, 2, "u", ["", "v"]
            )

            # Name in components (multiple) - should fail
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(
                ocp, 2, "u", ["u", "v"]
            )

            # Name == component (single) - should PASS (default behavior)
            ocp = Building.PreModel()
            Test.@test_nowarn Building.control!(ocp, 1, "u", ["u"])

            # Duplicate components
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(
                ocp, 2, "u", ["v", "v"]
            )
        end

        # NEW: Inter-component conflicts tests
        Test.@testset "control! - Inter-component conflicts" begin
            # control.name vs state.name
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp, 1, "x")  # Conflict!

            # control.name vs state.component
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["u", "v"])
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp, 1, "u")

            # control.component vs state.name
            ocp = Building.PreModel()
            Building.state!(ocp, 1, "x")
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(
                ocp, 2, "u", ["x", "v"]
            )

            # control.name vs time_name
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp, 1, "t")

            # control.component vs time_name
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(
                ocp, 2, "u", ["t", "v"]
            )

            # control.name vs variable.name
            ocp = Building.PreModel()
            Building.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp, 1, "v")

            # control.component vs variable.name
            ocp = Building.PreModel()
            Building.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(
                ocp, 2, "u", ["v", "w"]
            )
        end

        # NEW: Type stability tests
        Test.@testset "control! - Type stability" begin
            ocp = Building.PreModel()
            Building.control!(ocp, 2, "u", ["u₁", "u₂"])
            Test.@test_nowarn Test.@inferred Components.name(ocp.control)
            Test.@test_nowarn Test.@inferred Components.components(ocp.control)
            Test.@test_nowarn Test.@inferred Components.dimension(ocp.control)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_control() = TestOCPControl.test_control()
