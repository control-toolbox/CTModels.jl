module TestSolutionShow

import Test: Test
import CTModels.Components: Components
import CTModels.Building: Building
import CTModels.Models: Models
import CTModels.Solutions: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_solution_show()
    Test.@testset "Solution Display" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Solution show output
        # ====================================================================

        Test.@testset "Solution text/plain show" begin
            # create a minimal OCP
            pre_ocp = Building.PreModel()
            Building.time!(pre_ocp; t0=0.0, tf=1.0)
            Building.state!(pre_ocp, 1, "x", ["x"])
            Building.control!(pre_ocp, 1, "u", ["u"])
            Building.variable!(pre_ocp, 0)
            dynamics!(r, t, x, u, v) = (r[1] = u[1]; nothing)
            Building.dynamics!(pre_ocp, dynamics!)
            Building.objective!(
                pre_ocp, :min;
                mayer=(x0, xf, v) -> 0.0,
                lagrange=(t, x, u, v) -> 0.5 * u[1]^2,
            )
            Building.time_dependence!(pre_ocp; autonomous=false)
            ocp = Building.build(pre_ocp)

            # create a solution
            T = [0.0, 0.5, 1.0]
            X = zeros(3, 1)
            X[:, 1] = [0.0, 0.5, 1.0]
            U = zeros(3, 1)
            U[:, 1] = [1.0, 2.0, 3.0]
            v = Float64[]
            P = zeros(3, 1)
            P[:, 1] = [0.1, 0.2, 0.3]
            sol = Solutions.build_solution(
                ocp, T, X, U, v, P;
                objective=0.5,
                iterations=10,
                constraints_violation=1e-8,
                message="converged",
                status=:first_order,
                successful=true,
            )

            io = IOBuffer()
            show(io, MIME"text/plain"(), sol)
            s = String(take!(io))

            Test.@test occursin("Solver", s)
            Test.@test occursin("Successful", s)
            Test.@test occursin("Status", s)
            Test.@test occursin("Message", s)
            Test.@test occursin("Iterations", s)
            Test.@test occursin("Objective", s)
            Test.@test occursin("Constraints violation", s)
            Test.@test occursin("converged", s)
            Test.@test occursin("first_order", s)
        end

        Test.@testset "Solution show with variable" begin
            # create an OCP with a variable
            pre_ocp = Building.PreModel()
            Building.time!(pre_ocp; t0=0.0, tf=1.0)
            Building.state!(pre_ocp, 1, "x", ["x"])
            Building.control!(pre_ocp, 1, "u", ["u"])
            Building.variable!(pre_ocp, 1, "v", ["v"])
            dynamics!(r, t, x, u, v) = (r[1] = u[1]; nothing)
            Building.dynamics!(pre_ocp, dynamics!)
            Building.objective!(
                pre_ocp, :min;
                mayer=(x0, xf, v) -> 0.0,
                lagrange=(t, x, u, v) -> 0.5 * u[1]^2,
            )
            Building.time_dependence!(pre_ocp; autonomous=false)
            ocp = Building.build(pre_ocp)

            T = [0.0, 1.0]
            X = zeros(2, 1)
            X[:, 1] = [0.0, 1.0]
            U = zeros(2, 1)
            U[:, 1] = [1.0, 2.0]
            v = [5.0]
            P = zeros(2, 1)
            P[:, 1] = [0.1, 0.2]
            sol = Solutions.build_solution(
                ocp, T, X, U, v, P;
                objective=1.0,
                iterations=5,
                constraints_violation=0.0,
                message="ok",
                status=:first_order,
                successful=true,
            )

            io = IOBuffer()
            show(io, MIME"text/plain"(), sol)
            s = String(take!(io))

            Test.@test occursin("Variable", s)
            Test.@test occursin("5.0", s)
        end

        Test.@testset "Solution show with unsuccessful solver" begin
            pre_ocp = Building.PreModel()
            Building.time!(pre_ocp; t0=0.0, tf=1.0)
            Building.state!(pre_ocp, 1, "x", ["x"])
            Building.control!(pre_ocp, 1, "u", ["u"])
            Building.variable!(pre_ocp, 0)
            dynamics!(r, t, x, u, v) = (r[1] = u[1]; nothing)
            Building.dynamics!(pre_ocp, dynamics!)
            Building.objective!(
                pre_ocp, :min;
                mayer=(x0, xf, v) -> 0.0,
                lagrange=(t, x, u, v) -> 0.5 * u[1]^2,
            )
            Building.time_dependence!(pre_ocp; autonomous=false)
            ocp = Building.build(pre_ocp)

            T = [0.0, 1.0]
            X = zeros(2, 1)
            X[:, 1] = [0.0, 1.0]
            U = zeros(2, 1)
            U[:, 1] = [1.0, 2.0]
            v = Float64[]
            P = zeros(2, 1)
            P[:, 1] = [0.1, 0.2]
            sol = Solutions.build_solution(
                ocp, T, X, U, v, P;
                objective=1.0,
                iterations=3,
                constraints_violation=100.0,
                message="failed",
                status=:not_solved,
                successful=false,
            )

            io = IOBuffer()
            show(io, MIME"text/plain"(), sol)
            s = String(take!(io))

            Test.@test occursin("Solver", s)
            Test.@test occursin("false", s)
            Test.@test occursin("failed", s)
            Test.@test occursin("not_solved", s)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_solution_show() = TestSolutionShow.test_solution_show()
