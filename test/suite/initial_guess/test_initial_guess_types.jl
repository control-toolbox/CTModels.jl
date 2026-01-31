module TestInitialGuessTypes

using Test
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_initial_guess_types()
    Test.@testset "Initial Guess Types" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ========================================================================
        # Unit tests – core initial guess types
        # ========================================================================

        Test.@testset "OptimalControlInitialGuess structure" begin
            state_fun = t -> [t]
            control_fun = t -> [-t]
            variable_vec = [1.0, 2.0]

            ig = CTModels.OptimalControlInitialGuess(state_fun, control_fun, variable_vec)

            Test.@test ig.state === state_fun
            Test.@test ig.control === control_fun
            Test.@test ig.variable === variable_vec

            # Type parameters should reflect the concrete field types
            Test.@test ig isa CTModels.OptimalControlInitialGuess{
                typeof(state_fun),typeof(control_fun),typeof(variable_vec)
            }
        end

        Test.@testset "OptimalControlPreInit structure" begin
            sx = :state_spec
            su = :control_spec
            sv = :variable_spec

            pre = CTModels.OptimalControlPreInit(sx, su, sv)

            Test.@test pre.state === sx
            Test.@test pre.control === su
            Test.@test pre.variable === sv
        end

        # ========================================================================
        # Integration-style tests – fake consumer of initial guesses
        # ========================================================================

        Test.@testset "fake consumer of OptimalControlInitialGuess" begin
            state_fun = t -> 2t
            control_fun = t -> -3t
            variable_val = 1.23

            ig = CTModels.OptimalControlInitialGuess(state_fun, control_fun, variable_val)

            # Simple fake consumer that only relies on the fields of the type
            function consume_initial_guess(ig_local)
                y = ig_local.state(0.5)
                u = ig_local.control(0.5)
                v = ig_local.variable
                return y, u, v
            end

            y, u, v = consume_initial_guess(ig)

            Test.@test y == 2 * 0.5
            Test.@test u == -3 * 0.5
            Test.@test v == variable_val
        end
    end
end

end # module

test_initial_guess_types() = TestInitialGuessTypes.test_initial_guess_types()
