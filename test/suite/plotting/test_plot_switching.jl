module TestPlotSwitching

# =============================================================================
# Unit tests for the switching structure in the backend-free plotting case layer
# `CTModels.PlotCase`: vertical jumps in the panel data, vertical lines at the
# switching times, phase labels. No plotting backend is loaded.
# =============================================================================

using Test: Test
using CTBase: Plotting
using CTBase: Exceptions
using CTModels: CTModels
using CTModels: Building
using CTModels: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ẋ = u on [0, 2], 1-D, with the path constraint g = x + u (label :g).
function _ocp()
    pre = Building.PreModel()
    Building.time_dependence!(pre; autonomous=true)
    Building.time!(pre; t0=0.0, tf=2.0)
    Building.state!(pre, 1)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
    Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r[1] = x + u; nothing), lb=[-10.0], ub=[10.0], label=:g
    )
    return Building.build(pre)
end

const τ = 1.0
const T = collect(range(0.0, 2.0; length=11))   # holds τ
_x(t) = t <= τ ? t : t + 1.0
_u(t) = t <= τ ? 1.0 : -1.0
_p(t) = t <= τ ? 0.0 : 2.0

function _sw(; labels=["bang+", "bang-"], limits=true)
    limits || return Solutions.SwitchingModel(; times=[τ], labels=labels)
    return Solutions.SwitchingModel(;
        times=[τ],
        labels=labels,
        state=([τ;;], [τ + 1.0;;]),
        costate=([0.0;;], [2.0;;]),
        control=([1.0;;], [-1.0;;]),
    )
end

function _sol(; switching=_sw(), grid=T)
    return Solutions.build_solution(
        _ocp(),
        grid,
        reshape(_x.(grid), :, 1),
        reshape(_u.(grid), :, 1),
        Float64[],
        reshape(_p.(grid), :, 1);
        objective=0.0,
        successful=true,
        switching=switching,
    )
end

_leaves(fig) = Plotting.leaves(fig.root)
_leaf(fig, title) = only(l for l in _leaves(fig) if l.axes.title == title)
_series(fig, title) = _leaf(fig, title).axes.series[1]
_decos(fig, title, D) = filter(d -> d isa D, _leaf(fig, title).axes.decorations)
_texts(fig) = reduce(
    vcat,
    (filter(d -> d isa Plotting.Annotation, l.axes.decorations) for l in _leaves(fig));
    init=Plotting.Annotation[],
)

function test_plot_switching()
    Test.@testset "PlotCase: switching structure" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - vertical jumps in the panel data
        # ====================================================================

        Test.@testset "_spliced_samples: insertion of the limits" begin
            sol = _sol()
            Ts, M = CTModels.PlotCase._spliced_samples(sol, T, reshape(_x.(T), :, 1), :state)
            # τ is in the grid: its sample is replaced by (τ, left), (τ, right)
            Test.@test count(==(τ), Ts) == 2
            Test.@test length(Ts) == length(T) + 1
            k = findfirst(==(τ), Ts)
            Test.@test M[k, 1] ≈ τ
            Test.@test M[k + 1, 1] ≈ τ + 1.0
            Test.@test issorted(Ts)
            # τ not in the samples: inserted at its place
            Tn = [0.0, 0.5, 1.5, 2.0]
            Ts2, M2 = CTModels.PlotCase._spliced_samples(sol, Tn, reshape(_x.(Tn), :, 1), :state)
            Test.@test Ts2 == [0.0, 0.5, τ, τ, 1.5, 2.0]
            Test.@test M2[:, 1] ≈ [0.0, 0.5, τ, τ + 1.0, 2.5, 3.0]
            # τ after the last sample
            Ts3, _ = CTModels.PlotCase._spliced_samples(sol, [0.0, 0.5], zeros(2, 1), :state)
            Test.@test Ts3 == [0.0, 0.5, τ, τ]
            # unchanged when no switching time, or limits not known
            plain = _sol(; switching=Solutions.EmptySwitchingModel())
            Test.@test CTModels.PlotCase._spliced_samples(plain, T, zeros(11, 1), :state) ==
                (T, zeros(11, 1))
            nolim = _sol(; switching=_sw(; limits=false))
            Test.@test CTModels.PlotCase._spliced_samples(nolim, T, zeros(11, 1), :state)[1] == T
            # samples with other components than the limits: an error
            Test.@test_throws Exceptions.IncorrectArgument CTModels.PlotCase._spliced_samples(
                sol, T, zeros(11, 2), :state
            )
        end

        Test.@testset "_phase_label_group" begin
            g(pl; kw...) = CTModels.PlotCase._phase_label_group(
                pl;
                (; state=false, costate=false, control=false, path=false, dual=false)...,
                kw...,
            )
            Test.@test g(:all; control=true) === :all
            Test.@test g(:control; state=true, control=true) === :control
            Test.@test g(:control; state=true, costate=true) === :state
            Test.@test g(:control; costate=true, path=true) === :costate
            Test.@test g(:control; path=true, dual=true) === :path
            Test.@test g(:control; dual=true) === :dual
            Test.@test g(:control) === :none
        end

        Test.@testset "state, costate and control panels draw vertical jumps" begin
            fig = CTModels.PlotCase.build_figure(_sol())
            for (title, left, right) in
                (("state", τ, τ + 1.0), ("costate", 0.0, 2.0), ("control", 1.0, -1.0))
                s = _series(fig, title)
                k = findfirst(==(τ), s.x)
                Test.@test s.x[k + 1] == τ                       # vertical segment
                Test.@test s.y[k] ≈ left
                Test.@test s.y[k + 1] ≈ right
            end
            # control norm (in :split, :all is one column with the norm last)
            fig_all = CTModels.PlotCase.build_figure(_sol(); control=:all)
            ctrl = _leaves(fig_all)
            normcell = only(
                l for l in ctrl if !isempty(l.axes.series) && l.axes.ylabel == "‖u‖"
            )
            s = normcell.axes.series[1]
            k = findfirst(==(τ), s.x)
            Test.@test (s.y[k], s.y[k + 1]) == (1.0, 1.0)
        end

        Test.@testset "path constraints are evaluated at both limits" begin
            fig = CTModels.PlotCase.build_figure(_sol(), :path)
            s = _series(fig, "path constraints")
            k = findfirst(==(τ), s.x)
            Test.@test s.x[k + 1] == τ
            Test.@test s.y[k] ≈ τ + 1.0             # x⁻ + u⁻
            Test.@test s.y[k + 1] ≈ (τ + 1.0) - 1.0 # x⁺ + u⁺
            # limits not known: plain samples
            fig2 = CTModels.PlotCase.build_figure(_sol(; switching=_sw(; limits=false)), :path)
            Test.@test count(==(τ), _series(fig2, "path constraints").x) == 1
        end

        Test.@testset "jumps=:none breaks the curves between the limits" begin
            fig = CTModels.PlotCase.build_figure(_sol(); jumps=:none)
            for (title, left, right) in
                (("state", τ, τ + 1.0), ("costate", 0.0, 2.0), ("control", 1.0, -1.0))
                s = _series(fig, title)
                k = findfirst(==(τ), s.x)
                Test.@test s.x[k:(k + 2)] == [τ, τ, τ]
                Test.@test s.y[k] ≈ left
                Test.@test isnan(s.y[k + 1])                    # no vertical segment
                Test.@test s.y[k + 2] ≈ right
            end
            p = _series(CTModels.PlotCase.build_figure(_sol(), :path; jumps=:none), "path constraints")
            k = findfirst(==(τ), p.x)
            Test.@test isnan(p.y[k + 1])
            Test.@test (p.y[k], p.y[k + 2]) == (τ + 1.0, (τ + 1.0) - 1.0)
            # default: the vertical segment, no NaN
            Test.@test !any(isnan, _series(CTModels.PlotCase.build_figure(_sol()), "state").y)
        end

        Test.@testset "no switching structure: unchanged panels" begin
            fig = CTModels.PlotCase.build_figure(_sol(; switching=Solutions.EmptySwitchingModel()))
            Test.@test _series(fig, "state").x == T
            Test.@test isempty(_texts(fig))
            Test.@test length(_decos(fig, "state", Plotting.VLine)) == 2   # t0 and tf only
        end

        # ====================================================================
        # UNIT TESTS - vertical lines at the switching times
        # ====================================================================

        Test.@testset "switching lines: in every cell, styled like the time lines" begin
            fig = CTModels.PlotCase.build_figure(_sol())
            for l in _leaves(fig)
                vls = filter(d -> d isa Plotting.VLine, l.axes.decorations)
                Test.@test [v.value for v in vls] == [0.0, 2.0, τ]
                Test.@test vls[3].style == vls[1].style
            end
            # the user time style applies to them too
            fig2 = CTModels.PlotCase.build_figure(_sol(); time_style=(color=:blue,))
            Test.@test _decos(fig2, "state", Plotting.VLine)[3].style.color === :blue
            # their own style merges on top
            fig3 = CTModels.PlotCase.build_figure(
                _sol(); time_style=(color=:blue,), switching_style=(color=:red, linewidth=2)
            )
            v = _decos(fig3, "state", Plotting.VLine)[3]
            Test.@test v.style.color === :red
            Test.@test v.style.linewidth == 2
            Test.@test v.style.linestyle === :dash
            # :none hides them, and only them
            fig4 = CTModels.PlotCase.build_figure(_sol(); switching_style=:none)
            Test.@test [d.value for d in _decos(fig4, "state", Plotting.VLine)] == [0.0, 2.0]
            # they stay when the time lines are hidden
            fig5 = CTModels.PlotCase.build_figure(_sol(); time_style=:none)
            Test.@test [d.value for d in _decos(fig5, "state", Plotting.VLine)] == [τ]
        end

        Test.@testset "switching lines and labels under time normalisation" begin
            fig = CTModels.PlotCase.build_figure(_sol(); time=:normalize)
            Test.@test [d.value for d in _decos(fig, "state", Plotting.VLine)] ==
                [0.0, 1.0, 0.5]
            Test.@test [a.x for a in _texts(fig)] ≈ [0.25, 0.75]
        end

        # ====================================================================
        # UNIT TESTS - phase labels
        # ====================================================================

        Test.@testset "phase labels: on the control cell by default" begin
            fig = CTModels.PlotCase.build_figure(_sol())
            ts = _decos(fig, "control", Plotting.Annotation)
            Test.@test [a.text for a in ts] == ["bang+", "bang-"]
            Test.@test [a.x for a in ts] ≈ [0.5, 1.5]          # centred on each phase
            Test.@test all(a -> a.style.color === :gray30, ts)  # default style
            Test.@test length(_texts(fig)) == 2                 # nowhere else
        end

        Test.@testset "phase labels: :all, :none, style, empty labels" begin
            fig = CTModels.PlotCase.build_figure(_sol(); phase_labels=:all)
            Test.@test length(_decos(fig, "state", Plotting.Annotation)) == 2
            Test.@test length(_decos(fig, "costate", Plotting.Annotation)) == 2
            Test.@test length(_decos(fig, "control", Plotting.Annotation)) == 2
            Test.@test isempty(_texts(CTModels.PlotCase.build_figure(_sol(); phase_labels=:none)))
            st = CTModels.PlotCase.build_figure(
                _sol(); phase_labels_style=(color=:red, fontsize=14)
            )
            a = first(_texts(st))
            Test.@test a.style.color === :red && a.style.fontsize == 14
            # an empty label gets no text; no label at all: none
            fig2 = CTModels.PlotCase.build_figure(_sol(; switching=_sw(; labels=["", "b"])))
            Test.@test [a.text for a in _texts(fig2)] == ["b"]
            fig3 = CTModels.PlotCase.build_figure(_sol(; switching=_sw(; labels=["", ""])))
            Test.@test isempty(_texts(fig3))
        end

        Test.@testset "phase labels: fallback when the control is not drawn" begin
            fig = CTModels.PlotCase.build_figure(_sol(), :state, :costate)
            Test.@test length(_decos(fig, "state", Plotting.Annotation)) == 2
            Test.@test isempty(_decos(fig, "costate", Plotting.Annotation))
            fig2 = CTModels.PlotCase.build_figure(_sol(); control_style=:none)
            Test.@test length(_decos(fig2, "state", Plotting.Annotation)) == 2
            fig3 = CTModels.PlotCase.build_figure(_sol(), :costate)
            Test.@test length(_decos(fig3, "costate", Plotting.Annotation)) == 2
        end

        Test.@testset "phase labels: group layout" begin
            fig = CTModels.PlotCase.build_figure(_sol(); layout=:group, control=:all)
            leaves = _leaves(fig)
            ctrl = only(l for l in leaves if l.axes.title == "control")
            norm = only(l for l in leaves if l.axes.title == "control norm")
            Test.@test count(d -> d isa Plotting.Annotation, ctrl.axes.decorations) == 2
            Test.@test !any(d -> d isa Plotting.Annotation, norm.axes.decorations)
        end

        Test.@testset "a labelled single phase" begin
            one = Solutions.SwitchingModel(; times=Float64[], labels=["bang"])
            fig = CTModels.PlotCase.build_figure(_sol(; switching=one))
            ts = _texts(fig)
            Test.@test [a.text for a in ts] == ["bang"]
            Test.@test only(ts).x ≈ 1.0
            Test.@test _series(fig, "state").x == T            # no jump
        end

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        Test.@testset "invalid jumps" begin
            Test.@test_throws Exceptions.IncorrectArgument CTModels.PlotCase.build_figure(
                _sol(); jumps=:dotted
            )
        end

        Test.@testset "invalid phase_labels" begin
            Test.@test_throws Exceptions.IncorrectArgument CTModels.PlotCase.build_figure(
                _sol(); phase_labels=:everywhere
            )
        end

        Test.@testset "keywords reach build_figure, not the backend" begin
            build, render = CTModels.PlotCase.split_plot_kwargs((
                switching_style=:none, phase_labels=:all, phase_labels_style=(;), color=:red
            ))
            Test.@test keys(build) == (:switching_style, :phase_labels, :phase_labels_style)
            Test.@test keys(render) == (:color,)
        end
    end
end

end # module

test_plot_switching() = TestPlotSwitching.test_plot_switching()
