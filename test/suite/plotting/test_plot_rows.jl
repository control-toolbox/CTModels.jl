module TestPlotRows

# =============================================================================
# Unit tests for the constraint rows of the plot (issue #506): one row per constraint
# label — path, state box or control box — pairing the constraint with its dual.
# Backend-free: exercises `CTModels.PlotCase` directly.
# =============================================================================

using Test: Test
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

        Test.@testset "a label with an unknown dual gives no row" begin
            # path duals only: the control box :u_con has no dual
            ocp_pc, sol_pc = TestProblems.solution_example_dual()
            labels = [r.label for r in CTModels.PlotCase._constraint_rows(sol_pc, ocp_pc)]
            Test.@test :u_con ∉ labels
            Test.@test :con2 ∈ labels
            # a solution without any dual: no row
            ocp0, sol0, _ = TestProblems.solution_example()
            Test.@test isempty(CTModels.PlotCase._constraint_rows(sol0, ocp0))
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
