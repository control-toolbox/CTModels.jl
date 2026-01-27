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

        # Suppress JLD2 warnings about anonymous functions (expected behaviour)
        Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
            CTModels.export_ocp_solution(sol; filename="solution_test") # default is :JLD
        end
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
end

end # module

test_export_import() = TestExportImport.test_export_import()
