module TestPlotMakie

# =============================================================================
# End-to-end matrix for the Makie plotting extension (CTModelsMakie).
#
# Loaded with CairoMakie so `Makie` is present and the `CTModelsMakie` extension
# is active. Mirrors `test_plot_reference.jl` (the Plots reference matrix):
# `Makie.plot(sol, …)` / `Makie.plot!(f, sol, …)` must return a `Makie.Figure`
# for the common description / layout / style / overlay combinations. Freeze
# granularity is behavioural (`isa Makie.Figure` / no throw), plus the structural
# assertions the Makie backend makes checkable (axis count, Stairs / HLines /
# VLines plot objects).
# =============================================================================

using Test: Test
using CTBase: Plotting
using CairoMakie: CairoMakie
using CairoMakie: Makie
using CTModels: CTModels

include(joinpath("..", "..", "problems", "TestProblems.jl"))
using .TestProblems: TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_axes(f) = [x for x in f.content if x isa Makie.Axis]
_n_axes(f) = length(_axes(f))
_count_plots(axis, ::Type{T}) where {T} = count(p -> p isa T, axis.scene.plots)

function test_plot_makie()
    Test.@testset "Plotting Makie matrix" verbose = VERBOSE showtiming = SHOWTIMING begin
        _, sol, _ = TestProblems.solution_example()
        _, sol_pc = TestProblems.solution_example_dual()
        ocp_tf, sol_tf = TestProblems.solution_example_free_final_time()

        Test.@testset "default plot for every fixture" begin
            for s in (sol, sol_pc, sol_tf)
                Test.@test Makie.plot(s) isa Makie.Figure
            end
        end

        Test.@testset "description subsets" begin
            Test.@test Makie.plot(sol_pc) isa Makie.Figure
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
                Test.@test Makie.plot(sol_pc, desc...) isa Makie.Figure
                Test.@test Makie.plot(sol_pc, desc...; layout=:group) isa Makie.Figure
            end
        end

        Test.@testset "control mode × description × layout" begin
            for layout in (:split, :group)
                Test.@test Makie.plot(sol; layout=layout, control=:components) isa
                    Makie.Figure
                Test.@test Makie.plot(sol; layout=layout, control=:norm) isa Makie.Figure
                Test.@test Makie.plot(sol; layout=layout, control=:all) isa Makie.Figure
                Test.@test Makie.plot(sol, :control; layout=layout, control=:norm) isa
                    Makie.Figure
                Test.@test Makie.plot(
                    sol, :state, :control; layout=layout, control=:all
                ) isa Makie.Figure
            end
        end

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
            )
                Test.@test Makie.plot(sol_pc; layout=:split, kw...) isa Makie.Figure
            end
        end

        Test.@testset "decorations disabled render" begin
            for kw in (
                (; time_style=:none, label="toto"),
                (; state_bounds_style=:none),
                (; control_bounds_style=:none),
                (; path_bounds_style=:none),
                (; state_bounds_style=:none, control_bounds_style=:none),
                (;
                    state_bounds_style=:none,
                    control_bounds_style=:none,
                    path_bounds_style=:none,
                ),
                (; time_style=:none, control_bounds_style=:none, path_bounds_style=:none),
            )
                Test.@test Makie.plot(sol_pc; layout=:split, kw...) isa Makie.Figure
            end
        end

        Test.@testset "user styles and keywords" begin
            dash = (linestyle=:dash, linewidth=1)
            Test.@test Makie.plot(sol; label="tata", color=2) isa Makie.Figure
            Test.@test Makie.plot(sol; state_style=dash) isa Makie.Figure
            Test.@test Makie.plot(sol; costate_style=dash) isa Makie.Figure
            Test.@test Makie.plot(
                sol; state_style=dash, control_style=(dash..., seriestype=:path)
            ) isa Makie.Figure
            Test.@test Makie.plot(
                sol; state_style=:none, costate_style=dash, control_style=dash
            ) isa Makie.Figure
        end

        Test.@testset "color / size keywords" begin
            Test.@test Makie.plot(sol_pc; color=:red) isa Makie.Figure
            f = Makie.plot(sol_pc; size=(700, 500))
            Test.@test size(f.scene) == (700, 500)
        end

        Test.@testset "axis count matches the layout" begin
            f_split = Makie.plot(sol_pc)
            Test.@test _n_axes(f_split) ==
                Plotting.n_leaves(CTModels.PlotCase.build_figure(sol_pc))
            f_group = Makie.plot(sol_pc; layout=:group)
            Test.@test _n_axes(f_group) == 3
        end

        Test.@testset "decorations and step controls reach the axes" begin
            # solution_example has constant-interpolation control (→ stairs) and
            # box bounds + t0/tf markers (→ HLines / VLines).
            f = Makie.plot(sol)
            axs = _axes(f)
            Test.@test any(ax -> _count_plots(ax, Makie.Stairs) >= 1, axs)
            Test.@test any(ax -> _count_plots(ax, Makie.VLines) >= 1, axs)
        end

        Test.@testset "nothing to draw -> empty figure, no throw" begin
            f = Makie.plot(
                sol_pc;
                state_style=:none,
                costate_style=:none,
                control_style=:none,
                path_style=:none,
                dual_style=:none,
            )
            Test.@test f isa Makie.Figure
        end

        Test.@testset "overlay onto an existing figure" begin
            f = Makie.plot(sol_pc; color=15, time=:normalise, label="sol1")
            n = _n_axes(f)
            style = (linestyle=:dash,)
            out = Makie.plot!(
                f,
                sol_pc;
                color=1,
                time=:normalise,
                label="sol2",
                state_style=style,
                costate_style=style,
                control_style=style,
            )
            Test.@test out === f
            Test.@test _n_axes(f) == n            # overlay adds no axes
        end

        Test.@testset "plot! onto current and fresh figures" begin
            Makie.plot(sol_pc)                    # sets the current figure
            Test.@test Makie.plot!(sol_pc; color=2) isa Makie.Figure
            Test.@test Makie.plot!(Makie.Figure(), sol_pc) isa Makie.Figure
        end

        Test.@testset "plot(; size) is an empty canvas to overlay onto" begin
            # mirror of `Plots.plot(; size=…)`: a blank figure, then `plot!(f, sol)`.
            f = Makie.plot(; size=(800, 800))
            Test.@test f isa Makie.Figure
            Test.@test _n_axes(f) == 0
            Test.@test size(f.scene) == (800, 800)
            out = Makie.plot!(f, sol_pc)
            Test.@test out === f
            Test.@test _n_axes(f) == _n_axes(Makie.plot(sol_pc))
        end

        Test.@testset "free final time decorations" begin
            Test.@test !CTModels.has_fixed_final_time(ocp_tf)
            Test.@test CTModels.final_time(ocp_tf, CTModels.variable(sol_tf)) ≈ 2.0
            Test.@test Makie.plot(sol_tf) isa Makie.Figure
            Test.@test Makie.plot(sol_tf; layout=:group) isa Makie.Figure
            Test.@test Makie.plot(sol_tf; time=:normalize) isa Makie.Figure
            Test.@test Makie.plot(sol_tf, :state, :control) isa Makie.Figure
            Test.@test Makie.plot(sol_tf; time_style=(color=:red,)) isa Makie.Figure
            Test.@test Makie.plot(sol_tf; time_style=:none) isa Makie.Figure
        end
    end
    return nothing
end

end # module TestPlotMakie

# CRITICAL: Redefine in outer scope for TestRunner
test_plot_makie() = TestPlotMakie.test_plot_makie()
