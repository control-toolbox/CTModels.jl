module TestOCPEmptyDualModel

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Building: Building
import CTModels.Models: Models
import CTModels.Solutions: Solutions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Top-level helper: build a minimal Model with a boundary constraint so that the
# solution's model declares constraints, yet the solution itself carries no duals.
function _build_model_with_boundary()
    ocp = Building.PreModel()
    Building.time!(ocp; t0=0.0, tf=1.0)
    Building.state!(ocp, 2)
    Building.control!(ocp, 1)
    _dyn!(r, t, x, u, v) = (r .= zero(x))
    Building.dynamics!(ocp, _dyn!)
    Building.objective!(ocp, :min; mayer=(x0, xf, v) -> 0.0)
    _bc!(r, x0, xf, v) = (r .= x0)
    Building.constraint!(ocp, :boundary; f=_bc!, lb=[0.0, 0.0], ub=[0.0, 0.0], label=:bc)
    Building.definition!(ocp, quote end)
    Building.time_dependence!(ocp; autonomous=false)
    return Building.build(ocp)
end

# Build a Solution without any dual variable (the flow-like path).
function _make_dualfree_solution(m::Models.Model; state_dim::Int=2, control_dim::Int=1)
    T = [0.0, 0.5, 1.0]
    X = zeros(3, state_dim)
    U = zeros(3, control_dim)
    P = zeros(3, state_dim)
    v = Float64[]
    return Solutions.build_solution(
        m, T, X, U, v, P;
        objective=0.0,
        iterations=0,
        constraints_violation=0.0,
        message="",
        status=:optimal,
        successful=true,
    )
end

function test_empty_dual_model()
    Test.@testset "Empty Dual Model Tests" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # Sentinel construction and trait
        # ====================================================================
        Test.@testset "EmptyDualModel sentinel and has_duals trait" begin
            edm = Solutions.EmptyDualModel()
            Test.@test edm isa Solutions.AbstractDualModel
            Test.@test !Solutions.has_duals(edm)

            # a non-empty DualModel reports has_duals == true, even if all-nothing
            dm = Solutions.DualModel(
                nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing
            )
            Test.@test Solutions.has_duals(dm)
        end

        # ====================================================================
        # Accessors return nothing for the sentinel
        # ====================================================================
        Test.@testset "EmptyDualModel accessors return nothing" begin
            edm = Solutions.EmptyDualModel()
            Test.@test Solutions.path_constraints_dual(edm) === nothing
            Test.@test Solutions.boundary_constraints_dual(edm) === nothing
            Test.@test Solutions.state_constraints_lb_dual(edm) === nothing
            Test.@test Solutions.state_constraints_ub_dual(edm) === nothing
            Test.@test Solutions.control_constraints_lb_dual(edm) === nothing
            Test.@test Solutions.control_constraints_ub_dual(edm) === nothing
            Test.@test Solutions.variable_constraints_lb_dual(edm) === nothing
            Test.@test Solutions.variable_constraints_ub_dual(edm) === nothing
        end

        # ====================================================================
        # build_solution with no duals yields the sentinel
        # ====================================================================
        Test.@testset "build_solution without duals yields EmptyDualModel" begin
            m = _build_model_with_boundary()
            sol = _make_dualfree_solution(m)

            Test.@test Solutions.dual_model(sol) isa Solutions.EmptyDualModel
            Test.@test !Solutions.has_duals(sol)

            # Solution-level dual accessors delegate to nothing
            Test.@test Solutions.path_constraints_dual(sol) === nothing
            Test.@test Solutions.boundary_constraints_dual(sol) === nothing
            Test.@test Solutions.variable_constraints_lb_dual(sol) === nothing
        end

        # ====================================================================
        # dual(sol, model, label) throws on a dual-free solution
        # ====================================================================
        Test.@testset "dual() on dual-free solution → PreconditionError" begin
            m = _build_model_with_boundary()
            sol = _make_dualfree_solution(m)
            Test.@test_throws Exceptions.PreconditionError Solutions.dual(sol, m, :bc)
        end

        # ====================================================================
        # show prints cleanly (no dual blocks) for a dual-free solution
        # ====================================================================
        Test.@testset "show of a dual-free solution" begin
            m = _build_model_with_boundary()
            sol = _make_dualfree_solution(m)
            str = repr(MIME("text/plain"), sol)
            Test.@test str isa String
            Test.@test occursin("Solver", str)
            # the model has boundary constraints but the solution carries no duals,
            # so the boundary-duals block must not appear
            Test.@test !occursin("Boundary duals", str)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_empty_dual_model() = TestOCPEmptyDualModel.test_empty_dual_model()
