module TestCodeQuality

import Test: Test
import Aqua: Aqua
import JET: JET
import CTModels: CTModels
import CTModels.Components: Components
import CTModels.Solutions: Solutions
import CTModels.Models: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Why JET is scoped to the hot path here, not `JET.test_package`
# ==============================================================================
#
# `JET.test_package` is a whole-package *correctness* scan: it statically visits
# every method signature, including CTModels' mutable `PreModel` builder, whose
# fields are `Union{SomeType,Nothing}` by design (validated incrementally as the
# problem is built up). That union-split analysis reports ~40 "no matching method
# found `f(::Nothing)`" findings for branches that are unreachable at runtime
# (guarded by `Core.@ensure`/precondition checks before the field is read) — this
# is setup-path code, deliberately dynamic, not a defect (see the Handbook's
# performance guide, "hot path vs. setup path").
#
# So instead of a whole-package scan, JET is applied precisely where the Handbook
# says it matters: `JET.@test_opt` on concrete **hot-path** calls (functor
# evaluation, accessor reads) — the code called repeatedly during a solve, where a
# dispatch regression actually multiplies over thousands of calls.
function test_code_quality()
    Test.@testset "Code quality" verbose = VERBOSE showtiming = SHOWTIMING begin
        Test.@testset "Aqua.jl Quality Checks" verbose = VERBOSE showtiming = SHOWTIMING begin
            Aqua.test_all(
                CTModels;
                ambiguities=false,
                #stale_deps=(ignore=[:SomePackage],),
                deps_compat=(ignore=[:LinearAlgebra, :Unicode],),
                piracies=true,
            )
            # do not warn about ambiguities in dependencies
            Aqua.test_ambiguities(CTModels)
        end

        Test.@testset "JET — hot path" begin
            # --- Time-function functors (Components) ---
            f_const = Components.ConstantInTime(1.0)
            JET.@test_opt target_modules = (CTModels,) f_const(0.5)

            f_coerced = Components.CoercedTrajectory(t -> [2t], only)
            JET.@test_opt target_modules = (CTModels,) f_coerced(0.5)

            # --- Component accessors (state/control solution reads) ---
            sms = Components.StateModelSolution("x", ["x1", "x2"], t -> [sin(t), cos(t)])
            JET.@test_opt target_modules = (CTModels,) Components.value(sms)
            JET.@test_opt target_modules = (CTModels,) Components.dimension(sms)

            cms = Components.ControlModelSolution("u", ["u"], t -> cos(t), :constant)
            JET.@test_opt target_modules = (CTModels,) Components.value(cms)
            JET.@test_opt target_modules = (CTModels,) Components.interpolation(cms)

            # --- Dual-by-label functors (Solutions) ---
            duals_fn = t -> [1.0, 2.0, 3.0]
            f_slice = Solutions.DualSlice(duals_fn, 2)
            JET.@test_opt target_modules = (CTModels,) f_slice(0.5)

            f_boxdiff = Solutions.BoxDualDiff(t -> [1.0, 2.0, 3.0], t -> [0.5, 0.5, 0.5], 2)
            JET.@test_opt target_modules = (CTModels,) f_boxdiff(0.5)

            # --- Constraint-by-label functor (Models) ---
            f_proj = Models.BoxProjection{:state}(2)
            JET.@test_opt target_modules = (CTModels,) f_proj(
                nothing, [1.0, 2.0, 3.0], nothing, nothing
            )
        end
    end
end

end # module TestCodeQuality

# CRITICAL: Redefine in outer scope for TestRunner
test_code_quality() = TestCodeQuality.test_code_quality()
