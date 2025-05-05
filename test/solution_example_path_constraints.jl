function solution_example_path_constraints()
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
            -Inf ≤ x(t) + u(t) ≤ 0
            [-3, 1] ≤ [x(t) + 1, u(t) + 1] ≤ [1, 2.5], (2)
            ẋ(t) == u(t)
            ∫(-u(t)) → min
        end;

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
            stopping=:optimal,
            success=true,
            path_constraints_dual=path_constraints_dual,
        )

        return sol
    end

    ocp = OCP(t0, tf, x0)
    sol = SOL(ocp, t0, tf)

    return ocp, sol
end
