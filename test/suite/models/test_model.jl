module TestOCPModel

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Building: Building
import CTModels.Models: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_model()
    Test.@testset "Model Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Model Building
        # ====================================================================

        # create a pre-model
        pre_ocp = Building.PreModel()

        # exception: times must be set
        Test.@test_throws Exceptions.PreconditionError Building.build(pre_ocp)

        # set times
        Building.time!(pre_ocp; t0=0.0, tf=1.0)

        # exception: state must be set
        Test.@test_throws Exceptions.PreconditionError Building.build(pre_ocp)

        # set state
        Building.state!(pre_ocp, 2)

        # exception: control must be set
        Test.@test_throws Exceptions.PreconditionError Building.build(pre_ocp)

        # set control
        Building.control!(pre_ocp, 2)

        # set variable
        Building.variable!(pre_ocp, 2)

        # exception: dynamics must be set
        Test.@test_throws Exceptions.PreconditionError Building.build(pre_ocp)

        # set dynamics
        dynamics!(r, t, x, u, v) = r .= t .+ x .+ u .+ v
        Building.dynamics!(pre_ocp, dynamics!)

        # exception: objective must be set
        Test.@test_throws Exceptions.PreconditionError Building.build(pre_ocp)

        # set objective
        mayer(x0, xf, v) = x0 .+ xf .+ v
        lagrange(t, x, u, v) = t .+ x .+ u .+ v
        Building.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)

        # exception: definition must be set
        Test.@test_throws Exceptions.PreconditionError Building.build(pre_ocp)

        # set definition
        definition = quote
            t ∈ [0, 1], time
            x ∈ R², state
            u ∈ R, control
            x(0) == [-1, 0]
            x(1) == [0, 0]
            ẋ(t) == [x₂(t), u(t)]
            ∫(0.5u(t)^2) → min
        end
        Building.definition!(pre_ocp, definition)

        # exception: time dependence must be set
        Test.@test_throws Exceptions.PreconditionError Building.build(pre_ocp)

        # set time dependence
        Building.time_dependence!(pre_ocp; autonomous=false)

        # set some constraints
        f_path(r, t, x, u, v) = r .= x .+ u .+ v .+ t
        f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)

        Building.constraint!(pre_ocp, :path; f=f_path, lb=[-0, -1], ub=[1, 2], label=:path)
        Building.constraint!(
            pre_ocp, :boundary; f=f_boundary, lb=[-2, -3], ub=[3, 4], label=:boundary
        )
        Building.constraint!(pre_ocp, :state; rg=1:2, lb=[-4, -5], ub=[5, 6], label=:state)
        Building.constraint!(
            pre_ocp, :control; rg=1:2, lb=[-6, -7], ub=[7, 8], label=:control
        )
        Building.constraint!(
            pre_ocp, :variable; rg=1:2, lb=[-8, -9], ub=[9, 10], label=:variable
        )

        f_path_scalar(r, t, x, u, v) = r .= x[1] + u[1] + v[1] + t
        f_boundary_scalar(r, x0, xf, v) = r .= x0[1] + v[1] * (xf[1] - x0[1])
        Building.constraint!(
            pre_ocp, :path; f=f_path_scalar, lb=-10, ub=11, label=:path_scalar
        )
        Building.constraint!(
            pre_ocp, :boundary; f=f_boundary_scalar, lb=-11, ub=12, label=:boundary_scalar
        )
        Building.constraint!(pre_ocp, :state; rg=1, lb=-12, ub=13, label=:state_scalar)
        Building.constraint!(pre_ocp, :control; rg=1, lb=-13, ub=14, label=:control_scalar)
        Building.constraint!(
            pre_ocp, :variable; rg=1, lb=-14, ub=15, label=:variable_scalar
        )
        Building.constraint!(pre_ocp, :state; rg=2, lb=-15, ub=16, label=:state_scalar_2)
        Building.constraint!(
            pre_ocp, :control; rg=2, lb=-16, ub=17, label=:control_scalar_2
        )
        Building.constraint!(
            pre_ocp, :variable; rg=2, lb=-17, ub=18, label=:variable_scalar_2
        )

        # build the model
        # Note: the scalar constraints (:state_scalar, :state_scalar_2, and
        # their control/variable analogues) intentionally re-declare bounds on
        # components already declared by :state/:control/:variable. Under the
        # per-component uniqueness invariant, this emits one warning per
        # duplicated component (6 warnings here). @test_logs verifies the
        # warnings are emitted; redirect_stderr(devnull) suppresses them from
        # the test output.
        model = Test.@test_logs(
            (:warn, r"Multiple bound declarations for state component 1 \(labels: state, state_scalar\)"),
            (:warn, r"Multiple bound declarations for state component 2 \(labels: state, state_scalar_2\)"),
            (:warn, r"Multiple bound declarations for control component 1 \(labels: control, control_scalar\)"),
            (:warn, r"Multiple bound declarations for control component 2 \(labels: control, control_scalar_2\)"),
            (:warn, r"Multiple bound declarations for variable component 1 \(labels: variable, variable_scalar\)"),
            (:warn, r"Multiple bound declarations for variable component 2 \(labels: variable, variable_scalar_2\)"),
            redirect_stderr(devnull) do
                Building.build(pre_ocp)
            end
        )

        # check the type of the model
        Test.@test model isa Models.Model

        # check retrieved constraints
        t = 1
        x = [2, 3]
        u = [4, 5]
        v = [6, 7]
        x0 = [1, 2]
        xf = [3, 4]

        # test the functions
        Test.@test Models.constraint(model, :path)[2](t, x, u, v) == x .+ u .+ v .+ t
        Test.@test Models.constraint(model, :boundary)[2](x0, xf, v) == x0 .+ v .* (xf .- x0)
        Test.@test Models.constraint(model, :state)[2](t, x, u, v) == x
        Test.@test Models.constraint(model, :control)[2](t, x, u, v) == u
        Test.@test Models.constraint(model, :variable)[2](x0, xf, v) == v
        Test.@test Models.constraint(model, :path_scalar)[2](t, x, u, v) == x[1] + u[1] + v[1] + t
        Test.@test Models.constraint(model, :boundary_scalar)[2](x0, xf, v) == x0[1] + v[1] * (xf[1] - x0[1])
        Test.@test Models.constraint(model, :state_scalar)[2](t, x, u, v) == x[1]
        Test.@test Models.constraint(model, :control_scalar)[2](t, x, u, v) == u[1]
        Test.@test Models.constraint(model, :variable_scalar)[2](x0, xf, v) == v[1]
        Test.@test Models.constraint(model, :state_scalar_2)[2](t, x, u, v) == x[2]
        Test.@test Models.constraint(model, :control_scalar_2)[2](t, x, u, v) == u[2]
        Test.@test Models.constraint(model, :variable_scalar_2)[2](x0, xf, v) == v[2]

        # test the type of the constraints
        Test.@test Models.constraint(model, :path)[1] == :path
        Test.@test Models.constraint(model, :boundary)[1] == :boundary
        Test.@test Models.constraint(model, :state)[1] == :state
        Test.@test Models.constraint(model, :control)[1] == :control
        Test.@test Models.constraint(model, :variable)[1] == :variable
        Test.@test Models.constraint(model, :path_scalar)[1] == :path
        Test.@test Models.constraint(model, :boundary_scalar)[1] == :boundary
        Test.@test Models.constraint(model, :state_scalar)[1] == :state
        Test.@test Models.constraint(model, :control_scalar)[1] == :control
        Test.@test Models.constraint(model, :variable_scalar)[1] == :variable
        Test.@test Models.constraint(model, :state_scalar_2)[1] == :state
        Test.@test Models.constraint(model, :control_scalar_2)[1] == :control
        Test.@test Models.constraint(model, :variable_scalar_2)[1] == :variable

        # test the lower bounds
        # For path/boundary constraints (NL), bounds are per-declaration and
        # returned as declared. For state/control/variable box constraints
        # sharing components, `constraint(m, :label)[3]` returns the
        # **effective** (intersected) lower bound. E.g. :state_scalar declares
        # lb=-12 on component 1 but :state already declares lb=-4 on that same
        # component (tighter), so the effective lb is -4.
        Test.@test Models.constraint(model, :path)[3] == [-0, -1]
        Test.@test Models.constraint(model, :boundary)[3] == [-2, -3]
        Test.@test Models.constraint(model, :state)[3] == [-4, -5]
        Test.@test Models.constraint(model, :control)[3] == [-6, -7]
        Test.@test Models.constraint(model, :variable)[3] == [-8, -9]
        Test.@test Models.constraint(model, :path_scalar)[3] == -10
        Test.@test Models.constraint(model, :boundary_scalar)[3] == -11
        Test.@test Models.constraint(model, :state_scalar)[3] == -4    # intersected with :state
        Test.@test Models.constraint(model, :control_scalar)[3] == -6  # intersected with :control
        Test.@test Models.constraint(model, :variable_scalar)[3] == -8 # intersected with :variable
        Test.@test Models.constraint(model, :state_scalar_2)[3] == -5
        Test.@test Models.constraint(model, :control_scalar_2)[3] == -7
        Test.@test Models.constraint(model, :variable_scalar_2)[3] == -9

        # test the upper bounds (same intersection logic applies)
        Test.@test Models.constraint(model, :path)[4] == [1, 2]
        Test.@test Models.constraint(model, :boundary)[4] == [3, 4]
        Test.@test Models.constraint(model, :state)[4] == [5, 6]
        Test.@test Models.constraint(model, :control)[4] == [7, 8]
        Test.@test Models.constraint(model, :variable)[4] == [9, 10]
        Test.@test Models.constraint(model, :path_scalar)[4] == 11
        Test.@test Models.constraint(model, :boundary_scalar)[4] == 12
        Test.@test Models.constraint(model, :state_scalar)[4] == 5     # intersected with :state
        Test.@test Models.constraint(model, :control_scalar)[4] == 7   # intersected with :control
        Test.@test Models.constraint(model, :variable_scalar)[4] == 9  # intersected with :variable
        Test.@test Models.constraint(model, :state_scalar_2)[4] == 6
        Test.@test Models.constraint(model, :control_scalar_2)[4] == 8
        Test.@test Models.constraint(model, :variable_scalar_2)[4] == 10

        # print the premodel (captured, no terminal output)
        redirect_stderr(devnull) do
            io = IOBuffer()
            show(io, MIME"text/plain"(), pre_ocp)
        end

        # -------------------------------------------------------------------------- #
        # Just for printing
        #
        pre_ocp = Building.PreModel()
        Building.time!(pre_ocp; t0=0.0, tf=1.0)
        Building.state!(pre_ocp, 1, "y", ["y"])
        Building.control!(pre_ocp, 1, "u", ["u"])
        Building.variable!(pre_ocp, 1, "v", ["v"])
        Building.dynamics!(pre_ocp, dynamics!)
        Building.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)
        Building.definition!(pre_ocp, quote end)
        Building.time_dependence!(pre_ocp; autonomous=false)
        io = IOBuffer()
        redirect_stderr(devnull) do
            show(io, MIME"text/plain"(), pre_ocp)
        end

        #
        pre_ocp = Building.PreModel()
        Building.time!(pre_ocp; t0=0.0, tf=1.0)
        Building.state!(pre_ocp, 2, "y", ["q", "p"])
        Building.control!(pre_ocp, 2, "u", ["w", "z"])
        Building.variable!(pre_ocp, 2, "v", ["c", "d"])
        Building.dynamics!(pre_ocp, dynamics!)
        Building.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)
        Building.definition!(pre_ocp, quote end)
        Building.time_dependence!(pre_ocp; autonomous=true)
        io = IOBuffer()
        redirect_stderr(devnull) do
            show(io, MIME"text/plain"(), pre_ocp)
        end

        # ====================================================================
        # UNIT TESTS - is_autonomous / derived trait getters
        # ====================================================================

        Test.@testset "is_autonomous and derived traits" begin
            _dyn!(r, _t, x, _u, _v) = (r .= x)

            pre_a = Building.PreModel()
            Building.time!(pre_a; t0=0.0, tf=1.0)
            Building.state!(pre_a, 1)
            Building.control!(pre_a, 1)
            Building.dynamics!(pre_a, _dyn!)
            Building.objective!(pre_a, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre_a, quote end)
            Building.time_dependence!(pre_a; autonomous=true)
            m_aut = Building.build(pre_a)

            pre_na = Building.PreModel()
            Building.time!(pre_na; t0=0.0, tf=1.0)
            Building.state!(pre_na, 1)
            Building.control!(pre_na, 1)
            Building.dynamics!(pre_na, _dyn!)
            Building.objective!(pre_na, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre_na, quote end)
            Building.time_dependence!(pre_na; autonomous=false)
            m_na = Building.build(pre_na)

            Test.@test Models.is_autonomous(m_aut) == true
            Test.@test Models.is_nonautonomous(m_aut) == false
            Test.@test Models.is_autonomous(m_na) == false
            Test.@test Models.is_nonautonomous(m_na) == true

            # Variable / control presence
            pre_v = Building.PreModel()
            Building.time!(pre_v; t0=0.0, tf=1.0)
            Building.state!(pre_v, 2)
            Building.variable!(pre_v, 2)
            Building.dynamics!(pre_v, _dyn!)
            Building.objective!(pre_v, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre_v, quote end)
            Building.time_dependence!(pre_v; autonomous=false)
            m_noctl = Building.build(pre_v)

            Test.@test Models.has_variable(m_na) == false
            Test.@test Models.has_control(m_na) == true
            Test.@test Models.has_variable(m_noctl) == true
            Test.@test Models.is_control_free(m_noctl) == true
            Test.@test Models.has_control(m_noctl) == false
        end

        # ====================================================================
        # UNIT TESTS - initial_time / final_time branches
        # ====================================================================

        Test.@testset "initial_time / final_time fixed" begin
            pre = Building.PreModel()
            Building.time!(pre; t0=0.5, tf=3.0)
            Building.state!(pre, 1)
            Building.control!(pre, 1)
            _dyn!(r, _t, x, _u, _v) = (r .= x)
            Building.dynamics!(pre, _dyn!)
            Building.objective!(pre, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre, quote end)
            Building.time_dependence!(pre; autonomous=false)
            m = Building.build(pre)

            Test.@test Components.has_fixed_initial_time(m) == true
            Test.@test Components.has_fixed_final_time(m) == true
            Test.@test Components.initial_time(m) ≈ 0.5
            Test.@test Components.final_time(m) ≈ 3.0
        end

        Test.@testset "initial_time / final_time free (vector)" begin
            pre = Building.PreModel()
            Building.variable!(pre, 2, "v", ["t0", "tf"])
            Building.time!(pre; ind0=1, indf=2)
            Building.state!(pre, 1)
            Building.control!(pre, 1)
            _dyn!(r, _t, x, _u, _v) = (r .= x)
            Building.dynamics!(pre, _dyn!)
            Building.objective!(pre, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre, quote end)
            Building.time_dependence!(pre; autonomous=false)
            m = Building.build(pre)

            Test.@test Components.has_free_initial_time(m) == true
            Test.@test Components.has_free_final_time(m) == true
            Test.@test Components.initial_time(m, [0.3, 2.5]) ≈ 0.3
            Test.@test Components.final_time(m, [0.3, 2.5]) ≈ 2.5
        end

        Test.@testset "initial_time / final_time free (scalar)" begin
            pre = Building.PreModel()
            Building.variable!(pre, 1, "v", ["tf"])
            Building.time!(pre; t0=0.0, indf=1)
            Building.state!(pre, 1)
            Building.control!(pre, 1)
            _dyn!(r, _t, x, _u, _v) = (r .= x)
            Building.dynamics!(pre, _dyn!)
            Building.objective!(pre, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre, quote end)
            Building.time_dependence!(pre; autonomous=false)
            m = Building.build(pre)

            Test.@test Components.final_time(m, 2.0) ≈ 2.0
        end

        # ====================================================================
        # ERROR TESTS - mayer / lagrange stubs on wrong objective type
        # ====================================================================

        Test.@testset "mayer / lagrange stubs" begin
            _dyn!(r, _t, x, _u, _v) = (r .= x)

            # Model with Lagrange only → Components.mayer throws
            pre_lag = Building.PreModel()
            Building.time!(pre_lag; t0=0.0, tf=1.0)
            Building.state!(pre_lag, 1)
            Building.control!(pre_lag, 1)
            Building.dynamics!(pre_lag, _dyn!)
            Building.objective!(pre_lag, :min; lagrange=(t, x, u, v) -> u[1]^2)
            Building.definition!(pre_lag, quote end)
            Building.time_dependence!(pre_lag; autonomous=false)
            m_lag = Building.build(pre_lag)

            Test.@test_throws Exceptions.PreconditionError Components.mayer(m_lag)
            Test.@test Components.has_mayer_cost(m_lag) == false
            Test.@test Components.has_lagrange_cost(m_lag) == true

            # Model with Mayer only → Components.lagrange throws
            pre_may = Building.PreModel()
            Building.time!(pre_may; t0=0.0, tf=1.0)
            Building.state!(pre_may, 1)
            Building.control!(pre_may, 1)
            Building.dynamics!(pre_may, _dyn!)
            Building.objective!(pre_may, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre_may, quote end)
            Building.time_dependence!(pre_may; autonomous=false)
            m_may = Building.build(pre_may)

            Test.@test_throws Exceptions.PreconditionError Components.lagrange(m_may)
            Test.@test Components.has_lagrange_cost(m_may) == false
            Test.@test Components.has_mayer_cost(m_may) == true
        end

        # ====================================================================
        # ERROR TESTS - get_build_examodel stub
        # ====================================================================

        Test.@testset "get_build_examodel stub" begin
            _dyn!(r, _t, x, _u, _v) = (r .= x)
            pre = Building.PreModel()
            Building.time!(pre; t0=0.0, tf=1.0)
            Building.state!(pre, 1)
            Building.control!(pre, 1)
            Building.dynamics!(pre, _dyn!)
            Building.objective!(pre, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre, quote end)
            Building.time_dependence!(pre; autonomous=false)
            m = Building.build(pre)  # build_examodel = nothing

            Test.@test_throws Exceptions.PreconditionError Models.get_build_examodel(m)
        end

        # ====================================================================
        # ERROR TESTS - constraint label not found
        # ====================================================================

        Test.@testset "constraint label not found" begin
            _dyn!(r, _t, x, _u, _v) = (r .= x)
            pre = Building.PreModel()
            Building.time!(pre; t0=0.0, tf=1.0)
            Building.state!(pre, 1)
            Building.control!(pre, 1)
            Building.dynamics!(pre, _dyn!)
            Building.objective!(pre, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre, quote end)
            Building.time_dependence!(pre; autonomous=false)
            m = Building.build(pre)

            Test.@test_throws Exceptions.IncorrectArgument Models.constraint(m, :nonexistent)
        end

        # ====================================================================
        # QUALITY - @inferred on parametric getters
        # ====================================================================

        Test.@testset "@inferred parametric getters" begin
            _dyn!(r, _t, x, _u, _v) = (r .= x)
            pre = Building.PreModel()
            Building.time!(pre; t0=0.0, tf=1.0)
            Building.state!(pre, 2, "x", ["x1", "x2"])
            Building.control!(pre, 1, "u", ["u"])
            Building.variable!(pre, 1, "v", ["v"])
            Building.dynamics!(pre, _dyn!)
            Building.objective!(pre, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre, quote end)
            Building.time_dependence!(pre; autonomous=false)
            m = Building.build(pre)

            Test.@test_nowarn Test.@inferred Models.state(m)
            Test.@test_nowarn Test.@inferred Models.control(m)
            Test.@test_nowarn Test.@inferred Models.variable(m)
            Test.@test_nowarn Test.@inferred Models.times(m)
            Test.@test_nowarn Test.@inferred Models.state_dimension(m)
            Test.@test_nowarn Test.@inferred Models.control_dimension(m)
            Test.@test_nowarn Test.@inferred Models.variable_dimension(m)
            Test.@test_nowarn Test.@inferred Models.is_autonomous(m)
        end

        # ====================================================================
        # QUALITY - @allocated == 0 on hot dimension accessors
        # ====================================================================

        Test.@testset "@allocated dimension accessors" begin
            _dyn!(r, _t, x, _u, _v) = (r .= x)
            pre = Building.PreModel()
            Building.time!(pre; t0=0.0, tf=1.0)
            Building.state!(pre, 2)
            Building.control!(pre, 1)
            Building.dynamics!(pre, _dyn!)
            Building.objective!(pre, :min; mayer=(x0, xf, v) -> 0.0)
            Building.definition!(pre, quote end)
            Building.time_dependence!(pre; autonomous=false)
            m = Building.build(pre)

            # Warmup (triggers compilation)
            _ = Models.state_dimension(m)
            _ = Models.control_dimension(m)
            _ = Models.variable_dimension(m)

            Test.@test (@allocated Models.state_dimension(m)) == 0
            Test.@test (@allocated Models.control_dimension(m)) == 0
            Test.@test (@allocated Models.variable_dimension(m)) == 0
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_model() = TestOCPModel.test_model()
