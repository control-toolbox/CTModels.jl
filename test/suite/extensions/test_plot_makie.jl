module TestPlotMakie

# =============================================================================
# End-to-end matrix for the Makie plotting extension (CTModelsMakie, POC).
#
# Loaded with CairoMakie so `Makie` is present and the `CTModelsMakie` extension
# is active. Mirrors the subset of `test_plot_reference.jl` that the POC Makie
# backend supports: `Makie.plot(sol, …)` must return a `Makie.Figure` for the
# common description / layout / style combinations. Freeze granularity is
# behavioural (`isa Makie.Figure` / no throw), as for the Plots reference.
# =============================================================================

using Test: Test
using CTBase: Exceptions
using CTBase: Plotting
using CairoMakie: CairoMakie
using CairoMakie: Makie
using CTModels: CTModels

include(joinpath("..", "..", "problems", "TestProblems.jl"))
using .TestProblems: TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_n_axes(f) = count(x -> x isa Makie.Axis, f.content)

function test_plot_makie()
    Test.@testset "Plotting Makie matrix" verbose = VERBOSE showtiming = SHOWTIMING begin
        _, sol, _ = TestProblems.solution_example()
        _, sol_pc = TestProblems.solution_example_dual()
        _, sol_tf = TestProblems.solution_example_free_final_time()

        Test.@testset "default plot for every fixture" begin
            for s in (sol, sol_pc, sol_tf)
                Test.@test Makie.plot(s) isa Makie.Figure
            end
        end

        Test.@testset "description subsets" begin
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

        Test.@testset "layout x control" begin
            for layout in (:split, :group), control in (:components, :norm, :all)
                Test.@test Makie.plot(sol_pc; layout=layout, control=control) isa
                    Makie.Figure
            end
        end

        Test.@testset "group style :none / NamedTuple" begin
            for kw in (
                (; state_style=:none),
                (; costate_style=:none),
                (; control_style=:none),
                (; path_style=:none),
                (; dual_style=:none),
                (; state_style=(color=:blue,)),
                (; state_style=(color=:blue,), costate_style=:none, control_style=:none),
            )
                Test.@test Makie.plot(sol_pc; layout=:split, kw...) isa Makie.Figure
            end
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

        Test.@testset "overlay is not implemented" begin
            Test.@test_throws Exceptions.NotImplemented Makie.plot!(sol_pc)
        end

        Test.@testset "time normalization renders" begin
            Test.@test Makie.plot(sol_pc; time=:normalize) isa Makie.Figure
        end
    end
    return nothing
end

end # module TestPlotMakie

# CRITICAL: Redefine in outer scope for TestRunner
test_plot_makie() = TestPlotMakie.test_plot_makie()
