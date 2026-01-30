module TestPlot

using Test
using CTBase
using CTModels
using Main.TestProblems
using Main.TestOptions: VERBOSE, SHOWTIMING
using Plots

struct FakeModelDoPlot{N} <: CTModels.AbstractModel end

struct FakeSolutionDoPlot{N} <: CTModels.AbstractSolution
    ocp::FakeModelDoPlot{N}
    pcd
end

CTModels.dim_path_constraints_nl(::FakeModelDoPlot{N}) where {N} = N
CTModels.dim_path_constraints_nl(sol::FakeSolutionDoPlot{N}) where {N} = N
CTModels.path_constraints_dual(sol::FakeSolutionDoPlot) = sol.pcd
CTModels.model(sol::FakeSolutionDoPlot) = sol.ocp
CTModels.state_dimension(::FakeSolutionDoPlot) = 2
CTModels.control_dimension(::FakeSolutionDoPlot) = 1

function test_plot()

    # Resolve the plotting extension module to access internal helpers.
    plots_ext = Base.get_extension(CTModels, :CTModelsPlots)

    # ========================================================================
    # Unit tests – helper logic (no plotting side effects)
    # ========================================================================

    Test.@testset "plot helpers: clean" verbose=VERBOSE showtiming=SHOWTIMING begin
        description = (:states, :controls, :costates, :constraint, :cons, :duals, :state)
        cleaned = plots_ext.clean(description)
        Test.@test Set(cleaned) == Set((:state, :control, :costate, :path, :dual))
    end

    Test.@testset "plot helpers: do_plot" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp, sol, pre_ocp = solution_example()
        ocp_pc, sol_pc = solution_example_dual()

        # All descriptions enabled with non-:none styles
        desc = (:state, :costate, :control, :path, :dual)
        (ps, pc, pu, pp, pd) = plots_ext.do_plot(
            sol,
            desc...;
            state_style=NamedTuple(),
            control_style=NamedTuple(),
            costate_style=NamedTuple(),
            path_style=NamedTuple(),
            dual_style=NamedTuple(),
        )
        Test.@test ps
        Test.@test pc
        Test.@test pu
        Test.@test pp
        Test.@test !pd

        (ps2, pc2, pu2, pp2, pd2) = plots_ext.do_plot(
            sol_pc,
            desc...;
            state_style=NamedTuple(),
            control_style=NamedTuple(),
            costate_style=NamedTuple(),
            path_style=NamedTuple(),
            dual_style=NamedTuple(),
        )
        Test.@test ps2
        Test.@test pc2
        Test.@test pu2
        Test.@test pp2
        Test.@test pd2

        # Styles set to :none disable corresponding components
        (ps3, pc3, pu3, pp3, pd3) = plots_ext.do_plot(
            sol,
            :state,
            :control,
            :path,
            :dual;
            state_style=:none,
            control_style=:none,
            costate_style=:none,
            path_style=:none,
            dual_style=:none,
        )
        Test.@test !ps3
        Test.@test !pu3
        Test.@test !pp3
        Test.@test !pd3

        # Fakes: explicit combinations of path constraints and duals
        desc2 = (:state, :costate, :control, :path, :dual)

        # no path constraints, no duals
        fake1 = FakeSolutionDoPlot(FakeModelDoPlot{0}(), nothing)
        (_, _, _, fp1, fd1) = plots_ext.do_plot(
            fake1,
            desc2...;
            state_style=NamedTuple(),
            control_style=NamedTuple(),
            costate_style=NamedTuple(),
            path_style=NamedTuple(),
            dual_style=NamedTuple(),
        )
        Test.@test !fp1
        Test.@test !fd1

        # path constraints present, no duals
        fake2 = FakeSolutionDoPlot(FakeModelDoPlot{2}(), nothing)
        (_, _, _, fp2, fd2) = plots_ext.do_plot(
            fake2,
            desc2...;
            state_style=NamedTuple(),
            control_style=NamedTuple(),
            costate_style=NamedTuple(),
            path_style=NamedTuple(),
            dual_style=NamedTuple(),
        )
        Test.@test fp2
        Test.@test !fd2

        # path constraints present, duals present
        fake3 = FakeSolutionDoPlot(FakeModelDoPlot{3}(), (1.0,))
        (_, _, _, fp3, fd3) = plots_ext.do_plot(
            fake3,
            desc2...;
            state_style=NamedTuple(),
            control_style=NamedTuple(),
            costate_style=NamedTuple(),
            path_style=NamedTuple(),
            dual_style=NamedTuple(),
        )
        Test.@test fp3
        Test.@test fd3
    end

    Test.@testset "plot defaults: scalar helpers" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test plots_ext.__plot_layout() == :split
        Test.@test plots_ext.__control_layout() == :components
        Test.@test plots_ext.__time_normalization() == :default
        Test.@test plots_ext.__plot_style() == NamedTuple()
        Test.@test plots_ext.__plot_label_suffix() == ""
    end

    Test.@testset "plot defaults: __size_plot – layout=:group" verbose=VERBOSE showtiming=SHOWTIMING begin
        fake = FakeSolutionDoPlot(FakeModelDoPlot{0}(), nothing)
        desc = (:state, :costate, :control)

        sz_components = plots_ext.__size_plot(
            fake,
            CTModels.model(fake),
            :components,
            :group,
            desc...;
            state_style=NamedTuple(),
            control_style=NamedTuple(),
            costate_style=NamedTuple(),
            path_style=NamedTuple(),
            dual_style=NamedTuple(),
        )
        Test.@test sz_components == (600, 280)

        sz_all = plots_ext.__size_plot(
            fake,
            CTModels.model(fake),
            :all,
            :group,
            desc...;
            state_style=NamedTuple(),
            control_style=NamedTuple(),
            costate_style=NamedTuple(),
            path_style=NamedTuple(),
            dual_style=NamedTuple(),
        )
        Test.@test sz_all == (600, 420)
    end

    Test.@testset "plot defaults: __size_plot – layout=:split" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Only state → 2 lines
        fake_state = FakeSolutionDoPlot(FakeModelDoPlot{0}(), nothing)
        sz_state = plots_ext.__size_plot(
            fake_state,
            CTModels.model(fake_state),
            :components,
            :split,
            :state;
            state_style=NamedTuple(),
            control_style=:none,
            costate_style=:none,
            path_style=:none,
            dual_style=:none,
        )
        Test.@test sz_state == (600, 420)

        # Only control norm → 1 line
        fake_control = FakeSolutionDoPlot(FakeModelDoPlot{0}(), nothing)
        sz_control = plots_ext.__size_plot(
            fake_control,
            CTModels.model(fake_control),
            :norm,
            :split,
            :control;
            state_style=:none,
            control_style=NamedTuple(),
            costate_style=:none,
            path_style=:none,
            dual_style=:none,
        )
        Test.@test sz_control == (600, 280)

        # State + control + path constraints (nc = 2) → nb_lines > 2
        fake_full = FakeSolutionDoPlot(FakeModelDoPlot{2}(), nothing)
        sz_full = plots_ext.__size_plot(
            fake_full,
            CTModels.model(fake_full),
            :components,
            :split,
            :state,
            :control,
            :path;
            state_style=NamedTuple(),
            control_style=NamedTuple(),
            costate_style=:none,
            path_style=NamedTuple(),
            dual_style=:none,
        )
        Test.@test sz_full == (600, 140 * 5) # 2 (state) + 1 (control) + 2 (path)

        # Invalid control keyword should throw
        Test.@test_throws CTBase.IncorrectArgument plots_ext.__size_plot(
            fake_state,
            CTModels.model(fake_state),
            :wrong_choice,
            :split,
            :state;
            state_style=NamedTuple(),
            control_style=NamedTuple(),
            costate_style=:none,
            path_style=:none,
            dual_style=:none,
        )
    end

    Test.@testset "plot tree: __plot_tree" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Single leaf → one subplot
        leaf = plots_ext.PlotLeaf()
        p_leaf = plots_ext.__plot_tree(leaf, 0)
        Test.@test p_leaf isa Plots.Plot
        Test.@test length(p_leaf.subplots) == 1

        # Row layout with three leaves → three subplots
        leaves_row = [plots_ext.PlotLeaf() for _ in 1:3]
        node_row = plots_ext.PlotNode(:row, leaves_row)
        p_row = plots_ext.__plot_tree(node_row)
        Test.@test p_row isa Plots.Plot
        Test.@test length(p_row.subplots) == 3

        # Column layout with EmptyPlot filtered out → one subplot
        children_col = [plots_ext.EmptyPlot(), plots_ext.PlotLeaf(), plots_ext.EmptyPlot()]
        node_col = plots_ext.PlotNode(:column, children_col)
        p_col = plots_ext.__plot_tree(node_col)
        Test.@test p_col isa Plots.Plot
        Test.@test length(p_col.subplots) == 1

        # Nested nodes: a row of two columns (one with 2 leaves, one with 1)
        col1 = plots_ext.PlotNode(:column, [plots_ext.PlotLeaf(), plots_ext.PlotLeaf()])
        col2 = plots_ext.PlotNode(:column, [plots_ext.PlotLeaf()])
        root = plots_ext.PlotNode(:row, [col1, col2])
        p_nested = plots_ext.__plot_tree(root)
        Test.@test p_nested isa Plots.Plot
        # At the top level we have at least two column blocks
        Test.@test length(p_nested.subplots) ≥ 2
    end

    Test.@testset "plot helpers: do_decorate" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp, sol, pre_ocp = solution_example()

        # No model → nothing is decorated regardless of styles
        (dt, dsb, dcb, dpb) = plots_ext.do_decorate(
            model=nothing,
            time_style=NamedTuple(),
            state_bounds_style=NamedTuple(),
            control_bounds_style=NamedTuple(),
            path_bounds_style=NamedTuple(),
        )
        Test.@test !dt
        Test.@test !dsb
        Test.@test !dcb
        Test.@test !dpb

        # With model and non-:none styles → all decorations active
        (dt2, dsb2, dcb2, dpb2) = plots_ext.do_decorate(
            model=ocp,
            time_style=NamedTuple(),
            state_bounds_style=NamedTuple(),
            control_bounds_style=NamedTuple(),
            path_bounds_style=NamedTuple(),
        )
        Test.@test dt2
        Test.@test dsb2
        Test.@test dcb2
        Test.@test dpb2

        # Individual :none styles disable specific decorations
        (dt3, dsb3, dcb3, dpb3) = plots_ext.do_decorate(
            model=ocp,
            time_style=:none,
            state_bounds_style=NamedTuple(),
            control_bounds_style=:none,
            path_bounds_style=NamedTuple(),
        )
        Test.@test !dt3
        Test.@test dsb3
        Test.@test !dcb3
        Test.@test dpb3
    end

    Test.@testset "plot helpers: __keep_series_attributes" verbose=VERBOSE showtiming=SHOWTIMING begin
        attrs = plots_ext.__keep_series_attributes(color=:red, linestyle=:dash, foo=1)
        keys = [kv[1] for kv in attrs]

        # Unknown attributes should be filtered out
        Test.@test :foo ∉ keys

        # All returned keys must be known Plots series attributes
        series_attrs = Plots.attributes(:Series)
        for k in keys
            Test.@test k ∈ series_attrs
        end
    end

    # ========================================================================
    # Integration tests – solution_example (no path constraints)
    # ========================================================================

    ocp, sol, pre_ocp = solution_example()

    Test.@testset "plot(sol) – time keyword" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test plot(sol; time=:default) isa Plots.Plot
        Test.@test plot(sol; time=:normalize) isa Plots.Plot
        Test.@test plot(sol; time=:normalise) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot(sol; time=:wrong_choice)
    end

    Test.@testset "plot(sol) – layout and control options" verbose=VERBOSE showtiming=SHOWTIMING begin
        # group layout
        Test.@test plot(sol; layout=:group, control=:components) isa Plots.Plot
        Test.@test plot(sol; layout=:group, control=:norm) isa Plots.Plot
        Test.@test plot(sol; layout=:group, control=:all) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot(
            sol; layout=:group, control=:wrong_choice
        )

        # split layout
        Test.@test plot(sol; layout=:split, control=:components) isa Plots.Plot
        Test.@test plot(sol; layout=:split, control=:norm) isa Plots.Plot
        Test.@test plot(sol; layout=:split, control=:all) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot(
            sol; layout=:split, control=:wrong_choice
        )

        # layout only
        Test.@test plot(sol; layout=:split) isa Plots.Plot
        Test.@test plot(sol; layout=:group) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot(sol; layout=:wrong_choice)
    end

    Test.@testset "plot!(...) – reuse of plots and time keyword" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Start from plot(sol, time=...)
        plt = plot(sol; time=:default)
        Test.@test plot!(plt, sol; time=:default) isa Plots.Plot
        Test.@test plot!(plt, sol; time=:normalize) isa Plots.Plot
        Test.@test plot!(plt, sol; time=:normalise) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(plt, sol; time=:wrong_choice)

        # plot!(sol, ...) variants with implicit current plot
        plot(sol; time=:default)
        Test.@test plot!(sol; time=:default) isa Plots.Plot
        Test.@test plot!(sol; time=:normalize) isa Plots.Plot
        Test.@test plot!(sol; time=:normalise) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(sol; time=:wrong_choice)

        # Start from an empty plot()
        plt2 = plot()
        Test.@test plot!(plt2, sol; time=:default) isa Plots.Plot
        Test.@test plot!(plt2, sol; time=:normalize) isa Plots.Plot
        Test.@test plot!(plt2, sol; time=:normalise) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(plt2, sol; time=:wrong_choice)
    end

    Test.@testset "plot!(...) – layout and control options" verbose=VERBOSE showtiming=SHOWTIMING begin
        # group layout
        plt = plot(sol; layout=:group, control=:components)
        Test.@test plot!(plt, sol; layout=:group, control=:components) isa Plots.Plot
        Test.@test plot!(plt, sol; layout=:group, control=:norm) isa Plots.Plot

        plt = plot(sol; layout=:group, control=:norm)
        Test.@test plot!(plt, sol; layout=:group, control=:components) isa Plots.Plot
        Test.@test plot!(plt, sol; layout=:group, control=:norm) isa Plots.Plot

        plt = plot(sol; layout=:group, control=:all)
        Test.@test plot!(plt, sol; layout=:group, control=:all) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(
            plt, sol; layout=:group, control=:wrong_choice
        )

        # split layout
        plt = plot(sol; layout=:split, control=:components)
        Test.@test plot!(plt, sol; layout=:split, control=:components) isa Plots.Plot
        Test.@test plot!(plt, sol; layout=:split, control=:norm) isa Plots.Plot

        plt = plot(sol; layout=:split, control=:norm)
        Test.@test plot!(plt, sol; layout=:split, control=:components) isa Plots.Plot
        Test.@test plot!(plt, sol; layout=:split, control=:norm) isa Plots.Plot

        plt = plot(sol; layout=:split, control=:all)
        Test.@test plot!(plt, sol; layout=:split, control=:all) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(
            plt, sol; layout=:split, control=:wrong_choice
        )

        # layout only
        plt = plot(sol; layout=:split)
        Test.@test plot!(plt, sol; layout=:split) isa Plots.Plot

        plt = plot(sol; layout=:group)
        Test.@test plot!(plt, sol; layout=:group) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(plt, sol; layout=:wrong_choice)
    end

    Test.@testset "display(sol) – side effect" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test display(sol) isa Nothing
    end

    # ========================================================================
    # Integration tests – solution_example_dual (with duals)
    # ========================================================================

    ocp_pc, sol_pc = solution_example_dual()

    Test.@testset "plot(sol with path constraints) – time and layout" verbose=VERBOSE showtiming=SHOWTIMING begin
        # time keyword
        Test.@test plot(sol_pc; time=:default) isa Plots.Plot
        Test.@test plot(sol_pc; time=:normalize) isa Plots.Plot
        Test.@test plot(sol_pc; time=:normalise) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot(sol_pc; time=:wrong_choice)

        # layout/control
        Test.@test plot(sol_pc; layout=:group, control=:components) isa Plots.Plot
        Test.@test plot(sol_pc; layout=:group, control=:norm) isa Plots.Plot
        Test.@test plot(sol_pc; layout=:group, control=:all) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot(
            sol_pc; layout=:group, control=:wrong_choice
        )

        Test.@test plot(sol_pc; layout=:split, control=:components) isa Plots.Plot
        Test.@test plot(sol_pc; layout=:split, control=:norm) isa Plots.Plot
        Test.@test plot(sol_pc; layout=:split, control=:all) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot(
            sol_pc; layout=:split, control=:wrong_choice
        )

        Test.@test plot(sol_pc; layout=:split) isa Plots.Plot
        Test.@test plot(sol_pc; layout=:group) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot(sol_pc; layout=:wrong_choice)
    end

    Test.@testset "plot!(sol with path constraints) – layout and time" verbose=VERBOSE showtiming=SHOWTIMING begin
        # time keyword
        plt = plot(sol_pc; time=:default)
        Test.@test plot!(plt, sol_pc; time=:default) isa Plots.Plot
        Test.@test plot!(plt, sol_pc; time=:normalize) isa Plots.Plot
        Test.@test plot!(plt, sol_pc; time=:normalise) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(plt, sol_pc; time=:wrong_choice)

        # layout/control
        plt = plot(sol_pc; layout=:group, control=:components)
        Test.@test plot!(plt, sol_pc; layout=:group, control=:components) isa Plots.Plot
        Test.@test plot!(plt, sol_pc; layout=:group, control=:norm) isa Plots.Plot

        plt = plot(sol_pc; layout=:group, control=:norm)
        Test.@test plot!(plt, sol_pc; layout=:group, control=:components) isa Plots.Plot
        Test.@test plot!(plt, sol_pc; layout=:group, control=:norm) isa Plots.Plot

        plt = plot(sol_pc; layout=:group, control=:all)
        Test.@test plot!(plt, sol_pc; layout=:group, control=:all) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(
            plt, sol_pc; layout=:group, control=:wrong_choice
        )

        plt = plot(sol_pc; layout=:split, control=:components)
        Test.@test plot!(plt, sol_pc; layout=:split, control=:components) isa Plots.Plot
        Test.@test plot!(plt, sol_pc; layout=:split, control=:norm) isa Plots.Plot

        plt = plot(sol_pc; layout=:split, control=:norm)
        Test.@test plot!(plt, sol_pc; layout=:split, control=:components) isa Plots.Plot
        Test.@test plot!(plt, sol_pc; layout=:split, control=:norm) isa Plots.Plot

        plt = plot(sol_pc; layout=:split, control=:all)
        Test.@test plot!(plt, sol_pc; layout=:split, control=:all) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(
            plt, sol_pc; layout=:split, control=:wrong_choice
        )

        plt = plot(sol_pc; layout=:split)
        Test.@test plot!(plt, sol_pc; layout=:split) isa Plots.Plot

        plt = plot(sol_pc; layout=:group)
        Test.@test plot!(plt, sol_pc; layout=:group) isa Plots.Plot
        Test.@test_throws CTBase.IncorrectArgument plot!(plt, sol_pc; layout=:wrong_choice)
    end
end

end # module

test_plot() = TestPlot.test_plot()
