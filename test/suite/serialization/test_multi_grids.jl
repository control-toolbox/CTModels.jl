module TestMultiGrids

import Test
import CTModels
import JLD2
import JSON3
import CTBase.Exceptions

include(joinpath("..", "..", "problems", "TestProblems.jl"))
import .TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function remove_if_exists(filename::String)
    isfile(filename) && rm(filename)
end

function test_multi_grids()
    Test.@testset "Multi-Grid Serialization Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for multi-grid serialization functionality
        end

        # ====================================================================
        # INTEGRATION TESTS - Multi-Grid Support
        # ====================================================================

        # Create base solution with unified grid
        ocp, sol_unified = TestProblems.solution_example()

        # Extract data from unified solution
        T_unified = CTModels.time_grid(sol_unified)
        X = CTModels.state(sol_unified).(T_unified)
        U = CTModels.control(sol_unified).(T_unified)
        P = CTModels.costate(sol_unified).(T_unified)
        v = CTModels.variable(sol_unified)

        # Convert to matrices
        dim_x = CTModels.state_dimension(sol_unified)
        dim_u = CTModels.control_dimension(sol_unified)
        X_mat = hcat([x for x in X]...)'
        U_mat = hcat([u isa Number ? [u] : u for u in U]...)'
        P_mat = hcat([p for p in P]...)'

        # ====================================================================
        # Test 1: Unified Grid (should use UnifiedTimeGridModel)
        # ====================================================================

        Test.@testset "Unified grid detection" begin
            # Create solution with same grid for all components using functions
            T = collect(LinRange(0.0, 1.0, 11))
            
            # Use functions (simpler and more robust)
            X_func = CTModels.state(sol_unified)
            U_func = CTModels.control(sol_unified)
            P_func = CTModels.costate(sol_unified)
            
            sol = CTModels.build_solution(
                ocp,
                T, T, T, T,  # All grids identical
                X_func, U_func, v, P_func;
                objective=CTModels.objective(sol_unified),
                iterations=CTModels.iterations(sol_unified),
                constraints_violation=CTModels.constraints_violation(sol_unified),
                message=CTModels.message(sol_unified),
                status=CTModels.status(sol_unified),
                successful=CTModels.successful(sol_unified),
            )

            # Should create UnifiedTimeGridModel (optimization)
            Test.@test CTModels.time_grid_model(sol) isa CTModels.UnifiedTimeGridModel
            
            # time_grid without argument should work
            T_retrieved = CTModels.time_grid(sol)
            Test.@test T_retrieved ≈ T
        end

        # ====================================================================
        # Test 2: Multiple Grids (should use MultipleTimeGridModel)
        # ====================================================================

        Test.@testset "Multiple grids detection" begin
            # Create solution with different grids using functions
            T_state = collect(LinRange(0.0, 1.0, 21))     # Fine grid
            T_control = collect(LinRange(0.0, 1.0, 11))   # Coarse grid
            T_costate = collect(LinRange(0.0, 1.0, 21))   # Fine grid
            T_dual = collect(LinRange(0.0, 1.0, 21))      # Fine grid

            # Use functions instead of matrices (simpler)
            X_func = CTModels.state(sol_unified)
            U_func = CTModels.control(sol_unified)
            P_func = CTModels.costate(sol_unified)

            sol_multi = CTModels.build_solution(
                ocp,
                T_state, T_control, T_costate, T_dual,  # Different grids
                X_func, U_func, v, P_func;
                objective=CTModels.objective(sol_unified),
                iterations=CTModels.iterations(sol_unified),
                constraints_violation=CTModels.constraints_violation(sol_unified),
                message=CTModels.message(sol_unified),
                status=CTModels.status(sol_unified),
                successful=CTModels.successful(sol_unified),
            )

            # Should create MultipleTimeGridModel
            Test.@test CTModels.time_grid_model(sol_multi) isa CTModels.MultipleTimeGridModel
            
            # time_grid with component should work
            Test.@test CTModels.time_grid(sol_multi, :state) ≈ T_state
            Test.@test CTModels.time_grid(sol_multi, :control) ≈ T_control
            Test.@test CTModels.time_grid(sol_multi, :costate) ≈ T_costate
            Test.@test CTModels.time_grid(sol_multi, :dual) ≈ T_dual
        end

        # ====================================================================
        # Test 3: JLD2 Export/Import with Multiple Grids
        # ====================================================================

        Test.@testset "JLD2 multi-grid round-trip" begin
            # Create solution with different grids using functions
            T_state = collect(LinRange(0.0, 1.0, 21))
            T_control = collect(LinRange(0.0, 1.0, 11))
            T_costate = collect(LinRange(0.0, 1.0, 21))
            T_dual = collect(LinRange(0.0, 1.0, 21))

            X_func = CTModels.state(sol_unified)
            U_func = CTModels.control(sol_unified)
            P_func = CTModels.costate(sol_unified)

            sol_multi = CTModels.build_solution(
                ocp,
                T_state, T_control, T_costate, T_dual,
                X_func, U_func, v, P_func;
                objective=CTModels.objective(sol_unified),
                iterations=CTModels.iterations(sol_unified),
                constraints_violation=CTModels.constraints_violation(sol_unified),
                message=CTModels.message(sol_unified),
                status=CTModels.status(sol_unified),
                successful=CTModels.successful(sol_unified),
            )

            # Export
            CTModels.export_ocp_solution(sol_multi; filename="multi_grid_test", format=:JLD)
            
            # Import
            sol_reloaded = CTModels.import_ocp_solution(ocp; filename="multi_grid_test", format=:JLD)

            # Verify time grid model type
            Test.@test CTModels.time_grid_model(sol_reloaded) isa CTModels.MultipleTimeGridModel

            # Verify grids are preserved
            Test.@test CTModels.time_grid(sol_reloaded, :state) ≈ T_state
            Test.@test CTModels.time_grid(sol_reloaded, :control) ≈ T_control
            Test.@test CTModels.time_grid(sol_reloaded, :costate) ≈ T_costate
            Test.@test CTModels.time_grid(sol_reloaded, :dual) ≈ T_dual

            # Verify data integrity
            Test.@test CTModels.objective(sol_reloaded) ≈ CTModels.objective(sol_multi)
            Test.@test CTModels.variable(sol_reloaded) ≈ CTModels.variable(sol_multi)

            # Verify trajectories at their respective grids
            for t in T_state
                Test.@test CTModels.state(sol_reloaded)(t) ≈ CTModels.state(sol_multi)(t) atol=1e-8
            end
            for t in T_control
                Test.@test CTModels.control(sol_reloaded)(t) ≈ CTModels.control(sol_multi)(t) atol=1e-8
            end

            remove_if_exists("multi_grid_test.jld2")
        end

        # ====================================================================
        # Test 4: Error Handling for MultipleTimeGridModel
        # ====================================================================

        Test.@testset "Error handling - MultipleTimeGridModel" begin
            # Create a multi-grid solution
            T_state = collect(LinRange(0.0, 1.0, 21))
            T_control = collect(LinRange(0.0, 1.0, 11))
            T_costate = collect(LinRange(0.0, 1.0, 21))
            T_dual = collect(LinRange(0.0, 1.0, 21))

            X_func = CTModels.state(sol_unified)
            U_func = CTModels.control(sol_unified)
            P_func = CTModels.costate(sol_unified)

            sol_multi = CTModels.build_solution(
                ocp,
                T_state, T_control, T_costate, T_dual,
                X_func, U_func, v, P_func;
                objective=CTModels.objective(sol_unified),
                iterations=CTModels.iterations(sol_unified),
                constraints_violation=CTModels.constraints_violation(sol_unified),
                message=CTModels.message(sol_unified),
                status=CTModels.status(sol_unified),
                successful=CTModels.successful(sol_unified),
            )

            # time_grid without component should throw error
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time_grid(sol_multi)

            # Invalid component should throw error
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time_grid(sol_multi, :invalid)
        end

        # ====================================================================
        # Test 5: Component Symbol Mapping
        # ====================================================================

        Test.@testset "Component symbol mapping" begin
            # Create a multi-grid solution
            T_state = collect(LinRange(0.0, 1.0, 21))
            T_control = collect(LinRange(0.0, 1.0, 11))
            T_costate = collect(LinRange(0.0, 1.0, 21))
            T_dual = collect(LinRange(0.0, 1.0, 21))

            X_func = CTModels.state(sol_unified)
            U_func = CTModels.control(sol_unified)
            P_func = CTModels.costate(sol_unified)

            sol_multi = CTModels.build_solution(
                ocp,
                T_state, T_control, T_costate, T_dual,
                X_func, U_func, v, P_func;
                objective=CTModels.objective(sol_unified),
                iterations=CTModels.iterations(sol_unified),
                constraints_violation=CTModels.constraints_violation(sol_unified),
                message=CTModels.message(sol_unified),
                status=CTModels.status(sol_unified),
                successful=CTModels.successful(sol_unified),
            )

            # Test plural forms work
            Test.@test CTModels.time_grid(sol_multi, :states) ≈ T_state
            Test.@test CTModels.time_grid(sol_multi, :controls) ≈ T_control
            Test.@test CTModels.time_grid(sol_multi, :costates) ≈ T_costate

            # Test path/dual equivalence
            Test.@test CTModels.time_grid(sol_multi, :path) ≈ T_dual
            Test.@test CTModels.time_grid(sol_multi, :dual) ≈ T_dual
        end

        # ====================================================================
        # Test 6: Edge Cases
        # ====================================================================

        Test.@testset "Edge cases" begin
            # Test with T_dual = nothing
            T_state = collect(LinRange(0.0, 1.0, 11))
            T_control = collect(LinRange(0.0, 1.0, 11))
            T_costate = collect(LinRange(0.0, 1.0, 11))

            X_func = CTModels.state(sol_unified)
            U_func = CTModels.control(sol_unified)
            P_func = CTModels.costate(sol_unified)

            sol = CTModels.build_solution(
                ocp,
                T_state, T_control, T_costate, nothing,  # T_dual = nothing
                X_func, U_func, v, P_func;
                objective=CTModels.objective(sol_unified),
                iterations=CTModels.iterations(sol_unified),
                constraints_violation=CTModels.constraints_violation(sol_unified),
                message=CTModels.message(sol_unified),
                status=CTModels.status(sol_unified),
                successful=CTModels.successful(sol_unified),
            )

            # Should still work (uses T_state for dual)
            Test.@test CTModels.time_grid_model(sol) isa CTModels.UnifiedTimeGridModel
            Test.@test CTModels.time_grid(sol) ≈ T_state
        end

        # ====================================================================
        # Test 7: Unified vs Multiple Grid Optimization
        # ====================================================================

        Test.@testset "Unified grid optimization" begin
            # When all grids are identical, should optimize to UnifiedTimeGridModel
            T = collect(LinRange(0.0, 1.0, 11))

            X_func = CTModels.state(sol_unified)
            U_func = CTModels.control(sol_unified)
            P_func = CTModels.costate(sol_unified)

            # Pass same grid 4 times
            sol = CTModels.build_solution(
                ocp,
                T, T, T, T,  # All identical
                X_func, U_func, v, P_func;
                objective=CTModels.objective(sol_unified),
                iterations=CTModels.iterations(sol_unified),
                constraints_violation=CTModels.constraints_violation(sol_unified),
                message=CTModels.message(sol_unified),
                status=CTModels.status(sol_unified),
                successful=CTModels.successful(sol_unified),
            )

            # Should detect and optimize to UnifiedTimeGridModel
            Test.@test CTModels.time_grid_model(sol) isa CTModels.UnifiedTimeGridModel
            Test.@test CTModels.time_grid(sol) ≈ T

            # Now with different grids
            T_control_diff = collect(LinRange(0.0, 1.0, 6))

            sol_multi = CTModels.build_solution(
                ocp,
                T, T_control_diff, T, T,  # One different
                X_func, U_func, v, P_func;
                objective=CTModels.objective(sol_unified),
                iterations=CTModels.iterations(sol_unified),
                constraints_violation=CTModels.constraints_violation(sol_unified),
                message=CTModels.message(sol_unified),
                status=CTModels.status(sol_unified),
                successful=CTModels.successful(sol_unified),
            )

            # Should use MultipleTimeGridModel
            Test.@test CTModels.time_grid_model(sol_multi) isa CTModels.MultipleTimeGridModel
            Test.@test CTModels.time_grid(sol_multi, :state) ≈ T
            Test.@test CTModels.time_grid(sol_multi, :control) ≈ T_control_diff
        end

        # ====================================================================
        # TODO: Add JSON tests once matrix dimension issues are fixed
        # ====================================================================
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_multi_grids() = TestMultiGrids.test_multi_grids()
