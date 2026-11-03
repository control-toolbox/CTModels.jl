module TestLabelledDuals

using Test: Test
using CTBase: Exceptions
using CTModels: CTModels
using CTModels: Building
using CTModels: Models
using CTModels: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# TOP-LEVEL fixtures (TST3)
# ==============================================================================

# Constraint functions of the fixture model.
_ld_path2!(r, t, x, u, v) = (r .= x .+ u[1]; nothing)
_ld_path1!(r, t, x, u, v) = (r[1] = u[1]; nothing)
_ld_boundary1!(r, x0, xf, v) = (r[1] = x0[1]; nothing)
_ld_boundary2!(r, x0, xf, v) = (r .= xf; nothing)

# A model whose path and boundary constraints are declared interleaved with each other
# and with a state box. Stacked layout:
#   path     rows 1:2 → :c2, row 3 → :c1
#   boundary row  1   → :b1, rows 2:3 → :b2
function _ld_model()
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r .= x; nothing))
    Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    Building.definition!(pre, quote end)
    Building.time_dependence!(pre; autonomous=true)
    Building.constraint!(pre, :path; f=_ld_path2!, lb=[0, 0], ub=[1, 1], label=:c2)
    Building.constraint!(pre, :boundary; f=_ld_boundary1!, lb=0, ub=0, label=:b1)
    Building.constraint!(pre, :state; rg=2, lb=-1, ub=1, label=:x2_box)
    Building.constraint!(pre, :path; f=_ld_path1!, lb=-1, ub=1, label=:c1)
    Building.constraint!(pre, :boundary; f=_ld_boundary2!, lb=[0, 0], ub=[0, 0], label=:b2)
    return Building.build(pre)
end

# Fake producer dual: a callable struct, as a flow builds its duals (a closure over the
# trajectory), giving the dual of the two-row label :c2.
struct _FakeFlowDual <: Function
    scale::Float64
end
(f::_FakeFlowDual)(t) = f.scale .* [t, 2t]

const _T = collect(range(0.0, 1.0; length=5))

# A solution of the fixture model with the duals `duals` given by label.
function _ld_solution(ocp, duals; kwargs...)
    N = length(_T)
    return Solutions.build_solution(
        ocp,
        _T,
        zeros(N, 2),
        zeros(N, 1),
        Float64[],
        zeros(N, 2);
        objective=0.0,
        successful=true,
        duals=duals,
        kwargs...,
    )
end

# The dual of :c2 sampled on `_T` (times × 2 rows) and its exact value at `t`.
const _C2 = [_T 2 .* _T]
_c2(t) = [t, 2t]

function test_labelled_duals()
    Test.@testset "Duals by label" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp = _ld_model()

        # ======================================================================
        # UNIT — StackedDuals
        # ======================================================================
        Test.@testset "StackedDuals" begin
            f = Solutions.StackedDuals(4, ((1:2, t -> [t, 2t]), (4:4, t -> 3t)))
            v = f(0.5)
            Test.@test v[[1, 2, 4]] == [0.5, 1.0, 1.5]
            Test.@test isnan(v[3])  # the rows of the labels not given are unknown
            Test.@test (Test.@inferred f(0.5)) isa Vector{Float64}
            # a fresh vector at each call: the caller may keep it
            Test.@test f(0.5) !== f(0.5)
        end

        # ======================================================================
        # UNIT — placement into the stacked layout
        # ======================================================================
        Test.@testset "placement" begin
            # every label, all matrices: one stacked matrix, mask canonical (all known)
            (pc, pk), (bc, bk) = Solutions._place_duals(
                ocp, Dict{Symbol,Any}(:c1 => 3 .* _T, :c2 => _C2, :b1 => 1.0, :b2 => [2.0, 3.0]), _T
            )
            Test.@test pc == [_C2 3 .* _T]
            Test.@test bc == [1.0, 2.0, 3.0]
            Test.@test isnothing(pk) && isnothing(bk)

            # some labels only: NaN in the unknown rows, mask as a vector
            (pc, pk), (bc, bk) = Solutions._place_duals(ocp, Dict(:c1 => reshape(3 .* _T, :, 1)), _T)
            Test.@test pc[:, 3] == 3 .* _T
            Test.@test all(isnan, pc[:, 1:2])
            Test.@test pk == [false, false, true]
            Test.@test isnothing(bc) && isnothing(bk)  # no boundary label: no boundary dual

            (_, _), (bc, bk) = Solutions._place_duals(ocp, Dict(:b2 => [2.0, 3.0]), _T)
            Test.@test isnan(bc[1]) && bc[2:3] == [2.0, 3.0]
            Test.@test bk == [false, true, true]

            # a function among the path labels: every part becomes a function of time
            (pc, pk), _ = Solutions._place_duals(
                ocp, Dict{Symbol,Any}(:c2 => _FakeFlowDual(1.0), :c1 => 3 .* _T), _T
            )
            Test.@test pc isa Solutions.StackedDuals
            Test.@test pc(0.5) ≈ [0.5, 1.0, 1.5]
            Test.@test isnothing(pk)

            # canonical mask
            Test.@test isnothing(Solutions._canonical_mask([true, true]))
            Test.@test Solutions._canonical_mask([true, false]) == [true, false]
        end

        # ======================================================================
        # INTEGRATION — build_solution(...; duals=...) and dual(sol, ocp, :label)
        # ======================================================================
        Test.@testset "build_solution and dual" begin
            sol = _ld_solution(ocp, Dict{Symbol,Any}(:c2 => _C2, :b2 => [2.0, 3.0]))
            Test.@test Solutions.dual(sol, ocp, :c2)(0.5) ≈ _c2(0.5)
            Test.@test Solutions.dual(sol, ocp, :b2) == [2.0, 3.0]
            # the raw stacked accessor: NaN in the unknown rows, never a fake 0
            Test.@test isnan(Solutions.path_constraints_dual(sol)(0.5)[3])
            Test.@test isnan(Solutions.boundary_constraints_dual(sol)[1])

            # a label given as 0 is a known 0
            sol0 = _ld_solution(ocp, Dict{Symbol,Any}(:c1 => zeros(5), :b1 => 0.0))
            Test.@test Solutions.dual(sol0, ocp, :c1)(0.5) == 0.0
            Test.@test Solutions.dual(sol0, ocp, :b1) == 0.0

            # a one-row label gives a scalar (DIM1), from a vector or a function
            Test.@test Solutions.dual(sol0, ocp, :c1)(0.5) isa Float64
            solf = _ld_solution(ocp, Dict{Symbol,Any}(:c1 => t -> 3t, :c2 => _FakeFlowDual(2.0)))
            Test.@test Solutions.dual(solf, ocp, :c1)(0.25) ≈ 0.75
            Test.@test Solutions.dual(solf, ocp, :c2)(0.25) ≈ 2 .* _c2(0.25)

            # a path grid of its own (the multi-grid method; the cases above go through
            # the single-grid one, which forwards `duals`)
            Tp = collect(range(0.0, 1.0; length=3))
            solp = Solutions.build_solution(
                ocp, _T, _T, _T, Tp, zeros(5, 2), zeros(5, 1), Float64[], zeros(5, 2);
                objective=0.0, successful=true, duals=Dict(:c2 => [Tp 2 .* Tp]),
            )
            Test.@test Solutions.dual(solp, ocp, :c2)(0.25) ≈ _c2(0.25)

            # no duals at all: the solution carries none, as before
            Test.@test !Solutions.has_duals(_ld_solution(ocp, Dict{Symbol,Any}()))
        end

        # ======================================================================
        # NON-REGRESSION — the positional input, read by label
        # ======================================================================
        Test.@testset "positional and by label agree" begin
            sol_label = _ld_solution(
                ocp, Dict{Symbol,Any}(:c1 => 3 .* _T, :c2 => _C2, :b1 => 1.0, :b2 => [2.0, 3.0])
            )
            sol_pos = _ld_solution(
                ocp,
                Dict{Symbol,Any}();
                path_constraints_dual=[_C2 3 .* _T],
                boundary_constraints_dual=[1.0, 2.0, 3.0],
            )
            for label in (:c1, :c2)
                Test.@test Solutions.dual(sol_label, ocp, label)(0.3) ≈
                    Solutions.dual(sol_pos, ocp, label)(0.3)
            end
            for label in (:b1, :b2)
                Test.@test Solutions.dual(sol_label, ocp, label) ==
                    Solutions.dual(sol_pos, ocp, label)
            end
            # every row known: same canonical storage as the positional input
            Test.@test isnothing(Solutions.dual_model(sol_label).path_constraints_dual_known)

            # the eight-dual constructor: every stored row known
            dm = Solutions.DualModel(nothing, [1.0], nothing, nothing, nothing, nothing, nothing, nothing)
            Test.@test isnothing(dm.path_constraints_dual_known)
            Test.@test isnothing(dm.boundary_constraints_dual_known)
        end

        # ======================================================================
        # ERROR — unknown duals and invalid input (EXC1)
        # ======================================================================
        Test.@testset "absent label is unknown" begin
            sol = _ld_solution(ocp, Dict{Symbol,Any}(:c2 => _C2, :b2 => [2.0, 3.0]))
            Test.@test_throws Exceptions.PreconditionError Solutions.dual(sol, ocp, :c1)
            Test.@test_throws Exceptions.PreconditionError Solutions.dual(sol, ocp, :b1)
            # no boundary label given at all: the boundary duals are not stored
            solp = _ld_solution(ocp, Dict(:c2 => _C2))
            Test.@test_throws Exceptions.PreconditionError Solutions.dual(solp, ocp, :b2)
            # the producer's note is the suggestion
            soln = _ld_solution(
                ocp, Dict(:c2 => _C2); infos=Dict{Symbol,Any}(:missing_duals => "NOTE-492")
            )
            err = try
                Solutions.dual(soln, ocp, :c1)
            catch e
                e
            end
            Test.@test err isa Exceptions.PreconditionError
            Test.@test occursin("NOTE-492", sprint(showerror, err))
        end

        Test.@testset "invalid input" begin
            bad(d) = _ld_solution(ocp, d)
            # unknown label, box label
            Test.@test_throws Exceptions.IncorrectArgument bad(Dict(:nope => 1.0))
            Test.@test_throws Exceptions.IncorrectArgument bad(Dict(:x2_box => [_T _T]))
            # wrong sizes
            Test.@test_throws Exceptions.IncorrectArgument bad(Dict(:c2 => [_T _T _T]))
            Test.@test_throws Exceptions.IncorrectArgument bad(Dict(:c2 => _T))
            Test.@test_throws Exceptions.IncorrectArgument bad(Dict(:c2 => t -> [t]))
            Test.@test_throws Exceptions.IncorrectArgument bad(Dict(:b2 => 1.0))
            Test.@test_throws Exceptions.IncorrectArgument bad(Dict(:b1 => [1.0, 2.0]))
            # wrong types
            Test.@test_throws Exceptions.IncorrectArgument bad(Dict(:c1 => "dual"))
            Test.@test_throws Exceptions.IncorrectArgument bad(Dict(:b1 => t -> t))
            # path labels sampled on different numbers of times
            Test.@test_throws Exceptions.IncorrectArgument bad(
                Dict{Symbol,Any}(:c1 => 3 .* _T, :c2 => _C2[1:4, :])
            )
        end

        # ======================================================================
        # CONTRACT — exports
        # ======================================================================
        Test.@testset "exports" begin
            Test.@test :constraint_rows in names(Models)
            Test.@test :StackedDuals ∉ names(Solutions)  # an internal of the layout
            Test.@test :constraint_rows ∉ names(CTModels)  # no top-level export (MOD8)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_labelled_duals() = TestLabelledDuals.test_labelled_duals()
