module TestInitialGuessValidation

using Test
using CTModels
using CTModels.Exceptions
using Main.TestProblems
using Main.TestOptions: VERBOSE, SHOWTIMING

# Dummy OCPs for testing
struct DummyOCP1DNoVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1DNoVar) = 1
CTModels.control_dimension(::DummyOCP1DNoVar) = 1
CTModels.variable_dimension(::DummyOCP1DNoVar) = 0
CTModels.has_fixed_initial_time(::DummyOCP1DNoVar) = true
CTModels.initial_time(::DummyOCP1DNoVar) = 0.0
CTModels.state_name(::DummyOCP1DNoVar) = "x"
CTModels.state_components(::DummyOCP1DNoVar) = ["x"]
CTModels.control_name(::DummyOCP1DNoVar) = "u"
CTModels.control_components(::DummyOCP1DNoVar) = ["u"]
CTModels.variable_name(::DummyOCP1DNoVar) = "v"
CTModels.variable_components(::DummyOCP1DNoVar) = String[]

struct DummyOCP1DVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1DVar) = 1
CTModels.control_dimension(::DummyOCP1DVar) = 1
CTModels.variable_dimension(::DummyOCP1DVar) = 1
CTModels.has_fixed_initial_time(::DummyOCP1DVar) = true
CTModels.initial_time(::DummyOCP1DVar) = 0.0
CTModels.state_name(::DummyOCP1DVar) = "x"
CTModels.state_components(::DummyOCP1DVar) = ["x"]
CTModels.control_name(::DummyOCP1DVar) = "u"
CTModels.control_components(::DummyOCP1DVar) = ["u"]
CTModels.variable_name(::DummyOCP1DVar) = "v"
CTModels.variable_components(::DummyOCP1DVar) = ["v"]

struct DummyOCP1D2Var <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1D2Var) = 1
CTModels.control_dimension(::DummyOCP1D2Var) = 1
CTModels.variable_dimension(::DummyOCP1D2Var) = 2
CTModels.has_fixed_initial_time(::DummyOCP1D2Var) = true
CTModels.initial_time(::DummyOCP1D2Var) = 0.0
CTModels.state_name(::DummyOCP1D2Var) = "x"
CTModels.state_components(::DummyOCP1D2Var) = ["x"]
CTModels.control_name(::DummyOCP1D2Var) = "u"
CTModels.control_components(::DummyOCP1D2Var) = ["u"]
CTModels.variable_name(::DummyOCP1D2Var) = "w"
CTModels.variable_components(::DummyOCP1D2Var) = ["tf", "a"]

struct DummyOCP2DNoVar <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP2DNoVar) = 2
CTModels.control_dimension(::DummyOCP2DNoVar) = 1
CTModels.variable_dimension(::DummyOCP2DNoVar) = 0
CTModels.has_fixed_initial_time(::DummyOCP2DNoVar) = true
CTModels.initial_time(::DummyOCP2DNoVar) = 0.0
CTModels.state_name(::DummyOCP2DNoVar) = "x"
CTModels.state_components(::DummyOCP2DNoVar) = ["x1", "x2"]
CTModels.control_name(::DummyOCP2DNoVar) = "u"
CTModels.control_components(::DummyOCP2DNoVar) = ["u"]
CTModels.variable_name(::DummyOCP2DNoVar) = "v"
CTModels.variable_components(::DummyOCP2DNoVar) = String[]

struct DummyOCP1D2Control <: CTModels.AbstractModel end
CTModels.state_dimension(::DummyOCP1D2Control) = 1
CTModels.control_dimension(::DummyOCP1D2Control) = 2
CTModels.variable_dimension(::DummyOCP1D2Control) = 0
CTModels.has_fixed_initial_time(::DummyOCP1D2Control) = true
CTModels.initial_time(::DummyOCP1D2Control) = 0.0
CTModels.state_name(::DummyOCP1D2Control) = "x"
CTModels.state_components(::DummyOCP1D2Control) = ["x"]
CTModels.control_name(::DummyOCP1D2Control) = "u"
CTModels.control_components(::DummyOCP1D2Control) = ["u1", "u2"]
CTModels.variable_name(::DummyOCP1D2Control) = "v"
CTModels.variable_components(::DummyOCP1D2Control) = String[]

struct DummySolution1DVar <: CTModels.AbstractSolution
    model
    xfun::Function
    ufun::Function
    v
end
CTModels.state(sol::DummySolution1DVar) = sol.xfun
CTModels.control(sol::DummySolution1DVar) = sol.ufun
CTModels.variable(sol::DummySolution1DVar) = sol.v

function test_initial_guess_validation()
    # ========================================================================
    # UNIT TESTS - Validation Functions
    # ========================================================================

    Test.@testset "dimension validation - correct dimensions" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DNoVar()

        # Valid initial guess
        init = CTModels.initial_guess(ocp; state=0.2, control=-0.1)
        
        # Should not throw
        CTModels.validate_initial_guess(ocp, init)
        Test.@test true  # If we get here, validation passed
    end

    Test.@testset "dimension validation - incorrect state dimension" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DNoVar()

        # Function returning wrong dimension
        bad_state_fun = t -> [t, 2t]
        init_bad = CTModels.OptimalControlInitialGuess(
            bad_state_fun, t -> 0.1, Float64[]
        )

        # Should throw
        Test.@test_throws CTModels.Exceptions.IncorrectArgument CTModels.validate_initial_guess(
            ocp, init_bad
        )
    end

    Test.@testset "dimension validation - incorrect control dimension" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DNoVar()

        # Function returning wrong dimension
        bad_control_fun = t -> [t, 2t]
        init_bad = CTModels.OptimalControlInitialGuess(
            t -> 0.1, bad_control_fun, Float64[]
        )

        # Should throw
        Test.@test_throws CTModels.Exceptions.IncorrectArgument CTModels.validate_initial_guess(
            ocp, init_bad
        )
    end

    Test.@testset "dimension validation - incorrect variable dimension" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DVar()

        # Wrong variable dimension
        init_bad = CTModels.OptimalControlInitialGuess(
            t -> 0.1, t -> 0.1, [0.1, 0.2]  # Should be scalar, not vector
        )

        # Should throw
        Test.@test_throws CTModels.Exceptions.IncorrectArgument CTModels.validate_initial_guess(
            ocp, init_bad
        )
    end

    Test.@testset "warm-start from AbstractSolution" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DVar()

        xfun = t -> 0.1
        ufun = t -> -0.2
        v = 0.5

        # Create a dummy solution
        sol = DummySolution1DVar(ocp, xfun, ufun, v)

        # Build initial guess from solution
        ig = CTModels.build_initial_guess(ocp, sol)
        Test.@test ig isa CTModels.OptimalControlInitialGuess

        # Verify values match
        Test.@test CTModels.state(ig)(0.5) ≈ 0.1
        Test.@test CTModels.control(ig)(0.5) ≈ -0.2
        Test.@test CTModels.variable(ig) ≈ 0.5
    end

    Test.@testset "warm-start dimension mismatch" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp1 = DummyOCP1DVar()
        ocp2 = DummyOCP2DNoVar()  # Different dimensions

        # Create solution for ocp1
        sol = DummySolution1DVar(ocp1, t -> 0.1, t -> -0.2, 0.5)

        # Try to use it for ocp2 (wrong dimensions)
        Test.@test_throws CTModels.Exceptions.IncorrectArgument CTModels.build_initial_guess(
            ocp2, sol
        )
    end

    Test.@testset "NamedTuple alias keys from OCP names" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DNoVar()

        # Using generic keys
        init_nt1 = (x=0.2, u=-0.1)
        ig1 = CTModels.build_initial_guess(ocp, init_nt1)
        Test.@test ig1 isa CTModels.OptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig1)

        # Using standard keys
        init_nt2 = (state=0.2, control=-0.1)
        ig2 = CTModels.build_initial_guess(ocp, init_nt2)
        Test.@test ig2 isa CTModels.OptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig2)
    end

    Test.@testset "NamedTuple error - unknown key" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DNoVar()

        bad_unknown = (state=0.1, foo=1.0)
        Test.@test_throws CTModels.Exceptions.IncorrectArgument CTModels.build_initial_guess(
            ocp, bad_unknown
        )
    end

    Test.@testset "NamedTuple error - global time key" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DNoVar()

        bad_time = (time=[0.0, 1.0], state=0.1)
        Test.@test_throws CTModels.Exceptions.IncorrectArgument CTModels.build_initial_guess(
            ocp, bad_time
        )
    end

    Test.@testset "NamedTuple error - multiple state specifications" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP2DNoVar()

        # Both block and component level
        bad_nt = (state=[0.0, 0.0], x1=1.0)
        Test.@test_throws CTModels.Exceptions.IncorrectArgument CTModels.build_initial_guess(
            ocp, bad_nt
        )
    end

    Test.@testset "NamedTuple error - multiple control specifications" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1D2Control()

        # Both block and component level
        bad_nt = (control=[0.0, 1.0], u1=1.0)
        Test.@test_throws CTModels.Exceptions.IncorrectArgument CTModels.build_initial_guess(
            ocp, bad_nt
        )
    end

    Test.@testset "NamedTuple error - multiple variable specifications" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1D2Var()

        # Both block and component level
        bad_nt = (w=[1.0, 2.0], tf=1.0)
        Test.@test_throws CTModels.Exceptions.IncorrectArgument CTModels.build_initial_guess(
            ocp, bad_nt
        )
    end

    Test.@testset "2D variable block and components" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1D2Var()

        # Full block specification
        init_block = (w=[1.0, 2.0],)
        ig_block = CTModels.build_initial_guess(ocp, init_block)
        CTModels.validate_initial_guess(ocp, ig_block)
        v_block = CTModels.variable(ig_block)
        Test.@test length(v_block) == 2
        Test.@test v_block[1] ≈ 1.0
        Test.@test v_block[2] ≈ 2.0

        # Only tf component
        init_tf = (tf=1.0,)
        ig_tf = CTModels.build_initial_guess(ocp, init_tf)
        CTModels.validate_initial_guess(ocp, ig_tf)
        v_tf = CTModels.variable(ig_tf)
        Test.@test v_tf[1] ≈ 1.0
        Test.@test v_tf[2] ≈ 0.1  # default

        # Only a component
        init_a = (a=0.5,)
        ig_a = CTModels.build_initial_guess(ocp, init_a)
        CTModels.validate_initial_guess(ocp, ig_a)
        v_a = CTModels.variable(ig_a)
        Test.@test v_a[1] ≈ 0.1  # default
        Test.@test v_a[2] ≈ 0.5

        # Both components
        init_both = (tf=1.0, a=0.5)
        ig_both = CTModels.build_initial_guess(ocp, init_both)
        CTModels.validate_initial_guess(ocp, ig_both)
        v_both = CTModels.variable(ig_both)
        Test.@test v_both[1] ≈ 1.0
        Test.@test v_both[2] ≈ 0.5
    end

    # ========================================================================
    # INTEGRATION TESTS - Complex Validation Scenarios
    # ========================================================================

    Test.@testset "complete validation workflow with Beam problem" verbose=VERBOSE showtiming=SHOWTIMING begin
        beam_data = Beam()
        ocp = beam_data.ocp

        # Build from NamedTuple
        init_nt = (state=t -> [0.0, 0.0], control=t -> [1.0])
        ig = CTModels.build_initial_guess(ocp, init_nt)

        # Validate
        validated = CTModels.validate_initial_guess(ocp, ig)
        Test.@test validated === ig

        # Verify dimensions
        x = CTModels.state(ig)(0.5)
        Test.@test x isa AbstractVector
        Test.@test length(x) == 2

        u = CTModels.control(ig)(0.5)
        Test.@test u isa AbstractVector
        Test.@test length(u) == 1
    end

    Test.@testset "enriched error messages validation" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP2DNoVar()

        # Test that error messages include got/expected/suggestion
        try
            # Scalar state for 2D problem
            CTModels.initial_guess(ocp; state=0.1)
            Test.@test false  # Should not reach here
        catch e
            Test.@test e isa CTModels.Exceptions.IncorrectArgument
            # Verify enriched fields exist
            Test.@test !isempty(e.got)
            Test.@test !isempty(e.expected)
            Test.@test !isempty(e.suggestion)
            Test.@test !isempty(e.context)
        end
    end
end

end # module

test_initial_guess_validation() = TestInitialGuessValidation.test_initial_guess_validation()
