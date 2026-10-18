module TestSwitching

using Test: Test
using CTBase: Exceptions
using CTModels: CTModels
using CTModels: Building
using CTModels: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ============================================================================
# Problems and data (module top level, TST3)
# ============================================================================

# ẋ = u, 1-D state and control, t ∈ [0, 1].
function _ocp_1d()
    pre = Building.PreModel()
    Building.time_dependence!(pre; autonomous=true)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 1)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
    Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return Building.build(pre)
end

# ẋ = (x₂, u), 2-D state, 1-D control, t ∈ [0, 1].
function _ocp_2d()
    pre = Building.PreModel()
    Building.time_dependence!(pre; autonomous=true)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u; nothing))
    Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return Building.build(pre)
end

const τ = 0.5
const T11 = collect(range(0.0, 1.0; length=11))
# x(t) = t, then a jump of +1 at τ; u = 1 then -1; p = 0 then a jump to 2.
_x(t) = t <= τ ? t : t + 1.0
_u(t) = t <= τ ? 1.0 : -1.0
_p(t) = t <= τ ? 0.0 : 2.0

function _sw_1d(; labels=["bang+", "bang-"])
    return Solutions.SwitchingModel(;
        times=[τ],
        labels=labels,
        state=([τ;;], [τ + 1.0;;]),
        costate=([0.0;;], [2.0;;]),
        control=([1.0;;], [-1.0;;]),
    )
end

function _sol_1d(; T=T11, switching=_sw_1d(), kw...)
    X = reshape(_x.(T), :, 1)
    U = reshape(_u.(T), :, 1)
    P = reshape(_p.(T), :, 1)
    return Solutions.build_solution(
        _ocp_1d(),
        T,
        X,
        U,
        Float64[],
        P;
        objective=1.0,
        successful=true,
        switching=switching,
        kw...,
    )
end

_show(sol) = sprint(show, MIME"text/plain"(), sol)

function test_switching()
    Test.@testset "Switching structure" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - SwitchingModel construction
        # ====================================================================

        Test.@testset "SwitchingModel: keyword constructor and defaults" begin
            sw = _sw_1d()
            Test.@test sw isa Solutions.AbstractSwitchingModel
            Test.@test Solutions.switching_times(sw) == [τ]
            Test.@test Solutions.phase_labels(sw) == ["bang+", "bang-"]
            Test.@test Solutions.has_switching(sw)
            Test.@test Solutions.limits(sw, :state) == ([τ;;], [τ + 1.0;;])
            Test.@test Solutions.limits(sw, :control)[2] == [-1.0;;]
            # defaults: no labels, limits not known
            d = Solutions.SwitchingModel(; times=[0.2, 0.6])
            Test.@test Solutions.phase_labels(d) == ["", "", ""]
            Test.@test size(Solutions.limits(d, :state)[1]) == (2, 0)
            # conversions: Int times, SubString labels, Int matrices
            c = Solutions.SwitchingModel(;
                times=[1],
                labels=[SubString("ab", 1, 1), "b"],
                state=([1;;], [2;;]),
            )
            Test.@test Solutions.switching_times(c) == [1.0]
            Test.@test Solutions.phase_labels(c) == ["a", "b"]
            Test.@test eltype(Solutions.limits(c, :state)[1]) == Float64
            # a labelled single phase: no switching time, one label
            one = Solutions.SwitchingModel(; times=Float64[], labels=["bang"])
            Test.@test !Solutions.has_switching(one)
            Test.@test Solutions.phase_labels(one) == ["bang"]
        end

        Test.@testset "EmptySwitchingModel" begin
            e = Solutions.EmptySwitchingModel()
            Test.@test Solutions.switching_times(e) == Float64[]
            Test.@test Solutions.phase_labels(e) == String[]
            Test.@test !Solutions.has_switching(e)
            Test.@test Solutions.limits(e, :costate) == (zeros(0, 0), zeros(0, 0))
        end

        # ====================================================================
        # ERROR TESTS - SwitchingModel
        # ====================================================================

        Test.@testset "SwitchingModel: errors" begin
            # not strictly increasing
            Test.@test_throws Exceptions.IncorrectArgument Solutions.SwitchingModel(;
                times=[0.5, 0.5]
            )
            Test.@test_throws Exceptions.IncorrectArgument Solutions.SwitchingModel(;
                times=[0.6, 0.2]
            )
            # not finite
            Test.@test_throws Exceptions.IncorrectArgument Solutions.SwitchingModel(;
                times=[Inf]
            )
            # wrong number of labels
            Test.@test_throws Exceptions.IncorrectArgument Solutions.SwitchingModel(;
                times=[0.5], labels=["only one"]
            )
            # wrong number of rows, or left/right sizes differ
            Test.@test_throws Exceptions.IncorrectArgument Solutions.SwitchingModel(;
                times=[0.5], state=(zeros(2, 1), zeros(2, 1))
            )
            Test.@test_throws Exceptions.IncorrectArgument Solutions.SwitchingModel(;
                times=[0.5], state=(zeros(1, 1), zeros(1, 2))
            )
            # unknown component
            Test.@test_throws Exceptions.IncorrectArgument Solutions.limits(_sw_1d(), :foo)
            Test.@test_throws Exceptions.IncorrectArgument Solutions.limits(
                Solutions.EmptySwitchingModel(), :foo
            )
        end

        # ====================================================================
        # UNIT TESTS - build_solution with a switching model
        # ====================================================================

        Test.@testset "build_solution: getters" begin
            sol = _sol_1d()
            Test.@test Solutions.switching_model(sol) isa Solutions.SwitchingModel
            Test.@test CTModels.switching_times(sol) == [τ]
            Test.@test CTModels.phase_labels(sol) == ["bang+", "bang-"]
            Test.@test CTModels.has_switching(sol)
            # 1-D components are scalars (DIM1)
            Test.@test CTModels.left_limit(sol, :state, 1) === τ
            Test.@test CTModels.right_limit(sol, :state, 1) === τ + 1.0
            Test.@test CTModels.left_limit(sol, :costate, 1) === 0.0
            Test.@test CTModels.right_limit(sol, :costate, 1) === 2.0
            Test.@test CTModels.right_limit(sol, :control, 1) === -1.0
            # default: no switching structure
            plain = _sol_1d(; switching=Solutions.EmptySwitchingModel())
            Test.@test Solutions.switching_model(plain) isa Solutions.EmptySwitchingModel
            Test.@test isempty(CTModels.switching_times(plain))
            Test.@test isempty(CTModels.phase_labels(plain))
            Test.@test !CTModels.has_switching(plain)
        end

        Test.@testset "build_solution: vector limits in dimension 2" begin
            T = [0.0, 0.5, 1.0]
            sw = Solutions.SwitchingModel(;
                times=[0.5],
                state=([1.0 2.0], [3.0 4.0]),
                costate=([0.0 0.0], [1.0 1.0]),
                control=([1.0;;], [-1.0;;]),
            )
            sol = Solutions.build_solution(
                _ocp_2d(),
                T,
                zeros(3, 2),
                zeros(3, 1),
                Float64[],
                zeros(3, 2);
                objective=0.0,
                successful=true,
                switching=sw,
            )
            Test.@test CTModels.left_limit(sol, :state, 1) == [1.0, 2.0]
            Test.@test CTModels.right_limit(sol, :state, 1) == [3.0, 4.0]
            Test.@test CTModels.right_limit(sol, :control, 1) === -1.0
        end

        Test.@testset "the trajectories keep their jumps (matrix data)" begin
            sol = _sol_1d()
            x = CTModels.state(sol)
            u = CTModels.control(sol)
            p = CTModels.costate(sol)
            # left-continuous at τ
            Test.@test x(τ) ≈ τ
            Test.@test u(τ) ≈ 1.0
            Test.@test p(τ) ≈ 0.0
            # just after τ: the right limit, not a blend across the jump
            Test.@test x(0.55) ≈ 1.55
            Test.@test p(0.55) ≈ 2.0
            Test.@test u(0.55) ≈ -1.0
            # away from τ: the plain interpolation
            Test.@test x(0.3) ≈ 0.3
            Test.@test x(0.8) ≈ 1.8
            Test.@test x(1.0) ≈ 2.0
        end

        Test.@testset "jumps between grid points (τ not in the grid)" begin
            T = [0.0, 0.4, 0.6, 1.0]
            sol = _sol_1d(; T=T)
            x = CTModels.state(sol)
            # between 0.4 and τ: towards the left limit; between τ and 0.6: from the right
            Test.@test x(0.45) ≈ 0.45
            Test.@test x(τ) ≈ τ
            Test.@test x(0.55) ≈ 1.55
            Test.@test x(0.6) ≈ 1.6
            Test.@test x(0.2) ≈ 0.2
        end

        Test.@testset "piecewise-constant control keeps its switch" begin
            sol = _sol_1d(; control_interpolation=:constant)
            u = CTModels.control(sol)
            Test.@test u(0.45) ≈ 1.0
            Test.@test u(τ) ≈ 1.0
            Test.@test u(0.55) ≈ -1.0
            Test.@test u(0.95) ≈ -1.0
        end

        Test.@testset "function data is used as is" begin
            sol = Solutions.build_solution(
                _ocp_1d(),
                T11,
                t -> [_x(t)],
                t -> [_u(t)],
                Float64[],
                t -> [_p(t)];
                objective=1.0,
                successful=true,
                switching=_sw_1d(),
            )
            Test.@test CTModels.state(sol)(0.55) ≈ 1.55
            Test.@test CTModels.state(sol)(τ) ≈ τ
            Test.@test CTModels.switching_times(sol) == [τ]
        end

        Test.@testset "limits not known: plain interpolation" begin
            sw = Solutions.SwitchingModel(; times=[τ], labels=["a", "b"])
            sol = _sol_1d(; switching=sw)
            # the linear interpolation between 0.5 (x = 0.5) and 0.6 (x = 1.6)
            Test.@test CTModels.state(sol)(0.55) ≈ 1.05
        end

        Test.@testset "multiple grids keep the jumps on each grid" begin
            Ts = T11
            Tu = collect(range(0.0, 1.0; length=6))
            sol = Solutions.build_solution(
                _ocp_1d(),
                Ts,
                Tu,
                Ts,
                nothing,
                reshape(_x.(Ts), :, 1),
                reshape(_u.(Tu), :, 1),
                Float64[],
                reshape(_p.(Ts), :, 1);
                objective=1.0,
                successful=true,
                switching=_sw_1d(),
            )
            Test.@test CTModels.state(sol)(0.55) ≈ 1.55
            Test.@test CTModels.control(sol)(0.55) ≈ -1.0
        end

        # ====================================================================
        # ERROR TESTS - build_solution
        # ====================================================================

        Test.@testset "build_solution: switching errors" begin
            # switching time outside (t0, tf)
            for t in (0.0, 1.0, 1.5)
                sw = Solutions.SwitchingModel(; times=[t])
                Test.@test_throws Exceptions.IncorrectArgument _sol_1d(; switching=sw)
            end
            # wrong number of columns of the limits
            bad = Solutions.SwitchingModel(; times=[τ], state=(zeros(1, 2), zeros(1, 2)))
            Test.@test_throws Exceptions.IncorrectArgument _sol_1d(; switching=bad)
            bad_u = Solutions.SwitchingModel(;
                times=[τ], control=(zeros(1, 3), zeros(1, 3))
            )
            Test.@test_throws Exceptions.IncorrectArgument _sol_1d(; switching=bad_u)
        end

        Test.@testset "left_limit / right_limit: errors" begin
            sol = _sol_1d()
            for i in (0, 2)
                Test.@test_throws Exceptions.IncorrectArgument CTModels.left_limit(
                    sol, :state, i
                )
                Test.@test_throws Exceptions.IncorrectArgument CTModels.right_limit(
                    sol, :state, i
                )
            end
            Test.@test_throws Exceptions.IncorrectArgument CTModels.right_limit(
                sol, :foo, 1
            )
            # no switching time
            plain = _sol_1d(; switching=Solutions.EmptySwitchingModel())
            Test.@test_throws Exceptions.IncorrectArgument CTModels.right_limit(
                plain, :state, 1
            )
            # limits not known
            nolim = _sol_1d(; switching=Solutions.SwitchingModel(; times=[τ]))
            Test.@test_throws Exceptions.PreconditionError CTModels.left_limit(
                nolim, :state, 1
            )
            Test.@test_throws Exceptions.PreconditionError CTModels.right_limit(
                nolim, :control, 1
            )
        end

        Test.@testset "strict grid: a repeated time is an error" begin
            T = [0.0, 0.5, 0.5, 1.0]
            Test.@test_throws Exceptions.IncorrectArgument Solutions.build_solution(
                _ocp_1d(),
                T,
                zeros(4, 1),
                zeros(4, 1),
                Float64[],
                zeros(4, 1);
                objective=0.0,
                successful=true,
            )
            # also when the grid is not sorted (the repetition shows once sorted)
            Tu = [0.5, 1.0, 0.0, 0.5]
            Test.@test_throws Exceptions.IncorrectArgument Solutions.build_solution(
                _ocp_1d(),
                Tu,
                zeros(4, 1),
                zeros(4, 1),
                Float64[],
                zeros(4, 1);
                objective=0.0,
                successful=true,
            )
            # an unsorted grid without repeated time is still sorted, with a warning
            sol = Test.@test_logs (:warn, r"not increasing") match_mode = :any Solutions.build_solution(
                _ocp_1d(),
                [0.0, 1.0, 0.5],
                zeros(3, 1),
                zeros(3, 1),
                Float64[],
                zeros(3, 1);
                objective=0.0,
                successful=true,
            )
            Test.@test CTModels.time_grid(sol) == [0.0, 0.5, 1.0]
        end

        # ====================================================================
        # UNIT TESTS - backward-compatible positional constructor
        # ====================================================================

        Test.@testset "positional Solution constructor without switching" begin
            sol = _sol_1d()
            s10 = Solutions.Solution(
                sol.time_grid,
                sol.times,
                sol.state,
                sol.control,
                sol.variable,
                sol.model,
                sol.costate,
                sol.objective,
                sol.dual,
                sol.solver_infos,
            )
            Test.@test Solutions.switching_model(s10) isa Solutions.EmptySwitchingModel
            Test.@test CTModels.state(s10)(0.55) ≈ 1.55   # trajectories kept
        end

        # ====================================================================
        # UNIT TESTS - display
        # ====================================================================

        Test.@testset "show: switching times and phases" begin
            s = _show(_sol_1d())
            Test.@test occursin("Switching times : [0.5]", s)
            Test.@test occursin("Phases : bang+ → bang-", s)
            # the last row closes the tree
            Test.@test occursin("└─ Phases", s)
            # unlabelled phase shows as ·
            s2 = _show(_sol_1d(; switching=_sw_1d(; labels=["", "bang-"])))
            Test.@test occursin("Phases : · → bang-", s2)
            # no label at all: no Phases row
            s3 = _show(_sol_1d(; switching=_sw_1d(; labels=["", ""])))
            Test.@test occursin("Switching times", s3)
            Test.@test !occursin("Phases", s3)
            # no switching structure: neither row
            s4 = _show(_sol_1d(; switching=Solutions.EmptySwitchingModel()))
            Test.@test !occursin("Switching", s4)
            Test.@test !occursin("Phases", s4)
            # a labelled single phase: a Phases row, no switching times
            one = Solutions.SwitchingModel(; times=Float64[], labels=["bang"])
            s5 = _show(_sol_1d(; switching=one))
            Test.@test occursin("Phases : bang", s5)
            Test.@test !occursin("Switching times", s5)
        end

        Test.@testset "show: separator before solver metadata" begin
            sol = _sol_1d(; iterations=3, status=:ok)
            s = _show(sol)
            Test.@test occursin("Phases", s)
            Test.@test occursin("Iterations", s)
            lines = split(s, '\n')
            i = findfirst(l -> occursin("Phases", l), lines)
            Test.@test strip(lines[i + 1]) == "│"
        end

        # ====================================================================
        # TYPE STABILITY
        # ====================================================================

        Test.@testset "type stability" begin
            sol = _sol_1d()
            Test.@test_nowarn Test.@inferred CTModels.switching_times(sol)
            Test.@test_nowarn Test.@inferred CTModels.phase_labels(sol)
            Test.@test_nowarn Test.@inferred CTModels.has_switching(sol)
            x = CTModels.state(sol)
            Test.@test_nowarn Test.@inferred x(0.55)
        end
    end
end

end # module

test_switching() = TestSwitching.test_switching()
