function test_partial_dynamics()

    # Sample full dynamics function for comparison
    function full_dynamics!(r, t, x, u, v) 
        r[1] = t + x[1]
        r[2] = u[1] + x[2]
        r[3] = v[1] + x[3]
        return r
    end
    
    # Partial dynamics function examples (simple for testing)
    partial_dyn_1!(r, t, x, u, v) = (r[1] = t + x[1])
    partial_dyn_2!(r, t, x, u, v) = (r[1] = u[1] + x[2])
    partial_dyn_3!(r, t, x, u, v) = (r[1] = v[1] + x[3])
    
    partial_dyn_12!(r, t, x, u, v) = (r[1] = t + x[1]; r[2] = u[1] + x[2])
    partial_dyn_23!(r, t, x, u, v) = (r[1] = u[1] + x[2]; r[2] = v[1] + x[3])

    ######
    # 1. Setup common parameters and helper for test evaluations
    ######
    n_states = 3
    ocp = CTModels.PreModel()
    CTModels.time!(ocp; t0=0.0, tf=1.0)
    CTModels.state!(ocp, n_states)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    
    # Dummy variables for evaluating dynamics
    r = zeros(n_states)
    t = 10
    x = 20*ones(n_states)
    u = 100*ones(1)
    v = 1000*ones(1)

    ######
    # 2. Add index-by-index in order, then evaluate vs full function
    ######
    ocp1 = deepcopy(ocp)
    CTModels.dynamics!(ocp1, 1:1, partial_dyn_1!)
    CTModels.dynamics!(ocp1, 2:2, partial_dyn_2!)
    CTModels.dynamics!(ocp1, 3:3, partial_dyn_3!)
    @test length(ocp1.dynamics) == n_states

    # Evaluate partial dynamics and collect result vector
    r_partial = zeros(n_states)
    for (rg, f) in ocp1.dynamics
        f((@view r_partial[rg]), t, x, u, v)
    end

    # Evaluate full dynamics and compare
    r_full = zeros(n_states)
    full_dynamics!(r_full, t, x, u, v)
    @test r_partial == r_full

    # Evaluate after building
    f_from_parts! = CTModels.__build_dynamics_from_parts(ocp1.dynamics)
    r_partial = zeros(n_states)
    f_from_parts!(r_partial, t, x, u, v)
    @test r_partial == r_full

    ######
    # 3. Add index-by-index out of order, then evaluate vs full function
    ######
    ocp2 = deepcopy(ocp)
    CTModels.dynamics!(ocp2, 3:3, partial_dyn_3!)
    CTModels.dynamics!(ocp2, 1:1, partial_dyn_1!)
    CTModels.dynamics!(ocp2, 2:2, partial_dyn_2!)
    @test length(ocp2.dynamics) == n_states

    r_partial = zeros(n_states)
    for (rg, f) in ocp2.dynamics
        f((@view r_partial[rg]), t, x, u, v)
    end

    r_full = zeros(n_states)
    full_dynamics!(r_full, t, x, u, v)
    @test r_partial == r_full

    f_from_parts! = CTModels.__build_dynamics_from_parts(ocp2.dynamics)
    r_partial = zeros(n_states)
    f_from_parts!(r_partial, t, x, u, v)
    @test r_partial == r_full

    ######
    # 4. Add by ranges in order, evaluate vs full function
    ######
    ocp3 = deepcopy(ocp)
    CTModels.dynamics!(ocp3, 1:2, partial_dyn_12!)
    CTModels.dynamics!(ocp3, 3:3, partial_dyn_3!)
    @test length(ocp3.dynamics) == 2

    r_partial = zeros(n_states)
    for (rg, f) in ocp3.dynamics
        f((@view r_partial[rg]), t, x, u, v)
    end

    r_full = zeros(n_states)
    full_dynamics!(r_full, t, x, u, v)
    @test r_partial == r_full

    f_from_parts! = CTModels.__build_dynamics_from_parts(ocp3.dynamics)
    r_partial = zeros(n_states)
    f_from_parts!(r_partial, t, x, u, v)
    @test r_partial == r_full

    ######
    # 5. Add by ranges out of order, evaluate vs full function
    ######
    ocp4 = deepcopy(ocp)
    CTModels.dynamics!(ocp4, 2:3, partial_dyn_23!)
    CTModels.dynamics!(ocp4, 1:1, partial_dyn_1!)
    @test length(ocp4.dynamics) == 2

    r_partial = zeros(n_states)
    for (rg, f) in ocp4.dynamics
        f((@view r_partial[rg]), t, x, u, v)
    end

    r_full = zeros(n_states)
    full_dynamics!(r_full, t, x, u, v)
    @test r_partial == r_full

    f_from_parts! = CTModels.__build_dynamics_from_parts(ocp3.dynamics)
    r_partial = zeros(n_states)
    f_from_parts!(r_partial, t, x, u, v)
    @test r_partial == r_full
    
    ######
    # 6. Error: start with adding index or range then add full dynamics function -> error
    ######
    ocp5 = deepcopy(ocp)
    CTModels.dynamics!(ocp5, 1:1, partial_dyn_1!)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp5, full_dynamics!)

    ocp6 = deepcopy(ocp)
    CTModels.dynamics!(ocp6, 1:2, (r,t,x,u,v)->(r[1]=0;r[2]=0))
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp6, full_dynamics!)

    ######
    # 7. Error: add index out of range (< 1 or > n_states)
    ######
    ocp7 = deepcopy(ocp)
    @test_throws CTBase.IncorrectArgument CTModels.dynamics!(ocp7, 0:0, partial_dyn_1!)
    @test_throws CTBase.IncorrectArgument CTModels.dynamics!(ocp7, -1:-1, partial_dyn_1!)
    @test_throws CTBase.IncorrectArgument CTModels.dynamics!(ocp7, (n_states+1):(n_states+1), partial_dyn_1!)

    ######
    # 8. Error: add range with at least one index out of range
    ######
    ocp8 = deepcopy(ocp)
    @test_throws CTBase.IncorrectArgument CTModels.dynamics!(ocp8, (n_states):(n_states+1), partial_dyn_1!)

    ######
    # 9. Error: add twice the same index in one range
    ######
    ocp9 = deepcopy(ocp)
    CTModels.dynamics!(ocp9, 2:2, partial_dyn_1!)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp9, 1:2, partial_dyn_1!)

    ######
    # 10. Error: add twice the same index in two different ranges
    ######
    ocp10 = deepcopy(ocp)
    CTModels.dynamics!(ocp10, 1:2, (r,t,x,u,v) -> (r[1]=t; r[2]=u[1]))
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp10, 2:3, (r,t,x,u,v) -> (r[2]=0; r[3]=0))

    ######
    # 11. Error: prerequisite checks for partial dynamics (missing state, control, times)
    ######
    ocp_missing = CTModels.PreModel()
    CTModels.time!(ocp_missing; t0=0.0, tf=10.0)
    CTModels.control!(ocp_missing, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp_missing, 1:1, partial_dyn_1!)

    ocp_missing = CTModels.PreModel()
    CTModels.time!(ocp_missing; t0=0.0, tf=10.0)
    CTModels.state!(ocp_missing, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp_missing, 1:1, partial_dyn_1!)

    ocp_missing = CTModels.PreModel()
    CTModels.state!(ocp_missing, 1)
    CTModels.control!(ocp_missing, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp_missing, 1:1, partial_dyn_1!)

    # variable must NOT be set after dynamics
    ocp_variable = CTModels.PreModel()
    CTModels.time!(ocp_variable; t0=0.0, tf=10.0)
    CTModels.state!(ocp_variable, 3)
    CTModels.control!(ocp_variable, 1)
    CTModels.dynamics!(ocp_variable, 1:3, full_dynamics!)
    @test_throws CTBase.UnauthorizedCall CTModels.variable!(ocp_variable, 1)
end

function test_full_dynamics()

    # Sample full dynamics function
    dynamics!(r, t, x, u, v) = r .= t .+ x .+ u .+ v

    ######
    # 1. Success case: full dynamics set properly
    ######
    ocp = CTModels.PreModel()
    CTModels.time!(ocp; t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.dynamics!(ocp, dynamics!)
    @test ocp.dynamics == dynamics!

    ######
    # 2. Error: set full dynamics twice not allowed
    ######
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp, dynamics!)

    ######
    # 3. Error: state must be set before dynamics
    ######
    ocp2 = CTModels.PreModel()
    CTModels.time!(ocp2; t0=0.0, tf=10.0)
    CTModels.control!(ocp2, 1)
    CTModels.variable!(ocp2, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp2, dynamics!)

    ######
    # 4. Error: control must be set before dynamics
    ######
    ocp3 = CTModels.PreModel()
    CTModels.time!(ocp3; t0=0.0, tf=10.0)
    CTModels.state!(ocp3, 1)
    CTModels.variable!(ocp3, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp3, dynamics!)

    ######
    # 5. Error: time must be set before dynamics
    ######
    ocp4 = CTModels.PreModel()
    CTModels.state!(ocp4, 1)
    CTModels.control!(ocp4, 1)
    CTModels.variable!(ocp4, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp4, dynamics!)

    ######
    # 6. Error: variable must NOT be set after dynamics
    ######
    ocp5 = CTModels.PreModel()
    CTModels.time!(ocp5; t0=0.0, tf=10.0)
    CTModels.state!(ocp5, 1)
    CTModels.control!(ocp5, 1)
    CTModels.dynamics!(ocp5, dynamics!)
    @test_throws CTBase.UnauthorizedCall CTModels.variable!(ocp5, 1)

    ######
    # 7. Error: mixing full dynamics and partial dynamics not allowed
    ######
    ocp6 = CTModels.PreModel()
    CTModels.time!(ocp6; t0=0.0, tf=10.0)
    CTModels.state!(ocp6, 2)
    CTModels.control!(ocp6, 1)
    CTModels.variable!(ocp6, 1)
    CTModels.dynamics!(ocp6, dynamics!)

    # Attempt to add partial dynamics after full dynamics -> error
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp6, 1:1, (r,t,x,u,v)->(r[1]=0))

    # New ocp for partial dynamics first, then full -> error
    ocp7 = CTModels.PreModel()
    CTModels.time!(ocp7; t0=0.0, tf=10.0)
    CTModels.state!(ocp7, 2)
    CTModels.control!(ocp7, 1)
    CTModels.variable!(ocp7, 1)
    CTModels.dynamics!(ocp7, 1:1, (r,t,x,u,v)->(r[1]=0))
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp7, dynamics!)
end

function test_dynamics()
    test_full_dynamics()
    test_partial_dynamics()
end
