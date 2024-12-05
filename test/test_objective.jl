function test_objective()

    # is concretetype    
    @test isconcretetype(CTModels.Mayer{Function, Val, Val}) # Mayer
    @test isconcretetype(CTModels.Lagrange{Function, Val, Val, Val}) # Lagrange
    @test isconcretetype(CTModels.MayerObjectiveModel{CTModels.Mayer{Function, Val, Val}}) # MayerObjectiveModel
    @test isconcretetype(CTModels.LagrangeObjectiveModel{CTModels.Lagrange{Function, Val, Val, Val}}) # LagrangeObjectiveModel
    @test isconcretetype(CTModels.BolzaObjectiveModel{
        CTModels.Mayer{Function, Val, Val},
        CTModels.Lagrange{Function, Val, Val, Val}}) # BolzaObjectiveModel

    # Mayer function: basic test
    mayer!(r, x0, xf, v) = r .= x0 .+ xf .+ v
    mayer = CTModels.Mayer(mayer!, 1, 1)
    x0 = [1.0]
    xf = [2.0]
    v = [3.0]
    r = similar(x0)
    mayer!(r, x0, xf, v)
    @test r == [6.0]

    # Lagrange function: basic test
    lagrange!(r, t, x, u, v) = r .= t .+ x .+ u .+ v
    lagrange = CTModels.Lagrange(lagrange!, 1, 1, 1)
    t = 1.0
    x = [2.0]
    u = [3.0]
    v = [4.0]
    r = similar(x)
    lagrange!(r, t, x, u, v)
    @test r == [10.0]

    # MayerObjectiveModel
    objective = CTModels.MayerObjectiveModel(mayer, :min)
    @test CTModels.mayer(objective) == mayer
    @test CTModels.criterion(objective) == :min
    @test CTModels.has_mayer_cost(objective) == true
    @test CTModels.has_lagrange_cost(objective) == false
    @test_throws CTBase.UnauthorizedCall CTModels.lagrange(objective)

    # LagrangeObjectiveModel
    objective = CTModels.LagrangeObjectiveModel(lagrange, :max)
    @test CTModels.lagrange(objective) == lagrange
    @test CTModels.criterion(objective) == :max
    @test CTModels.has_mayer_cost(objective) == false
    @test CTModels.has_lagrange_cost(objective) == true
    @test_throws CTBase.UnauthorizedCall CTModels.mayer(objective)

    # BolzaObjectiveModel
    objective = CTModels.BolzaObjectiveModel(mayer, lagrange, :min)
    @test CTModels.mayer(objective) == mayer
    @test CTModels.lagrange(objective) == lagrange
    @test CTModels.criterion(objective) == :min
    @test CTModels.has_mayer_cost(objective) == true
    @test CTModels.has_lagrange_cost(objective) == true

    # from OptimalControlModelMutable with Mayer objective
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.objective!(ocp, :min, mayer=mayer!)
    @test ocp.objective == CTModels.MayerObjectiveModel(mayer, :min)
    @test CTModels.criterion(ocp.objective) == :min
    @test CTModels.has_mayer_cost(ocp.objective) == true
    @test CTModels.has_lagrange_cost(ocp.objective) == false
    @test_throws CTBase.UnauthorizedCall CTModels.lagrange(ocp.objective)

    # from OptimalControlModelMutable with Lagrange objective
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.objective!(ocp, :max, lagrange=lagrange!)
    @test ocp.objective == CTModels.LagrangeObjectiveModel(lagrange, :max)
    @test CTModels.criterion(ocp.objective) == :max
    @test CTModels.has_mayer_cost(ocp.objective) == false
    @test CTModels.has_lagrange_cost(ocp.objective) == true
    @test_throws CTBase.UnauthorizedCall CTModels.mayer(ocp.objective)

    # from OptimalControlModelMutable with Bolza objective
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.objective!(ocp, :min, mayer=mayer!, lagrange=lagrange!)
    @test ocp.objective == CTModels.BolzaObjectiveModel(mayer, lagrange, :min)
    @test CTModels.criterion(ocp.objective) == :min
    @test CTModels.has_mayer_cost(ocp.objective) == true
    @test CTModels.has_lagrange_cost(ocp.objective) == true

    # exceptions
    # state not set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.objective!(ocp, :min, mayer=mayer!)

    # control not set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.UnauthorizedCall CTModels.objective!(ocp, :min, mayer=mayer!)

    # objective already set
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    CTModels.objective!(ocp, :min, mayer=mayer!)
    @test_throws CTBase.UnauthorizedCall CTModels.objective!(ocp, :min, mayer=mayer!)

    # variable set after the objective
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.objective!(ocp, :min, mayer=mayer!)
    @test_throws CTBase.UnauthorizedCall CTModels.variable!(ocp, 1)

    # no function given
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.state!(ocp, 1)
    CTModels.control!(ocp, 1)
    CTModels.variable!(ocp, 1)
    @test_throws CTBase.IncorrectArgument CTModels.objective!(ocp, :min)

    # Mayer function, different dimensions: n = 1 or n > 1, and q = 0, 1 or q > 1
    # n = 1, q = 1
    function mayer_1(r, x0, xf, v) 
        @test size(r) == (1,)
        @test x0 isa Real
        @test xf isa Real
        @test v isa Real
        r .= x0 .+ xf .+ v
    end
    mayer = CTModels.Mayer(mayer_1, 1, 1)
    x0 = [1.0]
    xf = [2.0]
    v = [3.0]
    r = similar(x0)
    mayer(r, x0, xf, v)
    @test r == [6.0]

    # n > 1, q = 1
    function mayer_2(r, x0, xf, v) 
        @test size(r) == (1,)
        @test x0 isa AbstractVector
        @test xf isa AbstractVector
        @test v isa Real
        r .= sum(x0) + sum(xf) + v
    end
    mayer = CTModels.Mayer(mayer_2, 2, 1)
    x0 = [1.0, 2.0]
    xf = [3.0, 4.0]
    v = [5.0]
    r = similar(x0, 1)
    mayer(r, x0, xf, v)
    @test r == [15.0]

    # n = 1, q > 1
    function mayer_3(r, x0, xf, v) 
        @test size(r) == (1,)
        @test x0 isa Real
        @test xf isa Real
        @test v isa AbstractVector
        r .= x0 .+ xf .+ sum(v)
    end
    mayer = CTModels.Mayer(mayer_3, 1, 2)
    x0 = [1.0]
    xf = [2.0]
    v = [3.0, 4.0]
    r = similar(x0)
    mayer(r, x0, xf, v)
    @test r == [10.0]

    # n > 1, q > 1
    function mayer_4(r, x0, xf, v) 
        @test size(r) == (1,)
        @test x0 isa AbstractVector
        @test xf isa AbstractVector
        @test v isa AbstractVector
        r .= sum(x0) + sum(xf) + sum(v)
    end
    mayer = CTModels.Mayer(mayer_4, 2, 2)
    x0 = [1.0, 2.0]
    xf = [3.0, 4.0]
    v = [5.0, 6.0]
    r = similar(x0, 1)
    mayer(r, x0, xf, v)
    @test r == [21.0]

    # n = 1, q = 0
    function mayer_5(r, x0, xf) 
        @test size(r) == (1,)
        @test x0 isa Real
        @test xf isa Real
        r .= x0 .+ xf
    end
    mayer = CTModels.Mayer(mayer_5, 1, 0)
    x0 = [1.0]
    xf = [2.0]
    r = similar(x0)
    mayer(r, x0, xf, Float64[])
    @test r == [3.0]

    # n > 1, q = 0
    function mayer_6(r, x0, xf) 
        @test size(r) == (1,)
        @test x0 isa AbstractVector
        @test xf isa AbstractVector
        r .= sum(x0) + sum(xf)
    end
    mayer = CTModels.Mayer(mayer_6, 2, 0)
    x0 = [1.0, 2.0]
    xf = [3.0, 4.0]
    r = similar(x0, 1)
    mayer(r, x0, xf, Float64[])
    @test r == [10.0]

end