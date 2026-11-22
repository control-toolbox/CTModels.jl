module TestUnnamedLabels

# =============================================================================
# Unit tests for the labels generated for unnamed constraints (issue #526):
# `Models.is_unnamed_label` recognises them, whatever their prefix (`gensym(:unnamed)`
# from CTModels, `label##N` from CTParser), and the model signature ignores them.
# =============================================================================

using Test: Test
using CTModels: Building
using CTModels: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# TOP-LEVEL: constraint function of the fixture model.
_unnamed_path!(r, t, x, u, v) = (r[1]=x[1] + u[1]; nothing)

# A model with a named path constraint `:g` and three unnamed constraints: a path
# constraint and a state box with the default label of CTModels, and a control box with a
# label generated as CTParser does (`gensym(Symbol("label"))`, i.e. `label##N`).
function _unnamed_model()
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r.=x; nothing))
    Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    Building.definition!(pre, quote end)
    Building.time_dependence!(pre; autonomous=true)
    Building.constraint!(pre, :path; f=_unnamed_path!, lb=-1, ub=1, label=:g)
    Building.constraint!(pre, :path; f=_unnamed_path!, lb=-2, ub=2)
    Building.constraint!(pre, :state; rg=2, lb=-1, ub=1)
    Building.constraint!(pre, :control; rg=1, lb=-1, ub=1, label=gensym(:label))
    return Building.build(pre)
end

function test_unnamed_labels()
    Test.@testset "Unnamed constraint labels (issue #526)" verbose = VERBOSE showtiming =
        SHOWTIMING begin

        # ==================================================================
        # UNIT: the predicate
        # ==================================================================
        Test.@testset "is_unnamed_label" begin
            Test.@testset "generated labels" begin
                Test.@test Models.is_unnamed_label(gensym(:unnamed))
                Test.@test Models.is_unnamed_label(Building.__constraint_label())
                Test.@test Models.is_unnamed_label(gensym(:label))     # CTParser
                Test.@test Models.is_unnamed_label(Symbol("label##288"))
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
        # UNIT: labels in the model signature
        # ==================================================================
        Test.@testset "_label_strings maps generated labels to the empty string" begin
            labels = [:g, gensym(:unnamed), Symbol("label##288"), :u_box]
            Test.@test Models._label_strings(labels) == ["g", "", "", "u_box"]
        end

        # ==================================================================
        # NON-REGRESSION: two instances of a model have the same signature
        # ==================================================================
        Test.@testset "the signature ignores generated labels" begin
            ocp1, ocp2 = _unnamed_model(), _unnamed_model()
            # the generated labels differ from one instance to the other
            Test.@test Models.path_constraints_nl(ocp1)[4] !=
                Models.path_constraints_nl(ocp2)[4]
            Test.@test Models.control_constraints_box(ocp1)[4] !=
                Models.control_constraints_box(ocp2)[4]
            sig1, sig2 = Models._model_signature(ocp1), Models._model_signature(ocp2)
            Test.@test sig1 == sig2
            Test.@test sig1["labels_path_nl"] == ["g", ""]
            Test.@test sig1["labels_state_box"] == [""]
            Test.@test sig1["labels_control_box"] == [""]
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_unnamed_labels() = TestUnnamedLabels.test_unnamed_labels()
