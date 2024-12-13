function test_dynamics()

    # Dynamics
    dynamics!(r, t, x, u, v) = r .= t .+ x .+ u .+ v

    # from PreModel
    ocp = CTModels.PreModel()
    CTModels.time!(ocp; t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.dynamics!(ocp, dynamics!)
    @test ocp.dynamics == dynamics!

    # Error: the dynamics has already been set
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp, dynamics!)

    # Error: the state must be set before the dynamics
    ocp = CTModels.PreModel()
    CTModels.time!(ocp; t0=0.0, tf=10.0)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp, dynamics!)

    # Error: the control must be set before the dynamics
    ocp = CTModels.PreModel()
    CTModels.time!(ocp; t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp, dynamics!)

    # Error: the times must be set before the dynamics
    ocp = CTModels.PreModel()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.dynamics!(ocp, dynamics!)

    # Error: the variable must not be set after the dynamics
    ocp = CTModels.PreModel()
    CTModels.time!(ocp; t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.dynamics!(ocp, dynamics!)
    @test_throws CTBase.UnauthorizedCall CTModels.variable!(ocp, 1)
end
