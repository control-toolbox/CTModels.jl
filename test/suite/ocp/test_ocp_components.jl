function test_ocp_components()
    # TODO: add tests for src/core/types/ocp_components.jl.

    Test.@testset "state/control/variable models" verbose=VERBOSE showtiming=SHOWTIMING begin
        state = CTModels.StateModel("y", ["u", "v"])
        Test.@test CTModels.dimension(state) == 2
        Test.@test CTModels.name(state) == "y"
        Test.@test CTModels.components(state) == ["u", "v"]

        control = CTModels.ControlModel("u", ["u₁", "u₂"])
        Test.@test CTModels.dimension(control) == 2
        Test.@test CTModels.name(control) == "u"
        Test.@test CTModels.components(control) == ["u₁", "u₂"]

        variable = CTModels.VariableModel("v", ["v₁", "v₂"])
        Test.@test CTModels.dimension(variable) == 2
        Test.@test CTModels.name(variable) == "v"
        Test.@test CTModels.components(variable) == ["v₁", "v₂"]
    end

    Test.@testset "time models" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test isabstracttype(CTModels.AbstractTimeModel)

        t0 = CTModels.FixedTimeModel(0.0, "t₀")
        tf = CTModels.FixedTimeModel(1.0, "t_f")
        Test.@test t0.time == 0.0
        Test.@test t0.name == "t₀"
        Test.@test tf.time == 1.0
        Test.@test tf.name == "t_f"

        free_t0 = CTModels.FreeTimeModel(1, "t₀")
        free_tf = CTModels.FreeTimeModel(2, "t_f")
        Test.@test free_t0.index == 1
        Test.@test free_t0.name == "t₀"
        Test.@test free_tf.index == 2
        Test.@test free_tf.name == "t_f"

        times = CTModels.TimesModel(t0, tf, "t")
        Test.@test times.initial === t0
        Test.@test times.final === tf
        Test.@test times.time_name == "t"
    end

    Test.@testset "objective and constraints models" verbose=VERBOSE showtiming=SHOWTIMING begin
        mayer_f = (x0, xf, v) -> x0[1] + xf[1]
        lagrange_f = (t, x, u, v) -> u[1]^2

        mayer = CTModels.MayerObjectiveModel(mayer_f, :min)
        lagrange = CTModels.LagrangeObjectiveModel(lagrange_f, :max)
        bolza = CTModels.BolzaObjectiveModel(mayer_f, lagrange_f, :min)

        Test.@test mayer.criterion == :min
        Test.@test lagrange.criterion == :max
        Test.@test bolza.criterion == :min

        # Simple construction of an empty ConstraintsModel
        constraints = CTModels.ConstraintsModel((), (), (), (), ())
        Test.@test constraints.path_nl == ()
        Test.@test constraints.boundary_nl == ()
        Test.@test constraints.state_box == ()
        Test.@test constraints.control_box == ()
        Test.@test constraints.variable_box == ()
    end
end
