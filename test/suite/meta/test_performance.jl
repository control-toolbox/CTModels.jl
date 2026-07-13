module TestPerformance

# ==============================================================================
# Performance contract — deterministic allocation guards
# ==============================================================================
#
# This file asserts the *allocation* invariants of CTModels' hot path: the
# callable structs evaluated repeatedly while reading a solution (time-function
# functors, dual-by-label functors, constraint-projection functors) and the
# accessor reads on model/solution components.
#
# Why allocations, and why here:
#   - Type-stability is already guarded by `JET.@test_opt` (test_code_quality.jl)
#     and `Test.@inferred` (next to each fixture). This file guards the
#     complementary property: a change can keep a call type-stable yet start
#     allocating (a stray `collect`, a boxed closure, an abstract field access).
#     Neither `@test_opt` nor `@inferred` would catch that.
#   - Allocation counts are DETERMINISTIC — no run-to-run noise, independent of
#     the machine / CI runner. So `== 0` (or `== raw`) is a robust assertion,
#     unlike wall-clock time, which must never be asserted in the suite.
#
# Two invariant classes:
#   1. Zero-overhead wrappers — a wrapper call must allocate exactly what the
#      raw wrapped computation does (i.e. the wrapper itself adds nothing). We
#      compare wrapper-vs-raw rather than to a magic constant, so the guard is
#      independent of Julia version / word size.
#   2. Zero-allocation reads — component accessors and trait reads must
#      allocate nothing at all.
#
# Setup-path code (PreModel construction, build(), build_solution()) is
# deliberately NOT guarded here — see philosophy/performance.md in the Handbook
# ("hot path vs. setup path").
# ==============================================================================

using Test: Test
using BenchmarkTools: BenchmarkTools
import CTBase: CTBase
import CTBase.Interpolation
import CTBase.Traits
import CTModels.Components: Components
import CTModels.Building: Building
import CTModels.Solutions: Solutions
import CTModels.Models: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# TOP-LEVEL: raw functions/data to compare against (never define these inside
# the test function).
_const_raw(::Real) = 1.0
_traj_raw(t) = [2t]
_duals_raw(t) = [10.0 * t, 20.0 * t, 30.0 * t]
_lb_raw(t) = [1.0, 2.0, 3.0]
_ub_raw(t) = [0.5, 0.5, 0.5]
_boxdualdiff_raw(lb, ub, t, idx) = lb(t)[idx] - ub(t)[idx]
_boxproj_raw(x, idx) = x[idx]

# Minimal built `Model`, for trait reads.
_pre = Building.PreModel()
Building.time!(_pre; t0=0.0, tf=1.0)
Building.state!(_pre, 2)
Building.control!(_pre, 1)
Building.dynamics!(_pre, (r, t, x, u, v) -> (r .= x .+ u; nothing))
Building.objective!(_pre, :min; lagrange=(t, x, u, v) -> u[1]^2)
Building.definition!(
    _pre,
    quote
        t ∈ [0, 1], time
        x ∈ R², state
        u ∈ R, control
        ẋ(t) == x(t) .+ u(t)
        ∫(u(t)^2) → min
    end,
)
Building.time_dependence!(_pre; autonomous=true)
const _model = Building.build(_pre)

function test_performance()
    Test.@testset verbose = VERBOSE showtiming = SHOWTIMING "Performance contract" begin
        # ======================================================================
        # 1. Zero-overhead wrappers: wrapper allocations == raw allocations
        # ======================================================================
        Test.@testset "Zero-overhead wrappers" begin
            # `t`/`idx`/`x` are pre-bound local variables, `$`-interpolated on
            # BOTH the wrapper and the raw side of every comparison below. This
            # is not cosmetic: an un-interpolated literal (e.g. a bare `0.5` or
            # `[2]`) lets the compiler constant-fold the raw expression away to
            # a compile-time value with zero runtime allocation, while the
            # `$`-interpolated wrapper call is genuinely measured — silently
            # comparing a real cost against a folded-away one (`80 == 0`, always
            # failing, or worse, both folding and always trivially passing).
            t = 0.5
            idx = 2

            f_const = Components.ConstantInTime(1.0)
            Test.@test (BenchmarkTools.@ballocated $f_const($t)) ==
                (BenchmarkTools.@ballocated _const_raw($t))

            f_coerced = Components.CoercedTrajectory(_traj_raw, only)
            Test.@test (BenchmarkTools.@ballocated $f_coerced($t)) ==
                (BenchmarkTools.@ballocated only(_traj_raw($t)))

            f_slice = Solutions.DualSlice(_duals_raw, idx)
            Test.@test (BenchmarkTools.@ballocated $f_slice($t)) ==
                (BenchmarkTools.@ballocated _duals_raw($t)[$idx])

            # Raw target is a SINGLE specialised function performing the same
            # two-call subtraction, not two independently-benchmarked global
            # calls stitched together: the latter don't receive the same
            # escape-analysis/allocation-elimination treatment as one compiled
            # method body, and spuriously measured 160 B (2×80 B) against the
            # wrapper's real, reproducible 80 B — an artifact of the comparison,
            # not a wrapper defect (verified at the REPL before writing this).
            f_boxdiff = Solutions.BoxDualDiff(_lb_raw, _ub_raw, idx)
            Test.@test (BenchmarkTools.@ballocated $f_boxdiff($t)) == (BenchmarkTools.@ballocated _boxdualdiff_raw(
                $_lb_raw, $_ub_raw, $t, $idx
            ))

            f_proj = Models.BoxProjection{:state}(idx)
            x = [1.0, 2.0, 3.0]
            Test.@test (BenchmarkTools.@ballocated $f_proj(nothing, $x, nothing, nothing)) ==
                (BenchmarkTools.@ballocated _boxproj_raw($x, $idx))

            # CTModels-specific composition: the CoercedTrajectory+deepcopy
            # wrapping produced by `build_interpolated_function` (the function
            # every solution trajectory — state, control, costate — goes
            # through) must add zero overhead over the raw interpolant it wraps.
            T = [0.0, 0.5, 1.0]
            X = [0.0 1.0; 0.5 1.5; 1.0 2.0]
            fx = Solutions.build_interpolated_function(X, T, 2, Matrix{Float64}; expected_dim=2)
            raw_interp = Interpolation.ctinterpolate(T, CTBase.Core.matrix2vec(X, 1))
            Test.@test (BenchmarkTools.@ballocated $fx(0.25)) ==
                (BenchmarkTools.@ballocated $raw_interp(0.25))
        end

        # ======================================================================
        # 2. Zero-allocation reads: component accessors, trait reads, interpolants
        # ======================================================================
        Test.@testset "Zero-allocation reads" begin
            sms = Components.StateModelSolution("x", ["x1", "x2"], t -> [sin(t), cos(t)])
            Test.@test (BenchmarkTools.@ballocated Components.value($sms)) == 0
            Test.@test (BenchmarkTools.@ballocated Components.dimension($sms)) == 0

            cms = Components.ControlModelSolution("u", ["u"], t -> cos(t), :constant)
            Test.@test (BenchmarkTools.@ballocated Components.value($cms)) == 0
            Test.@test (BenchmarkTools.@ballocated Components.interpolation($cms)) == 0

            Test.@test (BenchmarkTools.@ballocated Traits.time_dependence($_model)) == 0

            interp = Interpolation.ctinterpolate([0.0, 1.0, 2.0, 3.0], [1.0, 2.0, 1.5, 3.0])
            Test.@test (BenchmarkTools.@ballocated $interp(1.5)) == 0
        end
    end
    return nothing
end

end # module TestPerformance

# CRITICAL: redefine in outer scope so the test runner can call it
test_performance() = TestPerformance.test_performance()
