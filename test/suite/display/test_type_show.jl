module TestTypeShow

using Test: Test
using CTModels: Components, Building, Models, Serialization, Solutions, Init

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function _show_string(value; plain=false, color=false)
    io = IOBuffer()
    context = IOContext(io, :color => color)
    plain ? show(context, MIME"text/plain"(), value) : show(context, value)
    return String(take!(io))
end

function test_type_show()
    Test.@testset "Concrete type display" verbose=VERBOSE showtiming=SHOWTIMING begin
        state = Components.StateModel("x", ["x₁", "x₂"])
        state_solution = Components.StateModelSolution("x", ["x₁"], t -> 2t)
        control = Components.ControlModel("u", ["u"])
        control_solution = Components.ControlModelSolution("u", ["u"], t -> 0.0, :linear)
        variable = Components.VariableModel("v", ["v"])
        variable_solution = Components.VariableModelSolution("v", ["v"], 1.0)
        fixed = Components.FixedTimeModel(0.0, "t₀")
        free = Components.FreeTimeModel(2, "tf")
        times = Components.TimesModel(fixed, free, "t")
        objective = Components.BolzaObjectiveModel(
            (x0, xf, v) -> 0.0, (t, x, u, v) -> 0.0, :min
        )
        constraints = Components.ConstraintsModel((), (), (), (), ())
        grid = Solutions.UnifiedTimeGridModel([0.0, 1.0])
        multi_grid = Solutions.MultipleTimeGridModel(
            state=[0.0, 1.0], control=[0.0], costate=[0.0, 1.0], path=[0.0]
        )
        infos = Solutions.SolverInfos(
            12, :first_order, "converged", true, 1e-8, Dict{Symbol,Any}()
        )
        dual = Solutions.DualModel(
            nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing
        )

        for value in (
            state,
            state_solution,
            control,
            control_solution,
            variable,
            variable_solution,
            fixed,
            free,
            times,
            objective,
            constraints,
            grid,
            multi_grid,
            infos,
            dual,
            Components.EmptyControlModel(),
            Components.EmptyVariableModel(),
            Solutions.EmptyTimeGridModel(),
            Solutions.EmptyDualModel(),
            Components.EmptyDefinition(),
            Serialization.JLD2Tag(),
            Serialization.JSON3Tag(),
        )
            compact = _show_string(value)
            detailed = _show_string(value; plain=true)
            plain = _show_string(value; plain=true, color=false)
            Test.@test !isempty(compact)
            Test.@test !isempty(detailed)
            Test.@test !occursin("\e[", plain)
        end

        Test.@test occursin("StateModel", _show_string(state; plain=true))
        Test.@test occursin("dimension", _show_string(state; plain=true))
        Test.@test occursin("interpolation", _show_string(control_solution; plain=true))
        Test.@test occursin("criterion", _show_string(objective; plain=true))
        Test.@test occursin("constraints violation", _show_string(infos; plain=true))
        Test.@test occursin("state", _show_string(multi_grid; plain=true))
        Test.@test occursin("status", _show_string(Solutions.EmptyDualModel(); plain=true))

        subpath = Models.SubPathConstraint(((1,), (r, t, x, u, v) -> nothing), 1, 1)
        projection = Models.BoxProjection{:state}(1)
        merged = Init.MergedTrajectory(t -> [0.0], Dict{Int,Function}(), 1, :state)
        constant = Components.ConstantInTime(1.0)
        coerced = Components.CoercedTrajectory(t -> [1.0], only)
        composite = Building.CompositeConstraint{:path}(
            1, [1], ((r, t, x, u, v) -> nothing,)
        )
        dual_slice = Solutions.DualSlice(t -> [1.0], 1)
        dual_diff = Solutions.BoxDualDiff(t -> [1.0], t -> [0.0], 1)

        for value in (
            subpath, projection, merged, constant, coerced, composite, dual_slice, dual_diff
        )
            Test.@test !occursin("\e[", _show_string(value; plain=true, color=false))
        end
    end
end

end

test_type_show() = TestTypeShow.test_type_show()
