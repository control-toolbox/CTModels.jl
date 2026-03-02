module TestNameValidation

using Test
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels

# Get test options if available, otherwise use defaults
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_name_validation()
    Test.@testset "Name Validation Helpers" verbose = VERBOSE showtiming = SHOWTIMING begin
        
        @testset "__collect_used_names" begin
            # Empty model
            ocp = CTModels.PreModel()
            names = CTModels.OCP.__collect_used_names(ocp)
            @test isempty(names)
            
            # Only state
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            names = CTModels.OCP.__collect_used_names(ocp)
            @test names == ["x", "x₁", "x₂"]
            
            # State and control
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            names = CTModels.OCP.__collect_used_names(ocp)
            @test names == ["x", "x₁", "x₂", "u"]
            
            # State, control, and time
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            names = CTModels.OCP.__collect_used_names(ocp)
            @test names == ["t", "x", "x₁", "x₂", "u"]
            
            # All components including variable
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            CTModels.variable!(ocp, 1, "v")
            names = CTModels.OCP.__collect_used_names(ocp)
            @test names == ["t", "x", "x₁", "x₂", "u", "v"]
            
            # Empty variable (should not be included)
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            CTModels.variable!(ocp, 0)  # Empty variable
            names = CTModels.OCP.__collect_used_names(ocp)
            @test names == ["x"]
        end
        
        @testset "__has_name_conflict" begin
            # Empty model - no conflicts
            ocp = CTModels.PreModel()
            @test !CTModels.OCP.__has_name_conflict(ocp, "x")
            @test !CTModels.OCP.__has_name_conflict(ocp, "y")
            
            # With state - conflicts with state names
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            @test CTModels.OCP.__has_name_conflict(ocp, "x")      # conflicts with state name
            @test CTModels.OCP.__has_name_conflict(ocp, "x₁")     # conflicts with state component
            @test CTModels.OCP.__has_name_conflict(ocp, "x₂")     # conflicts with state component
            @test !CTModels.OCP.__has_name_conflict(ocp, "y")     # no conflict
            
            # With exclude_component
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            @test !CTModels.OCP.__has_name_conflict(ocp, "x", :state)      # exclude state names
            @test !CTModels.OCP.__has_name_conflict(ocp, "x₁", :state)     # exclude state components
            @test !CTModels.OCP.__has_name_conflict(ocp, "x₂", :state)     # exclude state components
            
            # Multiple components
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            
            @test CTModels.OCP.__has_name_conflict(ocp, "x")      # conflicts with state
            @test CTModels.OCP.__has_name_conflict(ocp, "u")      # conflicts with control
            @test CTModels.OCP.__has_name_conflict(ocp, "t")      # conflicts with time
            @test CTModels.OCP.__has_name_conflict(ocp, "x₁")     # conflicts with state component
            @test !CTModels.OCP.__has_name_conflict(ocp, "y")     # no conflict
            
            # Test exclude_component with multiple components
            @test !CTModels.OCP.__has_name_conflict(ocp, "x", :state)      # exclude state
            @test CTModels.OCP.__has_name_conflict(ocp, "x", :control)     # still conflicts (x is state name, not excluded)
            @test !CTModels.OCP.__has_name_conflict(ocp, "u", :control)    # exclude control
            @test !CTModels.OCP.__has_name_conflict(ocp, "t", :time)       # exclude time
        end
        
        @testset "__validate_name_uniqueness" begin
            # Valid case - empty model
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "", ["x"], :state)
            
            # Empty component
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "x", [""], :state)
            
            # Name in components (multiple components) - should fail
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "x", ["x", "y"], :state)
            
            # Name == component (single component) - should PASS (default behavior)
            ocp = CTModels.PreModel()
            @test_nowarn CTModels.OCP.__validate_name_uniqueness(ocp, "x", ["x"], :state)
            
            # Duplicate components
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "x", ["y", "y"], :state)
            
            # Error: conflict with existing names
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "u", ["x₁"], :state)  # name conflicts
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "x", ["u"], :state)  # component conflicts
            
            # Complex scenario - all components set
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            CTModels.variable!(ocp, 1, "v")
            
            # All these should throw
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "t", ["y₁"], :state)  # conflicts with time
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "x", ["y₁"], :control)  # conflicts with state
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "u", ["y₁"], :variable)  # conflicts with control
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "v", ["y₁"], :state)  # conflicts with variable
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "x", ["x₁"], :control)  # conflicts with state component
            @test_throws Exceptions.IncorrectArgument CTModels.OCP.__validate_name_uniqueness(ocp, "x₁", ["y"], :control)  # conflicts with state component
            
            # Valid case with exclude_component
            @test_nowarn CTModels.OCP.__validate_name_uniqueness(ocp, "x", ["y₁", "y₂"], :state)  # exclude state, no conflicts
            @test_nowarn CTModels.OCP.__validate_name_uniqueness(ocp, "u", ["y₁"], :control)  # exclude control, no conflicts
        end
    end
end

end # module

test_name_validation() = TestNameValidation.test_name_validation()
