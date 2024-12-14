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
    mayer!(r, x0, xf, v) = r .= x0 .+ xf .+ v
    lagrange!(r, t, x, u, v) = r .= t .+ x .+ u .+ v
    CTModels.objective!(pre_ocp, :min; mayer=mayer!, lagrange=lagrange!)

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

    # set some constraints
    f_path(r, t, x, u, v) = r .= x .+ u .+ v .+ t
    f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)
    f_variable(r, t, v) = r .= v .+ t
    CTModels.constraint!(pre_ocp, :path; f=f_path, lb=[0, 1], ub=[1, 2], label=:path)
    CTModels.constraint!(
        pre_ocp, :boundary; f=f_boundary, lb=[0, 1], ub=[1, 2], label=:boundary
    )
    CTModels.constraint!(
        pre_ocp, :variable; f=f_variable, lb=[0, 1], ub=[1, 2], label=:variable
    )
    CTModels.constraint!(pre_ocp, :state; rg=1:2, lb=[0, 1], ub=[1, 2], label=:state_rg)
    CTModels.constraint!(pre_ocp, :control; rg=1:2, lb=[0, 1], ub=[1, 2], label=:control_rg)
    CTModels.constraint!(
        pre_ocp, :variable; rg=1:2, lb=[0, 1], ub=[1, 2], label=:variable_rg
    )

    # build the model
    model = CTModels.build_model(pre_ocp)

    # check the type of the model
    @test model isa CTModels.Model
end
