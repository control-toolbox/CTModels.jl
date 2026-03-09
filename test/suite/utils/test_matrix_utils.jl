module TestUtilsMatrixUtils

using Test: Test
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

"""
    test_matrix_utils()

Test matrix utility functions from src/utils/matrix_utils.jl.
"""
function test_matrix_utils()
    Test.@testset "Matrix Utils Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for matrix utils functionality
        end

        # ====================================================================
        # UNIT TESTS - Matrix Utility Functions
        # ====================================================================
        Test.@testset "matrix2vec - dimension 1 (rows)" begin
            A = [
                0 1
                2 3
            ]

            # Default dimension (should be 1)
            V = CTModels.matrix2vec(A)
            Test.@test V isa Vector{<:Vector}
            Test.@test length(V) == 2
            Test.@test V[1] == [0, 1]
            Test.@test V[2] == [2, 3]

            # Explicit dimension 1
            V1 = CTModels.matrix2vec(A, 1)
            Test.@test V1 == V
            Test.@test V1[1] == [0, 1]
            Test.@test V1[2] == [2, 3]
        end

        Test.@testset "matrix2vec - dimension 2 (columns)" begin
            A = [
                0 1
                2 3
            ]

            W = CTModels.matrix2vec(A, 2)
            Test.@test W isa Vector{<:Vector}
            Test.@test length(W) == 2
            Test.@test W[1] == [0, 2]
            Test.@test W[2] == [1, 3]
        end

        Test.@testset "matrix2vec - larger matrix" begin
            B = [
                1 2 3
                4 5 6
            ]

            # By rows
            rows = CTModels.matrix2vec(B, 1)
            Test.@test length(rows) == 2
            Test.@test rows[1] == [1, 2, 3]
            Test.@test rows[2] == [4, 5, 6]

            # By columns
            cols = CTModels.matrix2vec(B, 2)
            Test.@test length(cols) == 3
            Test.@test cols[1] == [1, 4]
            Test.@test cols[2] == [2, 5]
            Test.@test cols[3] == [3, 6]
        end

        Test.@testset "matrix2vec - single row/column" begin
            # Single row matrix
            R = [1 2 3]
            rows = CTModels.matrix2vec(R, 1)
            Test.@test length(rows) == 1
            Test.@test rows[1] == [1, 2, 3]

            cols = CTModels.matrix2vec(R, 2)
            Test.@test length(cols) == 3
            Test.@test cols[1] == [1]
            Test.@test cols[2] == [2]
            Test.@test cols[3] == [3]

            # Single column matrix (must be a Matrix, not a Vector)
            C = reshape([1, 2, 3], 3, 1)
            rows2 = CTModels.matrix2vec(C, 1)
            Test.@test length(rows2) == 3
            Test.@test rows2[1] == [1]
            Test.@test rows2[2] == [2]
            Test.@test rows2[3] == [3]

            cols2 = CTModels.matrix2vec(C, 2)
            Test.@test length(cols2) == 1
            Test.@test cols2[1] == [1, 2, 3]
        end

        Test.@testset "matrix2vec - Float64 matrix" begin
            F = [
                1.5 2.5
                3.5 4.5
            ]

            V = CTModels.matrix2vec(F, 1)
            Test.@test V[1] ≈ [1.5, 2.5]
            Test.@test V[2] ≈ [3.5, 4.5]

            W = CTModels.matrix2vec(F, 2)
            Test.@test W[1] ≈ [1.5, 3.5]
            Test.@test W[2] ≈ [2.5, 4.5]
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_matrix_utils() = TestUtilsMatrixUtils.test_matrix_utils()
