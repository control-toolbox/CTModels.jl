module TestInitialGuessBuilders

using Test
using CTModels
using CTModels.Exceptions
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

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

function test_initial_guess_builders()

    Test.@testset "Testing initial guess builders" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ========================================================================
        # UNIT TESTS - Builder Functions
        # ========================================================================

        Test.@testset "time-grid NamedTuple (per-block tuples)" begin
            ocp = DummyOCP1DNoVar()

            time = [0.0, 0.5, 1.0]
            state_samples = [0.0, 0.5, 1.0]
            control_samples = [1.0, 0.5, 0.0]

            init_nt = (state=(time, state_samples), control=(time, control_samples))
            ig = CTModels.build_initial_guess(ocp, init_nt)

            Test.@test ig isa CTModels.OptimalControlInitialGuess

            # Verify interpolation works
            x_fun = CTModels.state(ig)
            Test.@test x_fun(0.0) ≈ 0.0
            Test.@test x_fun(0.5) ≈ 0.5
            Test.@test x_fun(1.0) ≈ 1.0

            u_fun = CTModels.control(ig)
            Test.@test u_fun(0.0) ≈ 1.0
            Test.@test u_fun(0.5) ≈ 0.5
            Test.@test u_fun(1.0) ≈ 0.0

            # Test interpolation between points
            x_mid = x_fun(0.25)
            Test.@test x_mid ≈ 0.25 atol = 1e-10
        end

        Test.@testset "time-grid with 2D state matrix" begin
            ocp = DummyOCP2DNoVar()

            time = [0.0, 0.5, 1.0]
            # Matrix: each row is a time point, each column is a state component
            # Row 1: t=0.0 -> [0.0, 1.0]
            # Row 2: t=0.5 -> [0.5, 1.5]
            # Row 3: t=1.0 -> [1.0, 2.0]
            state_matrix = [0.0 1.0; 0.5 1.5; 1.0 2.0]

            init_nt = (state=(time, state_matrix),)
            ig = CTModels.build_initial_guess(ocp, init_nt)

            Test.@test ig isa CTModels.OptimalControlInitialGuess

            # Verify state function
            x_fun = CTModels.state(ig)
            x0 = x_fun(0.0)
            Test.@test x0 isa AbstractVector
            Test.@test length(x0) == 2
            Test.@test x0[1] ≈ 0.0
            Test.@test x0[2] ≈ 1.0

            x1 = x_fun(1.0)
            Test.@test x1[1] ≈ 1.0
            Test.@test x1[2] ≈ 2.0
        end

        Test.@testset "time-grid PreInit via tuples" begin
            ocp = DummyOCP1DNoVar()
            time = [0.0, 0.5, 1.0]
            state_samples = [[0.0], [0.5], [1.0]]
            control_samples = [[1.0], [0.5], [0.0]]

            # Create PreInit with time-grid tuples
            pre = CTModels.pre_initial_guess(
                state=(time, state_samples), control=(time, control_samples)
            )

            ig = CTModels.build_initial_guess(ocp, pre)
            Test.@test ig isa CTModels.OptimalControlInitialGuess

            # Verify interpolation
            x_fun = CTModels.state(ig)
            x1_val = x_fun(1.0)
            Test.@test x1_val isa AbstractVector
            Test.@test isapprox(x1_val[1], 1.0; atol=1e-12)
        end

        Test.@testset "per-component state init without time" begin
            ocp = DummyOCP2DNoVar()

            # Init only via components x1, x2
            init_nt = (x1=0.0, x2=1.0)
            ig = CTModels.build_initial_guess(ocp, init_nt)

            Test.@test ig isa CTModels.OptimalControlInitialGuess

            x = CTModels.state(ig)(0.5)
            Test.@test x isa AbstractVector
            Test.@test length(x) == 2
            Test.@test x[1] ≈ 0.0
            Test.@test x[2] ≈ 1.0
        end

        Test.@testset "per-component state init with time" begin
            ocp = DummyOCP2DNoVar()
            time = [0.0, 1.0]
            init_nt = (x1=(time, [0.0, 1.0]), x2=(time, [1.0, 2.0]))

            ig = CTModels.build_initial_guess(ocp, init_nt)
            Test.@test ig isa CTModels.OptimalControlInitialGuess

            x_fun = CTModels.state(ig)
            x0 = x_fun(0.0)
            Test.@test x0[1] ≈ 0.0
            Test.@test x0[2] ≈ 1.0

            x1 = x_fun(1.0)
            Test.@test x1[1] ≈ 1.0
            Test.@test x1[2] ≈ 2.0
        end

        Test.@testset "per-component control init without time" begin
            ocp = DummyOCP1D2Control()

            init_nt = (u1=0.0, u2=1.0)
            ig = CTModels.build_initial_guess(ocp, init_nt)

            Test.@test ig isa CTModels.OptimalControlInitialGuess

            u = CTModels.control(ig)(0.5)
            Test.@test u isa AbstractVector
            Test.@test length(u) == 2
            Test.@test u[1] ≈ 0.0
            Test.@test u[2] ≈ 1.0
        end

        Test.@testset "per-component control init with time" begin
            ocp = DummyOCP1D2Control()
            time = [0.0, 1.0]

            init_nt = (u1=(time, [0.0, 1.0]), u2=(time, [1.0, 2.0]))
            ig = CTModels.build_initial_guess(ocp, init_nt)

            Test.@test ig isa CTModels.OptimalControlInitialGuess

            u_fun = CTModels.control(ig)
            u0 = u_fun(0.0)
            Test.@test u0[1] ≈ 0.0
            Test.@test u0[2] ≈ 1.0

            u1 = u_fun(1.0)
            Test.@test u1[1] ≈ 1.0
            Test.@test u1[2] ≈ 2.0
        end

        Test.@testset "mixed block and component specifications" begin
            ocp = DummyOCP2DNoVar()

            # Specify x1 via component, x2 gets default
            init_nt = (x1=0.5,)
            ig = CTModels.build_initial_guess(ocp, init_nt)

            x = CTModels.state(ig)(0.5)
            Test.@test x[1] ≈ 0.5
            Test.@test x[2] ≈ 0.1  # default value
        end

        # ========================================================================
        # INTEGRATION TESTS - Complex Builder Scenarios
        # ========================================================================

        Test.@testset "complex time-grid with all components" begin
            ocp = DummyOCP2DNoVar()

            time = [0.0, 0.5, 1.0]
            x1_data = [0.0, 0.5, 1.0]
            x2_data = [1.0, 1.5, 2.0]
            u_data = [0.0, 0.5, 1.0]

            init_nt = (x1=(time, x1_data), x2=(time, x2_data), u=(time, u_data))
            ig = CTModels.build_initial_guess(ocp, init_nt)

            Test.@test ig isa CTModels.OptimalControlInitialGuess

            # Verify all components
            x = CTModels.state(ig)(0.5)
            Test.@test x[1] ≈ 0.5
            Test.@test x[2] ≈ 1.5

            u = CTModels.control(ig)(0.5)
            Test.@test u ≈ 0.5
        end

        Test.@testset "function-based component initialization" begin
            ocp = DummyOCP2DNoVar()

            # Use functions for components
            init_nt = (x1=t -> sin(t), x2=t -> cos(t))
            ig = CTModels.build_initial_guess(ocp, init_nt)

            Test.@test ig isa CTModels.OptimalControlInitialGuess

            x = CTModels.state(ig)(0.5)
            Test.@test x[1] ≈ sin(0.5)
            Test.@test x[2] ≈ cos(0.5)
        end
    end
end

end # module

test_initial_guess_builders() = TestInitialGuessBuilders.test_initial_guess_builders()
