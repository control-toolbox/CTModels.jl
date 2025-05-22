function test_model()

    # create a pre-model
    pre_ocp = CTModels.PreModel()

    # exception: times must be set
    @test_throws CTBase.UnauthorizedCall CTModels.build_model(pre_ocp)

    # set times
    CTModels.time!(pre_ocp; t0=0.0, tf=1.0)

    # exception: state must be set
    @test_throws CTBase.UnauthorizedCall CTModels.build_model(pre_ocp)

    # set state
    CTModels.state!(pre_ocp, 2)

    # exception: control must be set
    @test_throws CTBase.UnauthorizedCall CTModels.build_model(pre_ocp)

    # set control
    CTModels.control!(pre_ocp, 2)

    # set variable
    CTModels.variable!(pre_ocp, 2)

    # exception: dynamics must be set
    @test_throws CTBase.UnauthorizedCall CTModels.build_model(pre_ocp)

    # set dynamics
    dynamics!(r, t, x, u, v) = r .= t .+ x .+ u .+ v
    CTModels.dynamics!(pre_ocp, dynamics!)

    # exception: objective must be set
    @test_throws CTBase.UnauthorizedCall CTModels.build_model(pre_ocp)

    # set objective
    mayer(x0, xf, v) = x0 .+ xf .+ v
    lagrange(t, x, u, v) = t .+ x .+ u .+ v
    CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)

    # exception: definition must be set
    @test_throws CTBase.UnauthorizedCall CTModels.build_model(pre_ocp)

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
    CTModels.definition!(pre_ocp, definition)

    # exception: time dependence must be set
    @test_throws CTBase.UnauthorizedCall CTModels.build_model(pre_ocp)

    # set time dependence
    CTModels.time_dependence!(pre_ocp; autonomous=false)

    # set some constraints
    f_path(r, t, x, u, v) = r .= x .+ u .+ v .+ t
    f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)

    CTModels.constraint!(pre_ocp, :path; f=f_path, lb=[-0, -1], ub=[1, 2], label=:path)
    CTModels.constraint!(
        pre_ocp, :boundary; f=f_boundary, lb=[-2, -3], ub=[3, 4], label=:boundary
    )
    CTModels.constraint!(pre_ocp, :state; rg=1:2, lb=[-4, -5], ub=[5, 6], label=:state)
    CTModels.constraint!(pre_ocp, :control; rg=1:2, lb=[-6, -7], ub=[7, 8], label=:control)
    CTModels.constraint!(
        pre_ocp, :variable; rg=1:2, lb=[-8, -9], ub=[9, 10], label=:variable
    )

    f_path_scalar(r, t, x, u, v) = r .= x[1] + u[1] + v[1] + t
    f_boundary_scalar(r, x0, xf, v) = r .= x0[1] + v[1] * (xf[1] - x0[1])
    CTModels.constraint!(pre_ocp, :path; f=f_path_scalar, lb=-10, ub=11, label=:path_scalar)
    CTModels.constraint!(
        pre_ocp, :boundary; f=f_boundary_scalar, lb=-11, ub=12, label=:boundary_scalar
    )
    CTModels.constraint!(pre_ocp, :state; rg=1, lb=-12, ub=13, label=:state_scalar)
    CTModels.constraint!(pre_ocp, :control; rg=1, lb=-13, ub=14, label=:control_scalar)
    CTModels.constraint!(pre_ocp, :variable; rg=1, lb=-14, ub=15, label=:variable_scalar)
    CTModels.constraint!(pre_ocp, :state; rg=2, lb=-15, ub=16, label=:state_scalar_2)
    CTModels.constraint!(pre_ocp, :control; rg=2, lb=-16, ub=17, label=:control_scalar_2)
    CTModels.constraint!(pre_ocp, :variable; rg=2, lb=-17, ub=18, label=:variable_scalar_2)

    # build the model
    model = CTModels.build_model(pre_ocp)

    # check the type of the model
    @test model isa CTModels.Model

    # check retrieved constraints
    t = 1
    x = [2, 3]
    u = [4, 5]
    v = [6, 7]
    x0 = [1, 2]
    xf = [3, 4]

    # test the functions
    @test CTModels.constraint(model, :path)[2](t, x, u, v) == x .+ u .+ v .+ t
    @test CTModels.constraint(model, :boundary)[2](x0, xf, v) == x0 .+ v .* (xf .- x0)
    @test CTModels.constraint(model, :state)[2](t, x, u, v) == x
    @test CTModels.constraint(model, :control)[2](t, x, u, v) == u
    @test CTModels.constraint(model, :variable)[2](x0, xf, v) == v
    @test CTModels.constraint(model, :path_scalar)[2](t, x, u, v) == x[1] + u[1] + v[1] + t
    @test CTModels.constraint(model, :boundary_scalar)[2](x0, xf, v) ==
        x0[1] + v[1] * (xf[1] - x0[1])
    @test CTModels.constraint(model, :state_scalar)[2](t, x, u, v) == x[1]
    @test CTModels.constraint(model, :control_scalar)[2](t, x, u, v) == u[1]
    @test CTModels.constraint(model, :variable_scalar)[2](x0, xf, v) == v[1]
    @test CTModels.constraint(model, :state_scalar_2)[2](t, x, u, v) == x[2]
    @test CTModels.constraint(model, :control_scalar_2)[2](t, x, u, v) == u[2]
    @test CTModels.constraint(model, :variable_scalar_2)[2](x0, xf, v) == v[2]

    # test the type of the constraints
    @test CTModels.constraint(model, :path)[1] == :path
    @test CTModels.constraint(model, :boundary)[1] == :boundary
    @test CTModels.constraint(model, :state)[1] == :state
    @test CTModels.constraint(model, :control)[1] == :control
    @test CTModels.constraint(model, :variable)[1] == :variable
    @test CTModels.constraint(model, :path_scalar)[1] == :path
    @test CTModels.constraint(model, :boundary_scalar)[1] == :boundary
    @test CTModels.constraint(model, :state_scalar)[1] == :state
    @test CTModels.constraint(model, :control_scalar)[1] == :control
    @test CTModels.constraint(model, :variable_scalar)[1] == :variable
    @test CTModels.constraint(model, :state_scalar_2)[1] == :state
    @test CTModels.constraint(model, :control_scalar_2)[1] == :control
    @test CTModels.constraint(model, :variable_scalar_2)[1] == :variable

    # test the lower bounds
    @test CTModels.constraint(model, :path)[3] == [-0, -1]
    @test CTModels.constraint(model, :boundary)[3] == [-2, -3]
    @test CTModels.constraint(model, :state)[3] == [-4, -5]
    @test CTModels.constraint(model, :control)[3] == [-6, -7]
    @test CTModels.constraint(model, :variable)[3] == [-8, -9]
    @test CTModels.constraint(model, :path_scalar)[3] == -10
    @test CTModels.constraint(model, :boundary_scalar)[3] == -11
    @test CTModels.constraint(model, :state_scalar)[3] == -12
    @test CTModels.constraint(model, :control_scalar)[3] == -13
    @test CTModels.constraint(model, :variable_scalar)[3] == -14
    @test CTModels.constraint(model, :state_scalar_2)[3] == -15
    @test CTModels.constraint(model, :control_scalar_2)[3] == -16
    @test CTModels.constraint(model, :variable_scalar_2)[3] == -17

    # test the upper bounds
    @test CTModels.constraint(model, :path)[4] == [1, 2]
    @test CTModels.constraint(model, :boundary)[4] == [3, 4]
    @test CTModels.constraint(model, :state)[4] == [5, 6]
    @test CTModels.constraint(model, :control)[4] == [7, 8]
    @test CTModels.constraint(model, :variable)[4] == [9, 10]
    @test CTModels.constraint(model, :path_scalar)[4] == 11
    @test CTModels.constraint(model, :boundary_scalar)[4] == 12
    @test CTModels.constraint(model, :state_scalar)[4] == 13
    @test CTModels.constraint(model, :control_scalar)[4] == 14
    @test CTModels.constraint(model, :variable_scalar)[4] == 15
    @test CTModels.constraint(model, :state_scalar_2)[4] == 16
    @test CTModels.constraint(model, :control_scalar_2)[4] == 17
    @test CTModels.constraint(model, :variable_scalar_2)[4] == 18

    # print the premodel
    display(pre_ocp)

    # -------------------------------------------------------------------------- #
    # Just for printing
    #
    pre_ocp = CTModels.PreModel()
    CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
    CTModels.state!(pre_ocp, 1, "y", ["y"])
    CTModels.control!(pre_ocp, 1, "u", ["u"])
    CTModels.variable!(pre_ocp, 1, "v", ["v"])
    CTModels.dynamics!(pre_ocp, dynamics!)
    CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)
    CTModels.definition!(pre_ocp, quote end)
    display(pre_ocp)

    #
    pre_ocp = CTModels.PreModel()
    CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
    CTModels.state!(pre_ocp, 2, "y", ["q", "p"])
    CTModels.control!(pre_ocp, 2, "u", ["w", "z"])
    CTModels.variable!(pre_ocp, 2, "v", ["c", "d"])
    CTModels.dynamics!(pre_ocp, dynamics!)
    CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)
    CTModels.definition!(pre_ocp, quote end)
    display(pre_ocp)
end
