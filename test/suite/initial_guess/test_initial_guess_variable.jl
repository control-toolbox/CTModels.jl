# ------------------------------------------------------------------------------
# Variable Initial Guess Tests
# ------------------------------------------------------------------------------
using Test
using CTModels
using CTModels.InitialGuess

@testset "Variable Initial Guess" verbose = true begin
    
    @testset "initial_variable with Scalar" begin
        # 1D variable - should work
        ocp_1d = CTModels.PreModel()
        CTModels.variable!(ocp_1d, 1, "v")
        
        result = initial_variable(ocp_1d, 0.5)
        @test result == 0.5
        
        # 2D variable - should work
        ocp_2d = CTModels.PreModel()
        CTModels.variable!(ocp_2d, 2, "v", ["v₁", "v₂"])
        
        result_2d = initial_variable(ocp_2d, 0.5)
        @test result_2d == 0.5
        
        # No variable dimension - should throw error
        ocp_no_var = CTModels.PreModel()
        
        @test_throws CTModels.Exceptions.IncorrectArgument initial_variable(ocp_no_var, 0.5)
    end
    
    @testset "initial_variable with Vector" begin
        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2, "v", ["v₁", "v₂"])
        
        # Correct dimension
        result = initial_variable(ocp, [0.0, 1.0])
        @test result == [0.0, 1.0]
        
        # Wrong dimension
        @test_throws CTModels.Exceptions.IncorrectArgument initial_variable(ocp, [0.0])
    end
    
    @testset "initial_variable with Nothing" begin
        # No variable dimension
        ocp_no_var = CTModels.PreModel()
        result = initial_variable(ocp_no_var, nothing)
        @test result == Float64[]
        
        # 1D variable
        ocp_1d = CTModels.PreModel()
        CTModels.variable!(ocp_1d, 1, "v")
        result_1d = initial_variable(ocp_1d, nothing)
        @test result_1d == 0.1
        
        # 2D variable
        ocp_2d = CTModels.PreModel()
        CTModels.variable!(ocp_2d, 2, "v", ["v₁", "v₂"])
        result_2d = initial_variable(ocp_2d, nothing)
        @test result_2d == [0.1, 0.1]
    end
    
    @testset "variable accessor" begin
        ocp = CTModels.PreModel()
        CTModels.time!(ocp, t0=0, tf=1, time_name="t")
        CTModels.variable!(ocp, 2, "v", ["v₁", "v₂"])
        
        init = initial_guess(ocp; variable=[0.0, 1.0])
        
        @test variable(init) == [0.0, 1.0]
    end
end
