module TestImportModelMismatch

using Test: Test
using JLD2: JLD2
using JSON3: JSON3
using CTBase: Exceptions
using CTModels: Building
using CTModels: Models
using CTModels: Solutions
using CTModels: Serialization

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const _N = 5

# Configurable model: every keyword is one axis along which a file can differ from the
# model passed to `import_ocp_solution` (https://github.com/control-toolbox/CTModels.jl/issues/435).
function _model(;
    n::Int=1,
    m::Int=1,
    nv::Int=0,
    t0::Float64=0.0,
    tf::Float64=1.0,
    free_tf::Bool=false,
    xname::String="x",
    uname::String="u",
    vname::String="v",
    tname::String="t",
    path::Bool=true,
    boundary::Bool=true,
    path_label::Symbol=:pc,
    boundary_label::Symbol=:bc,
    criterion::Symbol=:min,
)
    pre = Building.PreModel()
    nv > 0 && Building.variable!(pre, nv, vname)
    if free_tf
        Building.time!(pre; t0=t0, indf=1, time_name=tname)
    else
        Building.time!(pre; t0=t0, tf=tf, time_name=tname)
    end
    Building.state!(pre, n, xname)
    m > 0 && Building.control!(pre, m, uname)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r .= 0.0))
    Building.objective!(pre, criterion; lagrange=(t, x, u, v) -> 0.0)
    path && Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r[1] = x[1]), lb=[-1.0], ub=[1.0], label=path_label
    )
    boundary && Building.constraint!(
        pre, :boundary; f=(r, x0, xf, v) -> (r[1] = x0[1]), lb=[0.0], ub=[0.0], label=boundary_label
    )
    Building.constraint!(pre, :state; rg=1:1, lb=[-5.0], ub=[5.0], label=:sb)
    Building.definition!(pre, quote end)
    Building.time_dependence!(pre; autonomous=false)
    return Building.build(pre)
end

function _solution(ocp)
    n = Models.state_dimension(ocp)
    m = Models.control_dimension(ocp)
    nv = Models.variable_dimension(ocp)
    np = Models.dim_path_constraints_nl(ocp)
    nb = Models.dim_boundary_constraints_nl(ocp)
    T = collect(range(0.0, 1.0, _N))
    return Solutions.build_solution(
        ocp,
        T,
        zeros(_N, n),
        zeros(_N, m),
        ones(nv),
        zeros(_N, n);
        objective=0.0,
        iterations=1,
        constraints_violation=0.0,
        message="",
        status=:optimal,
        successful=true,
        path_constraints_dual=np > 0 ? zeros(_N, np) : nothing,
        boundary_constraints_dual=nb > 0 ? zeros(nb) : nothing,
        state_constraints_lb_dual=zeros(_N, n),
        state_constraints_ub_dual=zeros(_N, n),
    )
end

_ext(fmt) = fmt == :JLD ? ".jld2" : ".json"

function _export(sol, fmt, dir; name="sol")
    filename = joinpath(dir, name)
    Serialization.export_ocp_solution(sol; filename=filename, format=fmt)
    return filename
end

# Simulate a file exported before the model signature existed.
function _strip_signature(fmt, filename)
    path = filename * _ext(fmt)
    if fmt == :JLD
        data = JLD2.load(path)["solution_data"]
        delete!(data, "model_signature")
        delete!(data, "format_version")
        JLD2.jldsave(path; solution_data=data)
    else
        blob = JSON3.read(read(path, String), Dict{String,Any})
        delete!(blob, "model_signature")
        delete!(blob, "format_version")
        open(io -> JSON3.write(io, blob), path, "w")
    end
    return nothing
end

function _import(ocp, fmt, filename)
    return Serialization.import_ocp_solution(ocp; filename=filename, format=fmt)
end

function _caught(f)
    try
        f()
    catch e
        return e
    end
    return nothing
end

function test_import_model_mismatch()
    Test.@testset "Import with a model that does not match the file" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ==================================================================
        # UNIT: validation on serialized data (no I/O)
        # ==================================================================
        Test.@testset "Unit: _validate_solution_against_model" begin
            ocp = _model()
            data = Solutions._serialize_solution(_solution(ocp))
            validate = Serialization._validate_solution_against_model

            Test.@testset "serialized data carries the signature" begin
                Test.@test haskey(data, "format_version")
                sig = data["model_signature"]
                Test.@test sig["dim_x"] == 1
                Test.@test sig["dim_u"] == 1
                Test.@test sig["dim_v"] == 0
                Test.@test sig["dim_path_nl"] == 1
                Test.@test sig["dim_boundary_nl"] == 1
                Test.@test sig["state_name"] == "x"
                Test.@test sig["criterion"] == "min"
                Test.@test sig["fixed_initial_time"] && sig["fixed_final_time"]
                Test.@test sig["initial_time"] == 0.0 && sig["final_time"] == 1.0
            end

            Test.@testset "same model: silent" begin
                Test.@test_logs validate(ocp, data)
            end

            Test.@testset "dimensions: error (signature present)" begin
                for (kw, key) in (
                    (:n, "state dimension"),
                    (:m, "control dimension"),
                    (:nv, "variable dimension"),
                )
                    other = _model(; kw => 2)
                    err = _caught(() -> validate(other, data))
                    Test.@test err isa Exceptions.IncorrectArgument
                    Test.@test occursin(key, err.got)
                    Test.@test occursin(key, err.expected)
                    Test.@test occursin("solution was computed from", err.suggestion)
                end
            end

            Test.@testset "dimensions: error (no signature)" begin
                legacy = filter(p -> p.first ∉ ("model_signature", "format_version"), data)
                for (kw, key) in ((:n, "state dimension"), (:m, "control dimension"))
                    err = _caught(() -> validate(_model(; kw => 2), legacy))
                    Test.@test err isa Exceptions.IncorrectArgument
                    Test.@test occursin(key, err.got)
                end
                err = _caught(() -> validate(_model(; nv=2), legacy))
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("variable dimension", err.got)
                err = _caught(() -> validate(_model(; path=false), legacy))
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("path constraints", err.got)
                err = _caught(() -> validate(_model(; boundary=false), legacy))
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("boundary constraints", err.got)
                Test.@test_logs (:info, r"older") validate(ocp, legacy)
            end

            Test.@testset "all differences are reported at once" begin
                err = _caught(() -> validate(_model(; n=2, m=2), data))
                Test.@test occursin("state dimension", err.got)
                Test.@test occursin("control dimension", err.got)
            end

            Test.@testset "constraint counts and labels: error (signature)" begin
                err = _caught(() -> validate(_model(; path=false), data))
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("path constraints", err.got)
                err = _caught(() -> validate(_model(; path_label=:other), data))
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("path constraint labels", err.got)
                err = _caught(() -> validate(_model(; boundary_label=:other), data))
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("boundary constraint labels", err.got)
            end

            Test.@testset "fixed vs free time: error" begin
                fixed = Solutions._serialize_solution(_solution(_model(; nv=1)))
                free = Solutions._serialize_solution(
                    _solution(_model(; nv=1, free_tf=true))
                )
                err = _caught(() -> validate(_model(; nv=1, free_tf=true), fixed))
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("final time", err.got)
                err = _caught(() -> validate(_model(; nv=1), free))
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("final time", err.got)
            end

            Test.@testset "names, criterion, fixed time values: warning" begin
                Test.@test_logs (:warn, r"state name") validate(_model(; xname="y"), data)
                Test.@test_logs (:warn, r"control name") validate(_model(; uname="w"), data)
                Test.@test_logs (:warn, r"time name") validate(_model(; tname="s"), data)
                Test.@test_logs (:warn, r"criterion") validate(
                    _model(; criterion=:max), data
                )
                Test.@test_logs (:warn, r"final time") validate(_model(; tf=2.0), data)
                Test.@test_logs (:warn, r"initial time") validate(_model(; t0=-1.0), data)
            end

            Test.@testset "fixed time values: warning (no signature)" begin
                legacy = filter(p -> p.first ∉ ("model_signature", "format_version"), data)
                Test.@test_logs (:info, r"older") (:warn, r"final time") validate(
                    _model(; tf=2.0), legacy
                )
            end

            Test.@testset "corrupted data: error" begin
                bad = copy(data)
                bad["state"] = zeros(_N + 3, 1)
                err = _caught(() -> validate(ocp, bad))
                Test.@test err isa Exceptions.IncorrectArgument
                Test.@test occursin("state", err.got)
            end
        end

        # ==================================================================
        # build_solution: inputs that used to be accepted silently
        # ==================================================================
        Test.@testset "build_solution rejects inconsistent sizes" begin
            ocp = _model(; nv=1)
            T = collect(range(0.0, 1.0, _N))
            build(; v=[1.0], kwargs...) = Solutions.build_solution(
                ocp,
                T,
                zeros(_N, 1),
                zeros(_N, 1),
                v,
                zeros(_N, 1);
                objective=0.0,
                iterations=1,
                constraints_violation=0.0,
                message="",
                status=:optimal,
                successful=true,
                kwargs...,
            )
            Test.@test build() isa Solutions.Solution
            Test.@test_throws Exceptions.IncorrectArgument build(; v=[1.0, 2.0])
            Test.@test_throws Exceptions.IncorrectArgument build(; v=Float64[])
            Test.@test_throws Exceptions.IncorrectArgument build(;
                path_constraints_dual=zeros(_N, 3)
            )
            Test.@test_throws Exceptions.IncorrectArgument build(;
                boundary_constraints_dual=zeros(2)
            )
            err = _caught(() -> build(; path_constraints_dual=zeros(_N, 3)))
            Test.@test occursin("model", err.suggestion)
        end

        # ==================================================================
        # INTEGRATION: JLD and JSON round trips
        # ==================================================================
        for fmt in (:JLD, :JSON)
            Test.@testset "Round trip ($fmt)" begin
                mktempdir() do dir
                    ocp = _model(; nv=1)
                    sol = _solution(ocp)
                    filename = _export(sol, fmt, dir)

                    Test.@testset "same model: no log" begin
                        Test.@test_logs _import(ocp, fmt, filename)
                    end

                    Test.@testset "issue #435: 2D state file, 1D state model" begin
                        big = _model(; n=2, nv=1)
                        fbig = _export(_solution(big), fmt, dir; name="big")
                        err = _caught(() -> _import(_model(; nv=1), fmt, fbig))
                        Test.@test err isa Exceptions.IncorrectArgument
                        Test.@test occursin("state dimension", err.got)
                        Test.@test occursin("solution was computed from", err.suggestion)
                        Test.@test !occursin("pad with zeros", err.suggestion)
                    end

                    Test.@testset "label and count differences" begin
                        Test.@test_throws Exceptions.IncorrectArgument _import(
                            _model(; nv=1, path_label=:other), fmt, filename
                        )
                        Test.@test_throws Exceptions.IncorrectArgument _import(
                            _model(; nv=1, path=false), fmt, filename
                        )
                    end

                    Test.@testset "time structure" begin
                        Test.@test_throws Exceptions.IncorrectArgument _import(
                            _model(; nv=1, free_tf=true), fmt, filename
                        )
                        Test.@test_logs (:warn, r"final time") _import(
                            _model(; nv=1, tf=2.0), fmt, filename
                        )
                    end

                    Test.@testset "names: warning, solution still usable" begin
                        sol2 = Test.@test_logs (:warn, r"state name") _import(
                            _model(; nv=1, xname="y"), fmt, filename
                        )
                        Test.@test sol2 isa Solutions.Solution
                    end

                    Test.@testset "old file without signature" begin
                        old = _export(sol, fmt, dir; name="old")
                        _strip_signature(fmt, old)
                        Test.@test_logs (:info, r"older") _import(ocp, fmt, old)
                        Test.@test_throws Exceptions.IncorrectArgument _import(
                            _model(; n=2, nv=1), fmt, old
                        )
                    end
                end
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_import_model_mismatch() = TestImportModelMismatch.test_import_model_mismatch()
