module TestConstraintRows

using Test: Test
using CTBase: Exceptions
using CTModels: Building
using CTModels: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# TOP-LEVEL: constraint functions of the fixture model.
_rows_path2!(r, t, x, u, v) = (r.=x .+ u[1]; nothing)
_rows_path1!(r, t, x, u, v) = (r[1]=u[1]; nothing)
_rows_boundary1!(r, x0, xf, v) = (r[1]=x0[1]; nothing)
_rows_boundary2!(r, x0, xf, v) = (r.=xf; nothing)

# A model whose path and boundary constraints are declared interleaved with each other and
# with the boxes, and whose state component 1 is bounded under two labels (aliases).
function _rows_model()
    pre = Building.PreModel()
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.variable!(pre, 2)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r.=x; nothing))
    Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    Building.definition!(pre, quote end)
    Building.time_dependence!(pre; autonomous=true)
    Building.constraint!(pre, :path; f=_rows_path2!, lb=[0, 0], ub=[1, 1], label=:c2)
    Building.constraint!(pre, :boundary; f=_rows_boundary1!, lb=0, ub=0, label=:b1)
    Building.constraint!(pre, :state; rg=2, lb=-1, ub=1, label=:x2_box)
    Building.constraint!(pre, :path; f=_rows_path1!, lb=-1, ub=1, label=:c1)
    Building.constraint!(
        pre, :boundary; f=_rows_boundary2!, lb=[0, 0], ub=[0, 0], label=:b2
    )
    Building.constraint!(pre, :control; rg=1, lb=-1, ub=1, label=:u_box)
    Building.constraint!(pre, :state; rg=1, lb=0, ub=2, label=:x1_box)
    Building.constraint!(pre, :state; rg=1, lb=0, ub=3, label=:x1_alias)
    Building.constraint!(pre, :variable; rg=1:2, lb=[0, 0], ub=[1, 1], label=:v_box)
    return redirect_stderr(devnull) do # the alias warns: several bounds on x₁
        return Building.build(pre)
    end
end

function test_constraint_rows()
    Test.@testset "constraint_rows" verbose = VERBOSE showtiming = SHOWTIMING begin
        model = _rows_model()

        Test.@testset "path and boundary: rows in the stacked vector" begin
            # rows follow the declaration order of each kind, whatever the interleaving
            Test.@test Models.constraint_rows(model, :c2) == (:path, [1, 2])
            Test.@test Models.constraint_rows(model, :c1) == (:path, [3])
            Test.@test Models.constraint_rows(model, :b1) == (:boundary, [1])
            Test.@test Models.constraint_rows(model, :b2) == (:boundary, [2, 3])
        end

        Test.@testset "boxes: bounded components" begin
            Test.@test Models.constraint_rows(model, :x2_box) == (:state, [2])
            Test.@test Models.constraint_rows(model, :x1_box) == (:state, [1])
            Test.@test Models.constraint_rows(model, :x1_alias) == (:state, [1])
            Test.@test Models.constraint_rows(model, :u_box) == (:control, [1])
            Test.@test Models.constraint_rows(model, :v_box) == (:variable, [1, 2])
        end

        Test.@testset "consistent with constraint" begin
            for label in (:c2, :c1, :b1, :b2, :x2_box, :x1_alias, :u_box, :v_box)
                Test.@test Models.constraint_rows(model, label)[1] ==
                    Models.constraint(model, label)[1]
            end
        end

        Test.@testset "unknown label" begin
            Test.@test_throws Exceptions.IncorrectArgument Models.constraint_rows(
                model, :nope
            )
        end

        Test.@testset "type stability" begin
            Test.@test (Test.@inferred Models.constraint_rows(model, :c1)) == (:path, [3])
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_constraint_rows() = TestConstraintRows.test_constraint_rows()
