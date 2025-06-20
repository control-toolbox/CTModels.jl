using Pkg
Pkg.activate(".")

using CTModels
using Plots

function get_solution()
    FUN = true

    # create a pre-model
    pre_ocp = CTModels.PreModel()

    # set times
    CTModels.time!(pre_ocp; t0=0.0, tf=1.0)

    # set state
    CTModels.state!(pre_ocp, 2)

    # set control
    CTModels.control!(pre_ocp, 1)

    # set dynamics
    dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
    CTModels.dynamics!(pre_ocp, dynamics!) # does not correspond to the solution

    # set objective
    mayer(x0, xf, v) = x0[1] + xf[1]
    lagrange(t, x, u, v) = 0.5 * u[1]^2
    CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange) # does not correspond to the solution

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
    CTModels.definition!(pre_ocp, definition) # does not correspond to the solution

    CTModels.time_dependence!(pre_ocp; autonomous=false)

    # build model
    ocp = CTModels.build(pre_ocp)

    # create a solution

    # times: T Vector{Float64}
    t0 = 0.0
    tf = 1.0
    N = 201
    T = range(t0, tf; length=N)
    # convert T to a vector of Float64
    T = Vector{Float64}(T)

    # state: X Matrix{Float64}
    x0 = [-1.0, 0.0]
    xf = [0.0, 0.0]
    a = x0[1]
    b = x0[2]
    C = [
        -(tf - t0)^3/6.0 (tf - t0)^2/2.0
        -(tf - t0)^2/2.0 (tf-t0)
    ]
    D = [-a - b * (tf - t0), -b] + xf
    p0 = C \ D
    α = p0[1]
    β = p0[2]
    function x(t)
        return [
            a + b * (t - t0) + β * (t - t0)^2 / 2.0 - α * (t - t0)^3 / 6.0,
            b + β * (t - t0) - α * (t - t0)^2 / 2.0,
        ]
    end
    X = FUN ? x : vcat([x(t)' for t in T]...)

    # costate: P Matrix{Float64}
    P = zeros(N, 2)
    function p(t)
        return [α, -α * (t - t0) + β]
    end
    P = FUN ? p : vcat([p(t)' for t in T[1:(end - 1)]]...)

    # control: U Matrix{Float64}
    U = zeros(N, 1)
    function u(t)
        return [p(t)[2]]
    end
    U = FUN ? u : vcat([u(t)' for t in T]...)

    # variable: v Vector{Float64}
    v = Float64[]

    # objective: Float64
    objective = 0.5 * (α^2 * (tf - t0)^3 / 3 + β^2 * (tf - t0) - α * β * (tf - t0)^2)

    # Iterations: Int
    iterations = 0

    # Constraints violation: Float64
    constraints_violation = 0.0

    # Message: String
    message = "Solve_Succeeded"

    # Stopping: Symbol
    status = :Solve_Succeeded

    # Success: Bool
    successful = true

    # solution
    sol = CTModels.build_solution(
        ocp,
        T,
        X,
        U,
        v,
        P;
        objective=objective,
        iterations=iterations,
        constraints_violation=constraints_violation,
        message=message,
        status=status,
        successful=successful,
    )

    return sol
end;

sol = get_solution();

#
plt = plot(; size=(800, 800))
p = Plots.current();
pp = plot!(sol)
pp = plot!(plt, sol)

pp
plt

# layout = :group

plot(sol; layout=:group, control=:components)
plot(sol; layout=:group, control=:norm)
plot(sol; layout=:group, control=:all)
plot(sol, :state; layout=:group)
plot(sol, :costate; layout=:group)
plot(sol, :control; layout=:group)
plot(sol, :control; layout=:group, control=:norm)
plot(sol, :state, :control; layout=:group)
plot(sol, :control; layout=:group, control=:all)
plot(sol, :state, :control; layout=:group, control=:all)

# style is :none
plot(sol; layout=:group, state_style=:none)
plot(sol; layout=:group, costate_style=:none)
plot(sol; layout=:group, control_style=:none)
plot(sol; layout=:group, state_style=:none, control_style=:none)
plot(sol; layout=:group, state_style=:none, costate_style=:none)
plot(sol; layout=:group, costate_style=:none, control_style=:none)

# layout = :split
plot(sol; layout=:split, label="tat")
plot(sol, :state)
plot(sol, :costate; layout=:split)
plot(sol, :control; layout=:split)
plot(sol, :control; layout=:split, control=:norm)
plot(sol, :state, :control; layout=:split)
plot(sol, :control; layout=:split, control=:all)
plot(sol, :state, :control; layout=:split, control=:all)
plot(sol, :state, :costate; layout=:split)

# style is :none
plot(sol; layout=:split, state_style=:none)
plot(sol; layout=:split, costate_style=:none)
plot(sol; layout=:split, control_style=:none)
plot(sol; layout=:split, state_style=:none, control_style=:none)
plot(sol; layout=:split, state_style=:none, costate_style=:none)
plot(sol; layout=:split, costate_style=:none, control_style=:none)

# change style
plot(sol; state_style=(linestyle=:dash, linewidth=1))
plot(sol; costate_style=(linestyle=:dash, linewidth=1))
plot(sol; control_style=(linestyle=:dash, linewidth=1))
plot(
    sol;
    state_style=(linestyle=:dash, linewidth=1),
    control_style=(linestyle=:dash, linewidth=1),
)
plot(
    sol;
    state_style=(linestyle=:dash, linewidth=1),
    costate_style=(linestyle=:dash, linewidth=1),
)
plot(
    sol;
    costate_style=(linestyle=:dash, linewidth=1),
    control_style=(linestyle=:dash, linewidth=1),
)
plot(
    sol;
    state_style=:none,
    costate_style=(linestyle=:dash, linewidth=1),
    control_style=(linestyle=:dash, linewidth=1),
)
nothing

plt = plot(sol; size=(700, 450), time=:normalise, label="sol1")
style = (linestyle=:dash,)
plot!(
    plt,
    sol;
    time=:normalise,
    label="sol2",
    state_style=style,
    costate_style=style,
    control_style=style,
)

# #
# plt = plot(sol; layout=:group, control=:components)
# plot!(plt, sol; layout=:group, control=:components)
# plot!(plt, sol; layout=:group, control=:norm)
# #plot!(plt, sol; layout=:group, control=:all)
