# Unit tests for CTModels problem-specific core builders (e.g. Rosenbrock).
function test_problem_core()

    # ========================================================================
    # Problems
    # ========================================================================
    ros = Rosenbrock()

    # Tests for problem-specific model builders provided by CTModels problems
    # (here the Rosenbrock problem exposes its own build_adnlp_model/build_exa_model).
    Test.@testset "ADNLPModels – Rosenbrock (specific builder)" verbose=VERBOSE showtiming=SHOWTIMING begin
        nlp_adnlp = ros.prob.build_adnlp_model(ros.init; show_time=false)
        Test.@test nlp_adnlp isa ADNLPModels.ADNLPModel
        Test.@test nlp_adnlp.meta.x0 == ros.init
        Test.@test NLPModels.obj(nlp_adnlp, nlp_adnlp.meta.x0) ==
            rosenbrock_objective(ros.init)
        Test.@test NLPModels.cons(nlp_adnlp, nlp_adnlp.meta.x0)[1] ==
            rosenbrock_constraint(ros.init)
        Test.@test nlp_adnlp.meta.minimize == rosenbrock_is_minimize()
    end

    Test.@testset "ExaModels (CPU) – Rosenbrock (specific builder, BaseType=Float32)" verbose=VERBOSE showtiming=SHOWTIMING begin
        BaseType = Float32
        nlp_exa_cpu = ros.prob.build_exa_model(BaseType, ros.init)
        Test.@test nlp_exa_cpu isa ExaModels.ExaModel{BaseType}
        Test.@test nlp_exa_cpu.meta.x0 == BaseType.(ros.init)
        Test.@test eltype(nlp_exa_cpu.meta.x0) == BaseType
        Test.@test NLPModels.obj(nlp_exa_cpu, nlp_exa_cpu.meta.x0) ==
            rosenbrock_objective(BaseType.(ros.init))
        Test.@test NLPModels.cons(nlp_exa_cpu, nlp_exa_cpu.meta.x0)[1] ==
            rosenbrock_constraint(BaseType.(ros.init))
        Test.@test nlp_exa_cpu.meta.minimize == rosenbrock_is_minimize()
    end

    # Tests for the generic ADNLPModelBuilder wrapper (higher-order function
    # that delegates to an arbitrary callable). Here we build a simple
    # ADNLPModel to respect the return type annotation ::ADNLPModels.ADNLPModel
    # and we verify that the inner builder is called exactly once with the
    # expected initial guess, and that keyword arguments are forwarded.
    Test.@testset "ADNLPModelBuilder wrapper" verbose=VERBOSE showtiming=SHOWTIMING begin
        calls = Ref(0)
        last_x = Ref{Any}(nothing)
        function local_ad_builder(x; kwargs...)
            calls[] += 1
            last_x[] = x
            f(z) = sum(z .^ 2)
            return ADNLPModels.ADNLPModel(f, x)
        end

        builder = CTModels.ADNLPModelBuilder(local_ad_builder)
        x0 = ros.init
        nlp = builder(x0)  # no extra kwargs to keep ADNLPModel signature simple

        Test.@test nlp isa ADNLPModels.ADNLPModel
        Test.@test calls[] == 1
        Test.@test last_x[] == x0

        # Keyword arguments should be forwarded to the inner builder.
        kw_calls = Ref(0)
        seen_kwargs = Ref{Any}(nothing)
        function local_ad_builder_kwargs(x; a=0, b=0)
            kw_calls[] += 1
            seen_kwargs[] = (x, a, b)
            f(z) = sum(z .^ 2)
            return ADNLPModels.ADNLPModel(f, x)
        end

        builder_kwargs = CTModels.ADNLPModelBuilder(local_ad_builder_kwargs)
        x1 = ros.init
        _ = builder_kwargs(x1; a=1, b=2)

        Test.@test kw_calls[] == 1
        Test.@test seen_kwargs[] == (x1, 1, 2)
    end

    # Tests for the generic ExaModelBuilder wrapper. Constructing a full
    # ExaModels.ExaModel instance in isolation is non-trivial, and the
    # call operator is annotated to return ::ExaModels.ExaModel. To avoid
    # fragile tests that depend on ExaModels internals, we limit ourselves
    # to checking that the wrapped callable is correctly stored inside
    # ExaModelBuilder.
    Test.@testset "ExaModelBuilder wrapper" verbose=VERBOSE showtiming=SHOWTIMING begin
        function local_exa_builder(::Type{BaseType}, x; foo=1) where {BaseType}
            return (:exa_builder_called, BaseType, x, foo)
        end

        builder = CTModels.ExaModelBuilder(local_exa_builder)

        Test.@test builder.f === local_exa_builder
        Test.@test builder isa CTModels.ExaModelBuilder{typeof(local_exa_builder)}
    end

    # Tests for the generic "NotImplemented" behaviour of the get_* functions
    # when called on a problem type that has no specialized implementation.
    Test.@testset "generic get_* NotImplemented" verbose=VERBOSE showtiming=SHOWTIMING begin
        dummy = DummyProblem()

        Test.@test_throws CTBase.NotImplemented CTModels.get_adnlp_model_builder(dummy)
        Test.@test_throws CTBase.NotImplemented CTModels.get_exa_model_builder(dummy)
        Test.@test_throws CTBase.NotImplemented CTModels.get_adnlp_solution_builder(dummy)
        Test.@test_throws CTBase.NotImplemented CTModels.get_exa_solution_builder(dummy)
    end
end