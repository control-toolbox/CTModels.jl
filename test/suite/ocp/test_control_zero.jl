module TestControlZero

import Test
import CTBase.Exceptions
import CTModels.OCP
import CTModels.Init
import Plots

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_control_zero()
    Test.@testset "Control Zero Dimension Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - EmptyControlModel
        # ====================================================================
        
        Test.@testset "EmptyControlModel - Type and Construction" begin
            ecm = OCP.EmptyControlModel()
            Test.@test ecm isa OCP.EmptyControlModel
            Test.@test ecm isa OCP.AbstractControlModel
        end
        
        Test.@testset "EmptyControlModel - Getters" begin
            ecm = OCP.EmptyControlModel()
            Test.@test OCP.name(ecm) == ""
            Test.@test OCP.components(ecm) == String[]
            Test.@test OCP.dimension(ecm) == 0
        end
        
        # ====================================================================
        # UNIT TESTS - PreModel Default
        # ====================================================================
        
        Test.@testset "PreModel - Default Control" begin
            pre = OCP.PreModel()
            Test.@test pre.control isa OCP.EmptyControlModel
            Test.@test OCP.dimension(pre.control) == 0
        end
        
        # ====================================================================
        # UNIT TESTS - Helper Functions
        # ====================================================================
        
        Test.@testset "Helper Functions - __is_control_empty" begin
            # EmptyControlModel should be empty
            ecm = OCP.EmptyControlModel()
            Test.@test OCP.__is_control_empty(ecm) == true
            
            # ControlModel should not be empty
            cm = OCP.ControlModel("u", ["u₁"])
            Test.@test OCP.__is_control_empty(cm) == false
        end
        
        Test.@testset "Helper Functions - __is_control_set" begin
            # PreModel with EmptyControlModel should return false
            pre = OCP.PreModel()
            Test.@test OCP.__is_control_set(pre) == false
            
            # PreModel after control! should return true
            pre2 = OCP.PreModel()
            OCP.control!(pre2, 1)
            Test.@test OCP.__is_control_set(pre2) == true
        end
        
        # ====================================================================
        # UNIT TESTS - Phase 2: Relaxed Preconditions
        # ====================================================================
        
        Test.@testset "dynamics! without control" begin
            # Should not throw error when control is not set
            pre = OCP.PreModel()
            OCP.state!(pre, 2)
            OCP.time!(pre, t0=0, tf=1)
            
            # This should work without calling control!
            OCP.dynamics!(pre, (x, u) -> [x[2], -x[1]])
            Test.@test OCP.__is_dynamics_set(pre)
        end
        
        Test.@testset "objective! without control" begin
            # Should not throw error when control is not set
            pre = OCP.PreModel()
            OCP.state!(pre, 2)
            OCP.time!(pre, t0=0, tf=1)
            
            # This should work without calling control!
            OCP.objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
            Test.@test OCP.__is_objective_set(pre)
        end
        
        Test.@testset "constraint! - boundary type without control" begin
            # Boundary constraints should work without control
            pre = OCP.PreModel()
            OCP.state!(pre, 2)
            OCP.time!(pre, t0=0, tf=1)
            
            # This should work without calling control!
            OCP.constraint!(pre, :boundary, f=(x0, xf) -> x0[1], lb=0, ub=0)
            Test.@test length(pre.constraints) == 1
        end
        
        Test.@testset "constraint! - path type without control" begin
            # Path constraints should work without control (e.g., state-only path constraints)
            pre = OCP.PreModel()
            OCP.state!(pre, 2)
            OCP.time!(pre, t0=0, tf=1)
            
            # This should work without calling control!
            OCP.constraint!(pre, :path, f=(t, x, u) -> x[1], lb=0, ub=1)
            Test.@test length(pre.constraints) == 1
        end
        
        Test.@testset "constraint! - control type requires control" begin
            # Only :control type constraints require control to be set
            pre = OCP.PreModel()
            OCP.state!(pre, 2)
            OCP.time!(pre, t0=0, tf=1)
            
            # This should throw a PreconditionError because control is not set
            exception_thrown = false
            try
                OCP.constraint!(pre, :control, rg=1, lb=-1, ub=1)
            catch e
                exception_thrown = true
                Test.@test e isa Exceptions.PreconditionError
            end
            Test.@test exception_thrown
        end
        
        # ====================================================================
        # UNIT TESTS - Phase 3: Building without control
        # ====================================================================
        
        Test.@testset "build() - Model without control" begin
            # Build a complete Model without control
            pre = OCP.PreModel()
            OCP.time!(pre, t0=0, tf=1)
            OCP.state!(pre, 2)
            OCP.dynamics!(pre, (x, u) -> [x[2], -x[1]])
            OCP.objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
            OCP.time_dependence!(pre, autonomous=false)
            OCP.definition!(pre, quote end)
            
            # This should work without calling control!
            model = OCP.build(pre)
            Test.@test model isa OCP.Model
            Test.@test OCP.control_dimension(model) == 0
            Test.@test OCP.control_name(model) == ""
            Test.@test OCP.control_components(model) == String[]
        end
        
        # ====================================================================
        # UNIT TESTS - Phase 4: Display without control
        # ====================================================================
        
        Test.@testset "Display - Model without control" begin
            # Build a Model without control
            pre = OCP.PreModel()
            OCP.time!(pre, t0=0, tf=1)
            OCP.state!(pre, 2)
            OCP.dynamics!(pre, (x, u) -> [x[2], -x[1]])
            OCP.objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
            OCP.time_dependence!(pre, autonomous=false)
            OCP.definition!(pre, quote end)
            model = OCP.build(pre)
            
            # Test that display works without error
            io = IOBuffer()
            Test.@test_nowarn show(io, MIME"text/plain"(), model)
            output = String(take!(io))
            
            # Verify control is not mentioned in output
            Test.@test !occursin("u(", output)
            Test.@test occursin("x(", output)  # State should be present
            Test.@test occursin("J(x", output)  # Objective should have only state
        end
        
        # ====================================================================
        # UNIT TESTS - Phase 5: Initialization without control
        # ====================================================================
        
        Test.@testset "Init - initial_control with nothing" begin
            # Build a Model without control
            pre = OCP.PreModel()
            OCP.time!(pre, t0=0, tf=1)
            OCP.state!(pre, 2)
            OCP.dynamics!(pre, (x, u) -> [x[2], -x[1]])
            OCP.objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
            OCP.time_dependence!(pre, autonomous=false)
            OCP.definition!(pre, quote end)
            model = OCP.build(pre)
            
            # Test that initial_control with nothing returns empty vector function
            u_init = Init.initial_control(model, nothing)
            Test.@test u_init isa Function
            Test.@test u_init(0.5) == Float64[]
        end
        
        Test.@testset "Init - initial_control with scalar throws error" begin
            # Build a Model without control
            pre = OCP.PreModel()
            OCP.time!(pre, t0=0, tf=1)
            OCP.state!(pre, 2)
            OCP.dynamics!(pre, (x, u) -> [x[2], -x[1]])
            OCP.objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
            OCP.time_dependence!(pre, autonomous=false)
            OCP.definition!(pre, quote end)
            model = OCP.build(pre)
            
            # This should throw an error
            exception_thrown = false
            try
                Init.initial_control(model, 0.5)
            catch e
                exception_thrown = true
                Test.@test e isa Exceptions.IncorrectArgument
            end
            Test.@test exception_thrown
        end
        
        Test.@testset "Init - initial_control with non-empty vector throws error" begin
            # Build a Model without control
            pre = OCP.PreModel()
            OCP.time!(pre, t0=0, tf=1)
            OCP.state!(pre, 2)
            OCP.dynamics!(pre, (x, u) -> [x[2], -x[1]])
            OCP.objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
            OCP.time_dependence!(pre, autonomous=false)
            OCP.definition!(pre, quote end)
            model = OCP.build(pre)
            
            # This should throw an error
            exception_thrown = false
            try
                Init.initial_control(model, [0.5])
            catch e
                exception_thrown = true
                Test.@test e isa Exceptions.IncorrectArgument
            end
            Test.@test exception_thrown
        end
        
        Test.@testset "Init - initial_guess without control" begin
            # Build a Model without control
            pre = OCP.PreModel()
            OCP.time!(pre, t0=0, tf=1)
            OCP.state!(pre, 2)
            OCP.dynamics!(pre, (x, u) -> [x[2], -x[1]])
            OCP.objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
            OCP.time_dependence!(pre, autonomous=false)
            OCP.definition!(pre, quote end)
            model = OCP.build(pre)
            
            # Test that initial_guess works without control
            init = Init.initial_guess(model)
            Test.@test init isa Init.InitialGuess
            Test.@test init.control(0.5) == Float64[]
        end
        
        # ====================================================================
        # UNIT TESTS - Phase 6: Name validation without control
        # ====================================================================
        
        Test.@testset "Validation - Name conflicts without control" begin
            # Build a PreModel without control
            pre = OCP.PreModel()
            OCP.time!(pre, t0=0, tf=1)
            OCP.state!(pre, 2, "x", ["x1", "x2"])
            
            # Verify that control names are not collected
            used_names = OCP.__collect_used_names(pre)
            Test.@test "t" ∈ used_names  # time should be present
            Test.@test "x" ∈ used_names  # state should be present
            Test.@test "x1" ∈ used_names
            Test.@test "x2" ∈ used_names
            Test.@test !("u" ∈ used_names)  # control should NOT be present
            
            # Should be able to use "u" as a state component name since control is not set
            pre2 = OCP.PreModel()
            OCP.time!(pre2, t0=0, tf=1)
            OCP.state!(pre2, 2, "x", ["u", "v"])  # "u" is allowed as state component
            Test.@test OCP.__is_state_set(pre2)
        end
        
        # ====================================================================
        # INTEGRATION TESTS - Phase 7: Serialization without control
        # ====================================================================
        
        Test.@testset "Serialization - Solution building without control" begin
            # Build a Model without control
            pre = OCP.PreModel()
            OCP.time!(pre, t0=0, tf=1)
            OCP.state!(pre, 2)
            OCP.dynamics!(pre, (x, u) -> [x[2], -x[1]])
            OCP.objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
            OCP.time_dependence!(pre, autonomous=false)
            OCP.definition!(pre, quote end)
            model = OCP.build(pre)
            
            # Create a solution without control
            T = collect(range(0, 1, length=10))
            x_data = hcat(sin.(T), cos.(T))  # (10, 2) matrix
            u_data = Matrix{Float64}(undef, 10, 0)  # Empty control matrix (10×0)
            p_data = hcat(cos.(T), -sin.(T))  # (10, 2) matrix
            v_data = Float64[]
            
            sol = OCP.build_solution(
                model,
                T, T, T, T,
                x_data, u_data, v_data, p_data;
                objective=1.0,
                iterations=10,
                constraints_violation=0.0,
                message="Test solution",
                status=:success,
                successful=true
            )
            
            # Test that control_dimension is 0
            Test.@test OCP.control_dimension(sol) == 0
            
            # Test that control function returns empty vector
            u_func = OCP.control(sol)
            Test.@test u_func(0.5) == Float64[]
            
            # Test that solution properties are correct
            Test.@test OCP.state_dimension(sol) == 2
            Test.@test OCP.objective(sol) == 1.0
        end
        
        # ====================================================================
        # INTEGRATION TESTS - Phase 8: Plotting without control
        # ====================================================================
        
        Test.@testset "Plotting - Verify subplot count without control" begin
            # Build a Model without control
            pre = OCP.PreModel()
            OCP.time!(pre, t0=0, tf=1)
            OCP.state!(pre, 2)
            OCP.dynamics!(pre, (x, u) -> [x[2], -x[1]])
            OCP.objective!(pre, :min, mayer=(x0, xf) -> xf[1]^2)
            OCP.time_dependence!(pre, autonomous=false)
            OCP.definition!(pre, quote end)
            model = OCP.build(pre)
            
            # Create a solution without control
            T = collect(range(0, 1, length=10))
            x_data = hcat(sin.(T), cos.(T))  # (10, 2) matrix
            u_data = Matrix{Float64}(undef, 10, 0)  # Empty control matrix (10×0)
            p_data = hcat(cos.(T), -sin.(T))  # (10, 2) matrix
            v_data = Float64[]
            
            sol = OCP.build_solution(
                model,
                T, T, T, T,
                x_data, u_data, v_data, p_data;
                objective=1.0,
                iterations=10,
                constraints_violation=0.0,
                message="Test solution",
                status=:success,
                successful=true
            )
            
            # Test plotting with :group layout
            p = Plots.plot(sol, layout=:group)
            # Without control: state + costate = 2 subplots
            # With control: state + costate + control = 3 subplots
            Test.@test length(p.subplots) == 2
            
            # Test plotting with :split layout
            p_split = Plots.plot(sol, layout=:split)
            # Without control: 2 state components + 2 costate components = 4 subplots
            # With control: 2 state + 2 costate + m control = 4 + m subplots
            Test.@test length(p_split.subplots) == 4
        end
        
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_control_zero() = TestControlZero.test_control_zero()
