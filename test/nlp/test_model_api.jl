# Unit tests for the generic optimization model API (model and solution builders).
struct DummyProblemAPI <: CTModels.AbstractOptimizationProblem end

struct DummyStatsAPI <: SolverCore.AbstractExecutionStats end

struct DummySolutionAPI <: CTModels.AbstractSolution end

struct FakeBackendAPI <: CTModels.AbstractOptimizationModeler
    model_calls::Base.RefValue{Int}
    solution_calls::Base.RefValue{Int}
end

function (b::FakeBackendAPI)(
    prob::CTModels.AbstractOptimizationProblem, initial_guess
)::NLPModels.AbstractNLPModel
    b.model_calls[] += 1
    # Use a simple real ADNLPModel here so that we respect the declared
    # return type ::NLPModels.AbstractNLPModel without defining custom
    # subtypes of NLPModels internals.
    f(z) = sum(z .^ 2)
    return ADNLPModels.ADNLPModel(f, initial_guess)
end

function (b::FakeBackendAPI)(
    prob::CTModels.AbstractOptimizationProblem,
    nlp_solution::SolverCore.AbstractExecutionStats,
)
    b.solution_calls[] += 1
    return DummySolutionAPI()
end

struct DummyOCPForModelAPI <: CTModels.AbstractModel end

function make_dummy_docp_for_model_api()
    ocp = DummyOCPForModelAPI()
    adnlp_builder = CTModels.ADNLPModelBuilder(
        (x; kwargs...) -> begin
            f(z) = sum(z .^ 2)
            # We deliberately ignore the extra keyword arguments such as
            # show_time, backend, and AD backend options here. For this
            # unit test we only need a valid ADNLPModel instance.
            return ADNLPModels.ADNLPModel(f, x)
        end
    )
    exa_builder = CTModels.ExaModelBuilder((T, x; kwargs...) -> :exa_model_dummy)
    adnlp_solution_builder = CTModels.ADNLPSolutionBuilder(s -> s)
    exa_solution_builder = CTModels.ExaSolutionBuilder(s -> s)
    return CTModels.DiscretizedOptimalControlProblem(
        ocp, adnlp_builder, exa_builder, adnlp_solution_builder, exa_solution_builder
    )
end

function test_model_api()

    # ========================================================================
    # Problems
    # ========================================================================
    ros = Rosenbrock()
    elec = Elec()
    maxd = Max1MinusX2()

    # ------------------------------------------------------------------
    # Unit tests for build_model delegation
    # ------------------------------------------------------------------
    Test.@testset "build_model delegation" verbose=VERBOSE showtiming=SHOWTIMING begin
        prob = DummyProblemAPI()
        x0 = [1.0, 2.0]
        model_calls = Ref(0)
        solution_calls = Ref(0)
        backend = FakeBackendAPI(model_calls, solution_calls)

        nlp = CTModels.build_model(prob, x0, backend)
        Test.@test nlp isa NLPModels.AbstractNLPModel
        Test.@test model_calls[] == 1
        Test.@test solution_calls[] == 0
    end

    # ------------------------------------------------------------------
    # Unit tests for nlp_model(DiscretizedOptimalControlProblem, ...)
    # ------------------------------------------------------------------
    Test.@testset "nlp_model(DiscretizedOptimalControlProblem, ...)" verbose=VERBOSE showtiming=SHOWTIMING begin
        docp = make_dummy_docp_for_model_api()
        x0 = [1.0, 2.0]
        modeler = CTModels.ADNLPModeler()

        nlp = CTModels.nlp_model(docp, x0, modeler)
        Test.@test nlp isa NLPModels.AbstractNLPModel
    end

    # ------------------------------------------------------------------
    # Unit tests for build_solution(prob, stats, backend) delegation
    # ------------------------------------------------------------------
    # Here we verify that build_solution(prob, nlp_solution, backend)
    # calls the backend's (prob, nlp_solution) method and returns whatever
    # the backend returns (here a DummySolutionAPI instance).

    Test.@testset "build_solution(prob, stats, backend)" verbose=VERBOSE showtiming=SHOWTIMING begin
        prob = DummyProblemAPI()
        stats = DummyStatsAPI()
        model_calls = Ref(0)
        solution_calls = Ref(0)
        backend = FakeBackendAPI(model_calls, solution_calls)

        sol = CTModels.build_solution(prob, stats, backend)
        Test.@test sol isa DummySolutionAPI
        Test.@test model_calls[] == 0
        Test.@test solution_calls[] == 1
    end

    # ------------------------------------------------------------------
    # Unit tests for ocp_solution(DiscretizedOptimalControlProblem, ...)
    # ------------------------------------------------------------------
    Test.@testset "ocp_solution(DiscretizedOptimalControlProblem, ...)" verbose=VERBOSE showtiming=SHOWTIMING begin
        docp = make_dummy_docp_for_model_api()
        stats = DummyStatsAPI()
        model_calls = Ref(0)
        solution_calls = Ref(0)
        backend = FakeBackendAPI(model_calls, solution_calls)

        sol = CTModels.ocp_solution(docp, stats, backend)
        Test.@test sol isa DummySolutionAPI
        Test.@test model_calls[] == 0
        Test.@test solution_calls[] == 1
    end

    # ------------------------------------------------------------------
    # Integration-style tests for build_model on real problems
    # ------------------------------------------------------------------
    Test.@testset "build_model on Rosenbrock, Elec, and Max1MinusX2" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@testset "Rosenbrock" verbose=VERBOSE showtiming=SHOWTIMING begin
            modeler_ad = CTModels.ADNLPModeler()
            nlp_ad = CTModels.build_model(ros.prob, ros.init, modeler_ad)
            Test.@test nlp_ad isa ADNLPModels.ADNLPModel
            Test.@test nlp_ad.meta.x0 == ros.init
            Test.@test NLPModels.obj(nlp_ad, nlp_ad.meta.x0) ==
                rosenbrock_objective(ros.init)
            Test.@test NLPModels.cons(nlp_ad, nlp_ad.meta.x0)[1] ==
                rosenbrock_constraint(ros.init)
            Test.@test nlp_ad.meta.minimize == rosenbrock_is_minimize()

            modeler_exa = CTModels.ExaModeler()
            nlp_exa = CTModels.build_model(ros.prob, ros.init, modeler_exa)
            Test.@test nlp_exa isa ExaModels.ExaModel
        end

        Test.@testset "Elec" verbose=VERBOSE showtiming=SHOWTIMING begin
            modeler_ad = CTModels.ADNLPModeler()
            nlp_ad = CTModels.build_model(elec.prob, elec.init, modeler_ad)
            Test.@test nlp_ad isa ADNLPModels.ADNLPModel
            Test.@test nlp_ad.meta.x0 == vcat(elec.init.x, elec.init.y, elec.init.z)
            Test.@test NLPModels.obj(nlp_ad, nlp_ad.meta.x0) ==
                elec_objective(elec.init.x, elec.init.y, elec.init.z)
            Test.@test NLPModels.cons(nlp_ad, nlp_ad.meta.x0) ==
                elec_constraint(elec.init.x, elec.init.y, elec.init.z)
            Test.@test nlp_ad.meta.minimize == elec_is_minimize()

            BaseType = Float64
            modeler_exa = CTModels.ExaModeler(; base_type=BaseType)
            nlp_exa = CTModels.build_model(elec.prob, elec.init, modeler_exa)
            Test.@test nlp_exa isa ExaModels.ExaModel{BaseType}
        end

        Test.@testset "Max1MinusX2" verbose=VERBOSE showtiming=SHOWTIMING begin
            modeler_ad = CTModels.ADNLPModeler()
            nlp_ad = CTModels.build_model(maxd.prob, maxd.init, modeler_ad)
            Test.@test nlp_ad isa ADNLPModels.ADNLPModel
            Test.@test nlp_ad.meta.x0 == maxd.init
            Test.@test NLPModels.obj(nlp_ad, nlp_ad.meta.x0) ==
                max1minusx2_objective(maxd.init)
            Test.@test NLPModels.cons(nlp_ad, nlp_ad.meta.x0)[1] ==
                max1minusx2_constraint(maxd.init)
            Test.@test nlp_ad.meta.minimize == max1minusx2_is_minimize()

            BaseType = Float64
            modeler_exa = CTModels.ExaModeler(; base_type=BaseType)
            nlp_exa = CTModels.build_model(maxd.prob, maxd.init, modeler_exa)
            Test.@test nlp_exa isa ExaModels.ExaModel{BaseType}
        end
    end
end