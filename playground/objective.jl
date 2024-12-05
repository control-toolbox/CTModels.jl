using CTModels
using StaticArrays

# dimensions
n = 2 # state dimension
m = 2 # control dimension
q = 2 # variable dimension

# functions
function mayer_user!(r, x0, xf, v)
    r .= zeros(eltype(r), 1)
end

# models
times = CTModels.TimesModel(CTModels.FreeTimeModel(1, "t₀"), CTModels.FreeTimeModel(2, "t_f"), "t")
state = CTModels.StateModel{n}("y", SA["y₁", "y₂"])
control = CTModels.ControlModel{m}("u", SA["u₁", "u₂"])
variable = CTModels.VariableModel{q}("v", SA["v₁", "v₂"])
objective = CTModels.MayerObjectiveModel(CTModels.Mayer(mayer_user!, n, q), :min)

# concrete ocp
ocp = CTModels.OptimalControlModel(times, state, control, variable, objective)

r = zeros(Float64, 1)
r_user = zeros(Float64, 1)
mayer! = CTModels.mayer(ocp)
x0 = [0.0, 0.0]
xf = [0.0, 0.0]
v = [0.0, 0.0]

# mayer!
@code_warntype mayer!(r, x0, xf, v)
@code_native debuginfo=:none dump_module=false mayer!(r, x0, xf, v)

# mayer_user!
@code_warntype mayer_user!(r_user, x0, xf, v)
@code_native debuginfo=:none dump_module=false mayer_user!(r_user, x0, xf, v)

# dummy
function mayer_out_of_place(x0, xf, v)
    r = zeros(eltype(r), 1)
    mayer_user!(r, x0, xf, v)
    return r[1]
end

@code_warntype mayer_out_of_place(x0, xf, v)
@code_native debuginfo=:none dump_module=false mayer_out_of_place(x0, xf, v)

# dummy
function mayer_out_of_place2(x0, xf, v)
    return 0.0
end

@code_warntype mayer_out_of_place2(x0, xf, v)
@code_native debuginfo=:none dump_module=false mayer_out_of_place2(x0, xf, v)

# dummy
function mayer_in_place!(r, x0, xf, v)
    r .= [0.0]
end

@code_warntype mayer_in_place!(r, x0, xf, v)
@code_native debuginfo=:none dump_module=false mayer_in_place!(r, x0, xf, v)