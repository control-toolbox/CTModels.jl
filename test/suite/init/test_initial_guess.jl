# Unit tests for CTModels initial guess construction and validation.
struct DummyOCP1DNoVar <: CTModels.AbstractModel end
struct DummyOCP1DVar <: CTModels.AbstractModel end
struct DummyOCP1D2Var <: CTModels.AbstractModel end

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
CTModels.control_dimension(::DummyOCP2DNoVar) = 0
CTModels.variable_dimension(::DummyOCP2DNoVar) = 0

CTModels.has_fixed_initial_time(::DummyOCP2DNoVar) = true
CTModels.initial_time(::DummyOCP2DNoVar) = 0.0

CTModels.state_name(::DummyOCP2DNoVar) = "x"
CTModels.state_components(::DummyOCP2DNoVar) = ["x1", "x2"]
CTModels.control_name(::DummyOCP2DNoVar) = "u"
CTModels.control_components(::DummyOCP2DNoVar) = String[]
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

function test_initial_guess()
    Test.@testset "basic construction and validation" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Simple 1D dummy problem: scalar x,u, no variable (dim(x)=dim(u)=1, dim(v)=0)
        ocp1 = DummyOCP1DNoVar()

        # Scalar initial guess consistent with dimension 1
        init1 = CTModels.initial_guess(ocp1; state=0.2, control=-0.1)
        Test.@test init1 isa CTModels.AbstractOptimalControlInitialGuess
        # validate_initial_guess should not throw
        CTModels.validate_initial_guess(ocp1, init1)

        # Incorrect vector initial guess for state (dim 1 but length 2)
        bad_state = [0.1, 0.2]
        Test.@test_throws CTBase.IncorrectArgument CTModels.initial_guess(
            ocp1; state=bad_state
        )

        # Scalar control init is OK, but a function returning a length-2 vector must be rejected
        bad_control_fun = t -> [t, 2t]
        init_bad_ctrl = CTModels.OptimalControlInitialGuess(
            CTModels.state(init1), bad_control_fun, Float64[]
        )
        Test.@test_throws CTBase.IncorrectArgument CTModels.validate_initial_guess(
            ocp1, init_bad_ctrl
        )

        # For a multi-dimensional state (dim(x)=2), passing a scalar state should trigger
        # the dimension-mismatch error in initial_state(ocp, ::Real).
        ocp_state2 = DummyOCP2DNoVar()
        Test.@test_throws CTBase.IncorrectArgument CTModels.initial_guess(
            ocp_state2; state=0.1
        )

        # For a multi-dimensional control (dim(u)=2), passing a scalar control should
        # trigger the analogous error in initial_control(ocp, ::Real).
        ocp_ctrl2 = DummyOCP1D2Control()
        Test.@test_throws CTBase.IncorrectArgument CTModels.initial_guess(
            ocp_ctrl2; control=0.1
        )
    end

    Test.@testset "variable dimension handling" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Dummy problem with scalar variable (dim(x)=dim(u)=dim(v)=1)
        ocp2 = DummyOCP1DVar()

        # Scalar variable consistent with dimension 1
        init2 = CTModels.initial_guess(ocp2; variable=0.5)
        CTModels.validate_initial_guess(ocp2, init2)

        # Variable as a length-2 vector for dimension 1 must throw
        Test.@test_throws CTBase.IncorrectArgument CTModels.initial_guess(
            ocp2; variable=[0.1, 0.2]
        )

        # Problem without variable: dim(v) == 0
        beam_data = Beam()  # beam has no variable in its initial guess
        ocp3 = beam_data.ocp
        # Providing a scalar variable must throw
        Test.@test_throws CTBase.IncorrectArgument CTModels.initial_guess(
            ocp3; variable=1.0
        )
    end

    Test.@testset "2D variable block and components" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1D2Var()

        # Full block specification for variable w
        init_block = (w=[1.0, 2.0],)
        ig_block = CTModels.build_initial_guess(ocp, init_block)
        Test.@test ig_block isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig_block)
        v_block = CTModels.variable(ig_block)
        Test.@test length(v_block) == 2
        Test.@test v_block[1] ≈ 1.0
        Test.@test v_block[2] ≈ 2.0

        # Only the tf component (first component)
        init_tf = (tf=1.0,)
        ig_tf = CTModels.build_initial_guess(ocp, init_tf)
        Test.@test ig_tf isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig_tf)
        v_tf = CTModels.variable(ig_tf)
        Test.@test length(v_tf) == 2
        Test.@test v_tf[1] ≈ 1.0
        Test.@test v_tf[2] ≈ 0.1  # default value coming from initial_variable(ocp, nothing)

        # Only the a component (second component)
        init_a = (a=0.5,)
        ig_a = CTModels.build_initial_guess(ocp, init_a)
        Test.@test ig_a isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig_a)
        v_a = CTModels.variable(ig_a)
        Test.@test length(v_a) == 2
        Test.@test v_a[1] ≈ 0.1
        Test.@test v_a[2] ≈ 0.5

        # Both components specified
        init_both = (tf=1.0, a=0.5)
        ig_both = CTModels.build_initial_guess(ocp, init_both)
        Test.@test ig_both isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig_both)
        v_both = CTModels.variable(ig_both)
        Test.@test length(v_both) == 2
        Test.@test v_both[1] ≈ 1.0
        Test.@test v_both[2] ≈ 0.5
    end

    Test.@testset "build_initial_guess from NamedTuple" verbose=VERBOSE showtiming=SHOWTIMING begin
        beam_data2 = Beam()
        ocp = beam_data2.ocp

        # Consistent NamedTuple
        init_named = (state=[0.05, 0.1], control=0.1, variable=Float64[])
        ig = CTModels.build_initial_guess(ocp, init_named)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig)

        # NamedTuple with incorrect state dimension must throw
        bad_named = (state=[0.1, 0.2, 0.3], control=0.1, variable=Float64[])
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp, bad_named
        )
    end

    Test.@testset "build_initial_guess generic inputs" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DNoVar()

        ig_default = CTModels.build_initial_guess(ocp, nothing)
        Test.@test ig_default isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig_default)

        init1 = CTModels.initial_guess(ocp; state=0.2, control=-0.1)
        ig_passthrough = CTModels.build_initial_guess(ocp, init1)
        Test.@test ig_passthrough === init1
        CTModels.validate_initial_guess(ocp, ig_passthrough)

        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(ocp, 42)
    end

    Test.@testset "PreInit handling" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp1 = DummyOCP1DNoVar()
        ocp2 = DummyOCP1DVar()

        pre1 = CTModels.pre_initial_guess(state=0.2, control=-0.1)
        ig1 = CTModels.build_initial_guess(ocp1, pre1)
        Test.@test ig1 isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp1, ig1)

        pre_bad_state = CTModels.pre_initial_guess(state=[0.1, 0.2])
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp1, pre_bad_state
        )

        pre2 = CTModels.pre_initial_guess(variable=0.5)
        ig2 = CTModels.build_initial_guess(ocp2, pre2)
        Test.@test ig2 isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp2, ig2)

        pre_bad_var = CTModels.pre_initial_guess(variable=[0.1, 0.2])
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp2, pre_bad_var
        )
    end

    Test.@testset "time-grid NamedTuple (per-block tuples)" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DNoVar()

        time = [0.0, 0.5, 1.0]
        state_samples = [[0.0], [0.5], [1.0]]
        control_samples = [0.0, 0.0, 1.0]

        init_nt = (
            state=(time, state_samples), control=(time, control_samples), variable=Float64[]
        )
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig)

        xfun = CTModels.state(ig)
        ufun = CTModels.control(ig)

        x0 = xfun(0.0);
        x1 = xfun(1.0)
        u0 = ufun(0.0);
        u1 = ufun(1.0)

        x0_val = x0 isa AbstractVector ? x0[1] : x0
        x1_val = x1 isa AbstractVector ? x1[1] : x1
        u0_val = u0 isa AbstractVector ? u0[1] : u0
        u1_val = u1 isa AbstractVector ? u1[1] : u1

        Test.@test isapprox(x0_val, 0.0; atol=1e-12)
        Test.@test isapprox(x1_val, 1.0; atol=1e-12)
        Test.@test isapprox(u0_val, 0.0; atol=1e-12)
        Test.@test isapprox(u1_val, 1.0; atol=1e-12)

        # Same test but using a matrix for the state samples (time-grid + matrix2vec path)
        state_matrix = [0.0; 0.5; 1.0]
        init_nt_mat = (
            state=(time, state_matrix), control=(time, control_samples), variable=Float64[]
        )
        ig_mat = CTModels.build_initial_guess(ocp, init_nt_mat)
        Test.@test ig_mat isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig_mat)

        # Edge case: (time, nothing) for state should fall back to default initial_state
        init_nt_state_nothing = (
            state=(time, nothing), control=(time, control_samples), variable=Float64[]
        )
        ig_state_nothing = CTModels.build_initial_guess(ocp, init_nt_state_nothing)
        Test.@test ig_state_nothing isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig_state_nothing)

        # Edge case: (time, nothing) for control should fall back to default initial_control
        init_nt_control_nothing = (
            state=(time, state_samples), control=(time, nothing), variable=Float64[]
        )
        ig_control_nothing = CTModels.build_initial_guess(ocp, init_nt_control_nothing)
        Test.@test ig_control_nothing isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig_control_nothing)

        bad_state_samples = [[0.0], [1.0]]
        bad_nt = (
            state=(time, bad_state_samples),
            control=(time, control_samples),
            variable=Float64[],
        )
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(ocp, bad_nt)
    end

    Test.@testset "time-grid NamedTuple with 2D state matrix" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP2DNoVar()

        time = [0.0, 0.5, 1.0]
        # Each row corresponds to a time sample, columns to state components (x1, x2)
        state_matrix = [
            0.0 1.0;
            0.5 1.5;
            1.0 2.0
        ]

        init_nt = (state=(time, state_matrix),)
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig)

        xfun = CTModels.state(ig)
        x0 = xfun(0.0)
        x1 = xfun(1.0)

        Test.@test x0[1] ≈ 0.0
        Test.@test x0[2] ≈ 1.0
        Test.@test x1[1] ≈ 1.0
        Test.@test x1[2] ≈ 2.0
    end

    Test.@testset "time-grid PreInit via tuples" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DNoVar()
        time = [0.0, 0.5, 1.0]
        state_samples = [[0.0], [0.5], [1.0]]

        pre = CTModels.pre_initial_guess(state=(time, state_samples))
        ig = CTModels.build_initial_guess(ocp, pre)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig)

        xfun = CTModels.state(ig)
        x0 = xfun(0.0);
        x1 = xfun(1.0)
        x0_val = x0 isa AbstractVector ? x0[1] : x0
        x1_val = x1 isa AbstractVector ? x1[1] : x1
        Test.@test isapprox(x0_val, 0.0; atol=1e-12)
        Test.@test isapprox(x1_val, 1.0; atol=1e-12)
    end

    Test.@testset "per-component state init without time" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP2DNoVar()

        # Init only via components x1, x2
        init_nt = (x1=0.0, x2=1.0)
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig)

        xfun = CTModels.state(ig)
        x = xfun(0.0)
        Test.@test x[1] ≈ 0.0
        Test.@test x[2] ≈ 1.0
    end

    Test.@testset "per-component state init with time" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP2DNoVar()
        time = [0.0, 1.0]
        init_nt = (x1=(time, [0.0, 1.0]), x2=(time, [1.0, 2.0]))
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig)

        xfun = CTModels.state(ig)
        x0 = xfun(0.0);
        x1 = xfun(1.0)
        Test.@test x0[1] ≈ 0.0
        Test.@test x0[2] ≈ 1.0
        Test.@test x1[1] ≈ 1.0
        Test.@test x1[2] ≈ 2.0
    end

    Test.@testset "uniqueness between block and component specs" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP2DNoVar()
        bad_nt = (state=[0.0, 0.0], x1=1.0)
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(ocp, bad_nt)
    end

    Test.@testset "warm-start from AbstractSolution" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1DVar()

        xfun = t -> 0.1
        ufun = t -> -0.2
        v = 0.5

        sol_ok = DummySolution1DVar(ocp, xfun, ufun, v)
        ig = CTModels.build_initial_guess(ocp, sol_ok)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig)

        model_bad_var = DummyOCP1DNoVar()
        sol_bad_var = DummySolution1DVar(model_bad_var, xfun, ufun, v)
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp, sol_bad_var
        )

        model_bad_state = DummyOCP2DNoVar()
        sol_bad_state = DummySolution1DVar(model_bad_state, xfun, ufun, v)
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp, sol_bad_state
        )
    end

    Test.@testset "NamedTuple alias keys from OCP names" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp1 = DummyOCP1DNoVar()

        init_nt1 = (x=0.2, u=-0.1)
        ig1 = CTModels.build_initial_guess(ocp1, init_nt1)
        Test.@test ig1 isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp1, ig1)

        time = [0.0, 0.5, 1.0]
        state_samples = [[0.0], [0.5], [1.0]]
        control_samples = [0.0, 0.0, 1.0]

        init_nt2 = (x=(time, state_samples), u=(time, control_samples), variable=Float64[])
        ig2 = CTModels.build_initial_guess(ocp1, init_nt2)
        Test.@test ig2 isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp1, ig2)
    end

    Test.@testset "NamedTuple error cases" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp1 = DummyOCP1DNoVar()

        bad_unknown = (state=0.1, foo=1.0)
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp1, bad_unknown
        )

        bad_time = (time=[0.0, 1.0], state=0.1)
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp1, bad_time
        )

        ocp2 = DummyOCP2DNoVar()

        bad_comp_vector = (x1=[0.0, 1.0])
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp2, bad_comp_vector
        )

        time = [0.0, 1.0, 2.0]
        bad_comp_time = (x1=(time, [0.0, 1.0]))
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp2, bad_comp_time
        )

        ocp3 = DummyOCP2DNoVar()
        bad_state_fun = t -> [0.0]
        bad_nt_state_fun = (state=bad_state_fun,)
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp3, bad_nt_state_fun
        )
    end

    Test.@testset "per-component control init without time" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1D2Control()

        init_nt = (u1=0.0, u2=1.0)
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig)

        ufun = CTModels.control(ig)
        u = ufun(0.0)
        Test.@test length(u) == 2
        Test.@test u[1] ≈ 0.0
        Test.@test u[2] ≈ 1.0
    end

    Test.@testset "per-component control init with time" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1D2Control()
        time = [0.0, 1.0]

        init_nt = (u1=(time, [0.0, 1.0]), u2=(time, [1.0, 2.0]))
        ig = CTModels.build_initial_guess(ocp, init_nt)
        Test.@test ig isa CTModels.AbstractOptimalControlInitialGuess
        CTModels.validate_initial_guess(ocp, ig)

        ufun = CTModels.control(ig)
        u0 = ufun(0.0)
        u1 = ufun(1.0)

        Test.@test u0[1] ≈ 0.0
        Test.@test u0[2] ≈ 1.0
        Test.@test u1[1] ≈ 1.0
        Test.@test u1[2] ≈ 2.0
    end

    Test.@testset "uniqueness between control block and component specs" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCP1D2Control()

        bad_nt1 = (control=[0.0, 1.0], u1=1.0)
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp, bad_nt1
        )

        bad_nt2 = (u=[0.0, 1.0], u1=1.0)
        Test.@test_throws CTBase.IncorrectArgument CTModels.build_initial_guess(
            ocp, bad_nt2
        )
    end
end
