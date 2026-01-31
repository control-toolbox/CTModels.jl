module TestOCPDualModel

using Test
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_dual_model()
    # TODO: add tests for src/ocp/dual_model.jl.

    # ========================================================================
    # Unit tests – low-level DualModel accessors
    # ========================================================================

    Test.@testset "DualModel constraint dual accessors" verbose=VERBOSE showtiming=SHOWTIMING begin
        pc = t -> [1.0, 2.0]
        bc = [3.0, 4.0]
        sc_lb = t -> [0.0]
        sc_ub = t -> [1.0]
        cc_lb = t -> [0.0]
        cc_ub = t -> [1.0]
        vc_lb = [5.0]
        vc_ub = [6.0]

        dual = CTModels.DualModel(pc, bc, sc_lb, sc_ub, cc_lb, cc_ub, vc_lb, vc_ub)

        Test.@test CTModels.path_constraints_dual(dual) === pc
        Test.@test CTModels.boundary_constraints_dual(dual) === bc
        Test.@test CTModels.state_constraints_lb_dual(dual) === sc_lb
        Test.@test CTModels.state_constraints_ub_dual(dual) === sc_ub
        Test.@test CTModels.control_constraints_lb_dual(dual) === cc_lb
        Test.@test CTModels.control_constraints_ub_dual(dual) === cc_ub
        Test.@test CTModels.variable_constraints_lb_dual(dual) === vc_lb
        Test.@test CTModels.variable_constraints_ub_dual(dual) === vc_ub
    end
end

end # module

test_dual_model() = TestOCPDualModel.test_dual_model()
