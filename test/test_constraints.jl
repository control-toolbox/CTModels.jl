function test_constraints()
    ∅ = Vector{Float64}()

    # From PreModel
    ocp_set = CTModels.PreModel()
    CTModels.time!(ocp_set; t0=0.0, tf=10.0)
    CTModels.state!(ocp_set, 2)
    CTModels.control!(ocp_set, 1)
    CTModels.variable!(ocp_set, 1)

    # state not set
    ocp = CTModels.PreModel()
    CTModels.time!(ocp; t0=0.0, tf=10.0)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp, :dummy)

    # control not set
    ocp = CTModels.PreModel()
    CTModels.time!(ocp; t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp, :dummy)

    # times not set
    ocp = CTModels.PreModel()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp, :dummy)

    # variable not set and try to add a :variable constraint
    ocp = CTModels.PreModel()
    CTModels.time!(ocp; t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp, :variable)

    # lb and ub cannot be both nothing
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp_set, :state)

    # twice the same label for two constraints
    CTModels.constraint!(ocp_set, :state; lb=[0, 1], label=:cons)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(
        ocp_set, :control, lb=[0, 1], label=:cons
    )

    # lb and ub must have the same length
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :state, lb=[0, 1], ub=[0, 1, 2]
    )

    # if no range nor function is provided, lb and ub must have the right length:
    # depending on state, control, or variable
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :state, lb=[0, 1, 2]
    )
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :control, lb=[0, 1, 2]
    )
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :variable, lb=[0, 1, 2]
    )
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :state, ub=[0, 1, 2]
    )
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :control, ub=[0, 1, 2]
    )
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :variable, ub=[0, 1, 2]
    )

    # if no range nor function is provided, the only possible constraints are 
    # :state, :control, and :variable
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :dummy, lb=[0], ub=[1]
    )

    # if a range is provided, lb and ub must have the same length as the range
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :state, rg=1:2, lb=[0], ub=[1]
    )

    # if a range is provided, it must be consistent with the dimensions of the model
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :state, rg=3:4, lb=[0, 1], ub=[1, 2]
    )
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :control, rg=2:3, lb=[0, 1], ub=[1, 2]
    )
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :variable, rg=2:3, lb=[0, 1], ub=[1, 2]
    )

    # if a range is provided, the only possible constraints are :state, :control, and :variable
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :dummy, rg=1:2, lb=[0, 1], ub=[1, 2]
    )

    # if a function is provided, the only possible constraints are :path, :boundary and :variable
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :dummy, f=(x, y) -> x + y, lb=[0, 1], ub=[1, 2]
    )

    # we cannot provide a function and a range
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(
        ocp_set, :variable, f=(x, y) -> x + y, rg=1:2, lb=[0, 1], ub=[1, 2]
    )

    # test with :path constraint
    f_path(r, t, x, u, v) = r .= x .+ u .+ v .+ t
    CTModels.constraint!(ocp_set, :path; f=f_path, lb=[0, 1], ub=[1, 2], label=:path)
    @test ocp_set.constraints[:path] == (:path, f_path, [0, 1], [1, 2])

    # test with :boundary constraint
    f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)
    CTModels.constraint!(
        ocp_set, :boundary; f=f_boundary, lb=[0, 1], ub=[1, 2], label=:boundary
    )
    @test ocp_set.constraints[:boundary] == (:boundary, f_boundary, [0, 1], [1, 2])

    # test with :state constraint and range
    CTModels.constraint!(ocp_set, :state; rg=1:2, lb=[0, 1], ub=[1, 2], label=:state_rg)
    @test ocp_set.constraints[:state_rg] == (:state, 1:2, [0, 1], [1, 2])

    # test with :control constraint and range
    CTModels.constraint!(ocp_set, :control; rg=1:1, lb=[1], ub=[1], label=:control_rg)
    @test ocp_set.constraints[:control_rg] == (:control, 1:1, [1], [1])

    # test with :variable constraint and range
    CTModels.constraint!(ocp_set, :variable; rg=1:1, lb=[1], ub=[1], label=:variable_rg)
    @test ocp_set.constraints[:variable_rg] == (:variable, 1:1, [1], [1])
end
