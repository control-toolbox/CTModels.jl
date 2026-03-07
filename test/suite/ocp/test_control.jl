module TestOCPControl

import Test
import CTBase.Exceptions
import CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_control()
    Test.@testset "Control Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for control functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Control Handling
        # ====================================================================
        # ControlModel

        # some checks
        ocp = CTModels.PreModel()
        Test.@test isnothing(ocp.control)
        Test.@test !CTModels.OCP.__is_control_set(ocp)
        CTModels.control!(ocp, 1)
        Test.@test CTModels.OCP.__is_control_set(ocp)

        # control!
        ocp = CTModels.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 0)

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 1)
        Test.@test CTModels.dimension(ocp.control) == 1
        Test.@test CTModels.name(ocp.control) == "u"
        Test.@test CTModels.components(ocp.control) == ["u"]

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 1, "v")
        Test.@test CTModels.dimension(ocp.control) == 1
        Test.@test CTModels.name(ocp.control) == "v"

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 2)
        Test.@test CTModels.dimension(ocp.control) == 2
        Test.@test CTModels.name(ocp.control) == "u"
        Test.@test CTModels.components(ocp.control) == ["u₁", "u₂"]

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 2, :v)
        Test.@test CTModels.dimension(ocp.control) == 2
        Test.@test CTModels.name(ocp.control) == "v"
        Test.@test CTModels.components(ocp.control) == ["v₁", "v₂"]

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 2, "v", ["a", "b"])
        Test.@test CTModels.dimension(ocp.control) == 2
        Test.@test CTModels.name(ocp.control) == "v"
        Test.@test CTModels.components(ocp.control) == ["a", "b"]

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 2, "v", [:a, :b])
        Test.@test CTModels.dimension(ocp.control) == 2
        Test.@test CTModels.name(ocp.control) == "v"
        Test.@test CTModels.components(ocp.control) == ["a", "b"]

        # set twice
        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.control!(ocp, 1)

        # wrong number of components
        ocp = CTModels.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 2, "v", ["a"])

        # NEW: Internal name validation tests
        Test.@testset "control! - Internal name validation" begin
            # Empty name
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "")

            # Empty component name
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["", "v"]
            )

            # Name in components (multiple) - should fail
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["u", "v"]
            )

            # Name == component (single) - should PASS (default behavior)
            ocp = CTModels.PreModel()
            Test.@test_nowarn CTModels.control!(ocp, 1, "u", ["u"])

            # Duplicate components
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["v", "v"]
            )
        end

        # NEW: Inter-component conflicts tests
        Test.@testset "control! - Inter-component conflicts" begin
            # control.name vs state.name
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "x")  # Conflict!

            # control.name vs state.component
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["u", "v"])
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "u")

            # control.component vs state.name
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["x", "v"]
            )

            # control.name vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "t")

            # control.component vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["t", "v"]
            )

            # control.name vs variable.name
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "v")

            # control.component vs variable.name
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["v", "w"]
            )
        end

        # NEW: Type stability tests
        Test.@testset "control! - Type stability" begin
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 2, "u", ["u₁", "u₂"])
            Test.@inferred CTModels.name(ocp.control)
            Test.@inferred CTModels.components(ocp.control)
            Test.@inferred CTModels.dimension(ocp.control)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_control() = TestOCPControl.test_control()
