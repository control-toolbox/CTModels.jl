module TestOptionalFields

using Test: Test
using JSON: JSON
using JLD2: JLD2
using CTBase: CTBase
using CTModels: Building
using CTModels: Solutions
using CTModels: Serialization

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const NP = CTBase.Core.NotProvided

const FORMATS = (:JSON, :JLD)
const FIELDS = (:iterations, :constraints_violation, :message, :status)

function _ocp()
    pre = Building.PreModel()
    Building.time_dependence!(pre; autonomous=true)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 1)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
    Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return Building.build(pre)
end

function _solution(ocp; set::Bool)
    T = collect(range(0.0, 1.0, 11))
    extra = if set
        (; iterations=7, constraints_violation=1e-9, message="converged", status=:Success)
    else
        (;)
    end
    return Solutions.build_solution(
        ocp, T, t -> [t], t -> [1.0], Float64[], t -> [0.0];
        objective=0.5, successful=true, extra...,
    )
end

_values(sol) = map(f -> getfield(Solutions, f)(sol), FIELDS)

_ext(fmt) = fmt === :JSON ? ".json" : ".jld2"

# What the previous version wrote for an unset field.
function _make_legacy(fmt, path)
    if fmt === :JSON
        blob = JSON.parse(read(path, String); dicttype=Dict{String,Any})
        for k in String.(FIELDS)
            blob[k] = "NotProvided"
        end
        write(path, JSON.json(blob; pretty=true))
    else
        data = JLD2.load(path)["solution_data"]
        data["iterations"] = NP
        data["constraints_violation"] = NP
        data["message"] = NP
        data["status"] = NP
        JLD2.jldsave(path; solution_data=data)
    end
    return nothing
end

function _import_with(ocp, fmt, path)
    return Serialization.import_ocp_solution(ocp; format=fmt, filename=path)
end

function test_optional_fields()
    Test.@testset "Optional solver fields round trip (#464)" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        ocp = _ocp()
        mktempdir() do dir
            for fmt in FORMATS
                Test.@testset "$fmt" begin
                    path = joinpath(dir, "sol_$(fmt)")
                    file = path * _ext(fmt)

                    Test.@testset "all four fields unset" begin
                        sol = _solution(ocp; set=false)
                        Test.@test all(v -> v === NP, _values(sol))
                        Serialization.export_ocp_solution(sol; format=fmt, filename=path)
                        back = _import_with(ocp, fmt, path)
                        Test.@test all(v -> v === NP, _values(back))
                        Test.@test Solutions.successful(back)
                    end

                    Test.@testset "all four fields set" begin
                        sol = _solution(ocp; set=true)
                        Serialization.export_ocp_solution(sol; format=fmt, filename=path)
                        back = _import_with(ocp, fmt, path)
                        Test.@test Solutions.iterations(back) == 7
                        Test.@test Solutions.constraints_violation(back) == 1e-9
                        Test.@test Solutions.message(back) == "converged"
                        Test.@test Solutions.status(back) === :Success
                    end

                    Test.@testset "legacy file with \"NotProvided\"" begin
                        sol = _solution(ocp; set=false)
                        Serialization.export_ocp_solution(sol; format=fmt, filename=path)
                        _make_legacy(fmt, file)
                        back = _import_with(ocp, fmt, path)
                        Test.@test all(v -> v === NP, _values(back))
                    end

                    Test.@testset "wrong type raises a ParsingError" begin
                        sol = _solution(ocp; set=true)
                        Serialization.export_ocp_solution(sol; format=fmt, filename=path)
                        if fmt === :JSON
                            blob = JSON.parse(read(file, String); dicttype=Dict{String,Any})
                            blob["iterations"] = "many"
                            write(file, JSON.json(blob; pretty=true))
                        else
                            data = JLD2.load(file)["solution_data"]
                            data["iterations"] = "many"
                            JLD2.jldsave(file; solution_data=data)
                        end
                        Test.@test_throws CTBase.Exceptions.ParsingError _import_with(
                            ocp, fmt, path
                        )
                    end
                end
            end

            Test.@testset "JSON file holds null, not \"NotProvided\"" begin
                path = joinpath(dir, "null_check")
                Serialization.export_ocp_solution(
                    _solution(ocp; set=false); format=:JSON, filename=path
                )
                blob = JSON.parse(read(path * ".json", String); dicttype=Dict{String,Any})
                for k in String.(FIELDS)
                    Test.@test haskey(blob, k) && blob[k] === nothing
                end
            end
        end
    end
    return nothing
end

end # module TestOptionalFields

test_optional_fields() = TestOptionalFields.test_optional_fields()
