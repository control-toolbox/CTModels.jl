function test_times()

    #
    @test isconcretetype(CTModels.FixedTimeModel)
    @test isconcretetype(CTModels.FreeTimeModel)
    @test all_concrete(CTModels.TimesModel)

    # FixedTimeModel
    time = CTModels.FixedTimeModel(1.0, "s")
    @test CTModels.time(time) == 1.0
    @test CTModels.name(time) == "s"

    # FreeTimeModel
    time = CTModels.FreeTimeModel(1, "s")
    @test CTModels.index(time) == 1
    @test CTModels.name(time) == "s"

    # some checkings
    ocp = CTModels.OptimalControlModelMutable()
    @test isnothing(ocp.times)
    @test !CTModels.__is_times_set(ocp)
    CTModels.time!(ocp, t0=0.0, tf=10.0, time_name="s")
    @test CTModels.__is_times_set(ocp)
    @test CTModels.time_name(ocp.times) == "s"

    # time!
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0) # t0, tf fixed
    @test CTModels.initial_time(ocp.times) == 0.0
    @test CTModels.final_time(ocp.times) == 10.0

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0, time_name="s") # t0, tf fixed
    @test CTModels.time_name(ocp.times) == "s"

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 1)
    CTModels.time!(ocp, ind0=1, tf=10.0) # t0 free, tf fixed, scalar variable
    @test CTModels.initial_time(ocp.times, [0.0]) == 0.0

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 2)
    CTModels.time!(ocp, ind0=2, tf=10.0) # t0 free, tf fixed, vector variable
    @test CTModels.initial_time(ocp.times, [0.0, 1.0]) == 1.0

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 1)
    CTModels.time!(ocp, t0=0.0, indf=1) # t0 fixed, tf free, scalar variable
    @test CTModels.final_time(ocp.times, [10.0]) == 10.0

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 2)
    CTModels.time!(ocp, t0=0.0, indf=2) # t0 fixed, tf free, vector variable
    @test CTModels.final_time(ocp.times, [0.0, 1.0]) == 1.0

    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 2)
    CTModels.time!(ocp, ind0=1, indf=2) # t0 free, tf free, vector variable
    @test CTModels.initial_time(ocp.times, [0.0, 1.0]) == 0.0
    @test CTModels.final_time(ocp.times, [0.0, 1.0]) == 1.0

    # Exceptions
    
    # set twice
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.time!(ocp, t0=0.0, tf=10.0)
    @test_throws CTBase.UnauthorizedCall CTModels.time!(ocp, t0=0.0, tf=10.0)

    # if ind0 or indf is provided, the variable must be set
    ocp = CTModels.OptimalControlModelMutable()
    @test_throws CTBase.UnauthorizedCall CTModels.time!(ocp, ind0=1, tf=10.0)
    @test_throws CTBase.UnauthorizedCall CTModels.time!(ocp, t0=0.0, indf=1)
    @test_throws CTBase.UnauthorizedCall CTModels.time!(ocp, ind0=1, indf=2)

    # index must statisfy 1 <= index <= q
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 2)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, ind0=0, tf=10.0)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, ind0=3, tf=10.0)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, t0=0.0, indf=0)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, t0=0.0, indf=3)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, ind0=0, indf=3)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, ind0=3, indf=3)

    # consistency of function arguments
    ocp = CTModels.OptimalControlModelMutable()
    CTModels.variable!(ocp, 2)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, t0=0.0, ind0=1)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, tf=10.0, indf=1)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, t0=0.0, tf=10.0, ind0=1)
    @test_throws CTBase.IncorrectArgument CTModels.time!(ocp, t0=0.0, tf=10.0, indf=1)


end