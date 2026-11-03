module TestPlotRows

# =============================================================================
# Unit tests for the constraint rows of the plot (issue #506): one row per constraint
# label — path, state box or control box — pairing the constraint with its dual.
# Backend-free: exercises `CTModels.PlotCase` directly.
# =============================================================================

using Test: Test
using CTBase: Plotting
using CTModels: CTModels

include(joinpath("..", "..", "problems", "TestProblems.jl"))
using .TestProblems: TestProblems

# TOP-LEVEL fixtures (TST3) for the review fixes of #510.

# `:xbox` bounds (x₁, x₂), `:x2_box` x₂ only: after deduplication `:x2_box` is an alias of
# component 2 (the first label of each component is `:xbox`). A control box `:u_box`, and
# two path labels `:g1`, `:g2`.
function _alias_model()
    pre = CTModels.PreModel()
    CTModels.time!(pre; t0=0.0, tf=1.0)
    CTModels.state!(pre, 2)
    CTModels.control!(pre, 1)
    CTModels.dynamics!(pre, (r, t, x, u, v) -> (r .= x; nothing))
    CTModels.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    CTModels.definition!(pre, quote end)
    CTModels.time_dependence!(pre; autonomous=true)
    CTModels.constraint!(pre, :path; f=(r, t, x, u, v) -> (r[1] = x[1]; nothing),
        lb=-10, ub=10, label=:g1)
    CTModels.constraint!(pre, :path; f=(r, t, x, u, v) -> (r[1] = x[2]; nothing),
        lb=-10, ub=10, label=:g2)
    CTModels.constraint!(pre, :state; rg=1:2, lb=[-1.0, -1.0], ub=[1.0, 1.0], label=:xbox)
    CTModels.constraint!(pre, :state; rg=2, lb=-Inf, ub=0.5, label=:x2_box)
    CTModels.constraint!(pre, :control; rg=1, lb=-1.0, ub=1.0, label=:u_box)
    return redirect_stderr(devnull) do # the alias warns: several bounds on x₂
        CTModels.build(pre)
    end
end

const _TA = collect(range(0.0, 1.0; length=11))

function _alias_solution(ocp; duals)
    N = length(_TA)
    return CTModels.build_solution(
        ocp, _TA, zeros(N, 2), zeros(N, 1), Float64[], zeros(N, 2);
        objective=0.0, successful=true, duals=duals,
    )
end

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_plot_rows()
    Test.@testset "PlotCase constraint rows (issue #506)" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        ocp, sol = TestProblems.solution_example_box_duals()
        rows = CTModels.PlotCase._constraint_rows(sol, ocp)

        Test.@testset "one row per path / state-box / control-box label, in this order" begin
            Test.@test [r.label for r in rows] == [:c1, :x2_box, :u_box]
            Test.@test [r.kind for r in rows] == [:path, :state, :control]
        end

        Test.@testset "a row records the rows of its constraint" begin
            Test.@test all(r -> r.dual, rows)
            Test.@test rows[1].rows == [1]
            Test.@test rows[2].rows == [2]
            Test.@test rows[3].rows == [1]
        end

        Test.@testset "boundary labels give no row" begin
            Test.@test :init ∉ [r.label for r in rows]
        end

        Test.@testset "the dual of a row is dual(sol, model, label)" begin
            for r in rows
                d = CTModels.PlotCase._row_dual(sol, ocp, r)
                ref = CTModels.dual(sol, ocp, r.label)
                for t in (0.0, 0.3, 1.0)
                    Test.@test d(t) == ref(t)
                end
            end
        end

        Test.@testset "a box with an unknown dual gives no row; a path label stays" begin
            # path duals only: the control box :u_con has no dual
            ocp_pc, sol_pc = TestProblems.solution_example_dual()
            rs = CTModels.PlotCase._constraint_rows(sol_pc, ocp_pc)
            Test.@test :u_con ∉ [r.label for r in rs]
            Test.@test all(r -> r.kind === :path && r.dual, rs)
            # a solution without any dual: the path rows only, without dual
            ocp0, sol0, _ = TestProblems.solution_example()
            rs0 = CTModels.PlotCase._constraint_rows(sol0, ocp0)
            Test.@test all(r -> r.kind === :path && !r.dual, rs0)
        end

        Test.@testset "figure: one (constraint | dual) row per label, below the control" begin
            fig = CTModels.PlotCase.build_figure(sol)
            leaves = Plotting.leaves(fig.root)
            # state (2) + costate (2) + control (1) + 3 rows of 2 cells
            Test.@test Plotting.n_leaves(fig) == 11
            ylabels = [l.axes.ylabel for l in leaves]
            Test.@test ylabels[6:end] == ["c1", "", "x₂ (x2_box)", "", "u (u_box)", ""]
            titles = [l.axes.title for l in leaves]
            # titles on the first row only, the time label on the last one only
            Test.@test titles[6:end] == ["constraints", "dual", "", "", "", ""]
            Test.@test [l.axes.xlabel for l in leaves[6:end]] == ["", "", "", "", "t", "t"]
        end

        Test.@testset "figure: the dual cell of a box row plots dual(sol, model, label)" begin
            fig = CTModels.PlotCase.build_figure(sol)
            leaves = Plotting.leaves(fig.root)
            for (label, k) in ((:x2_box, 9), (:u_box, 11))
                ser = only(leaves[k].axes.series)
                ref = CTModels.dual(sol, ocp, label)
                Test.@test ser.y ≈ ref.(ser.x)
            end
        end

        Test.@testset "figure: the bounds of a box row are drawn on its left cell" begin
            leaves = Plotting.leaves(CTModels.PlotCase.build_figure(sol).root)
            nh(l) = count(d -> d isa Plotting.HLine, l.axes.decorations)
            Test.@test nh(leaves[8]) == 2    # x₂ ∈ [-0.5, 2]
            Test.@test nh(leaves[10]) == 2   # u ∈ [-1, 1]
            leaves = Plotting.leaves(
                CTModels.PlotCase.build_figure(
                    sol; state_bounds_style=:none, control_bounds_style=:none
                ).root,
            )
            Test.@test nh(leaves[8]) == 0
            Test.@test nh(leaves[10]) == 0
        end

        Test.@testset "figure: selection through :path and :dual" begin
            n(args...; kw...) =
                Plotting.n_leaves(CTModels.PlotCase.build_figure(sol, args...; kw...))
            # :dual alone: the three duals; :path alone: the path constraint only
            Test.@test n(:dual) == 3
            Test.@test n(:path) == 1
            Test.@test n(:path, :dual) == 6
            # hidden duals: a box row is a pair, only the path constraint is left
            Test.@test n(:path, :dual; dual_style=:none) == 1
            Test.@test n(:path, :dual; path_style=:none) == 3
            Test.@test n(:state, :control) == 3
        end

        Test.@testset "figure: a box without dual is not plotted" begin
            ocp_pc, sol_pc = TestProblems.solution_example_dual()
            # the control box :u_con has no dual: path rows only, as before
            fig = CTModels.PlotCase.build_figure(sol_pc)
            n = CTModels.state_dimension(sol_pc)              # state
            n += CTModels.state_dimension(sol_pc)             # costate
            n += CTModels.control_dimension(sol_pc)           # control
            n += 2 * CTModels.dim_path_constraints_nl(ocp_pc) # path + dual
            Test.@test Plotting.n_leaves(fig) == n
        end

        Test.@testset "figure: the dual of a box row draws its jump at a switching time" begin
            τ = 0.5
            sw = CTModels.Solutions.SwitchingModel(;
                times=[τ],
                labels=["a", "b"],
                # x2_box: a known jump 0 → 3; no limits are given for u_box
                duals=Dict(:x2_box => ([0.0], [3.0])),
            )
            _, sols = TestProblems.solution_example_box_duals(; switching=sw)
            leaves = Plotting.leaves(CTModels.PlotCase.build_figure(sols).root)
            x2, u = only(leaves[9].axes.series), only(leaves[11].axes.series)
            # the switching time appears twice, with the left and the right limit
            k = findall(==(τ), x2.x)
            Test.@test length(k) == 2
            Test.@test x2.y[k] == [0.0, 3.0]
            # no limits for the control box: its dual is drawn without a jump
            Test.@test count(==(τ), u.x) <= 1
            Test.@test !any(isnan, u.y)

            # a component whose limits are unknown (NaN, a label not given) draws no jump
            # and no break, while the other components keep theirs
            sw_nan = CTModels.Solutions.SwitchingModel(;
                times=[τ],
                labels=["a", "b"],
                duals=Dict(:x2_box => ([NaN], [NaN])),
            )
            _, sol_nan = TestProblems.solution_example_box_duals(; switching=sw_nan)
            leaves_nan = Plotting.leaves(CTModels.PlotCase.build_figure(sol_nan).root)
            x2n = only(leaves_nan[9].axes.series)
            Test.@test !any(isnan, x2n.y)
            Test.@test count(==(τ), x2n.x) == 2
            k = findall(==(τ), x2n.x)
            Test.@test x2n.y[k[1]] == x2n.y[k[2]]
            # jumps = :none breaks the curve between the limits
            leaves = Plotting.leaves(
                CTModels.PlotCase.build_figure(sols; jumps=:none).root
            )
            Test.@test any(isnan, only(leaves[9].axes.series).y)
        end

        # ======================================================================
        # Review fixes of #510
        # ======================================================================
        ocp_a = _alias_model()

        Test.@testset "a box label that is only an alias has its row" begin
            sol_a = _alias_solution(ocp_a; duals=Dict{Symbol,Any}(:x2_box => t -> -t))
            rs = CTModels.PlotCase._constraint_rows(sol_a, ocp_a)
            Test.@test :x2_box in [r.label for r in rs]
            Test.@test only(filter(r -> r.label === :x2_box, rs)).rows == [2]
            Test.@test :xbox ∉ [r.label for r in rs]   # x₁ unknown: :xbox has no dual
            # the rows of the boxes follow their components; path rows come first
            Test.@test [r.kind for r in rs] == [:path, :path, :state]
        end

        Test.@testset "a row without dual keeps the right column (aligned axes)" begin
            # :g1 has its dual, :g2 not: both rows are pairs, :g2 with an empty cell
            sol_a = _alias_solution(ocp_a; duals=Dict{Symbol,Any}(:g1 => t -> t))
            fig = CTModels.PlotCase.build_figure(sol_a, :path, :dual)
            leaves = Plotting.leaves(fig.root)
            Test.@test length(leaves) == 4
            empty = leaves[4]
            Test.@test empty.axes.ylabel == ""
            notes = filter(d -> d isa Plotting.Annotation, empty.axes.decorations)
            Test.@test any(a -> a.text == "dual not known", notes)
            Test.@test only(notes).x ≈ 0.5            # the middle of the time axis
            Test.@test empty.axes.xlabel == "t"         # last row: the time label
            # no row has a dual: one column, as before
            sol_0 = _alias_solution(ocp_a; duals=Dict{Symbol,Any}())
            Test.@test length(Plotting.leaves(CTModels.PlotCase.build_figure(sol_0, :path).root)) == 2
            # the empty cell follows the time normalisation
            figz = CTModels.PlotCase.build_figure(sol_a, :path, :dual; time=:normalize)
            notez = filter(d -> d isa Plotting.Annotation, Plotting.leaves(figz.root)[4].axes.decorations)
            Test.@test only(notez).x ≈ 0.5
            Test.@test CTModels.PlotCase._mid_time([1.0, 3.0], :default) == 2.0
            Test.@test CTModels.PlotCase._mid_time([1.0, 3.0], :normalize) == 0.5
        end

        Test.@testset "the dual of a control box is a step function with a constant control" begin
            sol_a = _alias_solution(ocp_a; duals=Dict{Symbol,Any}(:u_box => t -> t))
            fig = CTModels.PlotCase.build_figure(sol_a, :path, :dual)
            row = filter(l -> l.axes.ylabel == "u (u_box)", Plotting.leaves(fig.root))
            Test.@test only(only(row).axes.series).style.seriestype === :steppost
            dual_cell = Plotting.leaves(fig.root)[end]
            Test.@test only(dual_cell.axes.series).style.seriestype === :steppost
            r = only(filter(r -> r.label === :u_box, CTModels.PlotCase._constraint_rows(sol_a, ocp_a)))
            Test.@test CTModels.PlotCase._row_seriestype(sol_a, r) === :steppost
        end

        Test.@testset "the samples of the path constraints are computed once and sliced" begin
            sol_a = _alias_solution(ocp_a; duals=Dict{Symbol,Any}(:g1 => t -> t, :g2 => t -> 2t))
            samples = CTModels.PlotCase._path_samples(sol_a, ocp_a)
            Test.@test size(samples[2]) == (length(_TA), 2)
            for (k, rows) in ((1, [1]), (2, [2]))
                shared = CTModels.PlotCase._path_panel(
                    sol_a, ocp_a, NamedTuple(); rows=rows, samples=samples
                )
                alone = CTModels.PlotCase._path_panel(sol_a, ocp_a, NamedTuple(); rows=rows)
                Test.@test shared.data == alone.data
            end
            duals = CTModels.PlotCase._sample(CTModels.path_constraints_dual(sol_a), _TA)
            shared = CTModels.PlotCase._dual_panel(
                sol_a, ocp_a, NamedTuple(); path_shown=true, rows=[2], samples=duals
            )
            alone = CTModels.PlotCase._dual_panel(sol_a, ocp_a, NamedTuple(); path_shown=true, rows=[2])
            Test.@test shared.data == alone.data
        end

        Test.@testset "do_plot: the rows given or listed agree" begin
            rs = CTModels.PlotCase._constraint_rows(sol, ocp)
            kw = (
                state_style=NamedTuple(), control_style=NamedTuple(),
                costate_style=NamedTuple(), path_style=NamedTuple(), dual_style=NamedTuple(),
            )
            for desc in ((:state, :path, :dual), (:path,), (:dual,))
                Test.@test CTModels.PlotCase.do_plot(sol, desc...; kw..., rows=rs) ==
                    CTModels.PlotCase.do_plot(sol, desc...; kw...)
            end
        end

        Test.@testset "a multi-row path label is one row" begin
            ocp_pc, sol_pc = TestProblems.solution_example_dual()
            r = only(filter(r -> r.label == :con2, CTModels.PlotCase._constraint_rows(sol_pc, ocp_pc)))
            Test.@test r.kind === :path
            Test.@test length(r.rows) == 2
        end
    end
end

end # module

test_plot_rows() = TestPlotRows.test_plot_rows()
