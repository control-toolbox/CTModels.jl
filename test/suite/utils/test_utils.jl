module TestUtils

using Test
using CTModels

function test_utils()
    @testset "Utils Tests" begin
        A = [
            0 1
            2 3
        ]

        V = CTModels.matrix2vec(A)
        @test V[1] == [0, 1]
        @test V[2] == [2, 3]

        V = CTModels.matrix2vec(A, 1)
        @test V[1] == [0, 1]
        @test V[2] == [2, 3]

        W = CTModels.matrix2vec(A, 2)
        @test W[1] == [0, 2]
        @test W[2] == [1, 3]
    end
end

end # module

# Re-export the entry point for the runner
test_utils() = TestUtils.test_utils()
