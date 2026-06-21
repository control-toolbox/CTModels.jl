module TestMultiGrids

import Test: Test
import JLD2: JLD2
import JSON3: JSON3
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Solutions: Solutions
import CTModels.Serialization: Serialization

include(joinpath("..", "..", "problems", "TestProblems.jl"))
import .TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function remove_if_exists(filename::String)
    return isfile(filename) && rm(filename)
end

function test_multi_grids()
    Test.@testset "Multi-Grid Serialization Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # INTEGRATION TESTS - Multi-Grid Support
        # ====================================================================

        # Create base solution with unified grid
        ocp, sol_unified = TestProblems.solution_example()

        # Extract data from unified solution
        T_unified = Components.time_grid(sol_unified)
        X = Components.state(sol_unified).(T_unified)
        U = Components.control(sol_unified).(T_unified)
        P = Components.costate(sol_unified).(T_unified)
        v = Components.variable(sol_unified)

        # Convert to matrices
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
            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol = Solutions.build_solution(
                ocp,
                T,
                T,
                T,
                T,  # All grids identical
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Should create UnifiedTimeGridModel (optimization)
            Test.@test Solutions.time_grid_model(sol) isa Solutions.UnifiedTimeGridModel

            # time_grid without argument should work
            T_retrieved = Components.time_grid(sol)
            Test.@test T_retrieved ≈ T
        end

        # ====================================================================
        # Test 2: Multiple Grids (should use MultipleTimeGridModel)
        # ====================================================================

        Test.@testset "Multiple grids detection" begin
            # Create solution with different grids using functions
            T_state = collect(LinRange(0.0, 1.0, 21))     # Fine grid
            T_control = collect(LinRange(0.0, 1.0, 11))   # Coarse grid
            T_costate = collect(LinRange(0.0, 1.0, 16))   # Medium grid
            T_path = collect(LinRange(0.0, 1.0, 21))      # Fine grid

            # Use functions instead of matrices (simpler)
            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol_multi = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,  # Different grids
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Should create MultipleTimeGridModel
            Test.@test Solutions.time_grid_model(sol_multi) isa
                Solutions.MultipleTimeGridModel

            # time_grid with component should work
            Test.@test Components.time_grid(sol_multi, :state) ≈ T_state
            Test.@test Components.time_grid(sol_multi, :control) ≈ T_control
            Test.@test Components.time_grid(sol_multi, :costate) ≈ T_costate
            Test.@test Components.time_grid(sol_multi, :dual) ≈ T_path
        end

        # ====================================================================
        # Test 3: JLD2 Export/Import with Multiple Grids
        # ====================================================================

        Test.@testset "JLD2 multi-grid round-trip" begin
            # Create solution with different grids using functions
            T_state = collect(LinRange(0.0, 1.0, 21))
            T_control = collect(LinRange(0.0, 1.0, 11))
            T_costate = collect(LinRange(0.0, 1.0, 16))
            T_path = collect(LinRange(0.0, 1.0, 21))
            # T_path same as T_state for this test

            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol_multi = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Export
            Serialization.export_ocp_solution(
                sol_multi; filename="multi_grid_test", format=:JLD
            )

            # Import
            sol_reloaded = Serialization.import_ocp_solution(
                ocp; filename="multi_grid_test", format=:JLD
            )

            # Verify time grid model type
            Test.@test Solutions.time_grid_model(sol_reloaded) isa
                Solutions.MultipleTimeGridModel

            # Verify grids are preserved
            Test.@test Components.time_grid(sol_reloaded, :state) ≈ T_state
            Test.@test Components.time_grid(sol_reloaded, :control) ≈ T_control
            Test.@test Components.time_grid(sol_reloaded, :costate) ≈ T_costate
            Test.@test Components.time_grid(sol_reloaded, :dual) ≈ T_path

            # Verify data integrity
            Test.@test Solutions.objective(sol_reloaded) ≈ Solutions.objective(sol_multi)
            Test.@test Components.variable(sol_reloaded) ≈ Components.variable(sol_multi)

            # Verify trajectories at their respective grids
            for t in T_state
                Test.@test Components.state(sol_reloaded)(t) ≈ Components.state(sol_multi)(t) atol=1e-8
            end
            for t in T_control
                Test.@test Components.control(sol_reloaded)(t) ≈ Components.control(sol_multi)(t) atol=1e-8
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
            T_costate = collect(LinRange(0.0, 1.0, 16))
            T_path = collect(LinRange(0.0, 1.0, 21))

            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol_multi = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # time_grid without component should return state grid (default behavior)
            Test.@test Components.time_grid(sol_multi) == T_state
            Test.@test Components.time_grid(sol_multi) ==
                Components.time_grid(sol_multi, :state)

            # Invalid component should throw error
            Test.@test_throws Exceptions.IncorrectArgument Components.time_grid(
                sol_multi, :invalid
            )
        end

        # ====================================================================
        # Test 5: Component Symbol Mapping
        # ====================================================================

        Test.@testset "Component symbol mapping" begin
            # Create a multi-grid solution
            T_state = collect(LinRange(0.0, 1.0, 21))
            T_control = collect(LinRange(0.0, 1.0, 11))
            T_costate = collect(LinRange(0.0, 1.0, 16))
            T_path = collect(LinRange(0.0, 1.0, 21))

            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol_multi = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Test plural forms work
            Test.@test Components.time_grid(sol_multi, :states) ≈ T_state
            Test.@test Components.time_grid(sol_multi, :controls) ≈ T_control
            Test.@test Components.time_grid(sol_multi, :costates) ≈ T_costate

            # Test path/dual equivalence
            Test.@test Components.time_grid(sol_multi, :path) ≈ T_path
            Test.@test Components.time_grid(sol_multi, :dual) ≈ T_path
        end

        # ====================================================================
        # Test 6: Edge Cases
        # ====================================================================

        Test.@testset "Edge cases" begin
            # Test with T_path = nothing
            T_state = collect(LinRange(0.0, 1.0, 11))
            T_control = collect(LinRange(0.0, 1.0, 11))
            T_costate = collect(LinRange(0.0, 1.0, 11))

            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                nothing,  # T_path = nothing
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Should still work (uses T_state for dual)
            Test.@test Solutions.time_grid_model(sol) isa Solutions.UnifiedTimeGridModel
            Test.@test Components.time_grid(sol) ≈ T_state
        end

        # ====================================================================
        # Test 7: Unified vs Multiple Grid Optimization
        # ====================================================================

        Test.@testset "Unified grid optimization" begin
            # When all grids are identical, should optimize to UnifiedTimeGridModel
            T = collect(LinRange(0.0, 1.0, 11))

            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            # Pass same grid 4 times
            sol = Solutions.build_solution(
                ocp,
                T,
                T,
                T,
                T,  # All identical
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Should detect and optimize to UnifiedTimeGridModel
            Test.@test Solutions.time_grid_model(sol) isa Solutions.UnifiedTimeGridModel
            Test.@test Components.time_grid(sol) ≈ T

            # Now with different grids
            T_control_diff = collect(LinRange(0.0, 1.0, 6))

            sol_multi = Solutions.build_solution(
                ocp,
                T,
                T_control_diff,
                T,
                T,  # One different
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Should use MultipleTimeGridModel
            Test.@test Solutions.time_grid_model(sol_multi) isa
                Solutions.MultipleTimeGridModel
            Test.@test Components.time_grid(sol_multi, :state) ≈ T
            Test.@test Components.time_grid(sol_multi, :control) ≈ T_control_diff
        end

        # ====================================================================
        # Test 8: Serialization Internal Structure
        # ====================================================================

        Test.@testset "Serialization structure" begin
            # Test UnifiedTimeGridModel serialization
            T = collect(LinRange(0.0, 1.0, 11))
            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol_uni = Solutions.build_solution(
                ocp,
                T,
                T,
                T,
                T,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Serialize and check structure
            data_uni = Solutions._serialize_solution(sol_uni)

            # Should have legacy format keys
            Test.@test haskey(data_uni, "time_grid")
            Test.@test !haskey(data_uni, "time_grid_state")
            Test.@test data_uni["time_grid"] ≈ T

            # Test MultipleTimeGridModel serialization
            T_state = collect(LinRange(0.0, 1.0, 21))
            T_control = collect(LinRange(0.0, 1.0, 11))
            T_costate = collect(LinRange(0.0, 1.0, 16))
            T_path = collect(LinRange(0.0, 1.0, 21))

            sol_multi = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Serialize and check structure
            data_multi = Solutions._serialize_solution(sol_multi)

            # Should have multi-grid format keys
            Test.@test haskey(data_multi, "time_grid_state")
            Test.@test haskey(data_multi, "time_grid_control")
            Test.@test haskey(data_multi, "time_grid_costate")
            Test.@test haskey(data_multi, "time_grid_path")
            Test.@test !haskey(data_multi, "time_grid")

            # Verify grid values
            Test.@test data_multi["time_grid_state"] ≈ T_state
            Test.@test data_multi["time_grid_control"] ≈ T_control
            Test.@test data_multi["time_grid_costate"] ≈ T_costate
            Test.@test data_multi["time_grid_path"] ≈ T_path
        end

        # ====================================================================
        # Test 9: Extreme Grid Sizes
        # ====================================================================

        Test.@testset "Extreme grid sizes" begin
            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            # Very different grid sizes
            T_state_large = collect(LinRange(0.0, 1.0, 1001))  # Fine grid
            T_control_small = collect(LinRange(0.0, 1.0, 11))  # Coarse grid
            T_costate_medium = collect(LinRange(0.0, 1.0, 101))  # Medium grid
            T_path_large = collect(LinRange(0.0, 1.0, 1001))

            sol_extreme = Solutions.build_solution(
                ocp,
                T_state_large,
                T_control_small,
                T_costate_medium,
                T_path_large,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Should create MultipleTimeGridModel
            Test.@test Solutions.time_grid_model(sol_extreme) isa
                Solutions.MultipleTimeGridModel

            # Verify grids
            Test.@test length(Components.time_grid(sol_extreme, :state)) == 1001
            Test.@test length(Components.time_grid(sol_extreme, :control)) == 11
            Test.@test Components.time_grid(sol_extreme, :state) ≈ T_state_large
            Test.@test Components.time_grid(sol_extreme, :control) ≈ T_control_small

            # Minimum grid size (2 points)
            T_min = collect(LinRange(0.0, 1.0, 2))

            sol_min = Solutions.build_solution(
                ocp,
                T_min,
                T_min,
                T_min,
                T_min,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Should work with minimum grid
            Test.@test Solutions.time_grid_model(sol_min) isa Solutions.UnifiedTimeGridModel
            Test.@test length(Components.time_grid(sol_min)) == 2
        end

        # ====================================================================
        # Test 10: Grid Reconstruction from Serialized Data
        # ====================================================================

        Test.@testset "Grid reconstruction" begin
            # Create multi-grid solution
            T_state = collect(LinRange(0.0, 1.0, 21))
            T_control = collect(LinRange(0.0, 1.0, 11))
            T_costate = collect(LinRange(0.0, 1.0, 16))
            T_path = collect(LinRange(0.0, 1.0, 21))

            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol_orig = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Serialize
            data = Solutions._serialize_solution(sol_orig)

            # Reconstruct using helper function
            sol_reconstructed = Serialization._reconstruct_solution_from_data(
                ocp, data; infos=get(data, "infos", Dict{Symbol,Any}())
            )

            # Verify reconstruction
            Test.@test Solutions.time_grid_model(sol_reconstructed) isa
                Solutions.MultipleTimeGridModel
            Test.@test Components.time_grid(sol_reconstructed, :state) ≈ T_state
            Test.@test Components.time_grid(sol_reconstructed, :control) ≈ T_control
            Test.@test Components.time_grid(sol_reconstructed, :costate) ≈ T_costate
            Test.@test Components.time_grid(sol_reconstructed, :dual) ≈ T_path
            Test.@test Solutions.objective(sol_reconstructed) ≈
                Solutions.objective(sol_orig)
        end

        # ====================================================================
        # Test 11: Backward Compatibility - Legacy Format Detection
        # ====================================================================

        Test.@testset "Legacy format detection" begin
            # Create a legacy-format data structure (single time_grid)
            T = collect(LinRange(0.0, 1.0, 11))
            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol = Solutions.build_solution(
                ocp,
                T,
                T,
                T,
                T,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Serialize (should produce legacy format)
            data = Solutions._serialize_solution(sol)

            # Verify legacy format
            Test.@test haskey(data, "time_grid")
            Test.@test !haskey(data, "time_grid_state")

            # Reconstruct from unified format
            sol_from_legacy = Serialization._reconstruct_solution_from_data(
                ocp,
                data;
                infos=get(data, "infos", Dict{Symbol,Any}()),
            )

            # Should create UnifiedTimeGridModel from legacy format
            Test.@test Solutions.time_grid_model(sol_from_legacy) isa
                Solutions.UnifiedTimeGridModel
            Test.@test Components.time_grid(sol_from_legacy) ≈ T
        end

        # ====================================================================
        # Test 12: Missing required time grid keys raise a KeyError
        # The legacy "time_grid_dual" key is no longer supported.
        # ====================================================================

        Test.@testset "JSON missing time_grid_path raises KeyError" begin
            T_state = collect(LinRange(0.0, 1.0, 11))
            T_control = collect(LinRange(0.0, 1.0, 6))
            T_costate = collect(LinRange(0.0, 1.0, 11))
            T_path = collect(LinRange(0.0, 1.0, 9))

            X_func = Components.state(sol_unified)
            U_func = Components.control(sol_unified)
            P_func = Components.costate(sol_unified)

            sol_multi = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                X_func,
                U_func,
                v,
                P_func;
                objective=Solutions.objective(sol_unified),
                iterations=Solutions.iterations(sol_unified),
                constraints_violation=Solutions.constraints_violation(sol_unified),
                message=Solutions.message(sol_unified),
                status=Solutions.status(sol_unified),
                successful=Solutions.successful(sol_unified),
            )

            # Export to JSON — produces "time_grid_path" key
            Serialization.export_ocp_solution(
                sol_multi; filename="missing_tgp_test", format=:JSON
            )
            Test.@test isfile("missing_tgp_test.json")

            # Simulate a file with the old key name (time_grid_dual) instead of time_grid_path
            json_string = read("missing_tgp_test.json", String)
            blob = JSON3.read(json_string)
            legacy_data = Dict{String,Any}(
                string(k) => v for (k, v) in blob if string(k) != "time_grid_path"
            )
            legacy_data["time_grid_dual"] = blob["time_grid_path"]  # old name
            open("missing_tgp_legacy.json", "w") do f
                return JSON3.write(f, legacy_data)
            end

            # Import from file with old key must raise a KeyError (required key absent)
            Test.@test_throws KeyError Serialization.import_ocp_solution(
                ocp; filename="missing_tgp_legacy", format=:JSON
            )

            remove_if_exists("missing_tgp_test.json")
            remove_if_exists("missing_tgp_legacy.json")
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_multi_grids() = TestMultiGrids.test_multi_grids()
