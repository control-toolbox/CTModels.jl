# A solution whose duals cover the three kinds of constraint rows of the plot (path,
# state box, control box) plus a boundary constraint, declared in this order:
#
#   boundary  :init    x(0) = 0
#   path      :c1      x₁(t) + x₂(t) ≤ 3
#   state box :x2_box  -0.5 ≤ x₂(t) ≤ 2       (two bounds: signed dual zU − zL)
#   ctrl box  :u_box   -1 ≤ u(t) ≤ 1
function solution_example_box_duals()
    pre = CTModels.PreModel()
    CTModels.variable!(pre, 0)
    CTModels.time!(pre; t0=0.0, tf=1.0)
    CTModels.state!(pre, 2)
    CTModels.control!(pre, 1)
    CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u[1]; nothing))
    CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u[1]^2)
    CTModels.constraint!(
        pre,
        :boundary;
        f=(r, x0, xf, v) -> (r[1] = x0[1]; r[2] = x0[2]; nothing),
        lb=[0.0, 0.0],
        ub=[0.0, 0.0],
        label=:init,
    )
    CTModels.constraint!(
        pre,
        :path;
        f=(r, t, x, u, v) -> (r[1] = x[1] + x[2]; nothing),
        lb=[-Inf],
        ub=[3.0],
        label=:c1,
    )
    CTModels.constraint!(pre, :state; rg=2:2, lb=[-0.5], ub=[2.0], label=:x2_box)
    CTModels.constraint!(pre, :control; rg=1:1, lb=[-1.0], ub=[1.0], label=:u_box)
    CTModels.time_dependence!(pre; autonomous=true)
    ocp = CTModels.build(pre)

    N = 51
    T = collect(range(0.0, 1.0; length=N))
    X = hcat(T .^ 2, 2T)
    U = reshape(1 .- T, N, 1)
    P = hcat(1 .- T, -T)
    sol = CTModels.build_solution(
        ocp,
        T,
        X,
        U,
        Float64[],
        P;
        objective=1 / 3,
        iterations=1,
        constraints_violation=0.0,
        message="",
        status=:optimal,
        successful=true,
        path_constraints_dual=hcat(T),
        boundary_constraints_dual=[0.1, 0.2],
        state_constraints_lb_dual=hcat(zeros(N), max.(0.0, 1 .- 4T)),
        state_constraints_ub_dual=hcat(zeros(N), max.(0.0, 4T .- 3)),
        control_constraints_lb_dual=reshape(max.(0.0, 0.5 .- T), N, 1),
        control_constraints_ub_dual=zeros(N, 1),
    )
    return ocp, sol
end
