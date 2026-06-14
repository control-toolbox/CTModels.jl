module TestNameValidation

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_name_validation()
    Test.@testset "Name Validation Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Name Validation Helpers
        # ====================================================================

        Test.@testset "__collect_used_names" begin
            # Empty model
            ocp = Building.PreModel()
            names = Building.__collect_used_names(ocp)
            Test.@test isempty(names)

            # Only state
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            names = Building.__collect_used_names(ocp)
            Test.@test names == ["x", "x₁", "x₂"]

            # State and control
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Building.control!(ocp, 1, "u")
            names = Building.__collect_used_names(ocp)
            Test.@test names == ["x", "x₁", "x₂", "u"]

            # State, control, and time
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Building.control!(ocp, 1, "u")
            names = Building.__collect_used_names(ocp)
            Test.@test names == ["t", "x", "x₁", "x₂", "u"]

            # All components including variable
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Building.control!(ocp, 1, "u")
            Building.variable!(ocp, 1, "v")
            names = Building.__collect_used_names(ocp)
            Test.@test names == ["t", "x", "x₁", "x₂", "u", "v"]

            # Empty variable (should not be included)
            ocp = Building.PreModel()
            Building.state!(ocp, 1, "x")
            Building.variable!(ocp, 0)
            names = Building.__collect_used_names(ocp)
            Test.@test names == ["x"]
        end

        Test.@testset "__has_name_conflict" begin
            # Empty model - no conflicts
            ocp = Building.PreModel()
            Test.@test !Building.__has_name_conflict(ocp, "x")
            Test.@test !Building.__has_name_conflict(ocp, "y")

            # With state - conflicts with state names
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test Building.__has_name_conflict(ocp, "x")
            Test.@test Building.__has_name_conflict(ocp, "x₁")
            Test.@test Building.__has_name_conflict(ocp, "x₂")
            Test.@test !Building.__has_name_conflict(ocp, "y")

            # With exclude_component
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test !Building.__has_name_conflict(ocp, "x", :state)
            Test.@test !Building.__has_name_conflict(ocp, "x₁", :state)
            Test.@test !Building.__has_name_conflict(ocp, "x₂", :state)

            # Multiple components
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Building.control!(ocp, 1, "u")
            Building.time!(ocp, t0=0, tf=1, time_name="t")

            Test.@test Building.__has_name_conflict(ocp, "x")
            Test.@test Building.__has_name_conflict(ocp, "u")
            Test.@test Building.__has_name_conflict(ocp, "t")
            Test.@test Building.__has_name_conflict(ocp, "x₁")
            Test.@test !Building.__has_name_conflict(ocp, "y")

            # Test exclude_component with multiple components
            Test.@test !Building.__has_name_conflict(ocp, "x", :state)
            Test.@test Building.__has_name_conflict(ocp, "x", :control)
            Test.@test !Building.__has_name_conflict(ocp, "u", :control)
            Test.@test !Building.__has_name_conflict(ocp, "t", :time)
        end

        Test.@testset "__validate_name_uniqueness" begin
            # Empty name
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "", ["x"], :state
            )

            # Empty component
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "x", [""], :state
            )

            # Name in components (multiple components) - should fail
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "x", ["x", "y"], :state
            )

            # Name == component (single component) - should PASS
            ocp = Building.PreModel()
            Test.@test_nowarn Building.__validate_name_uniqueness(
                ocp, "x", ["x"], :state
            )

            # Duplicate components
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "x", ["y", "y"], :state
            )

            # Error: conflict with existing names
            ocp = Building.PreModel()
            Building.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "u", ["x₁"], :state
            )
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "x", ["u"], :state
            )

            # Complex scenario - all components set
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Building.control!(ocp, 1, "u")
            Building.variable!(ocp, 1, "v")

            # All these should throw
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "t", ["y₁"], :state
            )
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "x", ["y₁"], :control
            )
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "u", ["y₁"], :variable
            )
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "v", ["y₁"], :state
            )
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "x", ["x₁"], :control
            )
            Test.@test_throws Exceptions.IncorrectArgument Building.__validate_name_uniqueness(
                ocp, "x₁", ["y"], :control
            )

            # Valid case with exclude_component
            Test.@test_nowarn Building.__validate_name_uniqueness(
                ocp, "x", ["y₁", "y₂"], :state
            )
            Test.@test_nowarn Building.__validate_name_uniqueness(
                ocp, "u", ["y₁"], :control
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_name_validation() = TestNameValidation.test_name_validation()
