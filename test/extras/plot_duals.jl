using CTModels
using Plots
import CTParser: CTParser, @def

t0 = 0
tf = 1
x0 = -1

# the model
function OCP(t0, tf, x0)
    @def ocp begin
        t ∈ [t0, tf], time
        x ∈ R, state
        u ∈ R, control
        x(t0) == x0, (initial_con)
        0 ≤ u(t) ≤ +Inf, (u_con)
        -Inf ≤ x(t) + u(t) ≤ 0, (mixed_con)
        [-3, 1] ≤ [x(t) + 1, u(t) + 1] ≤ [1, 2.5], (2)
        ẋ(t) == u(t)
        ∫(-u(t)) → min
    end true;

    return ocp
end;

ocp = OCP(t0, tf, x0);

# the solution
function SOL(ocp, t0, tf)
    x(t) = -exp(-t)
    p(t) = exp(t-1) - 1
    u(t) = -x(t)
    objective = exp(-1) - 1
    v = Float64[]

    #
    path_constraints_dual(t) = [-(p(t)+1), 0, t]

    # 
    times = range(t0, tf, 201)
    sol = CTModels.build_solution(
        ocp,
        Vector{Float64}(times),
        x,
        u,
        v,
        p;
        objective=objective,
        iterations=-1,
        constraints_violation=0.0,
        message="",
        status=:optimal,
        successful=true,
        path_constraints_dual=path_constraints_dual,
    )

    return sol
end;

sol = SOL(ocp, t0, tf);

# from description
plt = plot(sol; label="tata", color=2)
plt = plot(sol; layout=:group)
plt = plot(sol, :state)
plt = plot(sol, :state, :costate)
plt = plot(sol, :state, :control; color=2)
plt = plot(sol, :state, :control, :path)
plt = plot(sol, :costate)
plt = plot(sol, :control)
plt = plot(sol, :path)
plt = plot(sol, :dual)
plt = plot(sol, :path, :dual)

# style is :none
plot(sol; layout=:split, state_style=:none)
plot(sol; layout=:split, costate_style=:none)
plot(sol; layout=:split, control_style=:none)
plot(sol; layout=:split, path_style=:none)
plot(sol; layout=:split, dual_style=:none)
plot(sol; layout=:split, state_style=:none, control_style=:none)
plot(sol; layout=:split, state_style=:none, costate_style=:none)
plot(sol; layout=:split, costate_style=:none, control_style=:none)
plot(sol; layout=:split, path_style=:none, control_style=:none)
plot(sol; layout=:split, dual_style=:none, control_style=:none)

# no decorations
plot(sol; layout=:split, time_style=:none, label="toto")
plot(sol; layout=:split, state_bounds_style=:none)
plot(sol; layout=:split, control_bounds_style=:none)
plot(sol; layout=:split, path_bounds_style=:none)
plot(sol; layout=:split, state_bounds_style=:none, control_bounds_style=:none)
plot(sol; layout=:split, state_bounds_style=:none, path_bounds_style=:none)
plot(sol; layout=:split, control_bounds_style=:none, path_bounds_style=:none)
plot(
    sol;
    layout=:split,
    state_bounds_style=:none,
    control_bounds_style=:none,
    path_bounds_style=:none,
)
plot(sol; layout=:split, time_style=:none, state_bounds_style=:none)
plot(sol; layout=:split, time_style=:none, control_bounds_style=:none)
plot(
    sol;
    layout=:split,
    time_style=:none,
    control_bounds_style=:none,
    path_bounds_style=:none,
)

# mixed_con_dual = CTModels.dual(sol, ocp, :mixed_con)
# plot(range(t0, tf; length=101), mixed_con_dual)

# eq2_dual = CTModels.dual(sol, ocp, :eq2)
# plot(range(t0, tf; length=101), t -> eq2_dual(t)[1]; label="eq2_dual 1")
# plot!(range(t0, tf; length=101), t -> eq2_dual(t)[2]; label="eq2_dual 2")
