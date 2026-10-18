module TestJSONFormat

using Test: Test
using JSON: JSON
using CTBase: Exceptions
using CTModels: Building
using CTModels: Components
using CTModels: Serialization
using CTModels: Solutions

include(joinpath("..", "..", "problems", "TestProblems.jl"))
using .TestProblems: TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Files written by the previous version of CTModels, which used JSON3.jl for the JSON
# format (CTModels 0.19.8): the format of the files does not change with JSON.jl.
const FIXTURES = joinpath(@__DIR__, "..", "..", "fixtures")

# A small solution with a dimension-1 state and control, on a given objective.
function _small_solution(; objective=0.0)
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 1)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r .= u))
    Building.objective!(pre; mayer=(x0, xf, v) -> 0.0)
    Building.definition!(pre, quote end)
    Building.time_dependence!(pre; autonomous=false)
    ocp = Building.build(pre)
    sol = Solutions.build_solution(
        ocp,
        [0.0, 0.5, 1.0],
        zeros(3, 1),
        zeros(3, 1),
        Float64[],
        zeros(3, 1);
        objective=objective,
        iterations=1,
        constraints_violation=0.0,
        message="ok",
        status=:optimal,
        successful=true,
    )
    return ocp, sol
end

function _check_same(sol, back, ts)
    Test.@test Solutions.objective(back) ≈ Solutions.objective(sol)
    Test.@test Solutions.iterations(back) == Solutions.iterations(sol)
    Test.@test Solutions.status(back) == Solutions.status(sol)
    Test.@test Solutions.successful(back) == Solutions.successful(sol)
    Test.@test Components.time_grid(back) ≈ Components.time_grid(sol)
    for t in ts
        Test.@test Components.state(back)(t) ≈ Components.state(sol)(t) atol = 1e-8
        Test.@test Components.costate(back)(t) ≈ Components.costate(sol)(t) atol = 1e-8
        Test.@test Components.control(back)(t) ≈ Components.control(sol)(t) atol = 1e-8
    end
end

function test_json_format()
    Test.@testset "JSON format (JSON.jl)" verbose = VERBOSE showtiming = SHOWTIMING begin
        mktempdir() do dir
            # ================================================================
            # Files written by the JSON3-based version are still read
            # ================================================================

            Test.@testset "reads a file written with JSON3: solution_example" begin
                ocp, sol, _ = TestProblems.solution_example()
                path = joinpath(FIXTURES, "json3_solution_example")
                back = Serialization.import_ocp_solution(ocp; filename=path, format=:JSON)
                _check_same(sol, back, Components.time_grid(sol)[1:50:end])
            end

            Test.@testset "reads a file written with JSON3: solution with duals" begin
                ocp, sol = TestProblems.solution_example_dual()
                path = joinpath(FIXTURES, "json3_solution_example_dual")
                back = Serialization.import_ocp_solution(ocp; filename=path, format=:JSON)
                # the original trajectories are functions: compare on the exported grid
                _check_same(sol, back, Components.time_grid(sol)[1:50:end])
                Test.@test Solutions.path_constraints_dual(back)(0.5) ≈
                    Solutions.path_constraints_dual(sol)(0.5) atol = 1e-8
            end

            # ================================================================
            # The files written now have the structure of the previous ones
            # ================================================================

            Test.@testset "same keys and shapes as a file written with JSON3 (but for the version)" begin
                ocp, sol, _ = TestProblems.solution_example()
                path = joinpath(dir, "now")
                Serialization.export_ocp_solution(sol; filename=path, format=:JSON)
                now = JSON.parsefile(path * ".json")
                old = JSON.parsefile(joinpath(FIXTURES, "json3_solution_example.json"))
                # the same keys: only the optional switching structure is new, and only
                # written for a solution that holds one
                Test.@test Set(keys(now)) == Set(keys(old))
                for k in ("state", "control", "costate")   # lists of rows, not flat arrays
                    Test.@test now[k] isa AbstractVector
                    Test.@test all(r -> r isa AbstractVector, now[k])
                    Test.@test length(now[k]) == length(old[k])
                    Test.@test length(now[k][1]) == length(old[k][1])
                end
                # the version of the format is the current one; the file of the previous
                # version has the earlier one, and is read all the same
                Test.@test now["format_version"] == Solutions.SERIALIZATION_FORMAT_VERSION
                Test.@test old["format_version"] < now["format_version"]
                Test.@test isnothing(now["path_constraints_dual"]) ==
                    isnothing(old["path_constraints_dual"])
            end

            Test.@testset "round trip: a string, a symbol and nested infos" begin
                ocp, sol = _small_solution()
                path = joinpath(dir, "rt")
                Serialization.export_ocp_solution(sol; filename=path, format=:JSON)
                back = Serialization.import_ocp_solution(ocp; filename=path, format=:JSON)
                _check_same(sol, back, [0.0, 0.25, 1.0])
                Test.@test Solutions.status(back) === :optimal
                Test.@test Solutions.message(back) == "ok"
            end

            # ================================================================
            # NaN is not allowed in JSON: an error, and no half-written file
            # ================================================================

            Test.@testset "a NaN is rejected, no file is left" begin
                ocp, sol = _small_solution(; objective=NaN)
                path = joinpath(dir, "nan")
                Test.@test_throws ArgumentError Serialization.export_ocp_solution(
                    sol; filename=path, format=:JSON
                )
                Test.@test !isfile(path * ".json")
            end

            # ================================================================
            # The tag follows the package
            # ================================================================

            Test.@testset "JSONTag replaces JSON3Tag" begin
                Test.@test Serialization.JSONTag <: Serialization.AbstractTag
                Test.@test !isdefined(Serialization, :JSON3Tag)
                Test.@test sprint(show, Serialization.JSONTag()) == "JSONTag()"
                ocp, sol = _small_solution()
                path = joinpath(dir, "tag")
                Serialization.export_ocp_solution(Serialization.JSONTag(), sol; filename=path)
                back = Serialization.import_ocp_solution(
                    Serialization.JSONTag(), ocp; filename=path
                )
                _check_same(sol, back, [0.0, 0.5, 1.0])
            end
        end
    end
    return nothing
end

end # module TestJSONFormat

test_json_format() = TestJSONFormat.test_json_format()
