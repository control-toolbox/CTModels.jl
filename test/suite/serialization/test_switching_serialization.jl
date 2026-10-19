module TestSwitchingSerialization

using Test: Test
using JLD2: JLD2
using JSON: JSON
using CTModels: CTModels
using CTModels: Building
using CTModels: Solutions
using CTModels: Serialization

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ẋ = (x₂, u), 2-D state, 1-D control on [0, 1]: vector limits for the state and costate,
# scalar ones for the control.
function _ocp()
    pre = Building.PreModel()
    Building.time_dependence!(pre; autonomous=true)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return Building.build(pre)
end

const τ1, τ2 = 0.3, 0.7
_x(t) =
    if t <= τ1
        [t, 1.0]
    elseif t <= τ2
        [t + 1.0, 1.0]
    else
        [t + 1.0, 3.0]
    end
_p(t) = t <= τ2 ? [0.0, 0.0] : [1.0, -1.0]
_u(t) =
    if t <= τ1
        1.0
    elseif t <= τ2
        0.0
    else
        -1.0
    end

function _sw()
    return Solutions.SwitchingModel(;
        times=[τ1, τ2],
        labels=["bang", "", "boundary"],
        state=([τ1 1.0; τ2+1.0 1.0], [τ1+1.0 1.0; τ2+1.0 3.0]),
        costate=([0.0 0.0; 0.0 0.0], [0.0 0.0; 1.0 -1.0]),
        control=([1.0; 0.0;;], [0.0; -1.0;;]),
    )
end

function _sol(; switching=_sw())
    T = collect(range(0.0, 1.0; length=11))
    return Solutions.build_solution(
        _ocp(),
        T,
        reduce(vcat, (_x(t)' for t in T)),
        reshape(_u.(T), :, 1),
        Float64[],
        reduce(vcat, (_p(t)' for t in T));
        objective=0.0,
        iterations=3,
        constraints_violation=0.0,
        message="ok",
        status=:ok,
        successful=true,
        switching=switching,
    )
end

function _check_roundtrip(sol, back)
    Test.@test CTModels.switching_times(back) == CTModels.switching_times(sol)
    Test.@test CTModels.phase_labels(back) == CTModels.phase_labels(sol)
    for c in (:state, :costate, :control), i in 1:2
        Test.@test CTModels.left_limit(back, c, i) == CTModels.left_limit(sol, c, i)
        Test.@test CTModels.right_limit(back, c, i) == CTModels.right_limit(sol, c, i)
    end
    # the imported trajectories keep their jumps
    for t in (0.25, τ1, 0.35, 0.5, τ2, 0.75, 1.0)
        Test.@test CTModels.state(back)(t) ≈ CTModels.state(sol)(t)
        Test.@test CTModels.costate(back)(t) ≈ CTModels.costate(sol)(t)
        Test.@test CTModels.control(back)(t) ≈ CTModels.control(sol)(t)
    end
    Test.@test CTModels.state(back)(0.35) ≈ [1.35, 1.0]   # after the jump at τ1
    return nothing
end

function test_switching_serialization()
    Test.@testset "Serialization of the switching structure" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = _ocp()

        Test.@testset "serialized data" begin
            data = Solutions._serialize_solution(_sol())
            Test.@test data["format_version"] == 2
            Test.@test data["switching_times"] == [τ1, τ2]
            Test.@test data["phase_labels"] == ["bang", "", "boundary"]
            Test.@test data["switching_state_right"] == [τ1+1.0 1.0; τ2+1.0 3.0]
            Test.@test size(data["switching_control_left"]) == (2, 1)
            # no structure: no key
            plain = Solutions._serialize_solution(
                _sol(; switching=Solutions.EmptySwitchingModel())
            )
            Test.@test !haskey(plain, "switching_times")
            Test.@test !any(startswith("switching_"), keys(plain))
        end

        Test.@testset "deserialized model" begin
            data = Solutions._serialize_solution(_sol())
            sw = Solutions._deserialize_switching(data)
            Test.@test sw isa Solutions.SwitchingModel
            Test.@test Solutions.limits(sw, :costate) == Solutions.limits(_sw(), :costate)
            Test.@test Solutions._deserialize_switching(Dict{String,Any}()) isa
                Solutions.EmptySwitchingModel
        end

        mktempdir() do dir
            Test.@testset "JLD round trip" begin
                f = joinpath(dir, "sw_jld")
                sol = _sol()
                Serialization.export_ocp_solution(sol; filename=f, format=:JLD)
                back = Serialization.import_ocp_solution(ocp; filename=f, format=:JLD)
                _check_roundtrip(sol, back)
            end

            Test.@testset "JSON round trip" begin
                f = joinpath(dir, "sw_json")
                sol = _sol()
                Serialization.export_ocp_solution(sol; filename=f, format=:JSON)
                back = Serialization.import_ocp_solution(ocp; filename=f, format=:JSON)
                _check_roundtrip(sol, back)
                blob = JSON.parse(read(f * ".json", String))
                Test.@test length(blob["switching_state_left"]) == 2   # one row per τ
            end

            Test.@testset "round trip: labels only, limits not known" begin
                sw = Solutions.SwitchingModel(; times=[τ1], labels=["a", "b"])
                sol = _sol(; switching=sw)
                for fmt in (:JLD, :JSON)
                    f = joinpath(dir, "sw_nolim_$(fmt)")
                    Serialization.export_ocp_solution(sol; filename=f, format=fmt)
                    back = Serialization.import_ocp_solution(ocp; filename=f, format=fmt)
                    Test.@test CTModels.switching_times(back) == [τ1]
                    Test.@test CTModels.phase_labels(back) == ["a", "b"]
                    Test.@test size(
                        Solutions.limits(Solutions.switching_model(back), :state)[1], 2
                    ) == 0
                end
            end

            Test.@testset "round trip: a labelled single phase" begin
                one = Solutions.SwitchingModel(; times=Float64[], labels=["bang"])
                sol = _sol(; switching=one)
                for fmt in (:JLD, :JSON)
                    f = joinpath(dir, "sw_one_$(fmt)")
                    Serialization.export_ocp_solution(sol; filename=f, format=fmt)
                    back = Serialization.import_ocp_solution(ocp; filename=f, format=fmt)
                    Test.@test isempty(CTModels.switching_times(back))
                    Test.@test CTModels.phase_labels(back) == ["bang"]
                end
            end

            Test.@testset "a file without the switching keys loads" begin
                sol = _sol(; switching=Solutions.EmptySwitchingModel())
                for fmt in (:JLD, :JSON)
                    f = joinpath(dir, "sw_none_$(fmt)")
                    Serialization.export_ocp_solution(sol; filename=f, format=fmt)
                    back = Serialization.import_ocp_solution(ocp; filename=f, format=fmt)
                    Test.@test Solutions.switching_model(back) isa
                        Solutions.EmptySwitchingModel
                end
                # an older file: the version-1 data, without switching keys
                data = Solutions._serialize_solution(_sol())
                for k in collect(keys(data))
                    (startswith(k, "switching_") || k == "phase_labels") && delete!(data, k)
                end
                data["format_version"] = 1
                old = Serialization._reconstruct_solution_from_data(ocp, data)
                Test.@test Solutions.switching_model(old) isa Solutions.EmptySwitchingModel
            end
        end
    end
end

end # module

test_switching_serialization() = TestSwitchingSerialization.test_switching_serialization()
