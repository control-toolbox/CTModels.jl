"""
Free-final-time fixture: the double integrator in minimum time.

Mirrors the OptimalControl tutorial
(https://control-toolbox.org/Tutorials.jl/stable/tutorial-free-times-final.html)
and is built with the functional CTModels API (variable! before time!(...; indf=…),
see https://control-toolbox.org/OptimalControl.jl/stable/manual-macro-free.html).

Problem (DSL form kept for printing only):

    tf ∈ R, variable
    t ∈ [0, tf], time
    x = (q, v) ∈ R², state
    u ∈ R, control
    -1 ≤ u(t) ≤ 1
    0.05 ≤ tf
    x(0) == [0, 0]
    x(tf) == [1, 0]
    ẋ(t) == [x₂(t), u(t)]
    tf → min

Analytical (bang-bang) solution, switch at t₁ = 1, optimal tf = 2:

    x₁(t) = t²/2                on [0,1),   -t²/2 + 2t - 1  on [1,2]
    x₂(t) = t                   on [0,1),    2 - t          on [1,2]
    u(t)  = +1                  on [0,1),   -1              on [1,2]
    p₁(t) = 1,  p₂(t) = 1 - t

The point of this fixture for the plot suite: `tf` is a decision variable, so the
time decorations (vertical lines at t0/tf) read the final time from the variable via
`final_time(model, variable(sol))` — a path no fixed-time fixture exercises.
"""
function solution_example_free_final_time()
    t0 = 0.0
    x0 = [0.0, 0.0]
    xf = [1.0, 0.0]
    tf_opt = 2.0

    # ---- model (functional API) ------------------------------------------------
    pre_ocp = CTModels.PreModel()

    # variable first: variable[1] holds the free final time
    CTModels.variable!(pre_ocp, 1, "tf")

    # free final time: tf = variable[1]
    CTModels.time!(pre_ocp; t0=t0, indf=1)

    CTModels.state!(pre_ocp, 2, "x", ["q", "v"])
    CTModels.control!(pre_ocp, 1)

    # dynamics: ẋ(t) == [x₂(t), u(t)]
    dynamics!(r, t, x, u, v) = begin
        r[1] = x[2]
        r[2] = u[1]
        return nothing
    end
    CTModels.dynamics!(pre_ocp, dynamics!)

    # objective: minimise tf = v[1]
    mayer(x0_, xf_, v) = v[1]
    CTModels.objective!(pre_ocp, :min; mayer=mayer)

    # control box constraint: -1 ≤ u(t) ≤ 1
    CTModels.constraint!(
        pre_ocp, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:u_box
    )

    # variable box constraint: 0.05 ≤ tf ≤ Inf
    CTModels.constraint!(
        pre_ocp, :variable; rg=1:1, lb=[0.05], ub=[Inf], label=:tf_box
    )

    # boundary constraints: x(t0) == x0 and x(tf) == xf
    f_boundary(r, x0_state, xf_state, v) = begin
        r[1] = x0_state[1] - x0[1]
        r[2] = x0_state[2] - x0[2]
        r[3] = xf_state[1] - xf[1]
        r[4] = xf_state[2] - xf[2]
        return nothing
    end
    CTModels.constraint!(
        pre_ocp, :boundary; f=f_boundary, lb=zeros(4), ub=zeros(4), label=:endpoints
    )

    # DSL-style definition, for printing only
    definition = quote
        tf ∈ R, variable
        t ∈ [0, tf], time
        x = (q, v) ∈ R², state
        u ∈ R, control
        -1 ≤ u(t) ≤ 1
        0.05 ≤ tf
        x(0) == [0, 0]
        x(tf) == [1, 0]
        ẋ(t) == [x₂(t), u(t)]
        tf → min
    end
    CTModels.definition!(pre_ocp, definition)

    CTModels.time_dependence!(pre_ocp; autonomous=true)

    ocp = CTModels.build(pre_ocp)

    # ---- solution (closed form) ------------------------------------------------
    x1(t) = t < 1 ? t^2 / 2 : -t^2 / 2 + 2t - 1
    x2(t) = t < 1 ? t : 2 - t
    x(t) = [x1(t), x2(t)]
    u(t) = [t < 1 ? 1.0 : -1.0]
    p(t) = [1.0, 1.0 - t]

    v = [tf_opt]
    objective = tf_opt

    times = Vector{Float64}(range(t0, tf_opt, 201))
    sol = CTModels.build_solution(
        ocp,
        times,
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
    )

    return ocp, sol
end
