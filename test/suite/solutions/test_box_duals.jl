module TestBoxDuals

using Test: Test
using CTBase: Exceptions
using JLD2: JLD2
using JSON: JSON
using CTModels: Building
using CTModels: Serialization
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

# A state of dimension 2 whose second component is bounded by no label.
function _box_model_free()
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r .= x; nothing))
    Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    Building.definition!(pre, quote end)
    Building.time_dependence!(pre; autonomous=true)
    Building.constraint!(pre, :state; rg=1, lb=0.0, ub=1.0, label=:x1_box)
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

        # ======================================================================
        # UNIT — the signed dual split back into zL, zU (SGN2/SGN3)
        # ======================================================================
        Test.@testset "split of the signed dual" begin
            for d in (-1.5, 0.0, 2.0), (cl, cu) in ((1.0, 0.0), (0.0, 1.0), (-1.0, 1.0))
                zL = Solutions._split_lower(d, cl, cu)
                zU = Solutions._split_upper(d, cl, cu)
                Test.@test cl * zL + cu * zU == d       # lossless
                Test.@test zL * zU == 0                 # at most one side active
                cl == -1 && Test.@test zL >= 0 && zU >= 0
            end
            f = Solutions.BoxDualSplit{:upper}(t -> [2t - 0.5, t], [-1.0, 1.0], [1.0, 0.0])
            Test.@test f(0.5) == [0.5, 0.0]
            Test.@test (Test.@inferred f(0.5)) isa Vector{Float64}
        end

        # ======================================================================
        # INTEGRATION — box labels in `duals`
        # ======================================================================
        Test.@testset "box labels: values and masks" begin
            d_x2 = 2 .* _T .- 0.5    # changes sign: lower side active, then upper side
            sol = _box_solution(
                ocp; duals=Dict{Symbol,Any}(:x2_two => d_x2, :u_up => 3 .* _T, :v_fix => -0.7)
            )
            for (k, t) in enumerate(_T)
                Test.@test Solutions.dual(sol, ocp, :x2_two)(t) ≈ d_x2[k]
                Test.@test Solutions.dual(sol, ocp, :u_up)(t) ≈ 3t
            end
            Test.@test Solutions.dual(sol, ocp, :v_fix) ≈ -0.7
            # the stored multipliers: nonnegative on a two-sided box, NaN when unknown
            zL, zU = Solutions.state_constraints_lb_dual(sol), Solutions.state_constraints_ub_dual(sol)
            Test.@test zL(0.0)[2] ≈ 0.5 && zU(0.0)[2] == 0.0
            Test.@test zL(1.0)[2] == 0.0 && zU(1.0)[2] ≈ 1.5
            Test.@test isnan(zL(0.5)[1]) && isnan(zU(0.5)[1])      # :x1_lo not given
            Test.@test Solutions.dual_model(sol).known.state == [false, true]
            Test.@test isnothing(Solutions.dual_model(sol).known.control)
            # an absent box label is unknown
            Test.@test !Solutions.has_dual(sol, ocp, :x1_lo)
            Test.@test_throws Exceptions.PreconditionError Solutions.dual(sol, ocp, :x1_lo)
            Test.@test Solutions.has_dual(sol, ocp, :x2_two)
        end

        Test.@testset "box labels as functions, with path labels" begin
            sol = _box_solution(
                ocp;
                duals=Dict{Symbol,Any}(
                    :x1_lo => t -> t,
                    :x2_two => t -> 2t - 0.5,
                    :u_up => t -> [3t],
                    :p => t -> -t,
                ),
            )
            for t in (0.1, 0.33, 0.9)  # exact between the grid points
                Test.@test Solutions.dual(sol, ocp, :x1_lo)(t) ≈ t
                Test.@test Solutions.dual(sol, ocp, :x2_two)(t) ≈ 2t - 0.5
                Test.@test Solutions.dual(sol, ocp, :u_up)(t) ≈ 3t
                Test.@test Solutions.dual(sol, ocp, :p)(t) ≈ -t
            end
            Test.@test Solutions.dual_model(sol).known == Solutions.DualMasks()  # all known
            Test.@test Solutions.state_constraints_lb_dual(sol)(0.1) ≈ [0.1, 0.3]
            # a matrix label mixed with a function label of the same kind
            sol = _box_solution(ocp; duals=Dict{Symbol,Any}(:x1_lo => _T, :x2_two => t -> 2t - 0.5))
            Test.@test Solutions.dual(sol, ocp, :x1_lo)(0.5) ≈ 0.5
            Test.@test Solutions.dual(sol, ocp, :x2_two)(0.6) ≈ 0.7
        end

        Test.@testset "a component bounded by no label is a known 0" begin
            ocp_free = _box_model_free()
            sol = Solutions.build_solution(
                ocp_free, _T, zeros(_N, 2), zeros(_N, 1), Float64[], zeros(_N, 2);
                objective=0.0, successful=true, duals=Dict(:x1_box => t -> -t),
            )
            Test.@test Solutions.dual_model(sol).known.state === nothing
            Test.@test Solutions.state_constraints_lb_dual(sol)(0.5) == [0.5, 0.0]
            Test.@test Solutions.state_constraints_ub_dual(sol)(0.5) == [0.0, 0.0]
        end

        # ======================================================================
        # NON-REGRESSION — by label and by component agree
        # ======================================================================
        Test.@testset "by label and by component agree" begin
            d(t) = [t, 2t - 0.5]                 # signed duals of :x1_lo, :x2_two
            sol_label = _box_solution(
                ocp; duals=Dict{Symbol,Any}(:x1_lo => t -> d(t)[1], :x2_two => t -> d(t)[2])
            )
            sol_comp = _box_solution(
                ocp;
                state_constraints_lb_dual=t -> [d(t)[1], max(-d(t)[2], 0.0)],
                state_constraints_ub_dual=t -> [0.0, max(d(t)[2], 0.0)],
            )
            for label in (:x1_lo, :x2_two), t in (0.0, 0.2, 0.7)
                Test.@test Solutions.dual(sol_label, ocp, label)(t) ≈
                    Solutions.dual(sol_comp, ocp, label)(t)
            end
        end

        # ======================================================================
        # INTEGRATION — limits of the duals at the switching times, by label
        # ======================================================================
        Test.@testset "switching limits by label" begin
            sw = Solutions.SwitchingModel(;
                times=[0.5],
                duals=Dict(
                    :p => ([1.0], [2.0]),           # one-row label: vectors
                    :x2_two => ([-0.5;;], [0.5;;]),  # signed dual of a two-sided box
                    :u_up => ([0.0], [1.0]),
                ),
            )
            sol = _box_solution(ocp; switching=sw, duals=Dict(:x2_two => t -> 2t - 0.5))
            m = Solutions.switching_model(sol)
            Test.@test isempty(m.labelled_duals)                  # placed by build_solution
            Test.@test Solutions.limits(m, :path_dual) == ([1.0;;], [2.0;;])
            L, R = Solutions.limits(m, :state_dual)
            Test.@test isnan(L[1, 1]) && isnan(R[1, 1])          # :x1_lo not given
            Test.@test (L[1, 2], R[1, 2]) == (-0.5, 0.5)
            Test.@test Solutions.limits(m, :control_dual) == ([0.0;;], [1.0;;])
            Test.@test Solutions.right_limit(sol, :control_dual, 1) == 1.0  # DIM1: scalar
            Test.@test occursin("state_dual", sprint(show, MIME"text/plain"(), m))
            # a kind with no label keeps no limit
            sw_p = Solutions.SwitchingModel(; times=[0.5], duals=Dict(:p => ([1.0], [2.0])))
            m_p = Solutions.switching_model(_box_solution(ocp; switching=sw_p))
            Test.@test size(Solutions.limits(m_p, :state_dual)[1]) == (1, 0)
        end

        Test.@testset "switching limits: errors and deprecation" begin
            sol_with(duals) = _box_solution(
                ocp; switching=Solutions.SwitchingModel(; times=[0.5], duals=duals)
            )
            # no limits for a dual that does not depend on time
            Test.@test_throws Exceptions.IncorrectArgument sol_with(Dict(:v_fix => ([0.0], [1.0])))
            # unknown label, wrong number of columns, not a (left, right) pair
            Test.@test_throws Exceptions.IncorrectArgument sol_with(Dict(:nope => ([0.0], [1.0])))
            Test.@test_throws Exceptions.IncorrectArgument sol_with(Dict(:p => ([0.0 1.0], [1.0 2.0])))
            Test.@test_throws Exceptions.IncorrectArgument Solutions.SwitchingModel(;
                times=[0.5], duals=Dict(:p => [0.0, 1.0])
            )
            # one row per switching time
            Test.@test_throws Exceptions.IncorrectArgument Solutions.SwitchingModel(;
                times=[0.5], duals=Dict(:p => ([0.0, 1.0], [1.0, 2.0]))
            )
            # the deprecated stacked keyword, alone and together with path labels
            sw = Test.@test_deprecated Solutions.SwitchingModel(;
                times=[0.5], path_dual=([1.0;;], [2.0;;])
            )
            Test.@test Solutions.limits(sw, :path_dual) == ([1.0;;], [2.0;;])
            sw_both = Test.@test_deprecated Solutions.SwitchingModel(;
                times=[0.5], path_dual=([1.0;;], [2.0;;]), duals=Dict(:p => ([1.0], [2.0]))
            )
            Test.@test_throws Exceptions.IncorrectArgument _box_solution(ocp; switching=sw_both)
        end

        # ======================================================================
        # INTEGRATION — export / import keep the unknown box duals unknown
        # ======================================================================
        sw_labels() = Solutions.SwitchingModel(;
            times=[0.5], duals=Dict(:x2_two => ([-0.5;;], [0.5;;]), :p => ([1.0], [2.0]))
        )
        partial() = _box_solution(
            ocp;
            switching=sw_labels(),
            duals=Dict{Symbol,Any}(:x2_two => 2 .* _T .- 0.5, :u_up => 3 .* _T, :p => -_T),
        )
        Test.@testset "serialization round trip ($fmt)" for fmt in (:JLD, :JSON)
            sol = partial()
            mktempdir() do dir
                file = joinpath(dir, "box_duals")
                Serialization.export_ocp_solution(sol; filename=file, format=fmt)
                sol2 = Serialization.import_ocp_solution(ocp; filename=file, format=fmt)
                for t in _T
                    Test.@test Solutions.dual(sol2, ocp, :x2_two)(t) ≈ 2t - 0.5
                    Test.@test Solutions.dual(sol2, ocp, :u_up)(t) ≈ 3t
                end
                Test.@test !Solutions.has_dual(sol2, ocp, :x1_lo)    # still unknown
                Test.@test !Solutions.has_dual(sol2, ocp, :v_fix)    # never stored
                Test.@test Solutions.dual_model(sol2).known.state == [false, true]
                L, R = Solutions.limits(Solutions.switching_model(sol2), :state_dual)
                Test.@test isnan(L[1, 1]) && (L[1, 2], R[1, 2]) == (-0.5, 0.5)
                Test.@test Solutions.limits(Solutions.switching_model(sol2), :path_dual) ==
                    ([1.0;;], [2.0;;])
            end
        end

        Test.@testset "JSON: null for unknown box duals and limits; files without masks" begin
            mktempdir() do dir
                file = joinpath(dir, "box_duals")
                Serialization.export_ocp_solution(partial(); filename=file, format=:JSON)
                blob = JSON.parse(read(file * ".json", String); dicttype=Dict{String,Any})
                Test.@test all(isnothing(row[1]) for row in blob["state_constraints_lb_dual"])
                Test.@test blob["state_constraints_dual_known"] == [false, true]
                Test.@test !haskey(blob, "control_constraints_dual_known")   # all known
                Test.@test isnothing(blob["switching_state_dual_left"][1][1])
            end
            # every box component known: no mask written, the keywords on reading
            sol = _box_solution(
                ocp;
                duals=Dict{Symbol,Any}(:x1_lo => _T, :x2_two => 2 .* _T .- 0.5, :v_fix => 0.3),
            )
            mktempdir() do dir
                file = joinpath(dir, "full")
                Serialization.export_ocp_solution(sol; filename=file, format=:JSON)
                blob = JSON.parse(read(file * ".json", String); dicttype=Dict{String,Any})
                Test.@test !haskey(blob, "state_constraints_dual_known")
                sol2 = Serialization.import_ocp_solution(ocp; filename=file, format=:JSON)
                Test.@test Solutions.dual(sol2, ocp, :x1_lo)(0.5) ≈ 0.5
                Test.@test Solutions.dual(sol2, ocp, :v_fix) ≈ 0.3
            end
        end

        # ======================================================================
        # ERROR — invalid box duals (EXC1)
        # ======================================================================
        Test.@testset "invalid box duals" begin
            bad(; kw...) = _box_solution(ocp; kw...)
            # a kind given both by label and by keyword
            Test.@test_throws Exceptions.IncorrectArgument bad(;
                duals=Dict(:u_up => t -> t), control_constraints_ub_dual=zeros(_N, 1)
            )
            # sizes and types
            Test.@test_throws Exceptions.IncorrectArgument bad(; duals=Dict(:x1_lo => t -> [t, t]))
            Test.@test_throws Exceptions.IncorrectArgument bad(; duals=Dict(:x1_lo => [_T _T]))
            Test.@test_throws Exceptions.IncorrectArgument bad(; duals=Dict(:v_fix => [1.0, 2.0]))
            Test.@test_throws Exceptions.IncorrectArgument bad(; duals=Dict(:v_fix => t -> t))
            Test.@test_throws Exceptions.IncorrectArgument bad(;
                duals=Dict{Symbol,Any}(:x1_lo => _T, :x2_two => _T[1:4])
            )
            # by label for the boxes and by keyword for another kind: accepted
            Test.@test bad(;
                duals=Dict(:x1_lo => t -> t), control_constraints_ub_dual=zeros(_N, 1),
                control_constraints_lb_dual=zeros(_N, 1),
            ) isa Solutions.Solution
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_box_duals() = TestBoxDuals.test_box_duals()
