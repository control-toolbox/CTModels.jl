module TestOCPVariable

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_variable()
    Test.@testset "Variable Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Variable Model
        # ====================================================================

        # some checks
        ocp = Building.PreModel()
        Test.@test ocp.variable isa Components.EmptyVariableModel
        Test.@test Building.__is_variable_empty(ocp)
        Building.variable!(ocp, 1)
        Test.@test !Building.__is_variable_empty(ocp)

        # variable!
        ocp = Building.PreModel()
        Building.variable!(ocp, 0)
        Test.@test Components.dimension(ocp.variable) == 0
        Test.@test Components.name(ocp.variable) == ""
        Test.@test Components.components(ocp.variable) == String[]

        ocp = Building.PreModel()
        Building.variable!(ocp, 1)
        Test.@test Components.dimension(ocp.variable) == 1
        Test.@test Components.name(ocp.variable) == "v"
        Test.@test Components.components(ocp.variable) == ["v"]

        ocp = Building.PreModel()
        Building.variable!(ocp, 1, "w")
        Test.@test Components.dimension(ocp.variable) == 1
        Test.@test Components.name(ocp.variable) == "w"
        Test.@test Components.components(ocp.variable) == ["w"]

        ocp = Building.PreModel()
        Building.variable!(ocp, 2)
        Test.@test Components.dimension(ocp.variable) == 2
        Test.@test Components.name(ocp.variable) == "v"
        Test.@test Components.components(ocp.variable) == ["v₁", "v₂"]

        ocp = Building.PreModel()
        Building.variable!(ocp, 2, :w)
        Test.@test Components.dimension(ocp.variable) == 2
        Test.@test Components.name(ocp.variable) == "w"
        Test.@test Components.components(ocp.variable) == ["w₁", "w₂"]

        ocp = Building.PreModel()
        Building.variable!(ocp, 2, "w", ["a", "b"])
        Test.@test Components.dimension(ocp.variable) == 2
        Test.@test Components.name(ocp.variable) == "w"
        Test.@test Components.components(ocp.variable) == ["a", "b"]

        ocp = Building.PreModel()
        Building.variable!(ocp, 2, "w", [:a, :b])
        Test.@test Components.dimension(ocp.variable) == 2
        Test.@test Components.name(ocp.variable) == "w"
        Test.@test Components.components(ocp.variable) == ["a", "b"]

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        # set twice
        ocp = Building.PreModel()
        Building.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError Building.variable!(ocp, 1)

        # wrong number of components
        ocp = Building.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument Building.variable!(
            ocp, 2, "w", ["a"]
        )

        # NEW: Internal name validation tests (only for q > 0)
        Test.@testset "variable! - Internal name validation" begin
            # Empty name (q > 0)
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(ocp, 1, "")

            # Empty component name (q > 0)
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(
                ocp, 2, "v", ["", "w"]
            )

            # Name in components (multiple) - should fail
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(
                ocp, 2, "v", ["v", "w"]
            )

            # Name == component (single) - should PASS (default behavior)
            ocp = Building.PreModel()
            Test.@test_nowarn Building.variable!(ocp, 1, "v", ["v"])

            # Duplicate components (q > 0)
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(
                ocp, 2, "v", ["w", "w"]
            )

            # Empty variable (q = 0) should not trigger name validation
            ocp = Building.PreModel()
            Test.@test_nowarn Building.variable!(ocp, 0)
        end

        # NEW: Inter-component conflicts tests (only for q > 0)
        Test.@testset "variable! - Inter-component conflicts" begin
            # variable.name vs state.name
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(ocp, 1, "x")

            # variable.name vs state.component
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["v", "w"])
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(ocp, 1, "v")

            # variable.component vs state.name
            ocp = Building.PreModel()
            Building.state!(ocp, 1, "x")
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(
                ocp, 2, "v", ["x", "w"]
            )

            # variable.name vs control.name
            ocp = Building.PreModel()
            Building.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(ocp, 1, "u")

            # variable.component vs control.name
            ocp = Building.PreModel()
            Building.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(
                ocp, 2, "v", ["u", "w"]
            )

            # variable.name vs time_name
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(ocp, 1, "t")

            # variable.component vs time_name
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(
                ocp, 2, "v", ["t", "w"]
            )

            # Empty variable (q = 0) should not trigger inter-component conflicts
            ocp = Building.PreModel()
            Building.state!(ocp, 1, "x")
            Test.@test_nowarn Building.variable!(ocp, 0)
        end

        # ====================================================================
        # QUALITY TESTS
        # ====================================================================

        Test.@testset "variable! - Type stability" begin
            ocp = Building.PreModel()
            Building.variable!(ocp, 2, "v", ["v₁", "v₂"])
            Test.@test_nowarn Test.@inferred Components.name(ocp.variable)
            Test.@test_nowarn Test.@inferred Components.components(ocp.variable)
            Test.@test_nowarn Test.@inferred Components.dimension(ocp.variable)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_variable() = TestOCPVariable.test_variable()
