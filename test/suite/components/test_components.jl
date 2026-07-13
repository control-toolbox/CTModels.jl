module TestComponents

import Test: Test
import CTModels.Components: Components

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_components()
    Test.@testset "OCP Components Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - OCP Components
        # ====================================================================
        Test.@testset "state/control/variable models" begin
            state = Components.StateModel("y", ["u", "v"])
            Test.@test Components.dimension(state) == 2
            Test.@test Components.name(state) == "y"
            Test.@test Components.components(state) == ["u", "v"]

            control = Components.ControlModel("u", ["u₁", "u₂"])
            Test.@test Components.dimension(control) == 2
            Test.@test Components.name(control) == "u"
            Test.@test Components.components(control) == ["u₁", "u₂"]

            variable = Components.VariableModel("v", ["v₁", "v₂"])
            Test.@test Components.dimension(variable) == 2
            Test.@test Components.name(variable) == "v"
            Test.@test Components.components(variable) == ["v₁", "v₂"]
        end

        # # Contract: Empty sentinel models — each accessor must return its zero value.
        Test.@testset "Empty sentinel models" begin
            ec = Components.EmptyControlModel()
            Test.@test Components.name(ec) == ""
            Test.@test Components.components(ec) == String[]
            Test.@test Components.dimension(ec) == 0

            ev = Components.EmptyVariableModel()
            Test.@test Components.name(ev) == ""
            Test.@test Components.components(ev) == String[]
            Test.@test Components.dimension(ev) == 0

            ed = Components.EmptyDefinition()
            _expr = Components.expression(ed)
            Test.@test Meta.isexpr(_expr, :block)
            Test.@test all(a -> a isa LineNumberNode, _expr.args)
        end

        # Contract: Solution variants carry value (and interpolation for control).
        Test.@testset "StateModelSolution / ControlModelSolution accessors" begin
            xf = t -> [sin(t), cos(t)]
            sms = Components.StateModelSolution("x", ["x1", "x2"], xf)
            Test.@test Components.name(sms) == "x"
            Test.@test Components.components(sms) == ["x1", "x2"]
            Test.@test Components.dimension(sms) == 2
            Test.@test Components.value(sms)(0.0) == xf(0.0)

            uf = t -> cos(t)
            cms = Components.ControlModelSolution("u", ["u"], uf, :constant)
            Test.@test Components.name(cms) == "u"
            Test.@test Components.components(cms) == ["u"]
            Test.@test Components.dimension(cms) == 1
            Test.@test Components.value(cms)(0.5) ≈ uf(0.5)
            Test.@test Components.interpolation(cms) == :constant
        end

        Test.@testset "time models" begin
            Test.@test isabstracttype(Components.AbstractTimeModel)

            t0 = Components.FixedTimeModel(0.0, "t₀")
            tf = Components.FixedTimeModel(1.0, "t_f")
            Test.@test Base.time(t0) == 0.0
            Test.@test Components.name(t0) == "t₀"
            Test.@test Base.time(tf) == 1.0
            Test.@test Components.name(tf) == "t_f"

            free_t0 = Components.FreeTimeModel(1, "t₀")
            free_tf = Components.FreeTimeModel(2, "t_f")
            Test.@test Components.index(free_t0) == 1
            Test.@test Components.name(free_t0) == "t₀"
            Test.@test Components.index(free_tf) == 2
            Test.@test Components.name(free_tf) == "t_f"

            times = Components.TimesModel(t0, tf, "t")
            Test.@test Components.initial(times) === t0
            Test.@test Components.final(times) === tf
            Test.@test Components.time_name(times) == "t"
        end

        Test.@testset "ConstantInTime" begin
            f_scalar = Components.ConstantInTime(1.0)
            Test.@test f_scalar(0.0) == 1.0
            Test.@test f_scalar(0.5) == 1.0
            Test.@test f_scalar(42.0) == 1.0

            f_vec = Components.ConstantInTime([1.0, 2.0])
            Test.@test f_vec(0.0) == [1.0, 2.0]
            Test.@test f_vec(99.9) == [1.0, 2.0]

            Test.@test f_scalar isa Function
            Test.@test f_vec isa Function

            Test.@test contains(repr(f_scalar), "ConstantInTime")
            Test.@test contains(repr(MIME("text/plain"), f_scalar), "ConstantInTime")
        end

        Test.@testset "CoercedTrajectory" begin
            # Scalar extraction (coerce = only)
            f = Components.CoercedTrajectory(t -> [2t], only)
            Test.@test f(0.5) == 1.0
            Test.@test f(0.5) isa Real
            Test.@test f(0.0) == 0.0

            # Vector pass-through (coerce = identity)
            g = Components.CoercedTrajectory(t -> [t, 2t], identity)
            Test.@test g(0.5) == [0.5, 1.0]
            Test.@test g(0.5) isa AbstractVector

            # <: Function compatibility
            Test.@test f isa Function
            Test.@test g isa Function

            # only validates length == 1 (should throw if inner returns length > 1)
            h = Components.CoercedTrajectory(t -> [1.0, 2.0], only)
            Test.@test_throws ArgumentError h(0.0)

            # show
            Test.@test contains(repr(f), "CoercedTrajectory")
            Test.@test contains(repr(MIME("text/plain"), f), "CoercedTrajectory")
            Test.@test contains(repr(MIME("text/plain"), f), "only")
        end

        # Contract: hot-path calls (functor evaluation, solution accessors) must
        # infer. Construction is not asserted — it may be dynamic by design.
        Test.@testset "Type stability" begin
            f_const = Components.ConstantInTime(1.0)
            Test.@inferred f_const(0.5)

            f_coerced_only = Components.CoercedTrajectory(t -> [2t], only)
            Test.@inferred f_coerced_only(0.5)

            f_coerced_id = Components.CoercedTrajectory(t -> [t, 2t], identity)
            Test.@inferred f_coerced_id(0.5)

            sms = Components.StateModelSolution("x", ["x1", "x2"], t -> [sin(t), cos(t)])
            Test.@inferred Components.name(sms)
            Test.@inferred Components.components(sms)
            Test.@inferred Components.dimension(sms)
            Test.@inferred Components.value(sms)

            cms = Components.ControlModelSolution("u", ["u"], t -> cos(t), :constant)
            Test.@inferred Components.value(cms)
            Test.@inferred Components.interpolation(cms)
        end

        Test.@testset "objective and constraints models" begin
            mayer_f = (x0, xf, _v) -> x0[1] + xf[1]
            lagrange_f = (_t, _x, u, _v) -> u[1]^2

            mayer = Components.MayerObjectiveModel(mayer_f, :min)
            lagrange = Components.LagrangeObjectiveModel(lagrange_f, :max)
            bolza = Components.BolzaObjectiveModel(mayer_f, lagrange_f, :min)

            Test.@test Components.criterion(mayer) == :min
            Test.@test Components.criterion(lagrange) == :max
            Test.@test Components.criterion(bolza) == :min
            Test.@test Components.has_mayer_cost(mayer) == true
            Test.@test Components.has_mayer_cost(lagrange) == false
            Test.@test Components.has_lagrange_cost(lagrange) == true
            Test.@test Components.has_lagrange_cost(mayer) == false
            Test.@test Components.has_mayer_cost(bolza) == true
            Test.@test Components.has_lagrange_cost(bolza) == true
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_components() = TestComponents.test_components()
