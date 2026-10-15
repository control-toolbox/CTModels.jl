module TestInitialGuessScalar

using Test: Test
using CTBase: Exceptions
using CTModels: Building
using CTModels: Components
using CTModels: Init

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# A model with one-dimensional state, control and variable: every component of a
# validated initial guess must then be a scalar, never a length-1 vector.
function scalar_ocp()
    pre = Building.PreModel()
    Building.variable!(pre, 1)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 1)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    Building.objective!(pre, :min; lagrange=(t, x, u, v) -> u^2)
    Building.time_dependence!(pre; autonomous=true)
    return Building.build(pre)
end

# A model with a two-dimensional state: vector components must be left untouched.
function vector_ocp()
    pre = Building.PreModel()
    Building.variable!(pre, 0)
    Building.time!(pre; t0=0.0, tf=1.0)
    Building.state!(pre, 2)
    Building.control!(pre, 1)
    Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    Building.objective!(pre, :min; lagrange=(t, x, u, v) -> u^2)
    Building.time_dependence!(pre; autonomous=true)
    return Building.build(pre)
end

function test_initial_guess_scalar()
    Test.@testset "1-D initial guesses are scalars" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = scalar_ocp()
        T = collect(range(0.0, 1.0; length=5))

        Test.@testset "length-1 vector constant" begin
            init = Init.build_initial_guess(
                ocp, (state=[0.2], control=[0.3], variable=[1.5])
            )
            Test.@test init.state(0.5) === 0.2
            Test.@test init.control(0.5) === 0.3
            Test.@test init.variable === 1.5
        end

        Test.@testset "function returning a length-1 vector" begin
            init = Init.build_initial_guess(ocp, (state=t -> [t], control=t -> [2t]))
            Test.@test init.state(0.5) === 0.5
            Test.@test init.control(0.5) === 1.0
        end

        Test.@testset "function returning a scalar is kept as is" begin
            f = t -> 3t
            init = Init.build_initial_guess(ocp, (control=f,))
            Test.@test init.control(0.5) === 1.5
        end

        Test.@testset "time grid with an N×1 matrix" begin
            init = Init.build_initial_guess(ocp, (control=(T, reshape(T, 5, 1)),))
            Test.@test init.control(0.5) isa Real
            Test.@test init.control(0.5) ≈ 0.5
        end

        Test.@testset "time grid with a vector of length-1 vectors" begin
            init = Init.build_initial_guess(ocp, (control=(T, [[t] for t in T]),))
            Test.@test init.control(0.5) isa Real
            Test.@test init.control(0.5) ≈ 0.5
        end

        Test.@testset "PreInitialGuess path" begin
            pre = Init.pre_initial_guess(; state=[0.2], control=t -> [0.3], variable=[1.5])
            init = Init.build_initial_guess(ocp, pre)
            Test.@test init.state(0.0) === 0.2
            Test.@test init.control(0.0) === 0.3
            Test.@test init.variable === 1.5
        end

        Test.@testset "InitialGuess built by hand" begin
            ig = Init.initial_guess(ocp; state=[0.2], control=t -> [0.3], variable=[1.5])
            init = Init.build_initial_guess(ocp, ig)
            Test.@test init.state(0.0) === 0.2
            Test.@test init.control(0.0) === 0.3
            Test.@test init.variable === 1.5
        end

        Test.@testset "already scalar guess is returned unchanged" begin
            ig = Init.initial_guess(ocp; state=0.2, control=0.3, variable=1.5)
            Test.@test Init.build_initial_guess(ocp, ig) === ig
        end

        Test.@testset "wrong length still raises IncorrectArgument" begin
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, (control=t -> [1.0, 2.0],)
            )
        end

        Test.@testset "multi-dimensional components are untouched" begin
            ocp2 = vector_ocp()
            init = Init.build_initial_guess(ocp2, (state=t -> [t, 2t], control=t -> [t]))
            Test.@test init.state(0.5) == [0.5, 1.0]
            Test.@test init.control(0.5) === 0.5
        end

        Test.@testset "type stability of the coerced trajectory" begin
            init = Init.build_initial_guess(ocp, (control=t -> [2t],))
            Test.@test (Test.@inferred init.control(0.5)) === 1.0
        end
    end
end

end # module

test_initial_guess_scalar() = TestInitialGuessScalar.test_initial_guess_scalar()
