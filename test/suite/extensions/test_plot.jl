module TestPlot

import Test: Test
import CTBase.Exceptions: Exceptions
import Plots: Plots
import CTModels: CTModels
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Solutions: Solutions

include(joinpath("..", "..", "problems", "TestProblems.jl"))
import .TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

struct FakeModelDoPlot{N} <: Models.AbstractModel end

struct FakeSolutionDoPlot{N} <: Solutions.AbstractSolution
    ocp::FakeModelDoPlot{N}
    pcd::Any
end

Components.dim_path_constraints_nl(::FakeModelDoPlot{N}) where {N} = N
Components.dim_path_constraints_nl(sol::FakeSolutionDoPlot{N}) where {N} = N
Solutions.path_constraints_dual(sol::FakeSolutionDoPlot) = sol.pcd
Solutions.model(sol::FakeSolutionDoPlot) = sol.ocp
Models.state_dimension(::FakeSolutionDoPlot) = 2
Models.control_dimension(::FakeSolutionDoPlot) = 1

function test_plot()
    Test.@testset "Plotting Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Case-layer vocabulary and gating
        #
        # The layout/rendering internals (sizes, weighted tree, series-attribute
        # filtering) now live in `CTBase.Plotting` and are tested there. This file
        # keeps the case-layer helpers (`clean`, `do_plot`, `do_decorate`, defaults)
        # and the end-to-end rendering behaviour.
        # ====================================================================

        # Resolve the plotting extension module to access internal helpers.
        plots_ext = Base.get_extension(CTModels, :CTModelsPlots)

        Test.@testset "plot helpers: clean" begin
            description = (
                :states, :controls, :costates, :constraint, :cons, :duals, :state
            )
            cleaned = plots_ext.clean(description)
            Test.@test Set(cleaned) == Set((:state, :control, :costate, :path, :dual))
        end

        Test.@testset "plot helpers: do_plot" begin
            ocp, sol, pre_ocp = TestProblems.solution_example()
            ocp_pc, sol_pc = TestProblems.solution_example_dual()

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

        Test.@testset "plot defaults: scalar helpers" begin
            Test.@test plots_ext.__plot_layout() == :split
            Test.@test plots_ext.__control_layout() == :components
            Test.@test plots_ext.__time_normalization() == :default
            Test.@test plots_ext.__plot_style() == NamedTuple()
            Test.@test plots_ext.__plot_label_suffix() == ""
        end

        Test.@testset "plot helpers: do_decorate" begin
            ocp, sol, pre_ocp = TestProblems.solution_example()

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

        # ====================================================================
        # INTEGRATION TESTS - Solution Example (no path constraints)
        # ====================================================================

        ocp, sol, pre_ocp = TestProblems.solution_example()

        Test.@testset "plot(sol) – time keyword" begin
            Test.@test Plots.plot(sol; time=:default) isa Plots.Plot
            Test.@test Plots.plot(sol; time=:normalize) isa Plots.Plot
            Test.@test Plots.plot(sol; time=:normalise) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(
                sol; time=:wrong_choice
            )
        end

        Test.@testset "plot(sol) – layout and control options" begin
            # group layout
            Test.@test Plots.plot(sol; layout=:group, control=:components) isa Plots.Plot
            Test.@test Plots.plot(sol; layout=:group, control=:norm) isa Plots.Plot
            Test.@test Plots.plot(sol; layout=:group, control=:all) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(
                sol; layout=:group, control=:wrong_choice
            )

            # split layout
            Test.@test Plots.plot(sol; layout=:split, control=:components) isa Plots.Plot
            Test.@test Plots.plot(sol; layout=:split, control=:norm) isa Plots.Plot
            Test.@test Plots.plot(sol; layout=:split, control=:all) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(
                sol; layout=:split, control=:wrong_choice
            )

            # layout only
            Test.@test Plots.plot(sol; layout=:split) isa Plots.Plot
            Test.@test Plots.plot(sol; layout=:group) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(
                sol; layout=:wrong_choice
            )
        end

        Test.@testset "plot!(...) – reuse of plots and time keyword" begin
            # Start from Plots.plot(sol, time=...)
            plt = Plots.plot(sol; time=:default)
            Test.@test Plots.plot!(plt, sol; time=:default) isa Plots.Plot
            Test.@test Plots.plot!(plt, sol; time=:normalize) isa Plots.Plot
            Test.@test Plots.plot!(plt, sol; time=:normalise) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                plt, sol; time=:wrong_choice
            )

            # Plots.plot!(sol, ...) variants with implicit current plot
            Plots.plot(sol; time=:default)
            Test.@test Plots.plot!(sol; time=:default) isa Plots.Plot
            Test.@test Plots.plot!(sol; time=:normalize) isa Plots.Plot
            Test.@test Plots.plot!(sol; time=:normalise) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                sol; time=:wrong_choice
            )

            # Start from an empty Plots.plot()
            plt2 = Plots.plot()
            Test.@test Plots.plot!(plt2, sol; time=:default) isa Plots.Plot
            Test.@test Plots.plot!(plt2, sol; time=:normalize) isa Plots.Plot
            Test.@test Plots.plot!(plt2, sol; time=:normalise) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                plt2, sol; time=:wrong_choice
            )
        end

        Test.@testset "plot!(...) – layout and control options" begin
            # group layout
            plt = Plots.plot(sol; layout=:group, control=:components)
            Test.@test Plots.plot!(plt, sol; layout=:group, control=:components) isa
                Plots.Plot
            Test.@test Plots.plot!(plt, sol; layout=:group, control=:norm) isa Plots.Plot

            plt = Plots.plot(sol; layout=:group, control=:norm)
            Test.@test Plots.plot!(plt, sol; layout=:group, control=:components) isa
                Plots.Plot
            Test.@test Plots.plot!(plt, sol; layout=:group, control=:norm) isa Plots.Plot

            plt = Plots.plot(sol; layout=:group, control=:all)
            Test.@test Plots.plot!(plt, sol; layout=:group, control=:all) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                plt, sol; layout=:group, control=:wrong_choice
            )

            # split layout
            plt = Plots.plot(sol; layout=:split, control=:components)
            Test.@test Plots.plot!(plt, sol; layout=:split, control=:components) isa
                Plots.Plot
            Test.@test Plots.plot!(plt, sol; layout=:split, control=:norm) isa Plots.Plot

            plt = Plots.plot(sol; layout=:split, control=:norm)
            Test.@test Plots.plot!(plt, sol; layout=:split, control=:components) isa
                Plots.Plot
            Test.@test Plots.plot!(plt, sol; layout=:split, control=:norm) isa Plots.Plot

            plt = Plots.plot(sol; layout=:split, control=:all)
            Test.@test Plots.plot!(plt, sol; layout=:split, control=:all) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                plt, sol; layout=:split, control=:wrong_choice
            )

            # layout only
            plt = Plots.plot(sol; layout=:split)
            Test.@test Plots.plot!(plt, sol; layout=:split) isa Plots.Plot

            plt = Plots.plot(sol; layout=:group)
            Test.@test Plots.plot!(plt, sol; layout=:group) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                plt, sol; layout=:wrong_choice
            )
        end

        Test.@testset "display(sol) – side effect" begin
            # Capture display output to IOBuffer to suppress terminal output
            io = IOBuffer()
            show(io, MIME"text/plain"(), sol)
            Test.@test true  # If we get here, display worked without error
        end

        # ====================================================================
        # INTEGRATION TESTS - Solution Example Dual (with duals)
        # ====================================================================

        ocp_pc, sol_pc = TestProblems.solution_example_dual()

        Test.@testset "plot(sol with path constraints) – time and layout" begin
            # time keyword
            Test.@test Plots.plot(sol_pc; time=:default) isa Plots.Plot
            Test.@test Plots.plot(sol_pc; time=:normalize) isa Plots.Plot
            Test.@test Plots.plot(sol_pc; time=:normalise) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(
                sol_pc; time=:wrong_choice
            )

            # layout/control
            Test.@test Plots.plot(sol_pc; layout=:group, control=:components) isa Plots.Plot
            Test.@test Plots.plot(sol_pc; layout=:group, control=:norm) isa Plots.Plot
            Test.@test Plots.plot(sol_pc; layout=:group, control=:all) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(
                sol_pc; layout=:group, control=:wrong_choice
            )

            Test.@test Plots.plot(sol_pc; layout=:split, control=:components) isa Plots.Plot
            Test.@test Plots.plot(sol_pc; layout=:split, control=:norm) isa Plots.Plot
            Test.@test Plots.plot(sol_pc; layout=:split, control=:all) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(
                sol_pc; layout=:split, control=:wrong_choice
            )

            Test.@test Plots.plot(sol_pc; layout=:split) isa Plots.Plot
            Test.@test Plots.plot(sol_pc; layout=:group) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(
                sol_pc; layout=:wrong_choice
            )
        end

        Test.@testset "plot!(sol with path constraints) – layout and time" begin
            # time keyword
            plt = Plots.plot(sol_pc; time=:default)
            Test.@test Plots.plot!(plt, sol_pc; time=:default) isa Plots.Plot
            Test.@test Plots.plot!(plt, sol_pc; time=:normalize) isa Plots.Plot
            Test.@test Plots.plot!(plt, sol_pc; time=:normalise) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                plt, sol_pc; time=:wrong_choice
            )

            # layout/control
            plt = Plots.plot(sol_pc; layout=:group, control=:components)
            Test.@test Plots.plot!(plt, sol_pc; layout=:group, control=:components) isa
                Plots.Plot
            Test.@test Plots.plot!(plt, sol_pc; layout=:group, control=:norm) isa Plots.Plot

            plt = Plots.plot(sol_pc; layout=:group, control=:norm)
            Test.@test Plots.plot!(plt, sol_pc; layout=:group, control=:components) isa
                Plots.Plot
            Test.@test Plots.plot!(plt, sol_pc; layout=:group, control=:norm) isa Plots.Plot

            plt = Plots.plot(sol_pc; layout=:group, control=:all)
            Test.@test Plots.plot!(plt, sol_pc; layout=:group, control=:all) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                plt, sol_pc; layout=:group, control=:wrong_choice
            )

            plt = Plots.plot(sol_pc; layout=:split, control=:components)
            Test.@test Plots.plot!(plt, sol_pc; layout=:split, control=:components) isa
                Plots.Plot
            Test.@test Plots.plot!(plt, sol_pc; layout=:split, control=:norm) isa Plots.Plot

            plt = Plots.plot(sol_pc; layout=:split, control=:norm)
            Test.@test Plots.plot!(plt, sol_pc; layout=:split, control=:components) isa
                Plots.Plot
            Test.@test Plots.plot!(plt, sol_pc; layout=:split, control=:norm) isa Plots.Plot

            plt = Plots.plot(sol_pc; layout=:split, control=:all)
            Test.@test Plots.plot!(plt, sol_pc; layout=:split, control=:all) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                plt, sol_pc; layout=:split, control=:wrong_choice
            )

            plt = Plots.plot(sol_pc; layout=:split)
            Test.@test Plots.plot!(plt, sol_pc; layout=:split) isa Plots.Plot

            plt = Plots.plot(sol_pc; layout=:group)
            Test.@test Plots.plot!(plt, sol_pc; layout=:group) isa Plots.Plot
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot!(
                plt, sol_pc; layout=:wrong_choice
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_plot() = TestPlot.test_plot()
