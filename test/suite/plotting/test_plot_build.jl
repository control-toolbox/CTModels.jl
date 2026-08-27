module TestPlotBuild

# =============================================================================
# Unit tests for the backend-free plotting case layer `CTModels.PlotCase`.
#
# `build_figure` produces a `CTBase.Plotting.Figure` (pure data) — these tests
# run with NO plotting backend loaded (no Plots, no Makie), exercising the
# vocabulary, gating, panels, decorations and layout assembly directly on the IR.
# =============================================================================

using Test: Test
using CTBase: Plotting
using CTModels: CTModels

include(joinpath("..", "..", "problems", "TestProblems.jl"))
using .TestProblems: TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_titles(fig) = filter(!isempty, [leaf.axes.title for leaf in Plotting.leaves(fig.root)])
function _all_decorations(fig)
    return reduce(
        vcat,
        (leaf.axes.decorations for leaf in Plotting.leaves(fig.root));
        init=Plotting.Decoration[],
    )
end
_vlines(fig) = filter(d -> d isa Plotting.VLine, _all_decorations(fig))
_hlines(fig) = filter(d -> d isa Plotting.HLine, _all_decorations(fig))

function test_plot_build()
    Test.@testset "PlotCase.build_figure (backend-free)" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        _, sol, _ = TestProblems.solution_example()
        _, sol_pc = TestProblems.solution_example_dual()
        _, sol_tf = TestProblems.solution_example_free_final_time()

        Test.@testset "returns a Figure for every fixture" begin
            for s in (sol, sol_pc, sol_tf)
                Test.@test CTModels.PlotCase.build_figure(s) isa Plotting.Figure
            end
        end

        Test.@testset "nothing to draw -> nothing" begin
            Test.@test CTModels.PlotCase.build_figure(
                sol_pc;
                state_style=:none,
                costate_style=:none,
                control_style=:none,
                path_style=:none,
                dual_style=:none,
            ) === nothing
        end

        Test.@testset "leaf count: :split sums the component counts" begin
            model = CTModels.model(sol_pc)
            n = CTModels.state_dimension(sol_pc)              # state
            n += CTModels.state_dimension(sol_pc)             # costate
            n += CTModels.control_dimension(sol_pc)           # control
            n += 2 * CTModels.dim_path_constraints_nl(model)  # path + dual
            Test.@test Plotting.n_leaves(CTModels.PlotCase.build_figure(sol_pc)) == n
        end

        Test.@testset "leaf count: :group is one cell per group" begin
            fig = CTModels.PlotCase.build_figure(sol_pc; layout=:group)
            # state, costate, control (path/dual are dropped in :group, historical)
            Test.@test Plotting.n_leaves(fig) == 3
        end

        Test.@testset ":group control=:all with 4 groups folds into a 2x2 grid" begin
            fig = CTModels.PlotCase.build_figure(sol; layout=:group, control=:all)   # state, costate, control, control-norm
            Test.@test fig.root isa Plotting.VBox
            Test.@test length(fig.root.children) == 2
            Test.@test all(
                c -> c isa Plotting.HBox && length(c.children) == 2, fig.root.children
            )
        end

        Test.@testset "description subset selects the groups" begin
            fig = CTModels.PlotCase.build_figure(sol_pc, :state, :control)
            Test.@test Set(_titles(fig)) == Set(["state", "control"])
        end

        Test.@testset "control layout" begin
            fnorm = CTModels.PlotCase.build_figure(sol_pc, :control; control=:norm)
            Test.@test "control" in _titles(fnorm)
            Test.@test Plotting.n_leaves(fnorm) == 1
            fall = CTModels.PlotCase.build_figure(sol_pc, :control; control=:all)
            # :split, :all -> one column of m + 1 components
            m = CTModels.control_dimension(sol_pc)
            Test.@test Plotting.n_leaves(fall) == m + 1
        end

        Test.@testset "time markers: two VLines on every leaf by default" begin
            fig = CTModels.PlotCase.build_figure(sol_pc)
            for leaf in Plotting.leaves(fig.root)
                vl = filter(d -> d isa Plotting.VLine, leaf.axes.decorations)
                Test.@test length(vl) == 2
            end
            # time_style=:none removes them
            f2 = CTModels.PlotCase.build_figure(sol_pc; time_style=:none)
            Test.@test isempty(_vlines(f2))
        end

        Test.@testset "bound lines: present with box constraints, gated by style" begin
            # solution_example has a state box constraint (see fixture)
            f_on = CTModels.PlotCase.build_figure(sol, :state)
            f_off = CTModels.PlotCase.build_figure(sol, :state; state_bounds_style=:none)
            Test.@test length(_hlines(f_on)) > length(_hlines(f_off))
            Test.@test isempty(_hlines(f_off))
        end

        Test.@testset "free final time: VLines at initial_time / final_time" begin
            model = CTModels.model(sol_tf)
            v = CTModels.variable(sol_tf)
            t0 = if CTModels.has_fixed_initial_time(model)
                CTModels.initial_time(model)
            else
                CTModels.initial_time(model, v)
            end
            tf = if CTModels.has_fixed_final_time(model)
                CTModels.final_time(model)
            else
                CTModels.final_time(model, v)
            end
            vals = sort(
                unique(d.value for d in _vlines(CTModels.PlotCase.build_figure(sol_tf)))
            )
            Test.@test vals ≈ sort(unique([t0, tf]))
        end

        Test.@testset "time normalization: VLines at 0 and 1, xlabel suffix" begin
            fig = CTModels.PlotCase.build_figure(sol_pc; time=:normalize)
            Test.@test sort(unique(d.value for d in _vlines(fig))) ≈ [0.0, 1.0]
            xlabels = filter(
                !isempty, [leaf.axes.xlabel for leaf in Plotting.leaves(fig.root)]
            )
            Test.@test any(occursin("(normalized)", x) for x in xlabels)
        end
    end
    return nothing
end

end # module TestPlotBuild

# CRITICAL: Redefine in outer scope for TestRunner
test_plot_build() = TestPlotBuild.test_plot_build()
