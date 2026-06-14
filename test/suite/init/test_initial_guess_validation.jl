module TestInitialGuessValidation

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Solutions: Solutions
import CTModels.Init: Init

include(joinpath("..", "..", "problems", "TestProblems.jl"))
import .TestProblems

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Dummy OCPs — top-level (world-age requirement)
struct DummyOCP1DNoVar <: Models.AbstractModel end
Models.state_dimension(::DummyOCP1DNoVar) = 1
Models.control_dimension(::DummyOCP1DNoVar) = 1
Models.variable_dimension(::DummyOCP1DNoVar) = 0
Components.has_fixed_initial_time(::DummyOCP1DNoVar) = true
Components.initial_time(::DummyOCP1DNoVar) = 0.0
Models.state_name(::DummyOCP1DNoVar) = "x"
Models.state_components(::DummyOCP1DNoVar) = ["x"]
Models.control_name(::DummyOCP1DNoVar) = "u"
Models.control_components(::DummyOCP1DNoVar) = ["u"]
Models.variable_name(::DummyOCP1DNoVar) = "v"
Models.variable_components(::DummyOCP1DNoVar) = String[]

struct DummyOCP1DVar <: Models.AbstractModel end
Models.state_dimension(::DummyOCP1DVar) = 1
Models.control_dimension(::DummyOCP1DVar) = 1
Models.variable_dimension(::DummyOCP1DVar) = 1
Components.has_fixed_initial_time(::DummyOCP1DVar) = true
Components.initial_time(::DummyOCP1DVar) = 0.0
Models.state_name(::DummyOCP1DVar) = "x"
Models.state_components(::DummyOCP1DVar) = ["x"]
Models.control_name(::DummyOCP1DVar) = "u"
Models.control_components(::DummyOCP1DVar) = ["u"]
Models.variable_name(::DummyOCP1DVar) = "v"
Models.variable_components(::DummyOCP1DVar) = ["v"]

struct DummyOCP1D2Var <: Models.AbstractModel end
Models.state_dimension(::DummyOCP1D2Var) = 1
Models.control_dimension(::DummyOCP1D2Var) = 1
Models.variable_dimension(::DummyOCP1D2Var) = 2
Components.has_fixed_initial_time(::DummyOCP1D2Var) = true
Components.initial_time(::DummyOCP1D2Var) = 0.0
Models.state_name(::DummyOCP1D2Var) = "x"
Models.state_components(::DummyOCP1D2Var) = ["x"]
Models.control_name(::DummyOCP1D2Var) = "u"
Models.control_components(::DummyOCP1D2Var) = ["u"]
Models.variable_name(::DummyOCP1D2Var) = "w"
Models.variable_components(::DummyOCP1D2Var) = ["tf", "a"]

struct DummyOCP2DNoVar <: Models.AbstractModel end
Models.state_dimension(::DummyOCP2DNoVar) = 2
Models.control_dimension(::DummyOCP2DNoVar) = 1
Models.variable_dimension(::DummyOCP2DNoVar) = 0
Components.has_fixed_initial_time(::DummyOCP2DNoVar) = true
Components.initial_time(::DummyOCP2DNoVar) = 0.0
Models.state_name(::DummyOCP2DNoVar) = "x"
Models.state_components(::DummyOCP2DNoVar) = ["x1", "x2"]
Models.control_name(::DummyOCP2DNoVar) = "u"
Models.control_components(::DummyOCP2DNoVar) = ["u"]
Models.variable_name(::DummyOCP2DNoVar) = "v"
Models.variable_components(::DummyOCP2DNoVar) = String[]

struct DummyOCP1D2Control <: Models.AbstractModel end
Models.state_dimension(::DummyOCP1D2Control) = 1
Models.control_dimension(::DummyOCP1D2Control) = 2
Models.variable_dimension(::DummyOCP1D2Control) = 0
Components.has_fixed_initial_time(::DummyOCP1D2Control) = true
Components.initial_time(::DummyOCP1D2Control) = 0.0
Models.state_name(::DummyOCP1D2Control) = "x"
Models.state_components(::DummyOCP1D2Control) = ["x"]
Models.control_name(::DummyOCP1D2Control) = "u"
Models.control_components(::DummyOCP1D2Control) = ["u1", "u2"]
Models.variable_name(::DummyOCP1D2Control) = "v"
Models.variable_components(::DummyOCP1D2Control) = String[]

struct DummySolution1DVar <: Solutions.AbstractSolution
    model
    xfun::Function
    ufun::Function
    v
end
Models.state(sol::DummySolution1DVar) = sol.xfun
Models.control(sol::DummySolution1DVar) = sol.ufun
Models.variable(sol::DummySolution1DVar) = sol.v

function test_initial_guess_validation()
    Test.@testset "Initial Guess Validation Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Validation Functions
        # ====================================================================

        Test.@testset "dimension validation - correct dimensions" begin
            ocp = DummyOCP1DNoVar()

            init = Init.initial_guess(ocp; state=0.2, control=-0.1)
            Init.validate_initial_guess(ocp, init)
            Test.@test true
        end

        Test.@testset "dimension validation - incorrect state dimension" begin
            ocp = DummyOCP1DNoVar()

            bad_state_fun = t -> [t, 2t]
            init_bad = Init.InitialGuess(bad_state_fun, t -> 0.1, Float64[])

            Test.@test_throws Exceptions.IncorrectArgument Init.validate_initial_guess(
                ocp, init_bad
            )
        end

        Test.@testset "dimension validation - incorrect control dimension" begin
            ocp = DummyOCP1DNoVar()

            bad_control_fun = t -> [t, 2t]
            init_bad = Init.InitialGuess(t -> 0.1, bad_control_fun, Float64[])

            Test.@test_throws Exceptions.IncorrectArgument Init.validate_initial_guess(
                ocp, init_bad
            )
        end

        Test.@testset "dimension validation - incorrect variable dimension" begin
            ocp = DummyOCP1DVar()

            init_bad = Init.InitialGuess(
                t -> 0.1,
                t -> 0.1,
                [0.1, 0.2],
            )

            Test.@test_throws Exceptions.IncorrectArgument Init.validate_initial_guess(
                ocp, init_bad
            )
        end

        Test.@testset "warm-start from AbstractSolution" begin
            ocp = DummyOCP1DVar()

            xfun = t -> 0.1
            ufun = t -> -0.2
            v = 0.5

            sol = DummySolution1DVar(ocp, xfun, ufun, v)

            ig = Init.build_initial_guess(ocp, sol)
            Test.@test ig isa Init.InitialGuess

            Test.@test Models.state(ig)(0.5) ≈ 0.1
            Test.@test Models.control(ig)(0.5) ≈ -0.2
            Test.@test Models.variable(ig) ≈ 0.5
        end

        Test.@testset "warm-start dimension mismatch" begin
            ocp1 = DummyOCP1DVar()
            ocp2 = DummyOCP2DNoVar()

            sol = DummySolution1DVar(ocp1, t -> 0.1, t -> -0.2, 0.5)

            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp2, sol
            )
        end

        Test.@testset "NamedTuple alias keys from OCP names" begin
            ocp = DummyOCP1DNoVar()

            init_nt1 = (x=0.2, u=-0.1)
            ig1 = Init.build_initial_guess(ocp, init_nt1)
            Test.@test ig1 isa Init.InitialGuess
            Init.validate_initial_guess(ocp, ig1)

            init_nt2 = (state=0.2, control=-0.1)
            ig2 = Init.build_initial_guess(ocp, init_nt2)
            Test.@test ig2 isa Init.InitialGuess
            Init.validate_initial_guess(ocp, ig2)
        end

        Test.@testset "NamedTuple error - unknown key" begin
            ocp = DummyOCP1DNoVar()

            bad_unknown = (state=0.1, foo=1.0)
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, bad_unknown
            )
        end

        Test.@testset "NamedTuple error - global time key" begin
            ocp = DummyOCP1DNoVar()

            bad_time = (time=[0.0, 1.0], state=0.1)
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, bad_time
            )
        end

        Test.@testset "NamedTuple error - multiple state specifications" begin
            ocp = DummyOCP2DNoVar()

            bad_nt = (state=[0.0, 0.0], x1=1.0)
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, bad_nt
            )
        end

        Test.@testset "NamedTuple error - multiple control specifications" begin
            ocp = DummyOCP1D2Control()

            bad_nt = (control=[0.0, 1.0], u1=1.0)
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, bad_nt
            )
        end

        Test.@testset "NamedTuple error - multiple variable specifications" begin
            ocp = DummyOCP1D2Var()

            bad_nt = (w=[1.0, 2.0], tf=1.0)
            Test.@test_throws Exceptions.IncorrectArgument Init.build_initial_guess(
                ocp, bad_nt
            )
        end

        Test.@testset "2D variable block and components" begin
            ocp = DummyOCP1D2Var()

            init_block = (w=[1.0, 2.0],)
            ig_block = Init.build_initial_guess(ocp, init_block)
            Init.validate_initial_guess(ocp, ig_block)
            v_block = Models.variable(ig_block)
            Test.@test length(v_block) == 2
            Test.@test v_block[1] ≈ 1.0
            Test.@test v_block[2] ≈ 2.0

            init_tf = (tf=1.0,)
            ig_tf = Init.build_initial_guess(ocp, init_tf)
            Init.validate_initial_guess(ocp, ig_tf)
            v_tf = Models.variable(ig_tf)
            Test.@test v_tf[1] ≈ 1.0
            Test.@test v_tf[2] ≈ 0.1

            init_a = (a=0.5,)
            ig_a = Init.build_initial_guess(ocp, init_a)
            Init.validate_initial_guess(ocp, ig_a)
            v_a = Models.variable(ig_a)
            Test.@test v_a[1] ≈ 0.1
            Test.@test v_a[2] ≈ 0.5

            init_both = (tf=1.0, a=0.5)
            ig_both = Init.build_initial_guess(ocp, init_both)
            Init.validate_initial_guess(ocp, ig_both)
            v_both = Models.variable(ig_both)
            Test.@test v_both[1] ≈ 1.0
            Test.@test v_both[2] ≈ 0.5
        end

        # ====================================================================
        # INTEGRATION TESTS - Complex Validation Scenarios
        # ====================================================================

        Test.@testset "complete validation workflow with Beam problem" begin
            beam_data = TestProblems.Beam()
            ocp = beam_data.ocp

            init_nt = (state=t -> [0.0, 0.0], control=t -> [1.0])
            ig = Init.build_initial_guess(ocp, init_nt)

            validated = Init.validate_initial_guess(ocp, ig)
            Test.@test validated === ig

            x = Models.state(ig)(0.5)
            Test.@test x isa AbstractVector
            Test.@test length(x) == 2

            u = Models.control(ig)(0.5)
            Test.@test u isa AbstractVector
            Test.@test length(u) == 1
        end

        Test.@testset "enriched error messages validation" begin
            ocp = DummyOCP2DNoVar()

            try
                Init.initial_guess(ocp; state=0.1)
                Test.@test false
            catch e
                Test.@test e isa Exceptions.IncorrectArgument
                Test.@test !isempty(e.got)
                Test.@test !isempty(e.expected)
                Test.@test !isempty(e.suggestion)
                Test.@test !isempty(e.context)
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_initial_guess_validation() = TestInitialGuessValidation.test_initial_guess_validation()
