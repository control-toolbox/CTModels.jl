module TestExportImport

using Test
using CTModels
using Main.TestProblems
using Main.TestOptions: VERBOSE, SHOWTIMING
using JLD2
using JSON3

# ============================================================================
# TEST HELPERS
# ============================================================================

function remove_if_exists(filename::String)
    isfile(filename) && rm(filename)
end

"""
Compare two trajectories (functions) at given time points.

Returns true if the trajectories are approximately equal at all time points.
"""
function compare_trajectories(
    f1::Function,
    f2::Function,
    times::Vector{Float64};
    atol::Float64=1e-8,
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
    sol1::CTModels.Solution,
    sol2::CTModels.Solution;
    atol_numerical::Float64=1e-10,
    atol_trajectories::Float64=1e-8,
)::Bool
    # Compare scalar fields
    if !isapprox(CTModels.objective(sol1), CTModels.objective(sol2); atol=atol_numerical)
        return false
    end
    if CTModels.iterations(sol1) != CTModels.iterations(sol2)
        return false
    end
    if !isapprox(
        CTModels.constraints_violation(sol1),
        CTModels.constraints_violation(sol2);
        atol=atol_numerical,
    )
        return false
    end
    if CTModels.message(sol1) != CTModels.message(sol2)
        return false
    end
    if CTModels.status(sol1) != CTModels.status(sol2)
        return false
    end
    if CTModels.successful(sol1) != CTModels.successful(sol2)
        return false
    end

    # Compare time grid
    T1 = CTModels.time_grid(sol1)
    T2 = CTModels.time_grid(sol2)
    if !isapprox(T1, T2; atol=atol_numerical)
        return false
    end

    # Compare variable
    v1 = CTModels.variable(sol1)
    v2 = CTModels.variable(sol2)
    if !isapprox(v1, v2; atol=atol_numerical)
        return false
    end

    # Compare trajectories at time grid points
    if !compare_trajectories(
        CTModels.state(sol1), CTModels.state(sol2), T1; atol=atol_trajectories
    )
        return false
    end
    if !compare_trajectories(
        CTModels.control(sol1), CTModels.control(sol2), T1; atol=atol_trajectories
    )
        return false
    end
    if !compare_trajectories(
        CTModels.costate(sol1), CTModels.costate(sol2), T1; atol=atol_trajectories
    )
        return false
    end

    # Compare dual variables
    pcd1 = CTModels.path_constraints_dual(sol1)
    pcd2 = CTModels.path_constraints_dual(sol2)
    if isnothing(pcd1) != isnothing(pcd2)
        return false
    end
    if !isnothing(pcd1) &&
       !compare_trajectories(pcd1, pcd2, T1; atol=atol_trajectories)
        return false
    end

    sclbd1 = CTModels.state_constraints_lb_dual(sol1)
    sclbd2 = CTModels.state_constraints_lb_dual(sol2)
    if isnothing(sclbd1) != isnothing(sclbd2)
        return false
    end
    if !isnothing(sclbd1) &&
       !compare_trajectories(sclbd1, sclbd2, T1; atol=atol_trajectories)
        return false
    end

    scubd1 = CTModels.state_constraints_ub_dual(sol1)
    scubd2 = CTModels.state_constraints_ub_dual(sol2)
    if isnothing(scubd1) != isnothing(scubd2)
        return false
    end
    if !isnothing(scubd1) &&
       !compare_trajectories(scubd1, scubd2, T1; atol=atol_trajectories)
        return false
    end

    cclbd1 = CTModels.control_constraints_lb_dual(sol1)
    cclbd2 = CTModels.control_constraints_lb_dual(sol2)
    if isnothing(cclbd1) != isnothing(cclbd2)
        return false
    end
    if !isnothing(cclbd1) &&
       !compare_trajectories(cclbd1, cclbd2, T1; atol=atol_trajectories)
        return false
    end

    ccubd1 = CTModels.control_constraints_ub_dual(sol1)
    ccubd2 = CTModels.control_constraints_ub_dual(sol2)
    if isnothing(ccubd1) != isnothing(ccubd2)
        return false
    end
    if !isnothing(ccubd1) &&
       !compare_trajectories(ccubd1, ccubd2, T1; atol=atol_trajectories)
        return false
    end

    bcd1 = CTModels.boundary_constraints_dual(sol1)
    bcd2 = CTModels.boundary_constraints_dual(sol2)
    if isnothing(bcd1) != isnothing(bcd2)
        return false
    end
    if !isnothing(bcd1) && !isapprox(bcd1, bcd2; atol=atol_numerical)
        return false
    end

    vclbd1 = CTModels.variable_constraints_lb_dual(sol1)
    vclbd2 = CTModels.variable_constraints_lb_dual(sol2)
    if isnothing(vclbd1) != isnothing(vclbd2)
        return false
    end
    if !isnothing(vclbd1) && !isapprox(vclbd1, vclbd2; atol=atol_numerical)
        return false
    end

    vcubd1 = CTModels.variable_constraints_ub_dual(sol2)
    vcubd2 = CTModels.variable_constraints_ub_dual(sol2)
    if isnothing(vcubd1) != isnothing(vcubd2)
        return false
    end
    if !isnothing(vcubd1) && !isapprox(vcubd1, vcubd2; atol=atol_numerical)
        return false
    end

    # Compare infos
    if !compare_infos(CTModels.infos(sol1), CTModels.infos(sol2); atol=atol_numerical)
        return false
    end

    return true
end

# ============================================================================
# MAIN TEST FUNCTION
# ============================================================================

function test_export_import()

    # ========================================================================
    # Integration tests – basic round-trip with solution_example
    # ========================================================================

    Test.@testset "JSON round-trip: solution_example (matrix)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp, sol = solution_example()

        CTModels.export_ocp_solution(sol; filename="solution_test", format=:JSON)
        sol_reloaded = CTModels.import_ocp_solution(
            ocp; filename="solution_test", format=:JSON
        )

        Test.@test CTModels.objective(sol) ≈ CTModels.objective(sol_reloaded) atol = 1e-8
        Test.@test CTModels.iterations(sol) == CTModels.iterations(sol_reloaded)
        Test.@test CTModels.successful(sol) == CTModels.successful(sol_reloaded)
        Test.@test CTModels.status(sol) == CTModels.status(sol_reloaded)

        remove_if_exists("solution_test.json")
    end

    Test.@testset "JSON round-trip: solution_example (function)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp, sol = solution_example(; fun=true)

        CTModels.export_ocp_solution(sol; filename="solution_test_fun", format=:JSON)
        sol_reloaded = CTModels.import_ocp_solution(
            ocp; filename="solution_test_fun", format=:JSON
        )

        Test.@test CTModels.objective(sol) ≈ CTModels.objective(sol_reloaded) atol = 1e-8
        Test.@test CTModels.iterations(sol) == CTModels.iterations(sol_reloaded)

        remove_if_exists("solution_test_fun.json")
    end

    Test.@testset "JLD round-trip: solution_example" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp, sol = solution_example()

        # Export solution (no more JLD2 warnings!)
        CTModels.export_ocp_solution(sol; filename="solution_test") # default is :JLD
        sol_reloaded = CTModels.import_ocp_solution(
            ocp; filename="solution_test", format=:JLD
        )

        Test.@test CTModels.objective(sol) ≈ CTModels.objective(sol_reloaded) atol = 1e-8
        Test.@test CTModels.iterations(sol) == CTModels.iterations(sol_reloaded)

        remove_if_exists("solution_test.jld2")
    end

    # ========================================================================
    # Comprehensive JSON tests – all fields with solution_example_dual
    # ========================================================================

    Test.@testset "JSON comprehensive: all fields preserved" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Use solution_example_dual which has all duals populated
        ocp, sol = solution_example_dual()

        # Export
        CTModels.export_ocp_solution(sol; filename="solution_full", format=:JSON)

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
        Test.@test blob["objective"] ≈ CTModels.objective(sol) atol = 1e-10
        Test.@test blob["iterations"] == CTModels.iterations(sol)
        Test.@test blob["constraints_violation"] ≈ CTModels.constraints_violation(sol) atol = 1e-10
        Test.@test blob["message"] == CTModels.message(sol)
        Test.@test blob["status"] == string(CTModels.status(sol))
        Test.@test blob["successful"] == CTModels.successful(sol)

        # Verify time_grid
        T_orig = CTModels.time_grid(sol)
        T_json = Vector{Float64}(blob["time_grid"])
        Test.@test length(T_json) == length(T_orig)
        Test.@test T_json ≈ T_orig atol = 1e-10

        # Verify variable
        v_orig = CTModels.variable(sol)
        v_json = if isempty(blob["variable"])
            Float64[]
        else
            Vector{Float64}(blob["variable"])
        end
        Test.@test v_json ≈ v_orig atol = 1e-10

        # Verify state discretization
        state_json = blob["state"]
        Test.@test length(state_json) == length(T_orig)
        x_func = CTModels.state(sol)
        for (i, t) in enumerate(T_orig)
            x_expected = x_func(t)
            x_from_json = if state_json[i] isa Number
                state_json[i]
            else
                Vector{Float64}(state_json[i])
            end
            Test.@test x_from_json ≈ x_expected atol = 1e-8
        end

        # Verify control discretization
        control_json = blob["control"]
        Test.@test length(control_json) == length(T_orig)
        u_func = CTModels.control(sol)
        for (i, t) in enumerate(T_orig)
            u_expected = u_func(t)
            u_from_json = if control_json[i] isa Number
                control_json[i]
            else
                Vector{Float64}(control_json[i])
            end
            Test.@test u_from_json ≈ u_expected atol = 1e-8
        end

        # Verify costate discretization
        costate_json = blob["costate"]
        Test.@test length(costate_json) == length(T_orig)
        p_func = CTModels.costate(sol)
        for (i, t) in enumerate(T_orig)
            p_expected = p_func(t)
            p_from_json = if costate_json[i] isa Number
                costate_json[i]
            else
                Vector{Float64}(costate_json[i])
            end
            Test.@test p_from_json ≈ p_expected atol = 1e-8
        end

        # Verify path_constraints_dual if present
        pcd = CTModels.path_constraints_dual(sol)
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
        bcd = CTModels.boundary_constraints_dual(sol)
        if !isnothing(bcd)
            bcd_json = blob["boundary_constraints_dual"]
            Test.@test !isnothing(bcd_json)
            bcd_from_json = Vector{Float64}(bcd_json)
            Test.@test bcd_from_json ≈ bcd atol = 1e-10
        end

        # Verify variable_constraints_lb_dual if present
        vclbd = CTModels.variable_constraints_lb_dual(sol)
        if !isnothing(vclbd)
            vclbd_json = blob["variable_constraints_lb_dual"]
            Test.@test !isnothing(vclbd_json)
            vclbd_from_json = Vector{Float64}(vclbd_json)
            Test.@test vclbd_from_json ≈ vclbd atol = 1e-10
        end

        # Verify variable_constraints_ub_dual if present
        vcubd = CTModels.variable_constraints_ub_dual(sol)
        if !isnothing(vcubd)
            vcubd_json = blob["variable_constraints_ub_dual"]
            Test.@test !isnothing(vcubd_json)
            vcubd_from_json = Vector{Float64}(vcubd_json)
            Test.@test vcubd_from_json ≈ vcubd atol = 1e-10
        end

        remove_if_exists("solution_full.json")
    end

    Test.@testset "JSON import: all fields reconstructed" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp, sol = solution_example_dual()

        CTModels.export_ocp_solution(sol; filename="solution_import_test", format=:JSON)
        sol_reloaded = CTModels.import_ocp_solution(
            ocp; filename="solution_import_test", format=:JSON
        )

        # Scalar fields
        Test.@test CTModels.objective(sol_reloaded) ≈ CTModels.objective(sol) atol = 1e-8
        Test.@test CTModels.iterations(sol_reloaded) == CTModels.iterations(sol)
        Test.@test CTModels.constraints_violation(sol_reloaded) ≈
            CTModels.constraints_violation(sol) atol=1e-8
        Test.@test CTModels.message(sol_reloaded) == CTModels.message(sol)
        Test.@test CTModels.status(sol_reloaded) == CTModels.status(sol)
        Test.@test CTModels.successful(sol_reloaded) == CTModels.successful(sol)

        # Time grid
        Test.@test CTModels.time_grid(sol_reloaded) ≈ CTModels.time_grid(sol) atol = 1e-10

        # Metadata: dimensions, names, components and time labels
        Test.@test CTModels.state_dimension(sol_reloaded) == CTModels.state_dimension(sol)
        Test.@test CTModels.control_dimension(sol_reloaded) == CTModels.control_dimension(sol)
        Test.@test CTModels.variable_dimension(sol_reloaded) == CTModels.variable_dimension(sol)

        Test.@test CTModels.state_name(sol_reloaded) == CTModels.state_name(sol)
        Test.@test CTModels.control_name(sol_reloaded) == CTModels.control_name(sol)
        Test.@test CTModels.variable_name(sol_reloaded) == CTModels.variable_name(sol)

        Test.@test CTModels.state_components(sol_reloaded) == CTModels.state_components(sol)
        Test.@test CTModels.control_components(sol_reloaded) == CTModels.control_components(sol)
        Test.@test CTModels.variable_components(sol_reloaded) ==
            CTModels.variable_components(sol)

        Test.@test CTModels.initial_time_name(sol_reloaded) == CTModels.initial_time_name(sol)
        Test.@test CTModels.final_time_name(sol_reloaded) == CTModels.final_time_name(sol)
        Test.@test CTModels.time_name(sol_reloaded) == CTModels.time_name(sol)

        # Variable
        Test.@test CTModels.variable(sol_reloaded) ≈ CTModels.variable(sol) atol = 1e-10

        # State at sample times
        T = CTModels.time_grid(sol)
        x_orig = CTModels.state(sol)
        x_reload = CTModels.state(sol_reloaded)
        for t in T
            Test.@test x_reload(t) ≈ x_orig(t) atol = 1e-8
        end

        # Control at sample times
        u_orig = CTModels.control(sol)
        u_reload = CTModels.control(sol_reloaded)
        for t in T
            Test.@test u_reload(t) ≈ u_orig(t) atol = 1e-8
        end

        # Costate at sample times
        p_orig = CTModels.costate(sol)
        p_reload = CTModels.costate(sol_reloaded)
        for t in T
            Test.@test p_reload(t) ≈ p_orig(t) atol = 1e-8
        end

        # Path constraints dual
        pcd_orig = CTModels.path_constraints_dual(sol)
        pcd_reload = CTModels.path_constraints_dual(sol_reloaded)
        if !isnothing(pcd_orig)
            Test.@test !isnothing(pcd_reload)
            for t in T
                Test.@test pcd_reload(t) ≈ pcd_orig(t) atol = 1e-8
            end
        else
            Test.@test isnothing(pcd_reload)
        end

        # Boundary constraints dual
        bcd_orig = CTModels.boundary_constraints_dual(sol)
        bcd_reload = CTModels.boundary_constraints_dual(sol_reloaded)
        if !isnothing(bcd_orig)
            Test.@test !isnothing(bcd_reload)
            Test.@test bcd_reload ≈ bcd_orig atol = 1e-10
        else
            Test.@test isnothing(bcd_reload)
        end

        # State constraints lb dual
        sclbd_orig = CTModels.state_constraints_lb_dual(sol)
        sclbd_reload = CTModels.state_constraints_lb_dual(sol_reloaded)
        if !isnothing(sclbd_orig)
            Test.@test !isnothing(sclbd_reload)
            for t in T
                Test.@test sclbd_reload(t) ≈ sclbd_orig(t) atol = 1e-8
            end
        else
            Test.@test isnothing(sclbd_reload)
        end

        # State constraints ub dual
        scubd_orig = CTModels.state_constraints_ub_dual(sol)
        scubd_reload = CTModels.state_constraints_ub_dual(sol_reloaded)
        if !isnothing(scubd_orig)
            Test.@test !isnothing(scubd_reload)
            for t in T
                Test.@test scubd_reload(t) ≈ scubd_orig(t) atol = 1e-8
            end
        else
            Test.@test isnothing(scubd_reload)
        end

        # Control constraints lb dual
        cclbd_orig = CTModels.control_constraints_lb_dual(sol)
        cclbd_reload = CTModels.control_constraints_lb_dual(sol_reloaded)
        if !isnothing(cclbd_orig)
            Test.@test !isnothing(cclbd_reload)
            for t in T
                Test.@test cclbd_reload(t) ≈ cclbd_orig(t) atol = 1e-8
            end
        else
            Test.@test isnothing(cclbd_reload)
        end

        # Control constraints ub dual
        ccubd_orig = CTModels.control_constraints_ub_dual(sol)
        ccubd_reload = CTModels.control_constraints_ub_dual(sol_reloaded)
        if !isnothing(ccubd_orig)
            Test.@test !isnothing(ccubd_reload)
            for t in T
                Test.@test ccubd_reload(t) ≈ ccubd_orig(t) atol = 1e-8
            end
        else
            Test.@test isnothing(ccubd_reload)
        end

        # Variable constraints lb dual
        vclbd_orig = CTModels.variable_constraints_lb_dual(sol)
        vclbd_reload = CTModels.variable_constraints_lb_dual(sol_reloaded)
        if !isnothing(vclbd_orig)
            Test.@test !isnothing(vclbd_reload)
            Test.@test vclbd_reload ≈ vclbd_orig atol = 1e-10
        else
            Test.@test isnothing(vclbd_reload)
        end

        # Variable constraints ub dual
        vcubd_orig = CTModels.variable_constraints_ub_dual(sol)
        vcubd_reload = CTModels.variable_constraints_ub_dual(sol_reloaded)
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

    Test.@testset "JSON: solution with all duals nothing" verbose=VERBOSE showtiming=SHOWTIMING begin
        # solution_example has no duals
        ocp, sol = solution_example()

        CTModels.export_ocp_solution(sol; filename="solution_no_duals", format=:JSON)

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
        sol_reloaded = CTModels.import_ocp_solution(
            ocp; filename="solution_no_duals", format=:JSON
        )
        Test.@test isnothing(CTModels.path_constraints_dual(sol_reloaded))
        Test.@test isnothing(CTModels.boundary_constraints_dual(sol_reloaded))
        Test.@test isnothing(CTModels.state_constraints_lb_dual(sol_reloaded))
        Test.@test isnothing(CTModels.state_constraints_ub_dual(sol_reloaded))
        Test.@test isnothing(CTModels.control_constraints_lb_dual(sol_reloaded))
        Test.@test isnothing(CTModels.control_constraints_ub_dual(sol_reloaded))
        Test.@test isnothing(CTModels.variable_constraints_lb_dual(sol_reloaded))
        Test.@test isnothing(CTModels.variable_constraints_ub_dual(sol_reloaded))

        remove_if_exists("solution_no_duals.json")
    end

    Test.@testset "JSON: solver infos dict preserved" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Create a solution with custom infos
        ocp, sol_base = solution_example()
        T = CTModels.time_grid(sol_base)

        # Build a new solution with custom infos
        x = CTModels.state(sol_base)
        u = CTModels.control(sol_base)
        p = CTModels.costate(sol_base)
        v = CTModels.variable(sol_base)

        custom_infos = Dict{Symbol,Any}(
            :solver_name => "TestSolver",
            :tolerance => 1e-6,
            :max_iterations => 1000,
            :converged => true,
            :residuals => [1e-3, 1e-5, 1e-8],
            :nested => Dict{Symbol,Any}(:a => 1, :b => "test"),
        )

        sol = CTModels.build_solution(
            ocp,
            Vector{Float64}(T),
            x,
            u,
            isa(v, Number) ? [v] : v,
            p;
            objective=CTModels.objective(sol_base),
            iterations=CTModels.iterations(sol_base),
            constraints_violation=CTModels.constraints_violation(sol_base),
            message=CTModels.message(sol_base),
            status=CTModels.status(sol_base),
            successful=CTModels.successful(sol_base),
            infos=custom_infos,
        )

        # Verify infos is set correctly
        Test.@test CTModels.infos(sol)[:solver_name] == "TestSolver"
        Test.@test CTModels.infos(sol)[:tolerance] == 1e-6

        # Export and import
        CTModels.export_ocp_solution(sol; filename="solution_with_infos", format=:JSON)
        sol_reloaded = CTModels.import_ocp_solution(
            ocp; filename="solution_with_infos", format=:JSON
        )

        # Verify infos is preserved
        reloaded_infos = CTModels.infos(sol_reloaded)
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

    Test.@testset "JSON idempotence: double cycle (solution_example_dual)" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp, sol0 = solution_example_dual()

        # First cycle: sol0 → export → import → sol1
        CTModels.export_ocp_solution(sol0; filename="idempotence_json_1", format=:JSON)
        sol1 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_json_1", format=:JSON
        )

        # Second cycle: sol1 → export → import → sol2
        CTModels.export_ocp_solution(sol1; filename="idempotence_json_2", format=:JSON)
        sol2 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_json_2", format=:JSON
        )

        # Verify idempotence: sol1 ≈ sol2 (no further information loss)
        Test.@test compare_solutions(sol1, sol2)

        remove_if_exists("idempotence_json_1.json")
        remove_if_exists("idempotence_json_2.json")
    end

    Test.@testset "JSON idempotence: triple cycle (solution_example_dual)" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp, sol0 = solution_example_dual()

        # First cycle
        CTModels.export_ocp_solution(sol0; filename="idempotence_json_t1", format=:JSON)
        sol1 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_json_t1", format=:JSON
        )

        # Second cycle
        CTModels.export_ocp_solution(sol1; filename="idempotence_json_t2", format=:JSON)
        sol2 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_json_t2", format=:JSON
        )

        # Third cycle
        CTModels.export_ocp_solution(sol2; filename="idempotence_json_t3", format=:JSON)
        sol3 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_json_t3", format=:JSON
        )

        # Verify convergence: sol2 ≈ sol3
        Test.@test compare_solutions(sol2, sol3)

        remove_if_exists("idempotence_json_t1.json")
        remove_if_exists("idempotence_json_t2.json")
        remove_if_exists("idempotence_json_t3.json")
    end

    Test.@testset "JSON idempotence: double cycle (solution_example no duals)" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp, sol0 = solution_example()

        # First cycle
        CTModels.export_ocp_solution(sol0; filename="idempotence_json_nd1", format=:JSON)
        sol1 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_json_nd1", format=:JSON
        )

        # Second cycle
        CTModels.export_ocp_solution(sol1; filename="idempotence_json_nd2", format=:JSON)
        sol2 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_json_nd2", format=:JSON
        )

        # Verify idempotence
        Test.@test compare_solutions(sol1, sol2)

        remove_if_exists("idempotence_json_nd1.json")
        remove_if_exists("idempotence_json_nd2.json")
    end

    Test.@testset "JSON idempotence: with complex infos" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp, sol_base = solution_example()
        T = CTModels.time_grid(sol_base)

        # Build solution with complex infos
        x = CTModels.state(sol_base)
        u = CTModels.control(sol_base)
        p = CTModels.costate(sol_base)
        v = CTModels.variable(sol_base)

        complex_infos = Dict{Symbol,Any}(
            :solver_name => "TestSolver",
            :tolerance => 1e-6,
            :max_iterations => 1000,
            :converged => true,
            :residuals => [1e-3, 1e-5, 1e-8],
            :nested => Dict{Symbol,Any}(:a => 1, :b => "test", :c => [1.0, 2.0, 3.0]),
            :symbol_value => :optimal,
        )

        sol0 = CTModels.build_solution(
            ocp,
            Vector{Float64}(T),
            x,
            u,
            isa(v, Number) ? [v] : v,
            p;
            objective=CTModels.objective(sol_base),
            iterations=CTModels.iterations(sol_base),
            constraints_violation=CTModels.constraints_violation(sol_base),
            message=CTModels.message(sol_base),
            status=CTModels.status(sol_base),
            successful=CTModels.successful(sol_base),
            infos=complex_infos,
        )

        # First cycle
        CTModels.export_ocp_solution(sol0; filename="idempotence_json_ci1", format=:JSON)
        sol1 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_json_ci1", format=:JSON
        )

        # Second cycle
        CTModels.export_ocp_solution(sol1; filename="idempotence_json_ci2", format=:JSON)
        sol2 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_json_ci2", format=:JSON
        )

        # Verify idempotence
        Test.@test compare_solutions(sol1, sol2)

        # Verify infos preservation
        infos2 = CTModels.infos(sol2)
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

    Test.@testset "JLD2 idempotence: double cycle (solution_example_dual)" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp, sol0 = solution_example_dual()

        # First cycle: sol0 → export → import → sol1
        CTModels.export_ocp_solution(sol0; filename="idempotence_jld_1", format=:JLD)
        sol1 = CTModels.import_ocp_solution(ocp; filename="idempotence_jld_1", format=:JLD)

        # Second cycle: sol1 → export → import → sol2
        CTModels.export_ocp_solution(sol1; filename="idempotence_jld_2", format=:JLD)
        sol2 = CTModels.import_ocp_solution(ocp; filename="idempotence_jld_2", format=:JLD)

        # Verify idempotence: sol1 ≈ sol2
        Test.@test compare_solutions(sol1, sol2)

        remove_if_exists("idempotence_jld_1.jld2")
        remove_if_exists("idempotence_jld_2.jld2")
    end

    Test.@testset "JLD2 idempotence: triple cycle (solution_example_dual)" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp, sol0 = solution_example_dual()

        # First cycle
        CTModels.export_ocp_solution(sol0; filename="idempotence_jld_t1", format=:JLD)
        sol1 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_jld_t1", format=:JLD
        )

        # Second cycle
        CTModels.export_ocp_solution(sol1; filename="idempotence_jld_t2", format=:JLD)
        sol2 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_jld_t2", format=:JLD
        )

        # Third cycle
        CTModels.export_ocp_solution(sol2; filename="idempotence_jld_t3", format=:JLD)
        sol3 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_jld_t3", format=:JLD
        )

        # Verify convergence: sol2 ≈ sol3
        Test.@test compare_solutions(sol2, sol3)

        remove_if_exists("idempotence_jld_t1.jld2")
        remove_if_exists("idempotence_jld_t2.jld2")
        remove_if_exists("idempotence_jld_t3.jld2")
    end

    Test.@testset "JLD2 idempotence: double cycle (solution_example no duals)" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp, sol0 = solution_example()

        # First cycle
        CTModels.export_ocp_solution(sol0; filename="idempotence_jld_nd1", format=:JLD)
        sol1 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_jld_nd1", format=:JLD
        )

        # Second cycle
        CTModels.export_ocp_solution(sol1; filename="idempotence_jld_nd2", format=:JLD)
        sol2 = CTModels.import_ocp_solution(
            ocp; filename="idempotence_jld_nd2", format=:JLD
        )

        # Verify idempotence
        Test.@test compare_solutions(sol1, sol2)

        remove_if_exists("idempotence_jld_nd1.jld2")
        remove_if_exists("idempotence_jld_nd2.jld2")
    end

    # ========================================================================
    # Empirical investigation: stack() behavior
    # ========================================================================
    
    Test.@testset "JSON stack() behavior investigation" verbose = VERBOSE showtiming = SHOWTIMING begin
        # Empirical investigation: When does stack() return Vector vs Matrix?
        # This validates the need for the conditional in _json_array_to_matrix
        # 
        # Findings:
        # - Multi-dimensional trajectories (state, costate): stack() → Matrix
        # - 1-dimensional trajectories (control in solution_example): stack() → Vector
        # 
        # This proves the refactoring with _json_array_to_matrix is correct and necessary.
        
        ocp, sol = solution_example()
        
        # Export to JSON
        CTModels.export_ocp_solution(sol; filename="stack_investigation", format=:JSON)
        
        # Read and observe what stack() returns
        json_string = read("stack_investigation.json", String)
        blob = JSON3.read(json_string)
        
        # Test state (multi-dimensional: 2D in solution_example)
        state_stacked = stack(blob["state"]; dims=1)
        Test.@test state_stacked isa Matrix  # Multi-D → Matrix
        
        # Test control (1-dimensional in solution_example)
        control_stacked = stack(blob["control"]; dims=1)
        Test.@test control_stacked isa Vector  # 1D → Vector
        
        # Test costate (multi-dimensional: 2D)
        costate_stacked = stack(blob["costate"]; dims=1)
        Test.@test costate_stacked isa Matrix  # Multi-D → Matrix
        
        # Verify import works correctly (indirect test of _json_array_to_matrix)
        sol_reloaded = CTModels.import_ocp_solution(ocp; filename="stack_investigation", format=:JSON)
        Test.@test CTModels.objective(sol) ≈ CTModels.objective(sol_reloaded) atol = 1e-8
        
        remove_if_exists("stack_investigation.json")
    end
end

end # module

test_export_import() = TestExportImport.test_export_import()
