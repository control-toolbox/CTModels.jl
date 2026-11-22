module TestInspectionCallables

using Test: Test
using CTModels: Building
using CTModels: Components
using CTModels: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Module-level helper: a model whose constraints are anonymous closures, the shape that
# leaks `var"#…"` names when it is printed. One nonlinear path declaration and one
# nonlinear boundary declaration (single-declaration groups), and one box per slot.
function _model_with_anonymous_constraints()
    pre = Building.PreModel()
    Building.variable!(pre, 2)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u; nothing))
    Building.objective!(pre, :min; lagrange=(t, x, u, v) -> u^2)
    Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r[1] = x[1] + u; nothing), lb=0.0, ub=1.0, label=:p
    )
    Building.constraint!(
        pre,
        :boundary;
        f=(r, x0, xf, v) -> (r[1] = x0[1]; r[2] = xf[1]; nothing),
        lb=[0.0, 0.0],
        ub=[0.0, 0.0],
        label=:bc,
    )
    Building.constraint!(pre, :state; rg=1:1, lb=-1.0, ub=1.0, label=:x1)
    Building.constraint!(pre, :control; rg=1:1, lb=-10.0, ub=10.0, label=:u)
    Building.constraint!(pre, :variable; rg=1:2, lb=[0.0, 0.0], ub=[1.0, 1.0], label=:v)
    Building.time_dependence!(pre; autonomous=true)
    return Building.build(pre)
end

_leaks_closure(s::AbstractString) = occursin("var\"#", s)

function test_inspection_callables()
    Test.@testset "Inspection callables print as named functors" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        model = _model_with_anonymous_constraints()

        # ====================================================================
        # INTEGRATION TESTS - constraint(model, label)
        # ====================================================================

        Test.@testset "constraint(model, label) — one named functor per kind" begin
            expected = (
                p=(:path, Models.SubPathConstraint, "SubPathConstraint(n=1, indices=1)"),
                bc=(
                    :boundary,
                    Models.SubBoundaryConstraint,
                    "SubBoundaryConstraint(n=2, indices=[1, 2])",
                ),
                x1=(:state, Models.BoxProjection{:state}, "BoxProjection{:state}(1)"),
                u=(:control, Models.BoxProjection{:control}, "BoxProjection{:control}(1)"),
                v=(
                    :variable,
                    Models.BoxProjection{:variable},
                    "BoxProjection{:variable}([1, 2])",
                ),
            )
            for (label, (kind, T, shown)) in pairs(expected)
                c = Models.constraint(model, label)
                Test.@test c[1] == kind
                Test.@test c[2] isa T
                Test.@test repr(c[2]) == shown
                Test.@test !_leaks_closure(repr(c))
                Test.@test !_leaks_closure(repr(MIME("text/plain"), c[2]))
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - stacked nonlinear groups
        # ====================================================================

        Test.@testset "*_constraints_nl — a single declaration prints as a group" begin
            path = Components.path_constraints_nl(model)
            boundary = Components.boundary_constraints_nl(model)
            Test.@test repr(path[2]) == "CompositeConstraint{:path}(n=1, dims=[1])"
            Test.@test repr(boundary[2]) == "CompositeConstraint{:boundary}(n=1, dims=[2])"
            Test.@test !_leaks_closure(repr(path))
            Test.@test !_leaks_closure(repr(boundary))
        end

        # ====================================================================
        # INTEGRATION TESTS - values unchanged
        # ====================================================================

        Test.@testset "constraint(model, label) — evaluation" begin
            t, x, u, v = 0.0, [0.25, 2.0], 0.5, [0.3, 0.7]
            Test.@test Models.constraint(model, :p)[2](t, x, u, v) === 0.75
            Test.@test Models.constraint(model, :bc)[2]([1.0, 0.0], [3.0, 0.0], v) ==
                [1.0, 3.0]
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_inspection_callables() = TestInspectionCallables.test_inspection_callables()
