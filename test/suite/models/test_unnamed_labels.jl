module TestUnnamedLabels

# =============================================================================
# Unit tests for the labels generated for unnamed constraints (issue #526):
# `Models.is_unnamed_label` recognises them, whatever their prefix (`gensym(:unnamed)`
# from CTModels, `label##N` from CTParser), the model signature ignores them, and the
# messages describe an unnamed constraint by what is known of it, never by its label.
# =============================================================================

using Test: Test
using CTBase: Exceptions
using CTModels: Building
using CTModels: Models
using CTModels: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# TOP-LEVEL: constraint functions of the fixture model.
_unnamed_path1!(r, t, x, u, v) = (r[1]=x[1] + u[1]; nothing)
_unnamed_path2!(r, t, x, u, v) = (r.=x; nothing)
_unnamed_boundary!(r, x0, xf, v) = (r[1]=x0[1]; nothing)

# A model with a named path constraint `:g` (row 1) and unnamed constraints of every kind:
# a two-row path constraint (rows 2:3), a boundary constraint, two boxes on x₂ (the second
# one an alias of the first), a box on (v₁, v₂), all with the default label of CTModels,
# and a control box with a label generated as CTParser does (`gensym(:label)`, i.e.
# `label##N`).
function _unnamed_model()
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.variable!(pre, 2)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r.=x; nothing))
    Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    Building.definition!(pre, quote end)
    Building.time_dependence!(pre; autonomous=true)
    Building.constraint!(pre, :path; f=_unnamed_path1!, lb=-1, ub=1, label=:g)
    Building.constraint!(pre, :path; f=_unnamed_path2!, lb=[-2, -2], ub=[2, 2])
    Building.constraint!(pre, :boundary; f=_unnamed_boundary!, lb=0, ub=0)
    Building.constraint!(pre, :state; rg=2, lb=-1, ub=1)
    Building.constraint!(pre, :state; rg=2, lb=-2, ub=2)
    Building.constraint!(pre, :control; rg=1, lb=-1, ub=1, label=gensym(:label))
    Building.constraint!(pre, :variable; rg=1:2, lb=[0, 0], ub=[1, 1])
    return redirect_stderr(devnull) do # the alias warns: several bounds on x₂
        return Building.build(pre)
    end
end

# The generated labels of `_unnamed_model()`, by kind.
function _unnamed_labels(ocp)
    return (
        path=Models.path_constraints_nl(ocp)[4][2],
        boundary=only(Models.boundary_constraints_nl(ocp)[4]),
        state=only(Models.state_constraints_box(ocp)[5]),          # (first, alias)
        control=only(Models.control_constraints_box(ocp)[4]),
        variable=first(Models.variable_constraints_box(ocp)[4]),
    )
end

const _N = 5
const _T = collect(range(0.0, 1.0; length=_N))

# A solution of `_unnamed_model()` with the duals `duals` given by label.
function _unnamed_solution(ocp, duals; kwargs...)
    return Solutions.build_solution(
        ocp,
        _T,
        zeros(_N, 2),
        zeros(_N, 1),
        zeros(2),
        zeros(_N, 2);
        objective=0.0,
        successful=true,
        duals=duals,
        kwargs...,
    )
end

# The message of the exception thrown by `f`, which must be an `IncorrectArgument`.
function _message(f)
    err = try
        f()
        nothing
    catch e
        e
    end
    Test.@test err isa Exceptions.IncorrectArgument
    return sprint(showerror, err)
end

function test_unnamed_labels()
    Test.@testset "Unnamed constraint labels (issue #526)" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        ocp = _unnamed_model()
        labels = _unnamed_labels(ocp)

        # ==================================================================
        # UNIT: the predicate
        # ==================================================================
        Test.@testset "is_unnamed_label" begin
            Test.@testset "generated labels" begin
                Test.@test Models.is_unnamed_label(gensym(:unnamed))
                Test.@test Models.is_unnamed_label(Building.__constraint_label())
                Test.@test Models.is_unnamed_label(gensym(:label))     # CTParser
                Test.@test Models.is_unnamed_label(Symbol("label##288"))
                Test.@test all(Models.is_unnamed_label, labels.state)
            end

            Test.@testset "labels given by the user" begin
                for label in (:u_box, :c1, :x₂_box, :unnamed, :label, Symbol("a#b"))
                    Test.@test !Models.is_unnamed_label(label)
                end
            end

            Test.@testset "type stability" begin
                Test.@test (Test.@inferred Models.is_unnamed_label(:u_box)) === false
            end
        end

        # ==================================================================
        # UNIT: the description of a constraint in a message
        # ==================================================================
        Test.@testset "_describe_constraint" begin
            describe(label) = Models._describe_constraint(ocp, label)
            Test.@testset "a labelled constraint: kind and label" begin
                Test.@test describe(:g) == "path constraint :g"
            end

            Test.@testset "an unnamed constraint: kind and what is known" begin
                Test.@test describe(labels.path) == "unnamed path constraint (rows 2:3)"
                Test.@test describe(labels.boundary) ==
                    "unnamed boundary constraint (row 1)"
                Test.@test describe(labels.state[1]) == "unnamed state box on x₂"
                Test.@test describe(labels.state[2]) == "unnamed state box on x₂"
                Test.@test describe(labels.control) == "unnamed control box on u"
                Test.@test describe(labels.variable) == "unnamed variable box on v₁, v₂"
            end

            Test.@testset "unknown label" begin
                Test.@test_throws Exceptions.IncorrectArgument describe(:nope)
            end

            Test.@testset "type stability" begin
                Test.@test (Test.@inferred Models._describe_constraint(
                    ocp, labels.control
                )) == "unnamed control box on u"
            end
        end

        # ==================================================================
        # UNIT: labels in the model signature
        # ==================================================================
        Test.@testset "_label_strings maps generated labels to the empty string" begin
            ls = [:g, gensym(:unnamed), Symbol("label##288"), :u_box]
            Test.@test Models._label_strings(ls) == ["g", "", "", "u_box"]
            # the labels read from a file are strings
            Test.@test Models._label_strings(["g", "label##288"]) == ["g", ""]
        end

        # ==================================================================
        # NON-REGRESSION: two instances of a model have the same signature
        # ==================================================================
        Test.@testset "the signature ignores generated labels" begin
            other = _unnamed_model()
            # the generated labels differ from one instance to the other
            Test.@test Models.path_constraints_nl(ocp)[4] !=
                Models.path_constraints_nl(other)[4]
            Test.@test Models.control_constraints_box(ocp)[4] !=
                Models.control_constraints_box(other)[4]
            sig = Models._model_signature(ocp)
            Test.@test sig == Models._model_signature(other)
            Test.@test sig["labels_path_nl"] == ["g", "", ""]
            Test.@test sig["labels_boundary_nl"] == [""]
            Test.@test sig["labels_state_box"] == [""]
            Test.@test sig["labels_control_box"] == [""]
            Test.@test sig["labels_variable_box"] == ["", ""]
        end

        # ==================================================================
        # build_solution: the messages never show a generated label
        # ==================================================================
        Test.@testset "messages of build_solution" begin
            bad(duals; kw...) = () -> _unnamed_solution(ocp, duals; kw...)
            nolabel(msg) = !occursin("##", msg)

            Test.@testset "a labelled constraint keeps its label" begin
                msg = _message(bad(Dict(:g => zeros(_N, 2))))
                Test.@test occursin("dual size mismatch for the path constraint :g", msg)
                Test.@test occursin("constraint_rows(model, :g)", msg)
            end

            Test.@testset "size of the dual of an unnamed path constraint" begin
                msg = _message(bad(Dict(labels.path => zeros(_N, 1))))
                Test.@test nolabel(msg)
                Test.@test occursin("unnamed path constraint (rows 2:3)", msg)
                # no call to suggest: a generated label is no valid symbol literal
                Test.@test !occursin("constraint_rows", msg)
            end

            Test.@testset "type of the dual of an unnamed box or boundary constraint" begin
                msg = _message(bad(Dict{Symbol,Any}(labels.control => "dual")))
                Test.@test nolabel(msg)
                Test.@test occursin("invalid dual for the unnamed control box on u", msg)
                msg = _message(bad(Dict{Symbol,Any}(labels.boundary => "dual")))
                Test.@test nolabel(msg)
                Test.@test occursin("unnamed boundary constraint (row 1)", msg)
            end

            Test.@testset "one component given by two unnamed boxes" begin
                msg = _message(
                    bad(Dict{Symbol,Any}(labels.state[1] => _T, labels.state[2] => _T))
                )
                Test.@test nolabel(msg)
                Test.@test occursin("the unnamed state box on x₂ and the unnamed", msg)
            end

            Test.@testset "limits at a switching time" begin
                sw(duals) =
                    Solutions.SwitchingModel(; times=[0.5], labels=["a", "b"], duals=duals)
                # no model is known to the switching model: the constraint is unnamed
                msg = _message(
                    () -> sw(Dict(labels.path => ([0.0 0.0; 1.0 1.0], [0.0 0.0])))
                )
                Test.@test nolabel(msg)
                Test.@test occursin("unnamed constraint dual", msg)
                # no limits for a boundary constraint
                limits = Dict(labels.boundary => ([0.0], [0.0]))
                msg = _message(bad(Dict{Symbol,Any}(); switching=sw(limits)))
                Test.@test nolabel(msg)
                Test.@test occursin(
                    "limits of the unnamed boundary constraint (row 1)", msg
                )
                # the limits of an unnamed path constraint with a wrong number of columns
                limits = Dict(labels.path => ([0.0], [1.0]))
                msg = _message(bad(Dict{Symbol,Any}(); switching=sw(limits)))
                Test.@test nolabel(msg)
                Test.@test occursin("unnamed path constraint (rows 2:3)", msg)
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_unnamed_labels() = TestUnnamedLabels.test_unnamed_labels()
