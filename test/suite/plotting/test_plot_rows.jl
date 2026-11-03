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
            # jumps = :none breaks the curve between the limits
            leaves = Plotting.leaves(
                CTModels.PlotCase.build_figure(sols; jumps=:none).root
            )
            Test.@test any(isnan, only(leaves[9].axes.series).y)
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
