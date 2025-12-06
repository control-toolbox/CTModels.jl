# Unit tests for CTModels discretized optimal control problems and solution builders.
# ============================================================================
# TEST HELPER TYPES
# ============================================================================

# Dummy stats types for testing solution builders
struct DummyStatsDiscretizedOCP <: SolverCore.AbstractExecutionStats
    value::Int
end

struct DummyStatsDiscretizedOCP2 <: SolverCore.AbstractExecutionStats
    value::String
end

struct DummyStatsDiscretizedOCP3 <: SolverCore.AbstractExecutionStats
    status::Symbol
end

struct DummyStatsDiscretizedOCP4 <: SolverCore.AbstractExecutionStats end

# Dummy OCP types for testing DiscretizedOptimalControlProblem
struct DummyOCPDiscretized <: CTModels.AbstractModel end
struct DummyOCPDiscretized2 <: CTModels.AbstractModel end
struct DummyOCPDiscretized3 <: CTModels.AbstractModel
    data::String
end
struct DummyOCPDiscretized4 <: CTModels.AbstractModel end
struct DummyOCPDiscretized5 <: CTModels.AbstractModel end
struct DummyOCPDiscretized6 <: CTModels.AbstractModel end
struct DummyOCPDiscretized7 <: CTModels.AbstractModel end
struct DummyOCPDiscretized8 <: CTModels.AbstractModel
    name::String
end
struct DummyOCPDiscretized9 <: CTModels.AbstractModel end

struct SimpleOCPDiscretized <: CTModels.AbstractModel
    dim::Int
end

struct ComplexOCPDiscretized <: CTModels.AbstractModel
    state_dim::Int
    control_dim::Int
    constraints::Vector{String}
end

# ============================================================================
# TEST FUNCTION
# ============================================================================

function test_discretized_ocp()

    # ============================================================================
    # TYPE HIERARCHY
    # ============================================================================

    Test.@testset "type hierarchy" verbose=VERBOSE showtiming=SHOWTIMING begin
        # AbstractOCPSolutionBuilder should be abstract and inherit from AbstractSolutionBuilder
        Test.@test isabstracttype(CTModels.AbstractOCPSolutionBuilder)
        Test.@test CTModels.AbstractOCPSolutionBuilder <: CTModels.AbstractSolutionBuilder

        # Concrete solution builders should inherit from AbstractOCPSolutionBuilder
        Test.@test CTModels.ADNLPSolutionBuilder <: CTModels.AbstractOCPSolutionBuilder
        Test.@test CTModels.ExaSolutionBuilder <: CTModels.AbstractOCPSolutionBuilder
    end

    # ============================================================================
    # SOLUTION BUILDERS - UNIT TESTS
    # ============================================================================

    Test.@testset "ADNLPSolutionBuilder" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Test constructor: wrap a function
        call_count = Ref(0)
        last_arg = Ref{Any}(nothing)

        function test_adnlp_builder_fn(stats)
            call_count[] += 1
            last_arg[] = stats
            return (:adnlp_result, stats)
        end

        builder = CTModels.ADNLPSolutionBuilder(test_adnlp_builder_fn)

        # Verify the function is stored
        Test.@test builder.f === test_adnlp_builder_fn
        Test.@test builder isa CTModels.ADNLPSolutionBuilder

        # Test call operator: should invoke the wrapped function
        stats = DummyStatsDiscretizedOCP(42)

        result = builder(stats)

        # Verify the wrapped function was called with correct argument
        Test.@test call_count[] == 1
        Test.@test last_arg[] === stats
        Test.@test result == (:adnlp_result, stats)
    end

    Test.@testset "ExaSolutionBuilder" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Test constructor: wrap a function
        call_count = Ref(0)
        last_arg = Ref{Any}(nothing)

        function test_exa_builder_fn(stats)
            call_count[] += 1
            last_arg[] = stats
            return (:exa_result, stats)
        end

        builder = CTModels.ExaSolutionBuilder(test_exa_builder_fn)

        # Verify the function is stored
        Test.@test builder.f === test_exa_builder_fn
        Test.@test builder isa CTModels.ExaSolutionBuilder

        # Test call operator: should invoke the wrapped function
        stats = DummyStatsDiscretizedOCP2("test")

        result = builder(stats)

        # Verify the wrapped function was called with correct argument
        Test.@test call_count[] == 1
        Test.@test last_arg[] === stats
        Test.@test result == (:exa_result, stats)
    end

    # ============================================================================
    # DISCRETIZED OCP - CONSTRUCTORS
    # ============================================================================

    Test.@testset "DiscretizedOptimalControlProblem - tuple constructor" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Create a dummy OCP (we need an AbstractOptimalControlProblem)
        ocp = DummyOCPDiscretized()

        # Create dummy model builders
        adnlp_model_builder = CTModels.ADNLPModelBuilder(x -> error("unused"))
        exa_model_builder = CTModels.ExaModelBuilder((T, x; kwargs...) -> error("unused"))

        # Create dummy solution builders
        adnlp_solution_builder = CTModels.ADNLPSolutionBuilder(s -> s)
        exa_solution_builder = CTModels.ExaSolutionBuilder(s -> s)

        # Build using tuple constructor with backend builder bundles
        backend_builders = (
            :adnlp =>
                CTModels.OCPBackendBuilders(adnlp_model_builder, adnlp_solution_builder),
            :exa => CTModels.OCPBackendBuilders(exa_model_builder, exa_solution_builder),
        )

        docp = CTModels.DiscretizedOptimalControlProblem(ocp, backend_builders)

        # Verify the problem was constructed correctly
        Test.@test docp isa CTModels.DiscretizedOptimalControlProblem
        Test.@test docp.optimal_control_problem === ocp

        # The Tuple-of-Pairs inputs should have been converted to a NamedTuple of OCPBackendBuilders
        expected_backend_builders = (;
            adnlp=CTModels.OCPBackendBuilders(adnlp_model_builder, adnlp_solution_builder),
            exa=CTModels.OCPBackendBuilders(exa_model_builder, exa_solution_builder),
        )

        Test.@test docp.backend_builders == expected_backend_builders
        Test.@test docp.backend_builders.adnlp.model === adnlp_model_builder
        Test.@test docp.backend_builders.adnlp.solution === adnlp_solution_builder
        Test.@test docp.backend_builders.exa.model === exa_model_builder
        Test.@test docp.backend_builders.exa.solution === exa_solution_builder
    end

    Test.@testset "DiscretizedOptimalControlProblem - individual args constructor" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Create a dummy OCP
        ocp = DummyOCPDiscretized2()

        # Create builders
        adnlp_model_builder = CTModels.ADNLPModelBuilder(x -> error("unused"))
        exa_model_builder = CTModels.ExaModelBuilder((T, x; kwargs...) -> error("unused"))
        adnlp_solution_builder = CTModels.ADNLPSolutionBuilder(s -> (:adnlp_sol, s))
        exa_solution_builder = CTModels.ExaSolutionBuilder(s -> (:exa_sol, s))

        # Build using individual args constructor
        docp = CTModels.DiscretizedOptimalControlProblem(
            ocp,
            adnlp_model_builder,
            exa_model_builder,
            adnlp_solution_builder,
            exa_solution_builder,
        )

        # Verify the problem was constructed correctly
        Test.@test docp isa CTModels.DiscretizedOptimalControlProblem
        Test.@test docp.optimal_control_problem === ocp

        # Verify the builders were converted to the expected backend_builders representation
        expected_backend_builders = (;
            adnlp=CTModels.OCPBackendBuilders(adnlp_model_builder, adnlp_solution_builder),
            exa=CTModels.OCPBackendBuilders(exa_model_builder, exa_solution_builder),
        )

        Test.@test docp.backend_builders == expected_backend_builders
        Test.@test docp.backend_builders.adnlp.model === adnlp_model_builder
        Test.@test docp.backend_builders.adnlp.solution === adnlp_solution_builder
        Test.@test docp.backend_builders.exa.model === exa_model_builder
        Test.@test docp.backend_builders.exa.solution === exa_solution_builder
    end

    # ============================================================================
    # ACCESSOR FUNCTIONS
    # ============================================================================

    Test.@testset "ocp_model" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Create a DOCP with a specific OCP
        ocp = DummyOCPDiscretized3("test_data")

        adnlp_model_builder = CTModels.ADNLPModelBuilder(x -> error("unused"))
        exa_model_builder = CTModels.ExaModelBuilder((T, x; kwargs...) -> error("unused"))
        adnlp_solution_builder = CTModels.ADNLPSolutionBuilder(s -> s)
        exa_solution_builder = CTModels.ExaSolutionBuilder(s -> s)

        docp = CTModels.DiscretizedOptimalControlProblem(
            ocp,
            adnlp_model_builder,
            exa_model_builder,
            adnlp_solution_builder,
            exa_solution_builder,
        )

        # Test ocp_model accessor
        retrieved_ocp = CTModels.ocp_model(docp)
        Test.@test retrieved_ocp === ocp
        Test.@test retrieved_ocp.data == "test_data"
    end

    Test.@testset "get_adnlp_model_builder" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCPDiscretized4()

        # Create a specific builder to verify retrieval
        function my_adnlp_builder(x)
            return :my_adnlp_model
        end
        adnlp_model_builder = CTModels.ADNLPModelBuilder(my_adnlp_builder)
        exa_model_builder = CTModels.ExaModelBuilder((T, x; kwargs...) -> error("unused"))
        adnlp_solution_builder = CTModels.ADNLPSolutionBuilder(s -> s)
        exa_solution_builder = CTModels.ExaSolutionBuilder(s -> s)

        docp = CTModels.DiscretizedOptimalControlProblem(
            ocp,
            adnlp_model_builder,
            exa_model_builder,
            adnlp_solution_builder,
            exa_solution_builder,
        )

        # Test get_adnlp_model_builder accessor
        retrieved_builder = CTModels.get_adnlp_model_builder(docp)
        Test.@test retrieved_builder === adnlp_model_builder
        Test.@test retrieved_builder.f === my_adnlp_builder
    end

    Test.@testset "get_exa_model_builder" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCPDiscretized5()

        # Create a specific builder to verify retrieval
        function my_exa_builder(::Type{T}, x; kwargs...) where {T}
            return :my_exa_model
        end
        adnlp_model_builder = CTModels.ADNLPModelBuilder(x -> error("unused"))
        exa_model_builder = CTModels.ExaModelBuilder(my_exa_builder)
        adnlp_solution_builder = CTModels.ADNLPSolutionBuilder(s -> s)
        exa_solution_builder = CTModels.ExaSolutionBuilder(s -> s)

        docp = CTModels.DiscretizedOptimalControlProblem(
            ocp,
            adnlp_model_builder,
            exa_model_builder,
            adnlp_solution_builder,
            exa_solution_builder,
        )

        # Test get_exa_model_builder accessor
        retrieved_builder = CTModels.get_exa_model_builder(docp)
        Test.@test retrieved_builder === exa_model_builder
        Test.@test retrieved_builder.f === my_exa_builder
    end

    Test.@testset "get_adnlp_solution_builder" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCPDiscretized6()

        # Create a specific solution builder to verify retrieval
        function my_adnlp_solution_builder(stats)
            return (:my_adnlp_solution, stats)
        end
        adnlp_model_builder = CTModels.ADNLPModelBuilder(x -> error("unused"))
        exa_model_builder = CTModels.ExaModelBuilder((T, x; kwargs...) -> error("unused"))
        adnlp_solution_builder = CTModels.ADNLPSolutionBuilder(my_adnlp_solution_builder)
        exa_solution_builder = CTModels.ExaSolutionBuilder(s -> s)

        docp = CTModels.DiscretizedOptimalControlProblem(
            ocp,
            adnlp_model_builder,
            exa_model_builder,
            adnlp_solution_builder,
            exa_solution_builder,
        )

        # Test get_adnlp_solution_builder accessor
        retrieved_builder = CTModels.get_adnlp_solution_builder(docp)
        Test.@test retrieved_builder === adnlp_solution_builder
        Test.@test retrieved_builder.f === my_adnlp_solution_builder
    end

    Test.@testset "get_exa_solution_builder" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCPDiscretized7()

        # Create a specific solution builder to verify retrieval
        function my_exa_solution_builder(stats)
            return (:my_exa_solution, stats)
        end
        adnlp_model_builder = CTModels.ADNLPModelBuilder(x -> error("unused"))
        exa_model_builder = CTModels.ExaModelBuilder((T, x; kwargs...) -> error("unused"))
        adnlp_solution_builder = CTModels.ADNLPSolutionBuilder(s -> s)
        exa_solution_builder = CTModels.ExaSolutionBuilder(my_exa_solution_builder)

        docp = CTModels.DiscretizedOptimalControlProblem(
            ocp,
            adnlp_model_builder,
            exa_model_builder,
            adnlp_solution_builder,
            exa_solution_builder,
        )

        # Test get_exa_solution_builder accessor
        retrieved_builder = CTModels.get_exa_solution_builder(docp)
        Test.@test retrieved_builder === exa_solution_builder
        Test.@test retrieved_builder.f === my_exa_solution_builder
    end

    # ============================================================================
    # INTEGRATION TESTS
    # ============================================================================

    Test.@testset "end-to-end workflow" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Create a complete DOCP and verify the full workflow
        ocp = DummyOCPDiscretized8("integration_test")

        # Track calls to verify builders are invoked correctly
        adnlp_model_calls = Ref(0)
        exa_model_calls = Ref(0)
        adnlp_solution_calls = Ref(0)
        exa_solution_calls = Ref(0)

        function adnlp_model_fn(x; kwargs...)
            adnlp_model_calls[] += 1
            # Minimal ADNLPModel construction, similar to test_ctmodels_problem_core
            f(z) = sum(z .^ 2)
            return ADNLPModels.ADNLPModel(f, x)
        end

        function exa_model_fn(::Type{T}, x; kwargs...) where {T}
            exa_model_calls[] += 1
            return (:exa_model, T, x)
        end

        function adnlp_solution_fn(stats)
            adnlp_solution_calls[] += 1
            return (:adnlp_solution, stats)
        end

        function exa_solution_fn(stats)
            exa_solution_calls[] += 1
            return (:exa_solution, stats)
        end

        # Create DOCP
        docp = CTModels.DiscretizedOptimalControlProblem(
            ocp,
            CTModels.ADNLPModelBuilder(adnlp_model_fn),
            CTModels.ExaModelBuilder(exa_model_fn),
            CTModels.ADNLPSolutionBuilder(adnlp_solution_fn),
            CTModels.ExaSolutionBuilder(exa_solution_fn),
        )

        # Verify OCP retrieval
        Test.@test CTModels.ocp_model(docp).name == "integration_test"

        # Retrieve and use model builders
        adnlp_builder = CTModels.get_adnlp_model_builder(docp)
        exa_builder = CTModels.get_exa_model_builder(docp)

        # Calling the ADNLPModelBuilder should produce a valid ADNLPModels.ADNLPModel
        nlp = adnlp_builder([1.0, 2.0])
        Test.@test nlp isa ADNLPModels.ADNLPModel
        Test.@test adnlp_model_calls[] == 1

        # For ExaModelBuilder, constructing a full ExaModels.ExaModel is non-trivial.
        # As in test_ctmodels_problem_core, we limit ourselves to checking that the
        # correct builder was retrieved and that its wrapped callable is exa_model_fn.
        Test.@test exa_builder isa CTModels.ExaModelBuilder
        Test.@test exa_builder.f === exa_model_fn

        # Retrieve and use solution builders
        adnlp_sol_builder = CTModels.get_adnlp_solution_builder(docp)
        exa_sol_builder = CTModels.get_exa_solution_builder(docp)

        stats = DummyStatsDiscretizedOCP3(:success)

        Test.@test adnlp_sol_builder(stats) == (:adnlp_solution, stats)
        Test.@test adnlp_solution_calls[] == 1

        Test.@test exa_sol_builder(stats) == (:exa_solution, stats)
        Test.@test exa_solution_calls[] == 1
    end

    # ============================================================================
    # EDGE CASES
    # ============================================================================

    Test.@testset "solution builder that throws" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Test that errors in solution builders are propagated correctly
        ocp = DummyOCPDiscretized9()

        function throwing_builder(stats)
            error("Intentional error in solution builder")
        end

        docp = CTModels.DiscretizedOptimalControlProblem(
            ocp,
            CTModels.ADNLPModelBuilder(x -> error("unused")),
            CTModels.ExaModelBuilder((T, x; kwargs...) -> error("unused")),
            CTModels.ADNLPSolutionBuilder(throwing_builder),
            CTModels.ExaSolutionBuilder(s -> s),
        )

        builder = CTModels.get_adnlp_solution_builder(docp)

        stats = DummyStatsDiscretizedOCP4()

        # Verify the error is propagated
        Test.@test_throws ErrorException builder(stats)
    end

    Test.@testset "missing backend errors" verbose=VERBOSE showtiming=SHOWTIMING begin
        ocp = DummyOCPDiscretized()

        # Construct a DOCP with only an :adnlp backend registered.
        adnlp_model_builder = CTModels.ADNLPModelBuilder(x -> :ad_model)
        adnlp_solution_builder = CTModels.ADNLPSolutionBuilder(s -> s)
        adnlp_bundle = CTModels.OCPBackendBuilders(
            adnlp_model_builder, adnlp_solution_builder
        )

        docp_ad_only = CTModels.DiscretizedOptimalControlProblem(
            ocp, (:adnlp => adnlp_bundle,)
        )

        Test.@test_throws ArgumentError CTModels.get_exa_model_builder(docp_ad_only)
        Test.@test_throws ArgumentError CTModels.get_exa_solution_builder(docp_ad_only)

        # Construct a DOCP with only an :exa backend registered.
        exa_model_builder = CTModels.ExaModelBuilder((T, x; kwargs...) -> :exa_model)
        exa_solution_builder = CTModels.ExaSolutionBuilder(s -> s)
        exa_bundle = CTModels.OCPBackendBuilders(exa_model_builder, exa_solution_builder)

        docp_exa_only = CTModels.DiscretizedOptimalControlProblem(
            ocp, (:exa => exa_bundle,)
        )

        Test.@test_throws ArgumentError CTModels.get_adnlp_model_builder(docp_exa_only)
        Test.@test_throws ArgumentError CTModels.get_adnlp_solution_builder(docp_exa_only)
    end

    Test.@testset "different OCP types" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Test that DOCP works with different concrete OCP types
        # Create DOCPs with different OCP types
        simple_ocp = SimpleOCPDiscretized(5)
        complex_ocp = ComplexOCPDiscretized(10, 3, ["bound1", "bound2"])

        adnlp_builder = CTModels.ADNLPModelBuilder(x -> :model)
        exa_builder = CTModels.ExaModelBuilder((T, x; kwargs...) -> :model)
        adnlp_sol_builder = CTModels.ADNLPSolutionBuilder(s -> s)
        exa_sol_builder = CTModels.ExaSolutionBuilder(s -> s)

        docp_simple = CTModels.DiscretizedOptimalControlProblem(
            simple_ocp, adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
        )

        docp_complex = CTModels.DiscretizedOptimalControlProblem(
            complex_ocp, adnlp_builder, exa_builder, adnlp_sol_builder, exa_sol_builder
        )

        # Verify both work correctly
        Test.@test CTModels.ocp_model(docp_simple).dim == 5
        Test.@test CTModels.ocp_model(docp_complex).state_dim == 10
        Test.@test CTModels.ocp_model(docp_complex).control_dim == 3
        Test.@test length(CTModels.ocp_model(docp_complex).constraints) == 2
    end
end