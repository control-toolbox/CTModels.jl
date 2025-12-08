function solution_example_dual()
    t0 = 0
    tf = 1
    x0 = -1

    # the model (explicit CTModels.PreModel construction)
    function OCP(t0, tf, x0)

        pre_ocp = CTModels.PreModel()

        # No variables
        CTModels.variable!(pre_ocp, 0)

        # Time, state, control
        CTModels.time!(pre_ocp; t0=t0, tf=tf)
        CTModels.state!(pre_ocp, 1)
        CTModels.control!(pre_ocp, 1)

        # Dynamics: ẋ(t) == u(t)
        dynamics!(r, t, x, u, v) = begin
            r[1] = u[1]
            return nothing
        end
        CTModels.dynamics!(pre_ocp, dynamics!)

        # Objective: ∫(-u(t)) → min
        lagrange(t, x, u, v) = -u[1]
        CTModels.objective!(pre_ocp, :min; lagrange=lagrange)

        # Boundary constraint: x(t0) == x0  (label: initial_con)
        f_initial(r, x0_state, xf, v) = begin
            r[1] = x0_state[1] - x0
            return nothing
        end
        CTModels.constraint!(
            pre_ocp,
            :boundary;
            f=f_initial,
            lb=[0.0],
            ub=[0.0],
            label=:initial_con,
        )

        # Control box constraint: 0 ≤ u(t) ≤ +Inf  (label: u_con)
        CTModels.constraint!(
            pre_ocp,
            :control;
            rg=1:1,
            lb=[0.0],
            ub=[Inf],
            label=:u_con,
        )

        # Path constraint: -Inf ≤ x(t) + u(t) ≤ 0
        f_path1(r, t, x, u, v) = begin
            r[1] = x[1] + u[1]
            return nothing
        end
        CTModels.constraint!(
            pre_ocp,
            :path;
            f=f_path1,
            lb=[-Inf],
            ub=[0.0],
        )

        # Path constraint: [-3, 1] ≤ [x(t)+1, u(t)+1] ≤ [1, 2.5]  (label: 2)
        f_path2(r, t, x, u, v) = begin
            r[1] = x[1] + 1
            r[2] = u[1] + 1
            return nothing
        end
        CTModels.constraint!(
            pre_ocp,
            :path;
            f=f_path2,
            lb=[-3.0, 1.0],
            ub=[1.0, 2.5],
            label=:con2,
        )

        # Keep a DSL-style definition expression for printing only
        definition = quote
            t ∈ [t0, tf], time
            x ∈ R, state
            u ∈ R, control
            x(t0) == x0, (initial_con)
            0 ≤ u(t) ≤ +Inf, (u_con)
            -Inf ≤ x(t) + u(t) ≤ 0
            [-3, 1] ≤ [x(t) + 1, u(t) + 1] ≤ [1, 2.5], (2)
            ẋ(t) == u(t)
            ∫(-u(t)) → min
        end
        CTModels.definition!(pre_ocp, definition)

        # Non-autonomous (matches the original DSL semantics)
        CTModels.time_dependence!(pre_ocp; autonomous=false)

        ocp = CTModels.build(pre_ocp)
        return ocp
    end

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
    end

    ocp = OCP(t0, tf, x0)
    sol = SOL(ocp, t0, tf)

    return ocp, sol
end
