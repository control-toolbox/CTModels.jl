module TestOCPDualModel

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Building: Building
import CTModels.Models: Models
import CTModels.Solutions: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Top-level helper: build a minimal Model and Solution with prescribed dual matrices.
# Used by integration tests for `dual(sol, model, label)`.
function _build_model_with_state_box(; state_dim::Int, constraints::Vector)
    ocp = Building.PreModel()
    Building.time!(ocp; t0=0.0, tf=1.0)
    Building.state!(ocp, state_dim)
    Building.control!(ocp, 1)
    _dyn!(r, t, x, u, v) = (r .= zero(x))
    Building.dynamics!(ocp, _dyn!)
    Building.objective!(ocp, :min; mayer=(x0, xf, v) -> 0.0)
    Building.definition!(ocp, quote end)
    Building.time_dependence!(ocp; autonomous=false)
    for (rg, lb, ub, label) in constraints
        Building.constraint!(ocp, :state; rg=rg, lb=lb, ub=ub, label=label)
    end
    return ocp
end

function _build_model_with_control_box(; control_dim::Int, constraints::Vector)
    ocp = Building.PreModel()
    Building.time!(ocp; t0=0.0, tf=1.0)
    Building.state!(ocp, 1)
    Building.control!(ocp, control_dim)
    _dyn!(r, t, x, u, v) = (r .= zero(x))
    Building.dynamics!(ocp, _dyn!)
    Building.objective!(ocp, :min; mayer=(x0, xf, v) -> 0.0)
    Building.definition!(ocp, quote end)
    Building.time_dependence!(ocp; autonomous=false)
    for (rg, lb, ub, label) in constraints
        Building.constraint!(ocp, :control; rg=rg, lb=lb, ub=ub, label=label)
    end
    return ocp
end

function _build_model_with_variable_box(; variable_dim::Int, constraints::Vector)
    ocp = Building.PreModel()
    Building.time!(ocp; t0=0.0, tf=1.0)
    Building.state!(ocp, 1)
    Building.control!(ocp, 1)
    Building.variable!(ocp, variable_dim)
    _dyn!(r, t, x, u, v) = (r .= zero(x))
    Building.dynamics!(ocp, _dyn!)
    Building.objective!(ocp, :min; mayer=(x0, xf, v) -> 0.0)
    Building.definition!(ocp, quote end)
    Building.time_dependence!(ocp; autonomous=false)
    for (rg, lb, ub, label) in constraints
        Building.constraint!(ocp, :variable; rg=rg, lb=lb, ub=ub, label=label)
    end
    return ocp
end

function _make_solution(
    ocp_model::Models.Model;
    state_dim::Int=1,
    control_dim::Int=1,
    variable_dim::Int=0,
    state_lb=nothing,
    state_ub=nothing,
    control_lb=nothing,
    control_ub=nothing,
    variable_lb=nothing,
    variable_ub=nothing,
)
    T = [0.0, 0.5, 1.0]
    X = zeros(3, state_dim)
    U = zeros(3, control_dim)
    P = zeros(3, state_dim)
    v = zeros(variable_dim)
    return Solutions.build_solution(
        ocp_model,
        T,
        X,
        U,
        v,
        P;
        objective=0.0,
        iterations=0,
        constraints_violation=0.0,
        message="",
        status=:optimal,
        successful=true,
        state_constraints_lb_dual=state_lb,
        state_constraints_ub_dual=state_ub,
        control_constraints_lb_dual=control_lb,
        control_constraints_ub_dual=control_ub,
        variable_constraints_lb_dual=variable_lb,
        variable_constraints_ub_dual=variable_ub,
    )
end

function test_dual_model()
    Test.@testset "Dual Model Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Low-level DualModel Accessors
        # ====================================================================

        Test.@testset "DualModel constraint dual accessors" verbose=VERBOSE showtiming=SHOWTIMING begin
            pc = t -> [1.0, 2.0]
            bc = [3.0, 4.0]
            sc_lb = t -> [0.0]
            sc_ub = t -> [1.0]
            cc_lb = t -> [0.0]
            cc_ub = t -> [1.0]
            vc_lb = [5.0]
            vc_ub = [6.0]

            dual = Solutions.DualModel(pc, bc, sc_lb, sc_ub, cc_lb, cc_ub, vc_lb, vc_ub)

            Test.@test Solutions.path_constraints_dual(dual) === pc
            Test.@test Solutions.boundary_constraints_dual(dual) === bc
            Test.@test Solutions.state_constraints_lb_dual(dual) === sc_lb
            Test.@test Solutions.state_constraints_ub_dual(dual) === sc_ub
            Test.@test Solutions.control_constraints_lb_dual(dual) === cc_lb
            Test.@test Solutions.control_constraints_ub_dual(dual) === cc_ub
            Test.@test Solutions.variable_constraints_lb_dual(dual) === vc_lb
            Test.@test Solutions.variable_constraints_ub_dual(dual) === vc_ub
        end

        # ====================================================================
        # INTEGRATION TESTS - dual(sol, model, label) on box constraints
        # Verifies that `dual(sol, m, :label)` returns the multiplier(s)
        # associated with each bound declaration (one column per declaration
        # in the provided dual matrix).
        # ====================================================================

        Test.@testset "INTEGRATION TESTS - dual() box constraints" verbose=VERBOSE showtiming=SHOWTIMING begin

            # --- State box ---
            Test.@testset "state - single full-range declaration" begin
                ocp = _build_model_with_state_box(;
                    state_dim=2, constraints=[(1:2, [0.0, 0.0], [1.0, 1.0], :s)]
                )
                m = Building.build(ocp)
                # 2 declarations → matrix must have 2 columns
                lb = [1.0 10.0; 2.0 20.0; 3.0 30.0]
                ub = [0.1 0.5; 0.2 0.6; 0.3 0.7]
                sol = _make_solution(m; state_dim=2, state_lb=lb, state_ub=ub)
                d = Solutions.dual(sol, m, :s)
                Test.@test d(0.0) ≈ [1.0 - 0.1, 10.0 - 0.5]
                Test.@test d(1.0) ≈ [3.0 - 0.3, 30.0 - 0.7]
            end

            Test.@testset "state - partial range not starting at 1" begin
                ocp = _build_model_with_state_box(;
                    state_dim=3, constraints=[(2:3, [0.0, 0.0], [1.0, 1.0], :s)]
                )
                m = Building.build(ocp)
                # Per-component convention: matrix has state_dim=3 columns.
                # Component 1 is unconstrained and carries a zero multiplier.
                lb = [0.0 1.0 10.0; 0.0 2.0 20.0; 0.0 3.0 30.0]
                ub = zeros(3, 3)
                sol = _make_solution(m; state_dim=3, state_lb=lb, state_ub=ub)
                d = Solutions.dual(sol, m, :s)
                # :s targets components 2,3 → slice cols 2,3
                Test.@test d(0.0) ≈ [1.0, 10.0]
                Test.@test d(1.0) ≈ [3.0, 30.0]
            end

            Test.@testset "state - two labels on same component: share per-component dual" begin
                ocp = _build_model_with_state_box(;
                    state_dim=1,
                    constraints=[(1:1, [0.0], [2.0], :s1), (1:1, [0.5], [1.5], :s2)],
                )
                m = (Test.@test_logs (:warn, r"Multiple bound declarations") Building.build(
                    ocp
                ))
                # After dedup, 1 unique component → matrix has state_dim=1 column
                lb = reshape([1.0, 2.0, 3.0], 3, 1)
                ub = zeros(3, 1)
                sol = _make_solution(m; state_dim=1, state_lb=lb, state_ub=ub)
                # Both labels point to component 1 → same scalar dual
                Test.@test Solutions.dual(sol, m, :s1)(0.0) ≈ 1.0
                Test.@test Solutions.dual(sol, m, :s2)(0.0) ≈ 1.0
                Test.@test Solutions.dual(sol, m, :s1)(1.0) ≈ 3.0
                Test.@test Solutions.dual(sol, m, :s2)(1.0) ≈ 3.0
            end

            # --- Control box ---
            Test.@testset "control - single full-range declaration" begin
                ocp = _build_model_with_control_box(;
                    control_dim=2, constraints=[(1:2, [0.0, 0.0], [1.0, 1.0], :c)]
                )
                m = Building.build(ocp)
                lb = [1.0 10.0; 2.0 20.0; 3.0 30.0]
                ub = zeros(3, 2)
                sol = _make_solution(m; control_dim=2, control_lb=lb, control_ub=ub)
                d = Solutions.dual(sol, m, :c)
                Test.@test d(0.0) ≈ [1.0, 10.0]
            end

            Test.@testset "control - partial range not starting at 1" begin
                ocp = _build_model_with_control_box(;
                    control_dim=3, constraints=[(2:3, [0.0, 0.0], [1.0, 1.0], :c)]
                )
                m = Building.build(ocp)
                # Per-component: matrix has control_dim=3 columns.
                lb = [0.0 1.0 10.0; 0.0 2.0 20.0; 0.0 3.0 30.0]
                ub = zeros(3, 3)
                sol = _make_solution(m; control_dim=3, control_lb=lb, control_ub=ub)
                d = Solutions.dual(sol, m, :c)
                Test.@test d(0.0) ≈ [1.0, 10.0]
            end

            Test.@testset "control - two labels on same component: share per-component dual" begin
                ocp = _build_model_with_control_box(;
                    control_dim=1,
                    constraints=[(1:1, [0.0], [2.0], :c1), (1:1, [0.5], [1.5], :c2)],
                )
                m = (Test.@test_logs (:warn, r"Multiple bound declarations") Building.build(
                    ocp
                ))
                lb = reshape([1.0, 2.0, 3.0], 3, 1)
                ub = zeros(3, 1)
                sol = _make_solution(m; control_dim=1, control_lb=lb, control_ub=ub)
                Test.@test Solutions.dual(sol, m, :c1)(0.0) ≈ 1.0
                Test.@test Solutions.dual(sol, m, :c2)(0.0) ≈ 1.0
            end

            # --- Variable box ---
            Test.@testset "variable - single full-range declaration" begin
                ocp = _build_model_with_variable_box(;
                    variable_dim=2, constraints=[(1:2, [0.0, 0.0], [1.0, 1.0], :vbl)]
                )
                m = Building.build(ocp)
                lb = [1.0, 10.0]
                ub = [0.1, 0.5]
                sol = _make_solution(m; variable_dim=2, variable_lb=lb, variable_ub=ub)
                d = Solutions.dual(sol, m, :vbl)
                Test.@test d ≈ [1.0 - 0.1, 10.0 - 0.5]
            end

            Test.@testset "variable - partial range not starting at 1" begin
                ocp = _build_model_with_variable_box(;
                    variable_dim=3, constraints=[(2:3, [0.0, 0.0], [1.0, 1.0], :vbl)]
                )
                m = Building.build(ocp)
                # Per-component: duals are variable_dim-sized vectors.
                lb = [0.0, 1.0, 10.0]
                ub = zeros(3)
                sol = _make_solution(m; variable_dim=3, variable_lb=lb, variable_ub=ub)
                d = Solutions.dual(sol, m, :vbl)
                Test.@test d ≈ [1.0, 10.0]
            end

            Test.@testset "variable - two labels on same component: share per-component dual" begin
                ocp = _build_model_with_variable_box(;
                    variable_dim=1,
                    constraints=[(1:1, [0.0], [2.0], :v1), (1:1, [0.5], [1.5], :v2)],
                )
                m = (Test.@test_logs (:warn, r"Multiple bound declarations") Building.build(
                    ocp
                ))
                lb = [1.0]
                ub = [0.0]
                sol = _make_solution(m; variable_dim=1, variable_lb=lb, variable_ub=ub)
                Test.@test Solutions.dual(sol, m, :v1) ≈ 1.0
                Test.@test Solutions.dual(sol, m, :v2) ≈ 1.0
            end
        end

        # ====================================================================
        # ERROR TESTS - dual() with unknown label
        # ====================================================================

        Test.@testset "dual() label not found → IncorrectArgument" begin
            ocp = _build_model_with_state_box(;
                state_dim=1, constraints=[(1:1, [0.0], [1.0], :known)]
            )
            m = Building.build(ocp)
            lb = reshape([1.0, 2.0, 3.0], 3, 1)
            ub = zeros(3, 1)
            sol = _make_solution(m; state_dim=1, state_lb=lb, state_ub=ub)

            Test.@test_throws Exceptions.IncorrectArgument Solutions.dual(
                sol, m, :nonexistent
            )
        end
    end

    Test.@testset "DualSlice and BoxDualDiff" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@testset "DualSlice — scalar index" begin
            duals_fn = t -> [10.0 * t, 20.0 * t, 30.0 * t]
            f = Solutions.DualSlice(duals_fn, 2)
            Test.@test f isa Function
            Test.@test f(1.0) == 20.0
            Test.@test f(1.0) isa Real
            Test.@test contains(repr(f), "DualSlice")
            Test.@test contains(repr(MIME("text/plain"), f), "DualSlice")
        end

        Test.@testset "DualSlice — vector index" begin
            duals_fn = t -> [10.0 * t, 20.0 * t, 30.0 * t]
            f = Solutions.DualSlice(duals_fn, [1, 3])
            Test.@test f isa Function
            Test.@test f(1.0) == [10.0, 30.0]
            Test.@test f(1.0) isa AbstractVector
        end

        Test.@testset "BoxDualDiff — scalar index" begin
            f = Solutions.BoxDualDiff(t -> [1.0, 2.0, 3.0], t -> [0.5, 0.5, 0.5], 2)
            Test.@test f isa Function
            Test.@test f(0.0) == 1.5
            Test.@test f(0.0) isa Real
            Test.@test contains(repr(f), "BoxDualDiff")
            Test.@test contains(repr(MIME("text/plain"), f), "BoxDualDiff")
        end

        Test.@testset "BoxDualDiff — vector index" begin
            f = Solutions.BoxDualDiff(t -> [1.0, 2.0, 3.0], t -> [0.5, 0.5, 0.5], [1, 3])
            Test.@test f isa Function
            Test.@test f(0.0) == [0.5, 2.5]
            Test.@test f(0.0) isa AbstractVector
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_dual_model() = TestOCPDualModel.test_dual_model()
