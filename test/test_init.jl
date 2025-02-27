function test_init()
    
    # test checkDim function
    @test_throws Exception CTModels.checkDim(1, 2)
    
    # test isaVectVect function
    # Return true if argument is a vector of vectors
    @test CTModels.isaVectVect([[1, 2], [3, 4]])
    @test !CTModels.isaVectVect([1, 2, 3, 4])

    # test formatData function
    # Convert matrix to vector of vectors (could be expanded)
    @test CTModels.formatData([[1, 2], [3, 4]]) == [[1, 2], [3, 4]]
    @test CTModels.formatData([1, 2, 3, 4]) == [1, 2, 3, 4]

    # test formatTimeGrid function
    # Convert matrix time-grid to vector
    @test CTModels.formatTimeGrid([1, 2, 3, 4]) == [1, 2, 3, 4]
    @test CTModels.formatTimeGrid(nothing) === nothing
    @test CTModels.formatTimeGrid([[1, 2]; [3, 4]]) == [1, 2, 3, 4]
    @test CTModels.formatTimeGrid([[1, 2], [3, 4]]) == [[1, 2], [3, 4]]

    # test buildFunctionalInit function
    # Build functional initialization: default case
    @test CTModels.buildFunctionalInit(nothing, range(0, 1, 11), 2)(0) === nothing

    # Build functional initialization: function case
    @test CTModels.buildFunctionalInit(t -> [t, t^2], range(0, 1, 11), 2)(0) == [0, 0]
    @test_throws Exception CTModels.buildFunctionalInit(t -> [t, t^2], range(0, 1, 11), 1)(0)

    # test buildFunctionalInit function: general interpolation case
    # Build functional initialization: general interpolation case
    @test CTModels.buildFunctionalInit([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], range(0, 1, 11), 1)(0) == 0
    
    # construction of Init

    # constant initial guess
    x_const = [0.5, 0.2]
    u_const = 0.5
    v_const = 0.15

    # functional initial guess
    x_func = t -> [t^2, sqrt(t)]
    u_func = t -> (cos(10 * t) + 1) * 0.5

    # interpolated initial guess
    x_vec = [[0, 0], [1, 2], [5, -1]]
    x_matrix = [0 0; 1 2; 5 -1]
    u_vec = [0, 0.3, 0.1]    
    t_vec = [0, 0.1, 0.2]

    init = (state = x_const,)
    @test CTModels.Init(init; state_dim=2, control_dim=1, variable_dim=1) isa CTModels.Init

    init = (state = x_const, control = u_const)
    @test CTModels.Init(init; state_dim=2, control_dim=1, variable_dim=1) isa CTModels.Init

    init = (state = x_const, control = u_const, variable = v_const)
    @test CTModels.Init(init; state_dim=2, control_dim=1, variable_dim=1) isa CTModels.Init

    init = (state = x_func,)
    @test CTModels.Init(init; state_dim=2, control_dim=1, variable_dim=1) isa CTModels.Init

    init = (state = x_func, control = u_func)
    @test CTModels.Init(init; state_dim=2, control_dim=1, variable_dim=1) isa CTModels.Init

    init = (state = x_func, control = u_func, variable = v_const)
    @test CTModels.Init(init; state_dim=2, control_dim=1, variable_dim=1) isa CTModels.Init

    init = (time = t_vec, state = x_vec)
    @test CTModels.Init(init; state_dim=2, control_dim=1, variable_dim=1) isa CTModels.Init

    init = (time = t_vec, state = x_vec, control = u_vec)
    @test CTModels.Init(init; state_dim=2, control_dim=1, variable_dim=1) isa CTModels.Init

    init = (time = t_vec, state = x_matrix, control = u_vec)
    @test CTModels.Init(init; state_dim=2, control_dim=1, variable_dim=1) isa CTModels.Init

end