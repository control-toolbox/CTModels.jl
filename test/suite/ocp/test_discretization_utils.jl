module TestDiscretizationUtils

using Test
using CTModels
using Main.TestOptions: VERBOSE, SHOWTIMING

function test_discretization_utils()
    @testset "Discretization utilities" verbose = VERBOSE showtiming = SHOWTIMING begin
        
        @testset "Basic discretization - scalar function" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Fonction scalaire simple
            f_scalar = t -> 2.0 * t
            T = [0.0, 0.5, 1.0]
            
            # Avec dimension explicite
            result = CTModels.OCP._discretize_function(f_scalar, T, 1)
            @test size(result) == (3, 1)
            @test result ≈ [0.0; 1.0; 2.0]
            
            # Avec auto-détection
            result_auto = CTModels.OCP._discretize_function(f_scalar, T)
            @test result_auto ≈ result
        end
        
        @testset "Basic discretization - vector function" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Fonction vectorielle
            f_vec = t -> [t, 2*t]
            T = [0.0, 0.5, 1.0]
            
            # Avec dimension explicite
            result = CTModels.OCP._discretize_function(f_vec, T, 2)
            @test size(result) == (3, 2)
            @test result ≈ [0.0 0.0; 0.5 1.0; 1.0 2.0]
            
            # Avec auto-détection
            result_auto = CTModels.OCP._discretize_function(f_vec, T)
            @test result_auto ≈ result
        end
        
        @testset "TimeGridModel support" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Test avec TimeGridModel
            T_grid = CTModels.TimeGridModel(LinRange(0.0, 1.0, 5))
            f = t -> [t, t^2]
            
            result = CTModels.OCP._discretize_function(f, T_grid, 2)
            @test size(result) == (5, 2)
            @test result[1, :] ≈ [0.0, 0.0]
            @test result[end, :] ≈ [1.0, 1.0]
        end
        
        @testset "Discretize dual - nothing handling" verbose = VERBOSE showtiming = SHOWTIMING begin
            T = [0.0, 0.5, 1.0]
            
            # Dual function is nothing
            result_nothing = CTModels.OCP._discretize_dual(nothing, T)
            @test isnothing(result_nothing)
            
            # Dual function exists
            f_dual = t -> [t, 2*t]
            result_func = CTModels.OCP._discretize_dual(f_dual, T, 2)
            @test !isnothing(result_func)
            @test size(result_func) == (3, 2)
            @test result_func ≈ [0.0 0.0; 0.5 1.0; 1.0 2.0]
            
            # Auto-detection
            result_auto = CTModels.OCP._discretize_dual(f_dual, T)
            @test result_auto ≈ result_func
        end
        
        @testset "Edge cases" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Single time point
            f = t -> [t, 2*t]
            T_single = [0.5]
            result = CTModels.OCP._discretize_function(f, T_single, 2)
            @test size(result) == (1, 2)
            @test result ≈ [0.5 1.0]
            
            # Large dimension
            f_large = t -> ones(10) .* t
            T = [0.0, 1.0]
            result = CTModels.OCP._discretize_function(f_large, T, 10)
            @test size(result) == (2, 10)
            @test result[1, :] ≈ zeros(10)
            @test result[2, :] ≈ ones(10)
        end
        
        @testset "Scalar return from vector function" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Fonction retourne vecteur mais on veut dim=1
            f = t -> [2.0 * t]  # Retourne vecteur de taille 1
            T = [0.0, 0.5, 1.0]
            
            result = CTModels.OCP._discretize_function(f, T, 1)
            @test size(result) == (3, 1)
            @test result ≈ [0.0; 1.0; 2.0]
        end
    end
end

end  # module

test_discretization_utils() = TestDiscretizationUtils.test_discretization_utils()
