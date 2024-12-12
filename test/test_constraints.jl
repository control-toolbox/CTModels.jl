function test_constraints()

    ∅ = Vector{Real}()

    # From OptimalControlModelMutable
    ocp_set = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp_set, t0=0.0, tf=10.0)
    CTModels.state!(ocp_set, 2)
    CTModels.control!(ocp_set, 1)
    CTModels.variable!(ocp_set, 1)

    # state not set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp, :dummy)

    # control not set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp, :dummy)

    # times not set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp, :dummy)

    # variable not set and try to add a :variable constraint
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp, :variable)

    # lb and ub cannot be both nothing
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp_set, :state)

    # twice the same label for two constraints
    CTModels.constraint!(ocp_set, :state, lb=[0, 1], label=:cons)
    @test_throws CTBase.UnauthorizedCall CTModels.constraint!(ocp_set, :control, lb=[0, 1], label=:cons)

    # lb and ub must have the same length
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :state, lb=[0, 1], ub=[0, 1, 2])

    # if no range nor function is provided, lb and ub must have the right length:
    # depending on state, control, or variable
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :state, lb=[0, 1, 2])
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :control, lb=[0, 1, 2])
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :variable, lb=[0, 1, 2])
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :state, ub=[0, 1, 2])
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :control, ub=[0, 1, 2])
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :variable, ub=[0, 1, 2])

    # if no range nor function is provided, the only possible constraints are 
    # :state, :control, and :variable
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :dummy, lb=[0], ub=[1])

    # if a range is provided, lb and ub must have the same length as the range
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :state, rg=1:2, lb=[0], ub=[1])

    # if a range is provided, it must be consistent with the dimensions of the model
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :state, rg=3:4, lb=[0, 1], ub=[1, 2])
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :control, rg=2:3, lb=[0, 1], ub=[1, 2])
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :variable, rg=2:3, lb=[0, 1], ub=[1, 2])

    # if a range is provided, the only possible constraints are :state, :control, and :variable
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :dummy, rg=1:2, lb=[0, 1], ub=[1, 2])

    # if a function is provided, the only possible constraints are :boundary, :control, :state, :variable and :mixed
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :dummy, f=(x, y) -> x + y, lb=[0, 1], ub=[1, 2])

    # we cannot provide a function and a range
    @test_throws CTBase.IncorrectArgument CTModels.constraint!(ocp_set, :state, f=(x, y) -> x + y, rg=1:2, lb=[0, 1], ub=[1, 2])

    # test with :boundary constraint
    f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)
    CTModels.constraint!(ocp_set, :boundary, f=f_boundary, lb=[0, 1], ub=[1, 2], label=:boundary)
    @test ocp_set.constraints[:boundary] == (:boundary, f_boundary, [0, 1], [1, 2])

    # test with :state constraint
    f_state(r, t, x) = r .= x .+ t
    CTModels.constraint!(ocp_set, :state, f=f_state, lb=[0, 1], ub=[1, 2], label=:state)
    @test ocp_set.constraints[:state] == (:state, f_state, [0, 1], [1, 2])

    # test with :control constraint
    f_control(r, t, u) = r .= u .+ t
    CTModels.constraint!(ocp_set, :control, f=f_control, lb=[0, 1], ub=[1, 2], label=:control)
    @test ocp_set.constraints[:control] == (:control, f_control, [0, 1], [1, 2])

    # test with :variable constraint
    f_variable(r, t, v) = r .= v .+ t
    CTModels.constraint!(ocp_set, :variable, f=f_variable, lb=[0, 1], ub=[1, 2], label=:variable)
    @test ocp_set.constraints[:variable] == (:variable, f_variable, [0, 1], [1, 2])

    # test with :mixed constraint
    f_mixed(r, t, x, u, v) = r .= x .+ u .+ v .+ t
    CTModels.constraint!(ocp_set, :mixed, f=f_mixed, lb=[0, 1], ub=[1, 2], label=:mixed)
    @test ocp_set.constraints[:mixed] == (:mixed, f_mixed, [0, 1], [1, 2])

    # test with :state constraint and range
    CTModels.constraint!(ocp_set, :state, rg=1:2, lb=[0, 1], ub=[1, 2], label=:state_rg)
    @test ocp_set.constraints[:state_rg] == (:state, 1:2, [0, 1], [1, 2])

    # test with :control constraint and range
    CTModels.constraint!(ocp_set, :control, rg=1:1, lb=[1], ub=[1], label=:control_rg)
    @test ocp_set.constraints[:control_rg] == (:control, 1:1, [1], [1])

    # test with :variable constraint and range
    CTModels.constraint!(ocp_set, :variable, rg=1:1, lb=[1], ub=[1], label=:variable_rg)
    @test ocp_set.constraints[:variable_rg] == (:variable, 1:1, [1], [1])

end