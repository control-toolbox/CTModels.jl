module TestPlotReference

# ==============================================================================
# Reference matrix for the plotting extension — behaviour freeze.
#
# This file turns the hand-written visual-check scripts under `.extras/`
# (`plot_duals.jl`, `plot_manual.jl`, `plot_series.jl`) into executable,
# assertion-based tests so the reference matrix runs in CI. It deliberately
# covers only what `test_plot.jl` does NOT already assert:
#   - description-symbol subsets: plot(sol, :state, :control, :path), …
#   - end-to-end per-group `*_style=:none`
#   - end-to-end decoration disabling (`time_style`, `*_bounds_style`)
#   - user style NamedTuples + `color`/`label` keywords
#   - two-solution comparison overlay (`plot!`)
#
# Freeze granularity is behavioural (`isa Plots.Plot` / no throw): the scripts
# themselves only checked "does it render". Golden assertions on the figure IR
# come with the CTBase engine migration (see .reports/dev report, phase 1/3).
#
# Fixtures (reused, no new problem introduced):
#   - solution_example()      → 2 states / 1 control, matrices (constant
#     interpolation) with a distinct costate grid `T[1:end-1]`, path constraint
#     in the model but no duals — mirrors `.extras/plot_manual.jl`.
#   - solution_example_dual() → the exact OCP of `.extras/plot_duals.jl`
#     (1 state / 1 control, path constraints + duals).
#   - solution_example_free_final_time() → double integrator in minimum time,
#     `tf` free (decision variable) — mirrors `.extras/plot_variable.jl` without
#     a CTDirect/Ipopt dependency (closed-form solution via `build_solution`).
# ==============================================================================

import Test: Test
import CTBase.Exceptions: Exceptions
import Plots: Plots
import CTModels: CTModels

include(joinpath("..", "..", "problems", "TestProblems.jl"))
import .TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_plot_reference()
    Test.@testset "Plotting reference matrix" verbose = VERBOSE showtiming = SHOWTIMING begin

        # solution_example: matrices / distinct costate grid (plot_manual.jl)
        _, sol, _ = TestProblems.solution_example()
        # solution_example_dual: the plot_duals.jl model, with duals
        _, sol_pc = TestProblems.solution_example_dual()
        # free final time: tf is a decision variable (plot_variable.jl)
        ocp_tf, sol_tf = TestProblems.solution_example_free_final_time()

        # ======================================================================
        # Description-symbol subsets (.extras/plot_duals.jl:70-78)
        # Every subset must render for a solution carrying path constraints and
        # duals. `plot(sol)` with no description falls back to "everything".
        # ======================================================================
        Test.@testset "description subsets" begin
            Test.@test Plots.plot(sol_pc) isa Plots.Plot
            for desc in (
                (:state,),
                (:state, :costate),
                (:state, :control),
                (:state, :control, :path),
                (:costate,),
                (:control,),
                (:path,),
                (:dual,),
                (:path, :dual),
            )
                Test.@test Plots.plot(sol_pc, desc...) isa Plots.Plot
                Test.@test Plots.plot(sol_pc, desc...; layout=:group) isa Plots.Plot
            end
        end

        # ======================================================================
        # Per-group styles set to :none, end to end (.extras/plot_duals.jl:80-90)
        # `do_plot` booleans are already unit-tested; here we assert the full
        # pipeline still returns a valid figure when a group is dropped.
        # ======================================================================
        Test.@testset "group style :none renders" begin
            for kw in (
                (; state_style=:none),
                (; costate_style=:none),
                (; control_style=:none),
                (; path_style=:none),
                (; dual_style=:none),
                (; state_style=:none, control_style=:none),
                (; state_style=:none, costate_style=:none),
                (; costate_style=:none, control_style=:none),
                (; path_style=:none, control_style=:none),
                (; dual_style=:none, control_style=:none),
            )
                Test.@test Plots.plot(sol_pc; layout=:split, kw...) isa Plots.Plot
            end
        end

        # ======================================================================
        # Decorations disabled, end to end (.extras/plot_duals.jl:92-115)
        # ======================================================================
        Test.@testset "decorations disabled render" begin
            for kw in (
                (; time_style=:none, label="toto"),
                (; state_bounds_style=:none),
                (; control_bounds_style=:none),
                (; path_bounds_style=:none),
                (; state_bounds_style=:none, control_bounds_style=:none),
                (; state_bounds_style=:none, path_bounds_style=:none),
                (; control_bounds_style=:none, path_bounds_style=:none),
                (;
                    state_bounds_style=:none,
                    control_bounds_style=:none,
                    path_bounds_style=:none,
                ),
                (; time_style=:none, state_bounds_style=:none),
                (; time_style=:none, control_bounds_style=:none),
                (; time_style=:none, control_bounds_style=:none, path_bounds_style=:none),
            )
                Test.@test Plots.plot(sol_pc; layout=:split, kw...) isa Plots.Plot
            end
        end

        # ======================================================================
        # User style NamedTuples + color/label (.extras/plot_manual.jl:201-225)
        # ======================================================================
        Test.@testset "user styles and keywords" begin
            dash = (linestyle=:dash, linewidth=1)
            Test.@test Plots.plot(sol; label="tata", color=2) isa Plots.Plot
            Test.@test Plots.plot(sol; state_style=dash) isa Plots.Plot
            Test.@test Plots.plot(sol; costate_style=dash) isa Plots.Plot
            Test.@test Plots.plot(sol; control_style=dash) isa Plots.Plot
            Test.@test Plots.plot(
                sol; state_style=dash, control_style=(dash..., seriestype=:path)
            ) isa Plots.Plot
            Test.@test Plots.plot(sol; state_style=dash, costate_style=dash) isa Plots.Plot
            Test.@test Plots.plot(sol; costate_style=dash, control_style=dash) isa
                Plots.Plot
            Test.@test Plots.plot(
                sol; state_style=:none, costate_style=dash, control_style=dash
            ) isa Plots.Plot
        end

        # ======================================================================
        # control=:all / :norm with description subsets, both layouts
        # (.extras/plot_manual.jl:163-190)
        # ======================================================================
        Test.@testset "control mode × description × layout" begin
            for layout in (:group, :split)
                Test.@test Plots.plot(sol; layout=layout, control=:components) isa
                    Plots.Plot
                Test.@test Plots.plot(sol; layout=layout, control=:norm) isa Plots.Plot
                Test.@test Plots.plot(sol; layout=layout, control=:all) isa Plots.Plot
                Test.@test Plots.plot(sol, :control; layout=layout, control=:norm) isa
                    Plots.Plot
                Test.@test Plots.plot(sol, :control; layout=layout, control=:all) isa
                    Plots.Plot
                Test.@test Plots.plot(
                    sol, :state, :control; layout=layout, control=:all
                ) isa Plots.Plot
            end
        end

        # ======================================================================
        # Two-solution comparison overlay (.extras/plot_manual.jl:228-239)
        # First solution sets size + normalized time; the second overlays with
        # per-group dashed styles. This is the R1 case (plot! reuse semantics).
        # ======================================================================
        Test.@testset "two-solution comparison overlay" begin
            plt = Plots.plot(sol; color=15, size=(700, 450), time=:normalise, label="sol1")
            Test.@test plt isa Plots.Plot
            style = (linestyle=:dash,)
            Test.@test Plots.plot!(
                plt,
                sol;
                color=1,
                time=:normalise,
                label="sol2",
                state_style=style,
                costate_style=style,
                control_style=style,
            ) isa Plots.Plot
        end

        # ======================================================================
        # plot! reuse against a pre-sized / current figure
        # (.extras/plot_manual.jl:153-159)
        # ======================================================================
        Test.@testset "plot! onto pre-sized and current figures" begin
            Plots.plot(; size=(800, 800))
            Test.@test Plots.plot!(sol; color=2) isa Plots.Plot

            plt = Plots.plot(; size=(800, 800))
            Test.@test Plots.plot!(plt, sol) isa Plots.Plot
        end

        # ======================================================================
        # Free final time (.extras/plot_variable.jl): tf is a decision variable,
        # so the time decorations read tf from the variable via
        # `final_time(model, variable(sol))`. This is the only path here that no
        # fixed-time fixture exercises. Covered for both real and normalized time.
        # ======================================================================
        Test.@testset "free final time decorations" begin
            # guard: the fixture is genuinely free-final-time, tf = 2
            Test.@test !CTModels.has_fixed_final_time(ocp_tf)
            Test.@test CTModels.final_time(ocp_tf, CTModels.variable(sol_tf)) ≈ 2.0

            Test.@test Plots.plot(sol_tf) isa Plots.Plot
            Test.@test Plots.plot(sol_tf; layout=:group) isa Plots.Plot
            Test.@test Plots.plot(sol_tf; time=:normalize) isa Plots.Plot
            Test.@test Plots.plot(sol_tf, :state, :control) isa Plots.Plot
            # time decoration explicitly on vs off
            Test.@test Plots.plot(sol_tf; time_style=(color=:red,)) isa Plots.Plot
            Test.@test Plots.plot(sol_tf; time_style=:none) isa Plots.Plot
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_plot_reference() = TestPlotReference.test_plot_reference()
