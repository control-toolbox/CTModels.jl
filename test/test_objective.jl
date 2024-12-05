function test_objective()

    # is concretetype    
    @test isconcretetype(CTModels.MayerObjectiveModel{Function}) # MayerObjectiveModel
    @test isconcretetype(CTModels.LagrangeObjectiveModel{Function}) # LagrangeObjectiveModel
    @test isconcretetype(CTModels.BolzaObjectiveModel{Function, Function}) # BolzaObjectiveModel

    # Functions
    mayer!(r, x0, xf, v) = r .= x0 .+ xf .+ v
    lagrange!(r, t, x, u, v) = r .= t .+ x .+ u .+ v

    # MayerObjectiveModel
    objective = CTModels.MayerObjectiveModel(mayer!, :min)
    @test CTModels.mayer(objective) == mayer!
    @test CTModels.criterion(objective) == :min
    @test CTModels.has_mayer_cost(objective) == true
    @test CTModels.has_lagrange_cost(objective) == false
    @test_throws CTBase.UnauthorizedCall CTModels.lagrange(objective)

    # LagrangeObjectiveModel
    objective = CTModels.LagrangeObjectiveModel(lagrange!, :max)
    @test CTModels.lagrange(objective) == lagrange!
    @test CTModels.criterion(objective) == :max
    @test CTModels.has_mayer_cost(objective) == false
    @test CTModels.has_lagrange_cost(objective) == true
    @test_throws CTBase.UnauthorizedCall CTModels.mayer(objective)

    # BolzaObjectiveModel
    objective = CTModels.BolzaObjectiveModel(mayer!, lagrange!, :min)
    @test CTModels.mayer(objective) == mayer!
    @test CTModels.lagrange(objective) == lagrange!
    @test CTModels.criterion(objective) == :min
    @test CTModels.has_mayer_cost(objective) == true
    @test CTModels.has_lagrange_cost(objective) == true

    # from OptimalControlModelMutable with Mayer objective
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.objective!(ocp, :min, mayer=mayer!)
    @test ocp.objective == CTModels.MayerObjectiveModel(mayer!, :min)
    @test CTModels.criterion(ocp.objective) == :min
    @test CTModels.has_mayer_cost(ocp.objective) == true
    @test CTModels.has_lagrange_cost(ocp.objective) == false
    @test_throws CTBase.UnauthorizedCall CTModels.lagrange(ocp.objective)

    # from OptimalControlModelMutable with Lagrange objective
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.objective!(ocp, :max, lagrange=lagrange!)
    @test ocp.objective == CTModels.LagrangeObjectiveModel(lagrange!, :max)
    @test CTModels.criterion(ocp.objective) == :max
    @test CTModels.has_mayer_cost(ocp.objective) == false
    @test CTModels.has_lagrange_cost(ocp.objective) == true
    @test_throws CTBase.UnauthorizedCall CTModels.mayer(ocp.objective)

    # from OptimalControlModelMutable with Bolza objective
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.objective!(ocp, :min, mayer=mayer!, lagrange=lagrange!)
    @test ocp.objective == CTModels.BolzaObjectiveModel(mayer!, lagrange!, :min)
    @test CTModels.criterion(ocp.objective) == :min
    @test CTModels.has_mayer_cost(ocp.objective) == true
    @test CTModels.has_lagrange_cost(ocp.objective) == true

    # exceptions
    # state not set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.objective!(ocp, :min, mayer=mayer!)

    # control not set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.objective!(ocp, :min, mayer=mayer!)

    # times not set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.objective!(ocp, :min, mayer=mayer!)

    # objective already set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.objective!(ocp, :min, mayer=mayer!)
    @test_throws CTBase.UnauthorizedCall CTModels.objective!(ocp, :min, mayer=mayer!)

    # variable set after the objective
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.objective!(ocp, :min, mayer=mayer!)
    @test_throws CTBase.UnauthorizedCall CTModels.variable!(ocp, 1)

    # no function given
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.IncorrectArgument CTModels.objective!(ocp, :min)

end