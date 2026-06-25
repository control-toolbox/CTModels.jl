module TestSerializationUnits

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Solutions: Solutions
import CTModels.Serialization: Serialization

include(joinpath("..", "..", "problems", "TestProblems.jl"))
import .TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_serialization_units()
    Test.@testset "Serialization unit tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ==============================================================================
        # C.1 — _discretize_function / _discretize_dual
        # ==============================================================================

        Test.@testset "_discretize_function: scalar function" begin
            f = t -> 2.0 * t
            T = [0.0, 0.5, 1.0]
            M = Solutions._discretize_function(f, T, 1)
            Test.@test M isa Matrix{Float64}
            Test.@test size(M) == (3, 1)
            Test.@test M[:, 1] ≈ [0.0, 1.0, 2.0]
        end

        Test.@testset "_discretize_function: vector function" begin
            f = t -> [t, 2t]
            T = [0.0, 0.5, 1.0]
            M = Solutions._discretize_function(f, T, 2)
            Test.@test M isa Matrix{Float64}
            Test.@test size(M) == (3, 2)
            Test.@test M ≈ [0.0 0.0; 0.5 1.0; 1.0 2.0]
        end

        Test.@testset "_discretize_function: auto-detect dim (scalar)" begin
            f = t -> 3.0 * t
            T = [0.0, 1.0]
            M = Solutions._discretize_function(f, T)
            Test.@test size(M) == (2, 1)
            Test.@test M[2, 1] ≈ 3.0
        end

        Test.@testset "_discretize_function: auto-detect dim (vector)" begin
            f = t -> [t, t^2]
            T = [0.0, 1.0, 2.0]
            M = Solutions._discretize_function(f, T)
            Test.@test size(M) == (3, 2)
            Test.@test M[3, 2] ≈ 4.0
        end

        Test.@testset "_discretize_dual: nothing passthrough" begin
            result = Solutions._discretize_dual(nothing, [0.0, 1.0], 2)
            Test.@test isnothing(result)
        end

        Test.@testset "_discretize_dual: non-nothing returns matrix" begin
            f = t -> [t, 1.0 - t]
            T = [0.0, 0.5, 1.0]
            M = Solutions._discretize_dual(f, T, 2)
            Test.@test M isa Matrix{Float64}
            Test.@test size(M) == (3, 2)
        end

        # ==============================================================================
        # C.2 — _serialize_solution: format detection
        # ==============================================================================

        Test.@testset "_serialize_solution: unified format produces time_grid key" begin
            _, sol = TestProblems.solution_example()
            data = Solutions._serialize_solution(sol)
            Test.@test data isa Dict{String,Any}
            Test.@test haskey(data, "time_grid")
            Test.@test !haskey(data, "time_grid_state")
            Test.@test haskey(data, "state")
            Test.@test haskey(data, "control")
            Test.@test haskey(data, "costate")
            Test.@test haskey(data, "variable")
            Test.@test haskey(data, "objective")
            Test.@test haskey(data, "control_interpolation")
            Test.@test haskey(data, "path_constraints_dual")
        end

        Test.@testset "_serialize_solution: multi-grid format produces 4 time_grid keys" begin
            ocp, sol_base = TestProblems.solution_example()
            T_state = collect(LinRange(0.0, 1.0, 11))
            T_control = collect(LinRange(0.0, 1.0, 6))
            T_costate = collect(LinRange(0.0, 1.0, 11))
            T_path = collect(LinRange(0.0, 1.0, 9))
            v = Components.variable(sol_base)

            sol_multi = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                Components.state(sol_base),
                Components.control(sol_base),
                v,
                Components.costate(sol_base);
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
            )

            data = Solutions._serialize_solution(sol_multi)
            Test.@test haskey(data, "time_grid_state")
            Test.@test haskey(data, "time_grid_control")
            Test.@test haskey(data, "time_grid_costate")
            Test.@test haskey(data, "time_grid_path")
            Test.@test !haskey(data, "time_grid")
            Test.@test data["time_grid_state"] ≈ T_state
            Test.@test data["time_grid_control"] ≈ T_control
        end

        # ==============================================================================
        # C.3 — _reconstruct_solution_from_data: unified and multi formats
        # ==============================================================================

        Test.@testset "_reconstruct_solution_from_data: unified format" begin
            ocp, sol = TestProblems.solution_example()
            data = Solutions._serialize_solution(sol)
            sol2 = Serialization._reconstruct_solution_from_data(ocp, data)
            Test.@test Solutions.objective(sol2) ≈ Solutions.objective(sol) atol = 1e-10
            Test.@test Components.time_grid(sol2) ≈ Components.time_grid(sol) atol = 1e-10
        end

        Test.@testset "_reconstruct_solution_from_data: multi-grid format" begin
            ocp, sol_base = TestProblems.solution_example()
            T_state = collect(LinRange(0.0, 1.0, 11))
            T_control = collect(LinRange(0.0, 1.0, 6))
            T_costate = collect(LinRange(0.0, 1.0, 11))
            T_path = collect(LinRange(0.0, 1.0, 9))
            v = Components.variable(sol_base)

            sol_multi = Solutions.build_solution(
                ocp,
                T_state,
                T_control,
                T_costate,
                T_path,
                Components.state(sol_base),
                Components.control(sol_base),
                v,
                Components.costate(sol_base);
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
            )

            data = Solutions._serialize_solution(sol_multi)
            sol2 = Serialization._reconstruct_solution_from_data(ocp, data)
            Test.@test Solutions.time_grid_model(sol2) isa Solutions.MultipleTimeGridModel
            Test.@test Components.time_grid(sol2, :state) ≈ T_state atol = 1e-10
            Test.@test Components.time_grid(sol2, :control) ≈ T_control atol = 1e-10
        end

        Test.@testset "_reconstruct_solution_from_data: missing time_grid raises ParsingError" begin
            ocp, sol = TestProblems.solution_example()
            data = Solutions._serialize_solution(sol)
            delete!(data, "time_grid")
            Test.@test_throws Exceptions.ParsingError Serialization._reconstruct_solution_from_data(
                ocp, data
            )
        end

        Test.@testset "_reconstruct_solution_from_data: missing control_interpolation raises KeyError" begin
            ocp, sol = TestProblems.solution_example()
            data = Solutions._serialize_solution(sol)
            delete!(data, "control_interpolation")
            Test.@test_throws KeyError Serialization._reconstruct_solution_from_data(
                ocp, data
            )
        end

        # ==============================================================================
        # C.4 — Pinning of reconstructed type after import
        # ==============================================================================

        Test.@testset "Reconstructed solution: unified time_grid_model pinning" begin
            ocp, sol = TestProblems.solution_example()
            data = Solutions._serialize_solution(sol)
            sol2 = Serialization._reconstruct_solution_from_data(ocp, data)

            # Unified solution → UnifiedTimeGridModel
            Test.@test Solutions.time_grid_model(sol2) isa Solutions.UnifiedTimeGridModel

            # Trajectories are callable and consistent at grid points
            T = Components.time_grid(sol2)
            x = Components.state(sol2)
            u = Components.control(sol2)
            p = Components.costate(sol2)
            for t in T[1:min(end, 5)]
                Test.@test x(t) isa AbstractVector
                Test.@test u(t) isa Union{Number,AbstractVector}
                Test.@test p(t) isa AbstractVector
            end
        end

        Test.@testset "Reconstructed solution: control_interpolation pinning" begin
            ocp, sol_base = TestProblems.solution_example()
            T = Components.time_grid(sol_base)
            x = Components.state(sol_base)
            u = Components.control(sol_base)
            p = Components.costate(sol_base)
            v = Components.variable(sol_base)

            sol_linear = Solutions.build_solution(
                ocp,
                Vector{Float64}(T),
                x,
                u,
                v,
                p;
                objective=Solutions.objective(sol_base),
                iterations=Solutions.iterations(sol_base),
                constraints_violation=Solutions.constraints_violation(sol_base),
                message=Solutions.message(sol_base),
                status=Solutions.status(sol_base),
                successful=Solutions.successful(sol_base),
                control_interpolation=:linear,
            )

            data = Solutions._serialize_solution(sol_linear)
            sol2 = Serialization._reconstruct_solution_from_data(ocp, data)
            Test.@test Solutions.control_interpolation(sol2) == :linear
        end

        # ==============================================================================
        # C.5 — Round-trip of duals from DualSlice / BoxDualDiff
        # ==============================================================================

        Test.@testset "Round-trip: duals from DualSlice/BoxDualDiff (JSON)" begin
            ocp, sol = TestProblems.solution_example_dual()

            # Access a path dual via dual() — returns a DualSlice functor
            pcd = Solutions.path_constraints_dual(sol)
            Test.@test !isnothing(pcd)

            # Export and re-import
            Serialization.export_ocp_solution(
                sol; filename="dual_functor_test", format=:JSON
            )
            sol2 = Serialization.import_ocp_solution(
                ocp; filename="dual_functor_test", format=:JSON
            )

            # Duals survive the round-trip
            pcd2 = Solutions.path_constraints_dual(sol2)
            Test.@test !isnothing(pcd2)
            T = Components.time_grid(sol)
            for t in T[1:min(end, 3)]
                Test.@test pcd2(t) ≈ pcd(t) atol = 1e-8
            end

            isfile("dual_functor_test.json") && rm("dual_functor_test.json")
        end

        Test.@testset "Round-trip: duals from DualSlice/BoxDualDiff (JLD2)" begin
            ocp, sol = TestProblems.solution_example_dual()
            pcd = Solutions.path_constraints_dual(sol)

            Serialization.export_ocp_solution(
                sol; filename="dual_functor_jld_test", format=:JLD
            )
            sol2 = Serialization.import_ocp_solution(
                ocp; filename="dual_functor_jld_test", format=:JLD
            )

            pcd2 = Solutions.path_constraints_dual(sol2)
            Test.@test !isnothing(pcd2)
            T = Components.time_grid(sol)
            for t in T[1:min(end, 3)]
                Test.@test pcd2(t) ≈ pcd(t) atol = 1e-8
            end

            isfile("dual_functor_jld_test.jld2") && rm("dual_functor_jld_test.jld2")
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_serialization_units() = TestSerializationUnits.test_serialization_units()
