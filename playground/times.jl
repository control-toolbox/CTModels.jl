using StaticArrays

times = CTModels.TimesModel(CTModels.FreeTimeModel(1, "t₀"), CTModels.FreeTimeModel(2, "t_f"), "t")
control = CTModels.ControlModel("u", SA["u₁", "u₂"])
state = CTModels.StateModel("y", SA["y₁", "y₂"])
variable = CTModels.VariableModel("v", SA["v₁", "v₂"])

# concrete ocp
ocp = CTModels.Model(times, state, control, variable)

@code_warntype CTModels.initial_time(ocp, [0, 10])

CTModels.initial_time(ocp, [0, 10])

#### 

f(x::Int, y::Float64) = convert(Float64, x) + y

@code_warntype f(1, 1.0)

struct Fun{TF <: Function}
    f::TF
end

F = Fun(f)

@code_warntype F.f(1, 1.0)

(F::Fun)(args...) = F.f(args...)

@code_warntype F(1, 1.0)

(F::Fun)(x, y) = F.f(x, y)

@code_warntype F(1, 1.0)