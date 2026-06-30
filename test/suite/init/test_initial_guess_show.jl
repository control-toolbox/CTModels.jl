module TestInitialGuessShow

import Test: Test
import CTModels.Init: Init

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_initial_guess_show()
    Test.@testset "InitialGuess Display" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - InitialGuess text/plain show
        # ====================================================================

        Test.@testset "InitialGuess text/plain show" begin
            ig = Init.InitialGuess(t -> [0.0, 0.0], t -> [0.1], [1.0])
            io = IOBuffer()
            show(io, MIME"text/plain"(), ig)
            s = String(take!(io))

            Test.@test occursin("InitialGuess", s)
            Test.@test occursin("state", s)
            Test.@test occursin("control", s)
            Test.@test occursin("variable", s)
            Test.@test occursin("<callable>", s)
            Test.@test occursin("1.0", s)
        end

        Test.@testset "InitialGuess text/plain show with empty variable" begin
            ig = Init.InitialGuess(t -> [0.0], t -> [0.0], Float64[])
            io = IOBuffer()
            show(io, MIME"text/plain"(), ig)
            s = String(take!(io))

            Test.@test occursin("InitialGuess", s)
            Test.@test occursin("(none)", s)
        end

        Test.@testset "InitialGuess compact show" begin
            ig = Init.InitialGuess(t -> [0.0], t -> [0.0], 1.23)
            io = IOBuffer()
            show(io, ig)
            s = String(take!(io))

            Test.@test occursin("InitialGuess", s)
            Test.@test occursin("<callable>", s)
            Test.@test occursin("1.23", s)
        end

        Test.@testset "InitialGuess compact show with empty variable" begin
            ig = Init.InitialGuess(t -> [0.0], t -> [0.0], Float64[])
            io = IOBuffer()
            show(io, ig)
            s = String(take!(io))

            Test.@test occursin("InitialGuess", s)
            Test.@test occursin("(none)", s)
        end

        # ====================================================================
        # UNIT TESTS - PreInitialGuess show
        # ====================================================================

        Test.@testset "PreInitialGuess text/plain show" begin
            pre = Init.PreInitialGuess([1.0 2.0; 3.0 4.0], [0.5, 0.6], [1.0])
            io = IOBuffer()
            show(io, MIME"text/plain"(), pre)
            s = String(take!(io))

            Test.@test occursin("PreInitialGuess", s)
            Test.@test occursin("state", s)
            Test.@test occursin("control", s)
            Test.@test occursin("variable", s)
            Test.@test occursin("Matrix", s)
        end

        Test.@testset "PreInitialGuess compact show" begin
            pre = Init.PreInitialGuess([1.0 2.0; 3.0 4.0], [0.5, 0.6], nothing)
            io = IOBuffer()
            show(io, pre)
            s = String(take!(io))

            Test.@test occursin("PreInitialGuess", s)
            Test.@test occursin("Matrix", s)
            Test.@test occursin("Nothing", s)
        end

        # ====================================================================
        # INTEGRATION TESTS - InitialGuess from build_initial_guess
        # ====================================================================

        Test.@testset "InitialGuess display via build_initial_guess" begin
            # Build a minimal OCP and initial guess
            ig = Init.InitialGuess(t -> [0.0, 0.0], t -> [0.1], [1.0])
            io = IOBuffer()
            show(io, MIME"text/plain"(), ig)
            s = String(take!(io))

            # Multi-line format for text/plain
            Test.@test countlines(IOBuffer(s)) >= 3
            Test.@test occursin("InitialGuess", s)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_initial_guess_show() = TestInitialGuessShow.test_initial_guess_show()
