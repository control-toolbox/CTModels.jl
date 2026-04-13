module TestGridExtension

using Test: Test
import CTBase.Exceptions
import CTModels.OCP

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_grid_extension()
    Test.@testset "Grid Extension Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Extension Logic
        # ====================================================================

        Test.@testset "UNIT TESTS - Grid Extension Function" begin
            Test.@testset "Extension when grid is strict prefix" begin
                T_ref = [0.0, 0.5, 1.0]
                T_target = [0.0, 0.5]  # Missing last element
                T_extended = OCP._extend_grid_to_match(T_target, T_ref, "control")
                Test.@test T_extended == T_ref
            end

            Test.@testset "No extension when grids differ significantly" begin
                T_ref = [0.0, 0.5, 1.0]
                T_target = [0.0, 0.3, 0.6]  # Different values
                T_extended = OCP._extend_grid_to_match(T_target, T_ref, "control")
                Test.@test T_extended == T_target  # Unchanged
            end

            Test.@testset "No extension when more than one element missing" begin
                T_ref = [0.0, 0.5, 1.0]
                T_target = [0.0]  # Missing 2 elements
                T_extended = OCP._extend_grid_to_match(T_target, T_ref, "control")
                Test.@test T_extended == T_target  # Unchanged
            end

            Test.@testset "No extension when grids are identical" begin
                T_ref = [0.0, 0.5, 1.0]
                T_target = [0.0, 0.5, 1.0]  # Identical
                T_extended = OCP._extend_grid_to_match(T_target, T_ref, "control")
                Test.@test T_extended == T_target  # Unchanged
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - build_solution with extension
        # ====================================================================

        Test.@testset "INTEGRATION TESTS - UnifiedTimeGridModel after extension" begin
            # Note: Full integration test requires complete OCP setup
            # This test verifies the extension logic works in context
            # Full end-to-end test is deferred to avoid OCP configuration complexity

            # Verify that extension logic is correctly integrated
            # by testing the detection of identical grids after extension
            T_state = [0.0, 0.5, 1.0]
            T_control = [0.0, 0.5]  # Missing last element
            T_costate = [0.0, 0.5]  # Missing last element
            T_path = nothing

            # Apply extension logic (mimicking build_solution internal logic)
            non_nothing_grids = filter(
                g -> !isnothing(g), [T_state, T_control, T_costate, T_path]
            )
            T_ref = non_nothing_grids[argmax(map(length, non_nothing_grids))]
            T_control_extended = OCP._extend_grid_to_match(T_control, T_ref, "control")
            T_costate_extended = OCP._extend_grid_to_match(T_costate, T_ref, "costate")

            # After extension, all grids should be identical
            Test.@test T_control_extended == T_ref
            Test.@test T_costate_extended == T_ref
            Test.@test T_state == T_ref

            # This would enable UnifiedTimeGridModel in build_solution
            non_nothing_grids_extended = filter(
                g -> !isnothing(g),
                [T_state, T_control_extended, T_costate_extended, T_path],
            )
            all_identical = all(
                g -> g == first(non_nothing_grids_extended), non_nothing_grids_extended
            )
            Test.@test all_identical
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_grid_extension() = TestGridExtension.test_grid_extension()
