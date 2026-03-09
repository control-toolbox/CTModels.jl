module TestOCPVariable

using Test: Test
import CTBase.Exceptions
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_variable()
    Test.@testset "Variable Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for variable functionality
        end

        # ====================================================================
        # UNIT TESTS - Variable Model
        # ====================================================================

        # VariableModel

        # some checks
        ocp = CTModels.PreModel()
        Test.@test ocp.variable isa CTModels.EmptyVariableModel
        Test.@test !CTModels.OCP.__is_variable_set(ocp)
        CTModels.variable!(ocp, 1)
        Test.@test CTModels.OCP.__is_variable_set(ocp)

        # variable!
        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 0)
        Test.@test CTModels.dimension(ocp.variable) == 0
        Test.@test CTModels.name(ocp.variable) == ""
        Test.@test CTModels.components(ocp.variable) == String[]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 1)
        Test.@test CTModels.dimension(ocp.variable) == 1
        Test.@test CTModels.name(ocp.variable) == "v"
        Test.@test CTModels.components(ocp.variable) == ["v"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 1, "w")
        Test.@test CTModels.dimension(ocp.variable) == 1
        Test.@test CTModels.name(ocp.variable) == "w"
        Test.@test CTModels.components(ocp.variable) == ["w"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2)
        Test.@test CTModels.dimension(ocp.variable) == 2
        Test.@test CTModels.name(ocp.variable) == "v"
        Test.@test CTModels.components(ocp.variable) == ["v₁", "v₂"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2, :w)
        Test.@test CTModels.dimension(ocp.variable) == 2
        Test.@test CTModels.name(ocp.variable) == "w"
        Test.@test CTModels.components(ocp.variable) == ["w₁", "w₂"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2, "w", ["a", "b"])
        Test.@test CTModels.dimension(ocp.variable) == 2
        Test.@test CTModels.name(ocp.variable) == "w"
        Test.@test CTModels.components(ocp.variable) == ["a", "b"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2, "w", [:a, :b])
        Test.@test CTModels.dimension(ocp.variable) == 2
        Test.@test CTModels.name(ocp.variable) == "w"
        Test.@test CTModels.components(ocp.variable) == ["a", "b"]

        # set twice
        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError CTModels.variable!(ocp, 1)

        # wrong number of components
        ocp = CTModels.PreModel()
        Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(
            ocp, 2, "w", ["a"]
        )

        # NEW: Internal name validation tests (only for q > 0)
        Test.@testset "variable! - Internal name validation" begin
            # Empty name (q > 0)
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "")

            # Empty component name (q > 0)
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(
                ocp, 2, "v", ["", "w"]
            )

            # Name in components (multiple) - should fail
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(
                ocp, 2, "v", ["v", "w"]
            )

            # Name == component (single) - should PASS (default behavior)
            ocp = CTModels.PreModel()
            Test.@test_nowarn CTModels.variable!(ocp, 1, "v", ["v"])

            # Duplicate components (q > 0)
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(
                ocp, 2, "v", ["w", "w"]
            )

            # Empty variable (q = 0) should not trigger name validation
            ocp = CTModels.PreModel()
            Test.@test_nowarn CTModels.variable!(ocp, 0)  # Should work fine
        end

        # NEW: Inter-component conflicts tests (only for q > 0)
        Test.@testset "variable! - Inter-component conflicts" begin
            # variable.name vs state.name
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "x")  # Conflict!

            # variable.name vs state.component
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["v", "w"])
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "v")

            # variable.component vs state.name
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(
                ocp, 2, "v", ["x", "w"]
            )

            # variable.name vs control.name
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "u")

            # variable.component vs control.name
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(
                ocp, 2, "v", ["u", "w"]
            )

            # variable.name vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "t")

            # variable.component vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.variable!(
                ocp, 2, "v", ["t", "w"]
            )

            # Empty variable (q = 0) should not trigger inter-component conflicts
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            Test.@test_nowarn CTModels.variable!(ocp, 0)  # Should work fine even with "x" existing
        end

        # NEW: Type stability tests
        Test.@testset "variable! - Type stability" begin
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 2, "v", ["v₁", "v₂"])
            Test.@inferred CTModels.name(ocp.variable)
            Test.@inferred CTModels.components(ocp.variable)
            Test.@inferred CTModels.dimension(ocp.variable)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_variable() = TestOCPVariable.test_variable()
