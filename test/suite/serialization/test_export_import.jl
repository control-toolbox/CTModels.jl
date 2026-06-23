module TestExportImport

import Test: Test
import JLD2: JLD2
import JSON3: JSON3
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Solutions: Solutions
import CTModels.Serialization: Serialization

include(joinpath("..", "..", "problems", "TestProblems.jl"))
import .TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ============================================================================
# TEST HELPERS
# ============================================================================

function remove_if_exists(filename::String)
    return isfile(filename) && rm(filename)
end

"""
Compare two trajectories (functions) at given time points.

Returns true if the trajectories are approximately equal at all time points.
"""
function compare_trajectories(
    f1::Function, f2::Function, times::Vector{Float64}; atol::Float64=1e-8
)::Bool
    for t in times
        v1 = f1(t)
        v2 = f2(t)
        if !isapprox(v1, v2; atol=atol)
            return false
        end
    end
    return true
end

"""
Compare two infos dictionaries.

Returns true if both dictionaries have the same keys and values.
Note: Non-serializable types that were converted to strings will not match their originals.
"""
function compare_infos(
    infos1::Dict{Symbol,Any}, infos2::Dict{Symbol,Any}; atol::Float64=1e-10
)::Bool
    # Check same keys
    if Set(keys(infos1)) != Set(keys(infos2))
        return false
    end

    # Compare values
    for (k, v1) in infos1
        v2 = infos2[k]

        # Handle different types
        if typeof(v1) != typeof(v2)
            return false
        end

        if v1 isa Number && v2 isa Number
            if !isapprox(v1, v2; atol=atol)
                return false
            end
        elseif v1 isa AbstractVector && v2 isa AbstractVector
            if length(v1) != length(v2)
                return false
            end
            for (x1, x2) in zip(v1, v2)
                if x1 isa Number && x2 isa Number
                    if !isapprox(x1, x2; atol=atol)
                        return false
                    end
                elseif x1 != x2
                    return false
                end
            end
        elseif v1 isa AbstractDict && v2 isa AbstractDict
            # Recursive comparison for nested dicts
            if !compare_infos(
                Dict{Symbol,Any}(Symbol(k) => v for (k, v) in v1),
                Dict{Symbol,Any}(Symbol(k) => v for (k, v) in v2);
                atol=atol,
            )
                return false
            end
        elseif v1 != v2
            return false
        end
    end

    return true
end

"""
Deep comparison of two Solution objects.

Returns true if all fields are approximately equal within tolerances.
"""
function compare_solutions(
    sol1::Solutions.Solution,
    sol2::Solutions.Solution;
    atol_numerical::Float64=1e-10,
    atol_trajectories::Float64=1e-8,
)::Bool
    # Compare scalar fields
    if !isapprox(Solutions.objective(sol1), Solutions.objective(sol2); atol=atol_numerical)
        return false
    end
    if Solutions.iterations(sol1) != Solutions.iterations(sol2)
        return false
    end
    if !isapprox(
        Solutions.constraints_violation(sol1),
        Solutions.constraints_violation(sol2);
        atol=atol_numerical,
    )
        return false
    end
    if Solutions.message(sol1) != Solutions.message(sol2)
        return false
    end
    if Solutions.status(sol1) != Solutions.status(sol2)
        return false
    end
    if Solutions.successful(sol1) != Solutions.successful(sol2)
        return false
    end

    # Compare time grid
    T1 = Components.time_grid(sol1)
    T2 = Components.time_grid(sol2)
    if !isapprox(T1, T2; atol=atol_numerical)
        return false
    end

    # Compare variable
    v1 = Components.variable(sol1)
    v2 = Components.variable(sol2)
    if !isapprox(v1, v2; atol=atol_numerical)
        return false
    end

    # Compare trajectories at time grid points
    if !compare_trajectories(
        Components.state(sol1), Components.state(sol2), T1; atol=atol_trajectories
    )
        return false
    end
    if !compare_trajectories(
        Components.control(sol1), Components.control(sol2), T1; atol=atol_trajectories
    )
        return false
    end
    if !compare_trajectories(
        Components.costate(sol1), Components.costate(sol2), T1; atol=atol_trajectories
    )
        return false
    end

    # Compare dual variables
    pcd1 = Solutions.path_constraints_dual(sol1)
    pcd2 = Solutions.path_constraints_dual(sol2)
    if isnothing(pcd1) != isnothing(pcd2)
        return false
    end
    if !isnothing(pcd1) && !compare_trajectories(pcd1, pcd2, T1; atol=atol_trajectories)
        return false
    end

    sclbd1 = Solutions.state_constraints_lb_dual(sol1)
    sclbd2 = Solutions.state_constraints_lb_dual(sol2)
    if isnothing(sclbd1) != isnothing(sclbd2)
        return false
    end
    if !isnothing(sclbd1) &&
        !compare_trajectories(sclbd1, sclbd2, T1; atol=atol_trajectories)
        return false
    end

    scubd1 = Solutions.state_constraints_ub_dual(sol1)
    scubd2 = Solutions.state_constraints_ub_dual(sol2)
    if isnothing(scubd1) != isnothing(scubd2)
        return false
    end
    if !isnothing(scubd1) &&
        !compare_trajectories(scubd1, scubd2, T1; atol=atol_trajectories)
        return false
    end

    cclbd1 = Solutions.control_constraints_lb_dual(sol1)
    cclbd2 = Solutions.control_constraints_lb_dual(sol2)
    if isnothing(cclbd1) != isnothing(cclbd2)
        return false
    end
    if !isnothing(cclbd1) &&
        !compare_trajectories(cclbd1, cclbd2, T1; atol=atol_trajectories)
        return false
    end

    ccubd1 = Solutions.control_constraints_ub_dual(sol1)
    ccubd2 = Solutions.control_constraints_ub_dual(sol2)
    if isnothing(ccubd1) != isnothing(ccubd2)
        return false
    end
    if !isnothing(ccubd1) &&
        !compare_trajectories(ccubd1, ccubd2, T1; atol=atol_trajectories)
        return false
    end

    bcd1 = Solutions.boundary_constraints_dual(sol1)
    bcd2 = Solutions.boundary_constraints_dual(sol2)
    if isnothing(bcd1) != isnothing(bcd2)
        return false
    end
    if !isnothing(bcd1) && !isapprox(bcd1, bcd2; atol=atol_numerical)
        return false
    end

    vclbd1 = Solutions.variable_constraints_lb_dual(sol1)
    vclbd2 = Solutions.variable_constraints_lb_dual(sol2)
    if isnothing(vclbd1) != isnothing(vclbd2)
        return false
    end
    if !isnothing(vclbd1) && !isapprox(vclbd1, vclbd2; atol=atol_numerical)
        return false
    end

    vcubd1 = Solutions.variable_constraints_ub_dual(sol1)
    vcubd2 = Solutions.variable_constraints_ub_dual(sol2)
    if isnothing(vcubd1) != isnothing(vcubd2)
        return false
    end
    if !isnothing(vcubd1) && !isapprox(vcubd1, vcubd2; atol=atol_numerical)
        return false
    end

    # Compare infos
    if !compare_infos(Solutions.infos(sol1), Solutions.infos(sol2); atol=atol_numerical)
        return false
    end

    return true
end

# ============================================================================
# MAIN TEST FUNCTION
# ============================================================================

function test_export_import()
    Test.@testset "Export/Import Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # INTEGRATION TESTS - Basic Round-Trip with TestProblems
        # ====================================================================

        Test.@testset "JSON round-trip: TestProblems.solution_example (matrix)" begin
            ocp, sol = TestProblems.solution_example()

            Serialization.export_ocp_solution(sol; filename="solution_test", format=:JSON)
            sol_reloaded = Serialization.import_ocp_solution(
                ocp; filename="solution_test", format=:JSON
            )

            Test.@test Solutions.objective(sol) ≈ Solutions.objective(sol_reloaded) atol =
                1e-8
            Test.@test Solutions.iterations(sol) == Solutions.iterations(sol_reloaded)
            Test.@test Solutions.successful(sol) == Solutions.successful(sol_reloaded)
            Test.@test Solutions.status(sol) == Solutions.status(sol_reloaded)

            remove_if_exists("solution_test.json")
        end

        Test.@testset "JSON round-trip: TestProblems.solution_example (function)" begin
            ocp, sol = TestProblems.solution_example(; fun=true)

            Serialization.export_ocp_solution(
                sol; filename="solution_test_fun", format=:JSON
            )
            sol_reloaded = Serialization.import_ocp_solution(
                ocp; filename="solution_test_fun", format=:JSON
            )

            Test.@test Solutions.objective(sol) ≈ Solutions.objective(sol_reloaded) atol =
                1e-8
            Test.@test Solutions.iterations(sol) == Solutions.iterations(sol_reloaded)

            remove_if_exists("solution_test_fun.json")
        end

        Test.@testset "JLD round-trip: TestProblems.solution_example" begin
            ocp, sol = TestProblems.solution_example()

            # Export solution (no more JLD2 warnings!)
            Serialization.export_ocp_solution(sol; filename="solution_test") # default is :JLD
            sol_reloaded = Serialization.import_ocp_solution(
                ocp; filename="solution_test", format=:JLD
            )

            Test.@test Solutions.objective(sol) ≈ Solutions.objective(sol_reloaded) atol =
                1e-8
            Test.@test Solutions.iterations(sol) == Solutions.iterations(sol_reloaded)

            remove_if_exists("solution_test.jld2")
        end

        # ========================================================================
        # Comprehensive JSON tests – all fields with TestProblems.solution_example_dual
        # ========================================================================

        Test.@testset "JSON comprehensive: all fields preserved" begin
            # Use TestProblems.solution_example_dual which has all duals populated
            ocp, sol = TestProblems.solution_example_dual()

            # Export
            Serialization.export_ocp_solution(sol; filename="solution_full", format=:JSON)

            # Read raw JSON to verify structure
            json_string = read("solution_full.json", String)
            blob = JSON3.read(json_string)

            # Verify all expected keys are present
            expected_keys = [
                "time_grid",
                "state",
                "control",
                "variable",
                "costate",
                "objective",
                "iterations",
                "constraints_violation",
                "message",
                "status",
                "successful",
                "path_constraints_dual",
                "state_constraints_lb_dual",
                "state_constraints_ub_dual",
                "control_constraints_lb_dual",
                "control_constraints_ub_dual",
                "boundary_constraints_dual",
                "variable_constraints_lb_dual",
                "variable_constraints_ub_dual",
            ]
            for key in expected_keys
                Test.@test haskey(blob, key)
            end

            # Verify scalar fields
            Test.@test blob["objective"] ≈ Solutions.objective(sol) atol = 1e-10
            Test.@test blob["iterations"] == Solutions.iterations(sol)
            Test.@test blob["constraints_violation"] ≈ Solutions.constraints_violation(sol) atol =
                1e-10
            Test.@test blob["message"] == Solutions.message(sol)
            Test.@test blob["status"] == string(Solutions.status(sol))
            Test.@test blob["successful"] == Solutions.successful(sol)

            # Verify time_grid
            T_orig = Components.time_grid(sol)
            T_json = Vector{Float64}(blob["time_grid"])
            Test.@test length(T_json) == length(T_orig)
            Test.@test T_json ≈ T_orig atol = 1e-10

            # Verify variable
            v_orig = Components.variable(sol)
            v_json = if isempty(blob["variable"])
                Float64[]
            else
                Vector{Float64}(blob["variable"])
            end
            Test.@test v_json ≈ v_orig atol = 1e-10

            # Verify state discretization
            state_json = blob["state"]
            Test.@test length(state_json) == length(T_orig)
            x_func = Components.state(sol)
            for (i, t) in enumerate(T_orig)
                x_expected = x_func(t)
                # After fix: state_json[i] is always a vector (even for 1D states)
                x_from_json = Vector{Float64}(state_json[i])
                # For 1D states, extract scalar to match x_expected type
                if length(x_from_json) == 1 && x_expected isa Number
                    x_from_json = x_from_json[1]
                end
                Test.@test x_from_json ≈ x_expected atol = 1e-8
            end

            # Verify control discretization
            control_json = blob["control"]
            Test.@test length(control_json) == length(T_orig)
            u_func = Components.control(sol)
            for (i, t) in enumerate(T_orig)
                u_expected = u_func(t)
                # After fix: control_json[i] is always a vector (even for 1D controls)
                u_from_json = Vector{Float64}(control_json[i])
                # For 1D controls, extract scalar
                if length(u_from_json) == 1
                    u_from_json = u_from_json[1]
                end
                Test.@test u_from_json ≈ u_expected atol = 1e-8
            end

            # Verify costate discretization
            costate_json = blob["costate"]
            Test.@test length(costate_json) == length(T_orig)
            p_func = Components.costate(sol)
            for (i, t) in enumerate(T_orig)
                p_expected = p_func(t)
                # After fix: costate_json[i] is always a vector
                p_from_json = Vector{Float64}(costate_json[i])
                # For 1D costates, extract scalar to match p_expected type
                if length(p_from_json) == 1 && p_expected isa Number
                    p_from_json = p_from_json[1]
                end
                Test.@test p_from_json ≈ p_expected atol = 1e-8
            end

            # Verify path_constraints_dual if present
            pcd = Solutions.path_constraints_dual(sol)
            if !isnothing(pcd)
                pcd_json = blob["path_constraints_dual"]
                Test.@test !isnothing(pcd_json)
                Test.@test length(pcd_json) == length(T_orig)
                for (i, t) in enumerate(T_orig)
                    pcd_expected = pcd(t)
                    pcd_from_json = Vector{Float64}(pcd_json[i])
                    Test.@test pcd_from_json ≈ pcd_expected atol = 1e-8
                end
            end

            # Verify boundary_constraints_dual if present
            bcd = Solutions.boundary_constraints_dual(sol)
            if !isnothing(bcd)
                bcd_json = blob["boundary_constraints_dual"]
                Test.@test !isnothing(bcd_json)
                bcd_from_json = Vector{Float64}(bcd_json)
                Test.@test bcd_from_json ≈ bcd atol = 1e-10
            end

            # Verify variable_constraints_lb_dual if present
            vclbd = Solutions.variable_constraints_lb_dual(sol)
            if !isnothing(vclbd)
                vclbd_json = blob["variable_constraints_lb_dual"]
                Test.@test !isnothing(vclbd_json)
                vclbd_from_json = Vector{Float64}(vclbd_json)
                Test.@test vclbd_from_json ≈ vclbd atol = 1e-10
            end

            # Verify variable_constraints_ub_dual if present
            vcubd = Solutions.variable_constraints_ub_dual(sol)
            if !isnothing(vcubd)
                vcubd_json = blob["variable_constraints_ub_dual"]
                Test.@test !isnothing(vcubd_json)
                vcubd_from_json = Vector{Float64}(vcubd_json)
                Test.@test vcubd_from_json ≈ vcubd atol = 1e-10
            end

            remove_if_exists("solution_full.json")
        end

        Test.@testset "JSON import: all fields reconstructed" begin
            ocp, sol = TestProblems.solution_example_dual()

            Serialization.export_ocp_solution(
                sol; filename="solution_import_test", format=:JSON
            )
            sol_reloaded = Serialization.import_ocp_solution(
                ocp; filename="solution_import_test", format=:JSON
            )

            # Scalar fields
            Test.@test Solutions.objective(sol_reloaded) ≈ Solutions.objective(sol) atol =
                1e-8
            Test.@test Solutions.iterations(sol_reloaded) == Solutions.iterations(sol)
            Test.@test Solutions.constraints_violation(sol_reloaded) ≈
                Solutions.constraints_violation(sol) atol = 1e-8
            Test.@test Solutions.message(sol_reloaded) == Solutions.message(sol)
            Test.@test Solutions.status(sol_reloaded) == Solutions.status(sol)
            Test.@test Solutions.successful(sol_reloaded) == Solutions.successful(sol)

            # Time grid
            Test.@test Components.time_grid(sol_reloaded) ≈ Components.time_grid(sol) atol =
                1e-10

            # Metadata: dimensions, names, components and time labels
            Test.@test Models.state_dimension(sol_reloaded) == Models.state_dimension(sol)
            Test.@test Models.control_dimension(sol_reloaded) ==
                Models.control_dimension(sol)
            Test.@test Models.variable_dimension(sol_reloaded) ==
                Models.variable_dimension(sol)

            Test.@test Models.state_name(sol_reloaded) == Models.state_name(sol)
            Test.@test Models.control_name(sol_reloaded) == Models.control_name(sol)
            Test.@test Models.variable_name(sol_reloaded) == Models.variable_name(sol)

            Test.@test Models.state_components(sol_reloaded) == Models.state_components(sol)
            Test.@test Models.control_components(sol_reloaded) ==
                Models.control_components(sol)
            Test.@test Models.variable_components(sol_reloaded) ==
                Models.variable_components(sol)

            Test.@test Components.initial_time_name(sol_reloaded) ==
                Components.initial_time_name(sol)
            Test.@test Components.final_time_name(sol_reloaded) ==
                Components.final_time_name(sol)
            Test.@test Components.time_name(sol_reloaded) == Components.time_name(sol)

            # Variable
            Test.@test Components.variable(sol_reloaded) ≈ Components.variable(sol) atol =
                1e-10

            # State at sample times
            T = Components.time_grid(sol)
            x_orig = Components.state(sol)
            x_reload = Components.state(sol_reloaded)
            for t in T
                Test.@test x_reload(t) ≈ x_orig(t) atol = 1e-8
            end

            # Control at sample times
            u_orig = Components.control(sol)
            u_reload = Components.control(sol_reloaded)
            for t in T
                Test.@test u_reload(t) ≈ u_orig(t) atol = 1e-8
            end

            # Costate at sample times
            p_orig = Components.costate(sol)
            p_reload = Components.costate(sol_reloaded)
            for t in T
                Test.@test p_reload(t) ≈ p_orig(t) atol = 1e-8
            end

            # Path constraints dual
            pcd_orig = Solutions.path_constraints_dual(sol)
            pcd_reload = Solutions.path_constraints_dual(sol_reloaded)
            if !isnothing(pcd_orig)
                Test.@test !isnothing(pcd_reload)
                for t in T
                    Test.@test pcd_reload(t) ≈ pcd_orig(t) atol = 1e-8
                end
            else
                Test.@test isnothing(pcd_reload)
            end

            # Boundary constraints dual
            bcd_orig = Solutions.boundary_constraints_dual(sol)
            bcd_reload = Solutions.boundary_constraints_dual(sol_reloaded)
            if !isnothing(bcd_orig)
                Test.@test !isnothing(bcd_reload)
                Test.@test bcd_reload ≈ bcd_orig atol = 1e-10
            else
                Test.@test isnothing(bcd_reload)
            end

            # State constraints lb dual
            sclbd_orig = Solutions.state_constraints_lb_dual(sol)
            sclbd_reload = Solutions.state_constraints_lb_dual(sol_reloaded)
            if !isnothing(sclbd_orig)
                Test.@test !isnothing(sclbd_reload)
                for t in T
                    Test.@test sclbd_reload(t) ≈ sclbd_orig(t) atol = 1e-8
                end
            else
                Test.@test isnothing(sclbd_reload)
            end

            # State constraints ub dual
            scubd_orig = Solutions.state_constraints_ub_dual(sol)
            scubd_reload = Solutions.state_constraints_ub_dual(sol_reloaded)
            if !isnothing(scubd_orig)
                Test.@test !isnothing(scubd_reload)
                for t in T
                    Test.@test scubd_reload(t) ≈ scubd_orig(t) atol = 1e-8
                end
            else
                Test.@test isnothing(scubd_reload)
            end

            # Control constraints lb dual
            cclbd_orig = Solutions.control_constraints_lb_dual(sol)
            cclbd_reload = Solutions.control_constraints_lb_dual(sol_reloaded)
            if !isnothing(cclbd_orig)
                Test.@test !isnothing(cclbd_reload)
                for t in T
                    Test.@test cclbd_reload(t) ≈ cclbd_orig(t) atol = 1e-8
                end
            else
                Test.@test isnothing(cclbd_reload)
            end

            # Control constraints ub dual
            ccubd_orig = Solutions.control_constraints_ub_dual(sol)
            ccubd_reload = Solutions.control_constraints_ub_dual(sol_reloaded)
            if !isnothing(ccubd_orig)
                Test.@test !isnothing(ccubd_reload)
                for t in T
                    Test.@test ccubd_reload(t) ≈ ccubd_orig(t) atol = 1e-8
                end
            else
                Test.@test isnothing(ccubd_reload)
            end

            # Variable constraints lb dual
            vclbd_orig = Solutions.variable_constraints_lb_dual(sol)
            vclbd_reload = Solutions.variable_constraints_lb_dual(sol_reloaded)
            if !isnothing(vclbd_orig)
                Test.@test !isnothing(vclbd_reload)
                Test.@test vclbd_reload ≈ vclbd_orig atol = 1e-10
            else
                Test.@test isnothing(vclbd_reload)
            end

            # Variable constraints ub dual
            vcubd_orig = Solutions.variable_constraints_ub_dual(sol)
            vcubd_reload = Solutions.variable_constraints_ub_dual(sol_reloaded)
            if !isnothing(vcubd_orig)
                Test.@test !isnothing(vcubd_reload)
                Test.@test vcubd_reload ≈ vcubd_orig atol = 1e-10
            else
                Test.@test isnothing(vcubd_reload)
            end

            remove_if_exists("solution_import_test.json")
        end

        # ========================================================================
        # Edge cases
        # ========================================================================

        Test.@testset "JSON: solution with all duals nothing" begin
            # TestProblems.solution_example has no duals
            ocp, sol = TestProblems.solution_example()

            Serialization.export_ocp_solution(
                sol; filename="solution_no_duals", format=:JSON
            )

            # Read raw JSON
            json_string = read("solution_no_duals.json", String)
            blob = JSON3.read(json_string)

            # Verify dual fields are null
            Test.@test isnothing(blob["path_constraints_dual"])
            Test.@test isnothing(blob["boundary_constraints_dual"])
            Test.@test isnothing(blob["state_constraints_lb_dual"])
            Test.@test isnothing(blob["state_constraints_ub_dual"])
            Test.@test isnothing(blob["control_constraints_lb_dual"])
            Test.@test isnothing(blob["control_constraints_ub_dual"])
            Test.@test isnothing(blob["variable_constraints_lb_dual"])
            Test.@test isnothing(blob["variable_constraints_ub_dual"])

            # Import and verify duals are nothing
            sol_reloaded = Serialization.import_ocp_solution(
                ocp; filename="solution_no_duals", format=:JSON
            )
            Test.@test isnothing(Solutions.path_constraints_dual(sol_reloaded))
            Test.@test isnothing(Solutions.boundary_constraints_dual(sol_reloaded))
            Test.@test isnothing(Solutions.state_constraints_lb_dual(sol_reloaded))
            Test.@test isnothing(Solutions.state_constraints_ub_dual(sol_reloaded))
            Test.@test isnothing(Solutions.control_constraints_lb_dual(sol_reloaded))
            Test.@test isnothing(Solutions.control_constraints_ub_dual(sol_reloaded))
            Test.@test isnothing(Solutions.variable_constraints_lb_dual(sol_reloaded))
            Test.@test isnothing(Solutions.variable_constraints_ub_dual(sol_reloaded))

            remove_if_exists("solution_no_duals.json")
        end

        Test.@testset "JSON: solver infos dict preserved" begin
            # Create a solution with custom infos
            ocp, sol_base = TestProblems.solution_example()
            T = Components.time_grid(sol_base)

            # Build a new solution with custom infos
            x = Components.state(sol_base)
            u = Components.control(sol_base)
            p = Components.costate(sol_base)
            v = Components.variable(sol_base)

            custom_infos = Dict{Symbol,Any}(
                :solver_name => "TestSolver",
                :tolerance => 1e-6,
                :max_iterations => 1000,
                :converged => true,
                :residuals => [1e-3, 1e-5, 1e-8],
                :nested => Dict{Symbol,Any}(:a => 1, :b => "test"),
            )

            sol = Solutions.build_solution(
                ocp,
                Vector{Float64}(T),
                x,
                u,
                isa(v, Number) ? [v] : v,
                p;
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
                infos=custom_infos,
            )

            # Verify infos is set correctly
            Test.@test Solutions.infos(sol)[:solver_name] == "TestSolver"
            Test.@test Solutions.infos(sol)[:tolerance] == 1e-6

            # Export and import
            Serialization.export_ocp_solution(
                sol; filename="solution_with_infos", format=:JSON
            )
            sol_reloaded = Serialization.import_ocp_solution(
                ocp; filename="solution_with_infos", format=:JSON
            )

            # Verify infos is preserved
            reloaded_infos = Solutions.infos(sol_reloaded)
            Test.@test reloaded_infos[:solver_name] == "TestSolver"
            Test.@test reloaded_infos[:tolerance] == 1e-6
            Test.@test reloaded_infos[:max_iterations] == 1000
            Test.@test reloaded_infos[:converged] == true
            Test.@test reloaded_infos[:residuals] == [1e-3, 1e-5, 1e-8]
            Test.@test reloaded_infos[:nested][:a] == 1
            Test.@test reloaded_infos[:nested][:b] == "test"

            # Verify JSON structure
            json_string = read("solution_with_infos.json", String)
            blob = JSON3.read(json_string)
            Test.@test haskey(blob, "infos")
            Test.@test blob["infos"]["solver_name"] == "TestSolver"
            Test.@test blob["infos"]["tolerance"] == 1e-6

            remove_if_exists("solution_with_infos.json")
        end

        # ========================================================================
        # Idempotence tests – verify stability across multiple export/import cycles
        # ========================================================================

        Test.@testset "JSON idempotence: double cycle (solution_example_dual)" verbose =
            VERBOSE showtiming = SHOWTIMING begin
            ocp, sol0 = TestProblems.solution_example_dual()

            # First cycle: sol0 → export → import → sol1
            Serialization.export_ocp_solution(
                sol0; filename="idempotence_json_1", format=:JSON
            )
            sol1 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_json_1", format=:JSON
            )

            # Second cycle: sol1 → export → import → sol2
            Serialization.export_ocp_solution(
                sol1; filename="idempotence_json_2", format=:JSON
            )
            sol2 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_json_2", format=:JSON
            )

            # Verify idempotence: sol1 ≈ sol2 (no further information loss)
            Test.@test compare_solutions(sol1, sol2)

            remove_if_exists("idempotence_json_1.json")
            remove_if_exists("idempotence_json_2.json")
        end

        Test.@testset "JSON idempotence: triple cycle (solution_example_dual)" verbose =
            VERBOSE showtiming = SHOWTIMING begin
            ocp, sol0 = TestProblems.solution_example_dual()

            # First cycle
            Serialization.export_ocp_solution(
                sol0; filename="idempotence_json_t1", format=:JSON
            )
            sol1 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_json_t1", format=:JSON
            )

            # Second cycle
            Serialization.export_ocp_solution(
                sol1; filename="idempotence_json_t2", format=:JSON
            )
            sol2 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_json_t2", format=:JSON
            )

            # Third cycle
            Serialization.export_ocp_solution(
                sol2; filename="idempotence_json_t3", format=:JSON
            )
            sol3 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_json_t3", format=:JSON
            )

            # Verify convergence: sol2 ≈ sol3
            Test.@test compare_solutions(sol2, sol3)

            remove_if_exists("idempotence_json_t1.json")
            remove_if_exists("idempotence_json_t2.json")
            remove_if_exists("idempotence_json_t3.json")
        end

        Test.@testset "JSON idempotence: double cycle (solution_example no duals)" verbose =
            VERBOSE showtiming = SHOWTIMING begin
            ocp, sol0 = TestProblems.solution_example()

            # First cycle
            Serialization.export_ocp_solution(
                sol0; filename="idempotence_json_multi1", format=:JSON
            )
            sol1 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_json_multi1", format=:JSON
            )

            # Second cycle
            Serialization.export_ocp_solution(
                sol1; filename="idempotence_json_multi2", format=:JSON
            )
            sol2 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_json_multi2", format=:JSON
            )

            # Verify idempotence
            Test.@test compare_solutions(sol1, sol2)

            remove_if_exists("idempotence_json_multi1.json")
            remove_if_exists("idempotence_json_multi2.json")
        end

        Test.@testset "JSON idempotence: with complex infos" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            ocp, sol_base = TestProblems.solution_example()
            T = Components.time_grid(sol_base)

            # Build solution with complex infos
            x = Components.state(sol_base)
            u = Components.control(sol_base)
            p = Components.costate(sol_base)
            v = Components.variable(sol_base)

            complex_infos = Dict{Symbol,Any}(
                :solver_name => "TestSolver",
                :tolerance => 1e-6,
                :max_iterations => 1000,
                :converged => true,
                :residuals => [1e-3, 1e-5, 1e-8],
                :nested => Dict{Symbol,Any}(:a => 1, :b => "test", :c => [1.0, 2.0, 3.0]),
                :symbol_value => :optimal,
            )

            sol0 = Solutions.build_solution(
                ocp,
                Vector{Float64}(T),
                x,
                u,
                isa(v, Number) ? [v] : v,
                p;
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
                infos=complex_infos,
            )

            # First cycle
            Serialization.export_ocp_solution(
                sol0; filename="idempotence_json_ci1", format=:JSON
            )
            sol1 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_json_ci1", format=:JSON
            )

            # Second cycle
            Serialization.export_ocp_solution(
                sol1; filename="idempotence_json_ci2", format=:JSON
            )
            sol2 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_json_ci2", format=:JSON
            )

            # Verify idempotence
            Test.@test compare_solutions(sol1, sol2)

            # Verify infos preservation
            infos2 = Solutions.infos(sol2)
            Test.@test infos2[:solver_name] == "TestSolver"
            Test.@test infos2[:tolerance] == 1e-6
            Test.@test infos2[:max_iterations] == 1000
            Test.@test infos2[:converged] == true
            Test.@test infos2[:residuals] == [1e-3, 1e-5, 1e-8]
            Test.@test infos2[:nested][:a] == 1
            Test.@test infos2[:nested][:b] == "test"
            Test.@test infos2[:nested][:c] == [1.0, 2.0, 3.0]
            # Symbol is now preserved with type metadata!
            Test.@test infos2[:symbol_value] == :optimal
            Test.@test infos2[:symbol_value] isa Symbol

            remove_if_exists("idempotence_json_ci1.json")
            remove_if_exists("idempotence_json_ci2.json")
        end

        Test.@testset "JLD2 idempotence: double cycle (solution_example_dual)" verbose =
            VERBOSE showtiming = SHOWTIMING begin
            ocp, sol0 = TestProblems.solution_example_dual()

            # First cycle: sol0 → export → import → sol1
            Serialization.export_ocp_solution(
                sol0; filename="idempotence_jld_1", format=:JLD
            )
            sol1 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_jld_1", format=:JLD
            )

            # Second cycle: sol1 → export → import → sol2
            Serialization.export_ocp_solution(
                sol1; filename="idempotence_jld_2", format=:JLD
            )
            sol2 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_jld_2", format=:JLD
            )

            # Verify idempotence: sol1 ≈ sol2
            Test.@test compare_solutions(sol1, sol2)

            remove_if_exists("idempotence_jld_1.jld2")
            remove_if_exists("idempotence_jld_2.jld2")
        end

        Test.@testset "JLD2 idempotence: triple cycle (solution_example_dual)" verbose =
            VERBOSE showtiming = SHOWTIMING begin
            ocp, sol0 = TestProblems.solution_example_dual()

            # First cycle
            Serialization.export_ocp_solution(
                sol0; filename="idempotence_jld_t1", format=:JLD
            )
            sol1 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_jld_t1", format=:JLD
            )

            # Second cycle
            Serialization.export_ocp_solution(
                sol1; filename="idempotence_jld_t2", format=:JLD
            )
            sol2 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_jld_t2", format=:JLD
            )

            # Third cycle
            Serialization.export_ocp_solution(
                sol2; filename="idempotence_jld_t3", format=:JLD
            )
            sol3 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_jld_t3", format=:JLD
            )

            # Verify convergence: sol2 ≈ sol3
            Test.@test compare_solutions(sol2, sol3)

            remove_if_exists("idempotence_jld_t1.jld2")
            remove_if_exists("idempotence_jld_t2.jld2")
            remove_if_exists("idempotence_jld_t3.jld2")
        end

        Test.@testset "JLD2 idempotence: double cycle (solution_example no duals)" verbose =
            VERBOSE showtiming = SHOWTIMING begin
            ocp, sol0 = TestProblems.solution_example()

            # First cycle
            Serialization.export_ocp_solution(
                sol0; filename="idempotence_jld_multi1", format=:JLD
            )
            sol1 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_jld_multi1", format=:JLD
            )

            # Second cycle
            Serialization.export_ocp_solution(
                sol1; filename="idempotence_jld_multi2", format=:JLD
            )
            sol2 = Serialization.import_ocp_solution(
                ocp; filename="idempotence_jld_multi2", format=:JLD
            )

            # Verify idempotence
            Test.@test compare_solutions(sol1, sol2)

            remove_if_exists("idempotence_jld_multi1.jld2")
            remove_if_exists("idempotence_jld_multi2.jld2")
        end

        # ========================================================================
        # Empirical investigation: stack() behavior
        # ========================================================================

        Test.@testset "JSON stack() behavior investigation" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            ocp, sol = TestProblems.solution_example()

            # Export to JSON
            Serialization.export_ocp_solution(
                sol; filename="stack_investigation", format=:JSON
            )

            # Read and observe what stack() returns
            json_string = read("stack_investigation.json", String)
            blob = JSON3.read(json_string)

            # Test state (multi-dimensional: 2D in TestProblems.solution_example)
            # Now exported as Vector{Vector}, so stack() returns Matrix
            state_stacked = stack(blob["state"]; dims=1)
            Test.@test state_stacked isa Matrix  # Vector{Vector} → Matrix
            Test.@test size(state_stacked, 2) == 2  # 2D state

            # Test control (1-dimensional in TestProblems.solution_example)
            # Now exported as Vector{Vector}, so stack() returns Matrix (N×1)
            control_stacked = stack(blob["control"]; dims=1)
            Test.@test control_stacked isa Matrix  # Vector{Vector} → Matrix
            Test.@test size(control_stacked, 2) == 1  # 1D control

            # Test costate (multi-dimensional: 2D)
            costate_stacked = stack(blob["costate"]; dims=1)
            Test.@test costate_stacked isa Matrix  # Vector{Vector} → Matrix
            Test.@test size(costate_stacked, 2) == 2  # 2D costate

            # Verify import works correctly (indirect test of _json_array_to_matrix)
            sol_reloaded = Serialization.import_ocp_solution(
                ocp; filename="stack_investigation", format=:JSON
            )
            Test.@test Solutions.objective(sol) ≈ Solutions.objective(sol_reloaded) atol =
                1e-8

            remove_if_exists("stack_investigation.json")
        end

        # ========================================================================
        # CONTROL INTERPOLATION SERIALIZATION TESTS
        # ========================================================================

        Test.@testset "Control interpolation preservation: JSON" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            ocp, sol_base = TestProblems.solution_example()
            T = Components.time_grid(sol_base)

            # Extract trajectories
            x = Components.state(sol_base)
            u = Components.control(sol_base)
            p = Components.costate(sol_base)
            v = Components.variable(sol_base)

            # Test with constant interpolation (default)
            sol_constant = Solutions.build_solution(
                ocp,
                Vector{Float64}(T),
                x,
                u,
                isa(v, Number) ? [v] : v,
                p;
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
                control_interpolation=:constant,
            )

            # Export and import
            Serialization.export_ocp_solution(
                sol_constant; filename="test_constant_interp", format=:JSON
            )
            sol_constant_reloaded = Serialization.import_ocp_solution(
                ocp; filename="test_constant_interp", format=:JSON
            )

            # Verify interpolation is preserved
            Test.@test Solutions.control_interpolation(sol_constant) == :constant
            Test.@test Solutions.control_interpolation(sol_constant_reloaded) == :constant

            # Test with linear interpolation
            sol_linear = Solutions.build_solution(
                ocp,
                Vector{Float64}(T),
                x,
                u,
                isa(v, Number) ? [v] : v,
                p;
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
                control_interpolation=:linear,
            )

            # Export and import
            Serialization.export_ocp_solution(
                sol_linear; filename="test_linear_interp", format=:JSON
            )
            sol_linear_reloaded = Serialization.import_ocp_solution(
                ocp; filename="test_linear_interp", format=:JSON
            )

            # Verify interpolation is preserved
            Test.@test Solutions.control_interpolation(sol_linear) == :linear
            Test.@test Solutions.control_interpolation(sol_linear_reloaded) == :linear

            # Verify control behavior is preserved (linear vs constant)
            u_const = Components.control(sol_constant_reloaded)
            u_linear = Components.control(sol_linear_reloaded)

            # At midpoint, linear should differ from constant
            if length(T) >= 2
                # For linear interpolation, value at midpoint should be interpolated
                # For constant interpolation, value should be from previous interval
                # This test verifies the interpolation type is correctly applied
                Test.@test Solutions.control_interpolation(sol_constant_reloaded) ==
                    :constant
                Test.@test Solutions.control_interpolation(sol_linear_reloaded) == :linear
            end

            remove_if_exists("test_constant_interp.json")
            remove_if_exists("test_linear_interp.json")
        end

        Test.@testset "Control interpolation preservation: JLD2" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            ocp, sol_base = TestProblems.solution_example()
            T = Components.time_grid(sol_base)

            # Extract trajectories
            x = Components.state(sol_base)
            u = Components.control(sol_base)
            p = Components.costate(sol_base)
            v = Components.variable(sol_base)

            # Test with constant interpolation (default)
            sol_constant = Solutions.build_solution(
                ocp,
                Vector{Float64}(T),
                x,
                u,
                isa(v, Number) ? [v] : v,
                p;
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
                control_interpolation=:constant,
            )

            # Export and import
            Serialization.export_ocp_solution(
                sol_constant; filename="test_constant_interp", format=:JLD
            )
            sol_constant_reloaded = Serialization.import_ocp_solution(
                ocp; filename="test_constant_interp", format=:JLD
            )

            # Verify interpolation is preserved
            Test.@test Solutions.control_interpolation(sol_constant) == :constant
            Test.@test Solutions.control_interpolation(sol_constant_reloaded) == :constant

            # Test with linear interpolation
            sol_linear = Solutions.build_solution(
                ocp,
                Vector{Float64}(T),
                x,
                u,
                isa(v, Number) ? [v] : v,
                p;
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
                control_interpolation=:linear,
            )

            # Export and import
            Serialization.export_ocp_solution(
                sol_linear; filename="test_linear_interp", format=:JLD
            )
            sol_linear_reloaded = Serialization.import_ocp_solution(
                ocp; filename="test_linear_interp", format=:JLD
            )

            # Verify interpolation is preserved
            Test.@test Solutions.control_interpolation(sol_linear) == :linear
            Test.@test Solutions.control_interpolation(sol_linear_reloaded) == :linear

            # Verify control behavior is preserved (linear vs constant)
            u_const = Components.control(sol_constant_reloaded)
            u_linear = Components.control(sol_linear_reloaded)

            # At midpoint, linear should differ from constant
            if length(T) >= 2
                # For linear interpolation, value at midpoint should be interpolated
                # For constant interpolation, value should be from previous interval
                # This test verifies the interpolation type is correctly applied
                Test.@test Solutions.control_interpolation(sol_constant_reloaded) ==
                    :constant
                Test.@test Solutions.control_interpolation(sol_linear_reloaded) == :linear
            end

            remove_if_exists("test_constant_interp.jld2")
            remove_if_exists("test_linear_interp.jld2")
        end

        Test.@testset "Missing control_interpolation raises ParsingError" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            ocp, sol_base = TestProblems.solution_example()

            # Export a valid solution
            Serialization.export_ocp_solution(
                sol_base; filename="test_missing_interp", format=:JSON
            )

            # Simulate a legacy file by removing control_interpolation from JSON
            json_string = read("test_missing_interp.json", String)
            json_data = JSON3.read(json_string)
            json_without = Dict{String,Any}(
                string(k) => v for
                (k, v) in json_data if string(k) != "control_interpolation"
            )
            open("test_missing_interp.json", "w") do f
                return JSON3.write(f, json_without)
            end

            # Import must now raise a KeyError (missing required field)
            Test.@test_throws KeyError Serialization.import_ocp_solution(
                ocp; filename="test_missing_interp", format=:JSON
            )

            remove_if_exists("test_missing_interp.json")
        end

        Test.@testset "Control interpolation mixed format compatibility" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            ocp, sol_base = TestProblems.solution_example()
            T = Components.time_grid(sol_base)

            # Extract trajectories
            x = Components.state(sol_base)
            u = Components.control(sol_base)
            p = Components.costate(sol_base)
            v = Components.variable(sol_base)

            # Create solution with linear interpolation
            sol_linear = Solutions.build_solution(
                ocp,
                Vector{Float64}(T),
                x,
                u,
                isa(v, Number) ? [v] : v,
                p;
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
                control_interpolation=:linear,
            )

            # Export to JSON
            Serialization.export_ocp_solution(
                sol_linear; filename="test_mixed_json", format=:JSON
            )
            sol_json_reloaded = Serialization.import_ocp_solution(
                ocp; filename="test_mixed_json", format=:JSON
            )

            # Export to JLD2
            Serialization.export_ocp_solution(
                sol_linear; filename="test_mixed_jld", format=:JLD
            )
            sol_jld_reloaded = Serialization.import_ocp_solution(
                ocp; filename="test_mixed_jld", format=:JLD
            )

            # Both should preserve linear interpolation
            Test.@test Solutions.control_interpolation(sol_linear) == :linear
            Test.@test Solutions.control_interpolation(sol_json_reloaded) == :linear
            Test.@test Solutions.control_interpolation(sol_jld_reloaded) == :linear

            # Verify control functions behave identically
            u_orig = Components.control(sol_linear)
            u_json = Components.control(sol_json_reloaded)
            u_jld = Components.control(sol_jld_reloaded)

            for t in T[1:min(end, 3)]  # Test first few points
                Test.@test u_orig(t) ≈ u_json(t) atol=1e-10
                Test.@test u_orig(t) ≈ u_jld(t) atol=1e-10
            end

            remove_if_exists("test_mixed_json.json")
            remove_if_exists("test_mixed_jld.jld2")
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_export_import() = TestExportImport.test_export_import()
