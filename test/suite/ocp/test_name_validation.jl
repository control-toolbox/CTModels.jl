module TestNameValidation

import Test
import CTBase.Exceptions
import CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_name_validation()
    Test.@testset "Name Validation Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for name validation functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Name Validation Helpers
        # ====================================================================
        Test.@testset "__collect_used_names" begin
            # Empty model
            ocp = CTModels.PreModel()
            names = CTModels.OCP.__collect_used_names(ocp)
            Test.@test isempty(names)

            # Only state
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            names = CTModels.OCP.__collect_used_names(ocp)
            Test.@test names == ["x", "x₁", "x₂"]

            # State and control
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            names = CTModels.OCP.__collect_used_names(ocp)
            Test.@test names == ["x", "x₁", "x₂", "u"]

            # State, control, and time
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            names = CTModels.OCP.__collect_used_names(ocp)
            Test.@test names == ["t", "x", "x₁", "x₂", "u"]

            # All components including variable
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            CTModels.variable!(ocp, 1, "v")
            names = CTModels.OCP.__collect_used_names(ocp)
            Test.@test names == ["t", "x", "x₁", "x₂", "u", "v"]

            # Empty variable (should not be included)
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            CTModels.variable!(ocp, 0)  # Empty variable
            names = CTModels.OCP.__collect_used_names(ocp)
            Test.@test names == ["x"]
        end

        Test.@testset "__has_name_conflict" begin
            # Empty model - no conflicts
            ocp = CTModels.PreModel()
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "x")
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "y")

            # With state - conflicts with state names
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test CTModels.OCP.__has_name_conflict(ocp, "x")      # conflicts with state name
            Test.@test CTModels.OCP.__has_name_conflict(ocp, "x₁")     # conflicts with state component
            Test.@test CTModels.OCP.__has_name_conflict(ocp, "x₂")     # conflicts with state component
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "y")     # no conflict

            # With exclude_component
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "x", :state)      # exclude state names
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "x₁", :state)     # exclude state components
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "x₂", :state)     # exclude state components

            # Multiple components
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")

            Test.@test CTModels.OCP.__has_name_conflict(ocp, "x")      # conflicts with state
            Test.@test CTModels.OCP.__has_name_conflict(ocp, "u")      # conflicts with control
            Test.@test CTModels.OCP.__has_name_conflict(ocp, "t")      # conflicts with time
            Test.@test CTModels.OCP.__has_name_conflict(ocp, "x₁")     # conflicts with state component
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "y")     # no conflict

            # Test exclude_component with multiple components
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "x", :state)      # exclude state
            Test.@test CTModels.OCP.__has_name_conflict(ocp, "x", :control)     # still conflicts (x is state name, not excluded)
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "u", :control)    # exclude control
            Test.@test !CTModels.OCP.__has_name_conflict(ocp, "t", :time)       # exclude time
        end

        Test.@testset "__validate_name_uniqueness" begin
            # Valid case - empty model
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "", ["x"], :state
            )

            # Empty component
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "x", [""], :state
            )

            # Name in components (multiple components) - should fail
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "x", ["x", "y"], :state
            )

            # Name == component (single component) - should PASS (default behavior)
            ocp = CTModels.PreModel()
            Test.@test_nowarn CTModels.OCP.__validate_name_uniqueness(ocp, "x", ["x"], :state)

            # Duplicate components
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "x", ["y", "y"], :state
            )

            # Error: conflict with existing names
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "u", ["x₁"], :state
            )  # name conflicts
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "x", ["u"], :state
            )  # component conflicts

            # Complex scenario - all components set
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            CTModels.variable!(ocp, 1, "v")

            # All these should throw
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "t", ["y₁"], :state
            )  # conflicts with time
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "x", ["y₁"], :control
            )  # conflicts with state
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "u", ["y₁"], :variable
            )  # conflicts with control
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "v", ["y₁"], :state
            )  # conflicts with variable
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "x", ["x₁"], :control
            )  # conflicts with state component
            Test.@test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(
                ocp, "x₁", ["y"], :control
            )  # conflicts with state component

            # Valid case with exclude_component
            Test.@test_nowarn CTModels.OCP.__validate_name_uniqueness(
                ocp, "x", ["y₁", "y₂"], :state
            )  # exclude state, no conflicts
            Test.@test_nowarn CTModels.OCP.__validate_name_uniqueness(ocp, "u", ["y₁"], :control)  # exclude control, no conflicts
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_name_validation() = TestNameValidation.test_name_validation()
