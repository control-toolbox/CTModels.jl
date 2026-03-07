module TestOCPModel

import Test
import CTBase.Exceptions
import CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_model()
    Test.@testset "Model Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for model functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Model Building
        # ====================================================================

        # create a pre-model
        pre_ocp = CTModels.PreModel()

        # exception: times must be set
        Test.@test_throws Exceptions.PreconditionError CTModels.build(pre_ocp)

        # set times
        CTModels.time!(pre_ocp; t0=0.0, tf=1.0)

        # exception: state must be set
        Test.@test_throws Exceptions.PreconditionError CTModels.build(pre_ocp)

        # set state
        CTModels.state!(pre_ocp, 2)

        # exception: control must be set
        Test.@test_throws Exceptions.PreconditionError CTModels.build(pre_ocp)

        # set control
        CTModels.control!(pre_ocp, 2)

        # set variable
        CTModels.variable!(pre_ocp, 2)

        # exception: dynamics must be set
        Test.@test_throws Exceptions.PreconditionError CTModels.build(pre_ocp)

        # set dynamics
        dynamics!(r, t, x, u, v) = r .= t .+ x .+ u .+ v
        CTModels.dynamics!(pre_ocp, dynamics!)

        # exception: objective must be set
        Test.@test_throws Exceptions.PreconditionError CTModels.build(pre_ocp)

        # set objective
        mayer(x0, xf, v) = x0 .+ xf .+ v
        lagrange(t, x, u, v) = t .+ x .+ u .+ v
        CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)

        # exception: definition must be set
        Test.@test_throws Exceptions.PreconditionError CTModels.build(pre_ocp)

        # set definition
        definition = quote
            t ∈ [0, 1], time
            x ∈ R², state
            u ∈ R, control
            x(0) == [-1, 0]
            x(1) == [0, 0]
            ẋ(t) == [x₂(t), u(t)]
            ∫(0.5u(t)^2) → min
        end
        CTModels.definition!(pre_ocp, definition)

        # exception: time dependence must be set
        Test.@test_throws Exceptions.PreconditionError CTModels.build(pre_ocp)

        # set time dependence
        CTModels.time_dependence!(pre_ocp; autonomous=false)

        # set some constraints
        f_path(r, t, x, u, v) = r .= x .+ u .+ v .+ t
        f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)

        CTModels.constraint!(pre_ocp, :path; f=f_path, lb=[-0, -1], ub=[1, 2], label=:path)
        CTModels.constraint!(
            pre_ocp, :boundary; f=f_boundary, lb=[-2, -3], ub=[3, 4], label=:boundary
        )
        CTModels.constraint!(pre_ocp, :state; rg=1:2, lb=[-4, -5], ub=[5, 6], label=:state)
        CTModels.constraint!(
            pre_ocp, :control; rg=1:2, lb=[-6, -7], ub=[7, 8], label=:control
        )
        CTModels.constraint!(
            pre_ocp, :variable; rg=1:2, lb=[-8, -9], ub=[9, 10], label=:variable
        )

        f_path_scalar(r, t, x, u, v) = r .= x[1] + u[1] + v[1] + t
        f_boundary_scalar(r, x0, xf, v) = r .= x0[1] + v[1] * (xf[1] - x0[1])
        CTModels.constraint!(
            pre_ocp, :path; f=f_path_scalar, lb=-10, ub=11, label=:path_scalar
        )
        CTModels.constraint!(
            pre_ocp, :boundary; f=f_boundary_scalar, lb=-11, ub=12, label=:boundary_scalar
        )
        CTModels.constraint!(pre_ocp, :state; rg=1, lb=-12, ub=13, label=:state_scalar)
        CTModels.constraint!(pre_ocp, :control; rg=1, lb=-13, ub=14, label=:control_scalar)
        CTModels.constraint!(
            pre_ocp, :variable; rg=1, lb=-14, ub=15, label=:variable_scalar
        )
        CTModels.constraint!(pre_ocp, :state; rg=2, lb=-15, ub=16, label=:state_scalar_2)
        CTModels.constraint!(
            pre_ocp, :control; rg=2, lb=-16, ub=17, label=:control_scalar_2
        )
        CTModels.constraint!(
            pre_ocp, :variable; rg=2, lb=-17, ub=18, label=:variable_scalar_2
        )

        # build the model
        model = CTModels.build(pre_ocp)

        # check the type of the model
        Test.@test model isa CTModels.Model

        # check retrieved constraints
        t = 1
        x = [2, 3]
        u = [4, 5]
        v = [6, 7]
        x0 = [1, 2]
        xf = [3, 4]

        # test the functions
        Test.@test CTModels.constraint(model, :path)[2](t, x, u, v) == x .+ u .+ v .+ t
        Test.@test CTModels.constraint(model, :boundary)[2](x0, xf, v) == x0 .+ v .* (xf .- x0)
        Test.@test CTModels.constraint(model, :state)[2](t, x, u, v) == x
        Test.@test CTModels.constraint(model, :control)[2](t, x, u, v) == u
        Test.@test CTModels.constraint(model, :variable)[2](x0, xf, v) == v
        Test.@test CTModels.constraint(model, :path_scalar)[2](t, x, u, v) ==
            x[1] + u[1] + v[1] + t
        Test.@test CTModels.constraint(model, :boundary_scalar)[2](x0, xf, v) ==
            x0[1] + v[1] * (xf[1] - x0[1])
        Test.@test CTModels.constraint(model, :state_scalar)[2](t, x, u, v) == x[1]
        Test.@test CTModels.constraint(model, :control_scalar)[2](t, x, u, v) == u[1]
        Test.@test CTModels.constraint(model, :variable_scalar)[2](x0, xf, v) == v[1]
        Test.@test CTModels.constraint(model, :state_scalar_2)[2](t, x, u, v) == x[2]
        Test.@test CTModels.constraint(model, :control_scalar_2)[2](t, x, u, v) == u[2]
        Test.@test CTModels.constraint(model, :variable_scalar_2)[2](x0, xf, v) == v[2]

        # test the type of the constraints
        Test.@test CTModels.constraint(model, :path)[1] == :path
        Test.@test CTModels.constraint(model, :boundary)[1] == :boundary
        Test.@test CTModels.constraint(model, :state)[1] == :state
        Test.@test CTModels.constraint(model, :control)[1] == :control
        Test.@test CTModels.constraint(model, :variable)[1] == :variable
        Test.@test CTModels.constraint(model, :path_scalar)[1] == :path
        Test.@test CTModels.constraint(model, :boundary_scalar)[1] == :boundary
        Test.@test CTModels.constraint(model, :state_scalar)[1] == :state
        Test.@test CTModels.constraint(model, :control_scalar)[1] == :control
        Test.@test CTModels.constraint(model, :variable_scalar)[1] == :variable
        Test.@test CTModels.constraint(model, :state_scalar_2)[1] == :state
        Test.@test CTModels.constraint(model, :control_scalar_2)[1] == :control
        Test.@test CTModels.constraint(model, :variable_scalar_2)[1] == :variable

        # test the lower bounds
        Test.@test CTModels.constraint(model, :path)[3] == [-0, -1]
        Test.@test CTModels.constraint(model, :boundary)[3] == [-2, -3]
        Test.@test CTModels.constraint(model, :state)[3] == [-4, -5]
        Test.@test CTModels.constraint(model, :control)[3] == [-6, -7]
        Test.@test CTModels.constraint(model, :variable)[3] == [-8, -9]
        Test.@test CTModels.constraint(model, :path_scalar)[3] == -10
        Test.@test CTModels.constraint(model, :boundary_scalar)[3] == -11
        Test.@test CTModels.constraint(model, :state_scalar)[3] == -12
        Test.@test CTModels.constraint(model, :control_scalar)[3] == -13
        Test.@test CTModels.constraint(model, :variable_scalar)[3] == -14
        Test.@test CTModels.constraint(model, :state_scalar_2)[3] == -15
        Test.@test CTModels.constraint(model, :control_scalar_2)[3] == -16
        Test.@test CTModels.constraint(model, :variable_scalar_2)[3] == -17

        # test the upper bounds
        Test.@test CTModels.constraint(model, :path)[4] == [1, 2]
        Test.@test CTModels.constraint(model, :boundary)[4] == [3, 4]
        Test.@test CTModels.constraint(model, :state)[4] == [5, 6]
        Test.@test CTModels.constraint(model, :control)[4] == [7, 8]
        Test.@test CTModels.constraint(model, :variable)[4] == [9, 10]
        Test.@test CTModels.constraint(model, :path_scalar)[4] == 11
        Test.@test CTModels.constraint(model, :boundary_scalar)[4] == 12
        Test.@test CTModels.constraint(model, :state_scalar)[4] == 13
        Test.@test CTModels.constraint(model, :control_scalar)[4] == 14
        Test.@test CTModels.constraint(model, :variable_scalar)[4] == 15
        Test.@test CTModels.constraint(model, :state_scalar_2)[4] == 16
        Test.@test CTModels.constraint(model, :control_scalar_2)[4] == 17
        Test.@test CTModels.constraint(model, :variable_scalar_2)[4] == 18

        # print the premodel (captured, no terminal output)
        io = IOBuffer()
        show(io, MIME"text/plain"(), pre_ocp)

        # -------------------------------------------------------------------------- #
        # Just for printing
        #
        pre_ocp = CTModels.PreModel()
        CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
        CTModels.state!(pre_ocp, 1, "y", ["y"])
        CTModels.control!(pre_ocp, 1, "u", ["u"])
        CTModels.variable!(pre_ocp, 1, "v", ["v"])
        CTModels.dynamics!(pre_ocp, dynamics!)
        CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=false)
        io = IOBuffer()
        show(io, MIME"text/plain"(), pre_ocp)

        #
        pre_ocp = CTModels.PreModel()
        CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
        CTModels.state!(pre_ocp, 2, "y", ["q", "p"])
        CTModels.control!(pre_ocp, 2, "u", ["w", "z"])
        CTModels.variable!(pre_ocp, 2, "v", ["c", "d"])
        CTModels.dynamics!(pre_ocp, dynamics!)
        CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        io = IOBuffer()
        show(io, MIME"text/plain"(), pre_ocp)
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_model() = TestOCPModel.test_model()
