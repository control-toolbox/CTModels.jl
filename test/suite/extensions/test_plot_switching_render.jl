module TestPlotSwitchingRender

# =============================================================================
# End-to-end rendering of a solution with a switching structure, with the Plots
# and Makie backends: the vertical jump, the switching-time lines and the phase
# labels reach the rendered figure.
# =============================================================================

using Test: Test
using Plots: Plots
using CairoMakie: CairoMakie
using CairoMakie: Makie
using CTModels: CTModels
using CTModels: Building
using CTModels: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const τ = 0.5

function _sol()
    pre = Building.PreModel()
    Building.time_dependence!(pre; autonomous=true)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 1)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    ocp = Building.build(pre)
    T = collect(range(0.0, 1.0; length=11))
    sw = Solutions.SwitchingModel(;
        times=[τ],
        labels=["bang+", "bang-"],
        state=([τ;;], [τ + 1.0;;]),
        costate=([0.0;;], [2.0;;]),
        control=([1.0;;], [-1.0;;]),
    )
    return Solutions.build_solution(
        ocp,
        T,
        reshape([t <= τ ? t : t + 1.0 for t in T], :, 1),
        reshape([t <= τ ? 1.0 : -1.0 for t in T], :, 1),
        Float64[],
        reshape([t <= τ ? 0.0 : 2.0 for t in T], :, 1);
        objective=0.0,
        successful=true,
        switching=sw,
    )
end

_axes(f) = [x for x in f.content if x isa Makie.Axis]
_count_plots(axis, ::Type{P}) where {P} = count(p -> p isa P, axis.scene.plots)

function test_plot_switching_render()
    Test.@testset "Rendering a solution with switching times" verbose=VERBOSE showtiming=SHOWTIMING begin
        sol = _sol()

        Test.@testset "Plots" begin
            plt = Plots.plot(sol)
            Test.@test plt isa Plots.Plot
            # state | costate over control: 3 cells
            Test.@test length(plt.subplots) == 3
            # the state series holds the vertical jump at τ
            xs = plt.subplots[1].series_list[1][:x]
            ys = plt.subplots[1].series_list[1][:y]
            k = findfirst(==(τ), xs)
            Test.@test xs[k + 1] == τ
            Test.@test (ys[k], ys[k + 1]) == (τ, τ + 1.0)
            # the phase labels are on the control cell only
            Test.@test length(plt.subplots[3][:annotations]) == 2
            Test.@test isempty(plt.subplots[1][:annotations])
            Test.@test sort([a[3].str for a in plt.subplots[3][:annotations]]) == ["bang+", "bang-"]
            # no labels, no switching lines: still renders
            Test.@test Plots.plot(sol; phase_labels=:none, switching_style=:none) isa
                Plots.Plot
            # overlay
            Test.@test Plots.plot!(Plots.plot(sol), sol) isa Plots.Plot
            # jumps=:none: a break (NaN) in the curve, no vertical segment
            br = Plots.plot(sol; jumps=:none)
            ys = br.subplots[1].series_list[1][:y]
            Test.@test count(isnan, ys) == 1
            # one color per trajectory: one series for the whole state component
            Test.@test count(s -> s[:seriestype] === :path, plt.subplots[1].series_list) ==
                1
        end

        Test.@testset "Makie" begin
            f = Makie.plot(sol)
            Test.@test f isa Makie.Figure
            axs = _axes(f)
            Test.@test length(axs) == 3
            # t0, tf and τ lines in every axis
            Test.@test all(ax -> _count_plots(ax, Makie.VLines) == 3, axs)
            # two phase labels, on the control axis only
            Test.@test sum(ax -> _count_plots(ax, Makie.Text), axs) == 2
            f2 = Makie.plot(sol; phase_labels=:all, switching_style=:none)
            Test.@test all(ax -> _count_plots(ax, Makie.VLines) == 2, _axes(f2))
            Test.@test sum(ax -> _count_plots(ax, Makie.Text), _axes(f2)) == 6
        end
    end
end

end # module

test_plot_switching_render() = TestPlotSwitchingRender.test_plot_switching_render()
