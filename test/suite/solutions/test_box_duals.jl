module TestBoxDuals

using Test: Test
using CTBase: Exceptions
using CTModels: Building
using CTModels: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# TOP-LEVEL fixtures (TST3)
# ==============================================================================

# Boxes of every shape (ct-conventions SGN2/SGN3):
#   :x1_lo  state x₁ ≥ 0               lower bound only  → dual  zL
#   :x2_two state -1 ≤ x₂ ≤ 1          two bounds        → dual  zU − zL
#   :u_up   control u ≤ 1              upper bound only  → dual  zU
#   :v_fix  variable v = 2 (fixed)     two equal bounds  → dual  zU − zL
#   :p      a path constraint, so that path and box labels are mixed
function _box_model()
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.variable!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r .= x; nothing))
    Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    Building.definition!(pre, quote end)
    Building.time_dependence!(pre; autonomous=true)
    Building.constraint!(pre, :state; rg=1, lb=0.0, ub=Inf, label=:x1_lo)
    Building.constraint!(pre, :path; f=(r, t, x, u, v) -> (r[1] = u[1]; nothing),
        lb=-1, ub=1, label=:p)
    Building.constraint!(pre, :state; rg=2, lb=-1.0, ub=1.0, label=:x2_two)
    Building.constraint!(pre, :control; rg=1, lb=-Inf, ub=1.0, label=:u_up)
    Building.constraint!(pre, :variable; rg=1, lb=2.0, ub=2.0, label=:v_fix)
    return Building.build(pre)
end

# Fake producer duals: callable structs, as a flow builds its duals (TST3).
struct _FakeBoxLower <: Function end
(::_FakeBoxLower)(t) = [t, 0.0]          # zL of (x₁, x₂)
struct _FakeBoxUpper <: Function end
(::_FakeBoxUpper)(t) = [0.0, 2t]         # zU of (x₁, x₂)

const _T = collect(range(0.0, 1.0; length=5))
const _N = length(_T)

# A solution of the fixture model; `kwargs` are the duals.
function _box_solution(ocp; kwargs...)
    return Solutions.build_solution(
        ocp,
        _T,
        zeros(_N, 2),
        zeros(_N, 1),
        [2.0],
        zeros(_N, 2);
        objective=0.0,
        successful=true,
        kwargs...,
    )
end

function test_box_duals()
    Test.@testset "Box duals" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp = _box_model()

        # ======================================================================
        # UNIT — the masks of the known rows
        # ======================================================================
        Test.@testset "DualMasks" begin
            m = Solutions.DualMasks()
            Test.@test all(isnothing, (m.path, m.boundary, m.state, m.control, m.variable))
            dm = Solutions.DualModel(nothing, nothing, nothing, nothing, nothing, nothing, 1.0, 1.0)
            Test.@test dm.known.variable === nothing
        end

        # ======================================================================
        # INTEGRATION — box duals as functions of time (by component)
        # ======================================================================
        Test.@testset "box keywords accept a function" begin
            sol_fun = _box_solution(
                ocp;
                state_constraints_lb_dual=_FakeBoxLower(),
                state_constraints_ub_dual=_FakeBoxUpper(),
                control_constraints_lb_dual=t -> [0.0],
                control_constraints_ub_dual=t -> [3t],
            )
            sol_mat = _box_solution(
                ocp;
                state_constraints_lb_dual=reduce(vcat, (_FakeBoxLower()(t)' for t in _T)),
                state_constraints_ub_dual=reduce(vcat, (_FakeBoxUpper()(t)' for t in _T)),
                control_constraints_lb_dual=zeros(_N, 1),
                control_constraints_ub_dual=reshape(3 .* _T, :, 1),
            )
            for t in (0.0, 0.25, 0.6)   # 0.6 is not on the grid: the function is exact
                Test.@test Solutions.dual(sol_fun, ocp, :x1_lo)(t) ≈ t          # zL
                Test.@test Solutions.dual(sol_fun, ocp, :x2_two)(t) ≈ 2t        # zU − zL
                Test.@test Solutions.dual(sol_fun, ocp, :u_up)(t) ≈ 3t          # zU
            end
            for t in _T                 # on the grid, sampled and exact agree
                Test.@test Solutions.dual(sol_fun, ocp, :x2_two)(t) ≈
                    Solutions.dual(sol_mat, ocp, :x2_two)(t)
            end
            # one control component: the stored dual is a scalar (DIM1)
            Test.@test Solutions.control_constraints_ub_dual(sol_fun)(0.5) ≈ 1.5
            Test.@test Solutions.has_dual(sol_fun, ocp, :x2_two)
            Test.@test !Solutions.has_dual(sol_fun, ocp, :v_fix)   # not stored
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_box_duals() = TestBoxDuals.test_box_duals()
