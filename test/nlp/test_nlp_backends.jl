# Unit tests for NLP backends (ADNLPModels and ExaModels) used by CTModels problems.
struct CM_DummyBackendStats <: SolverCore.AbstractExecutionStats end

struct CM_DummyModelerMissing <: CTModels.AbstractOptimizationModeler end

function test_nlp_backends()

    # ========================================================================
    # Problems
    # ========================================================================
    ros = Rosenbrock()
    elec = Elec()
    maxd = Max1MinusX2()

    # ------------------------------------------------------------------
    # Low-level defaults for ADNLPModeler / ExaModeler
    # ------------------------------------------------------------------
    Test.@testset "raw defaults" verbose=VERBOSE showtiming=SHOWTIMING begin
        # ADNLPModels defaults
        Test.@test CTModels.__adnlp_model_show_time() isa Bool
        Test.@test CTModels.__adnlp_model_backend() isa Symbol

        Test.@test CTModels.__adnlp_model_show_time() == false
        Test.@test CTModels.__adnlp_model_backend() == :optimized

        # ExaModels defaults
        Test.@test CTModels.__exa_model_base_type() isa DataType
        Test.@test CTModels.__exa_model_backend() isa Union{Nothing,Symbol}

        Test.@test CTModels.__exa_model_base_type() === Float64
        Test.@test CTModels.__exa_model_backend() === nothing
    end

    # ------------------------------------------------------------------
    # ADNLPModels backends (direct calls to ADNLPModeler)
    # ------------------------------------------------------------------
    # These tests exercise the call
    #   (modeler::ADNLPModeler)(prob, initial_guess)
    # directly, without going through the generic model API. We verify
    # that the resulting ADNLPModel has the correct initial point,
    # objective, constraints, and that the AD backends are configured as
    # expected when using the manual backend path.
    Test.@testset "ADNLPModels – Rosenbrock (direct call)" verbose=VERBOSE showtiming=SHOWTIMING begin
        modeler = CTModels.ADNLPModeler()
        nlp_adnlp = modeler(ros.prob, ros.init)
        Test.@test nlp_adnlp isa ADNLPModels.ADNLPModel
        Test.@test nlp_adnlp.meta.x0 == ros.init
        Test.@test NLPModels.obj(nlp_adnlp, nlp_adnlp.meta.x0) ==
            rosenbrock_objective(ros.init)
        Test.@test NLPModels.cons(nlp_adnlp, nlp_adnlp.meta.x0)[1] ==
            rosenbrock_constraint(ros.init)
        Test.@test nlp_adnlp.meta.minimize == rosenbrock_is_minimize()
    end

    # Different CTModels problem (Elec),
    # still calling the backend directly.
    Test.@testset "ADNLPModels – Elec (direct call)" verbose=VERBOSE showtiming=SHOWTIMING begin
        modeler = CTModels.ADNLPModeler()
        nlp_adnlp = modeler(elec.prob, elec.init)
        Test.@test nlp_adnlp isa ADNLPModels.ADNLPModel
        Test.@test nlp_adnlp.meta.x0 == vcat(elec.init.x, elec.init.y, elec.init.z)
        Test.@test NLPModels.obj(nlp_adnlp, nlp_adnlp.meta.x0) ==
            elec_objective(elec.init.x, elec.init.y, elec.init.z)
        Test.@test NLPModels.cons(nlp_adnlp, nlp_adnlp.meta.x0) ==
            elec_constraint(elec.init.x, elec.init.y, elec.init.z)
        Test.@test nlp_adnlp.meta.minimize == elec_is_minimize()
    end

    # 1D maximization problem: Max1MinusX2
    Test.@testset "ADNLPModels – Max1MinusX2 (direct call)" verbose=VERBOSE showtiming=SHOWTIMING begin
        modeler = CTModels.ADNLPModeler()
        nlp_adnlp = modeler(maxd.prob, maxd.init)
        Test.@test nlp_adnlp isa ADNLPModels.ADNLPModel
        Test.@test nlp_adnlp.meta.x0 == maxd.init
        Test.@test NLPModels.obj(nlp_adnlp, nlp_adnlp.meta.x0) ==
            max1minusx2_objective(maxd.init)
        Test.@test NLPModels.cons(nlp_adnlp, nlp_adnlp.meta.x0)[1] ==
            max1minusx2_constraint(maxd.init)
        Test.@test nlp_adnlp.meta.minimize == max1minusx2_is_minimize()
    end

    # For a problem without specialized get_* methods, ADNLPModeler
    # should surface the generic NotImplemented error from get_adnlp_model_builder
    # even when called directly.
    Test.@testset "ADNLPModels – DummyProblem (NotImplemented, direct call)" verbose=VERBOSE showtiming=SHOWTIMING begin
        modeler = CTModels.ADNLPModeler()
        Test.@test_throws CTBase.NotImplemented modeler(DummyProblem(), ros.init)
    end

    # ------------------------------------------------------------------
    # ExaModels backends (direct calls to ExaModeler, CPU)
    # ------------------------------------------------------------------
    # These tests exercise the call
    #   (modeler::ExaModeler)(prob, initial_guess)
    # directly, using a concrete BaseType (Float32).
    Test.@testset "ExaModels (CPU) – Rosenbrock (BaseType=Float32, direct call)" verbose=VERBOSE showtiming=SHOWTIMING begin
        BaseType = Float32
        modeler = CTModels.ExaModeler(; base_type=BaseType)
        nlp_exa_cpu = modeler(ros.prob, ros.init)
        Test.@test nlp_exa_cpu isa ExaModels.ExaModel{BaseType}
        Test.@test nlp_exa_cpu.meta.x0 == BaseType.(ros.init)
        Test.@test eltype(nlp_exa_cpu.meta.x0) == BaseType
        Test.@test NLPModels.obj(nlp_exa_cpu, nlp_exa_cpu.meta.x0) ==
            rosenbrock_objective(BaseType.(ros.init))
        Test.@test NLPModels.cons(nlp_exa_cpu, nlp_exa_cpu.meta.x0)[1] ==
            rosenbrock_constraint(BaseType.(ros.init))
        Test.@test nlp_exa_cpu.meta.minimize == rosenbrock_is_minimize()
    end

    # Same ExaModels backend but on the Elec problem, with direct backend call.
    Test.@testset "ExaModels (CPU) – Elec (BaseType=Float32, direct call)" begin
        BaseType = Float32
        modeler = CTModels.ExaModeler(; base_type=BaseType)
        nlp_exa_cpu = modeler(elec.prob, elec.init)
        Test.@test nlp_exa_cpu isa ExaModels.ExaModel{BaseType}
        Test.@test nlp_exa_cpu.meta.x0 ==
            BaseType.(vcat(elec.init.x, elec.init.y, elec.init.z))
        Test.@test eltype(nlp_exa_cpu.meta.x0) == BaseType
        Test.@test NLPModels.obj(nlp_exa_cpu, nlp_exa_cpu.meta.x0) == elec_objective(
            BaseType.(elec.init.x), BaseType.(elec.init.y), BaseType.(elec.init.z)
        )
        Test.@test NLPModels.cons(nlp_exa_cpu, nlp_exa_cpu.meta.x0) == elec_constraint(
            BaseType.(elec.init.x), BaseType.(elec.init.y), BaseType.(elec.init.z)
        )
        Test.@test nlp_exa_cpu.meta.minimize == elec_is_minimize()
    end

    Test.@testset "ExaModels (CPU) – Max1MinusX2 (BaseType=Float32, direct call)" verbose=VERBOSE showtiming=SHOWTIMING begin
        BaseType = Float32
        modeler = CTModels.ExaModeler(; base_type=BaseType)
        nlp_exa_cpu = modeler(maxd.prob, maxd.init)
        Test.@test nlp_exa_cpu isa ExaModels.ExaModel{BaseType}
        Test.@test nlp_exa_cpu.meta.x0 == BaseType.(maxd.init)
        Test.@test eltype(nlp_exa_cpu.meta.x0) == BaseType
        Test.@test NLPModels.obj(nlp_exa_cpu, nlp_exa_cpu.meta.x0) ==
            max1minusx2_objective(BaseType.(maxd.init))
        Test.@test NLPModels.cons(nlp_exa_cpu, nlp_exa_cpu.meta.x0)[1] ==
            max1minusx2_constraint(BaseType.(maxd.init))
        Test.@test nlp_exa_cpu.meta.minimize == max1minusx2_is_minimize()
    end

    # For a problem without specialized get_* methods, ExaModeler
    # should surface the generic NotImplemented error from get_exa_model_builder
    # even when called directly.
    Test.@testset "ExaModels (CPU) – DummyProblem (NotImplemented, direct call)" verbose=VERBOSE showtiming=SHOWTIMING begin
        modeler = CTModels.ExaModeler()
        Test.@test_throws CTBase.NotImplemented modeler(DummyProblem(), ros.init)
    end

    # ------------------------------------------------------------------
    # Constructor-level tests for ADNLPModeler and ExaModeler
    # ------------------------------------------------------------------
    # These tests now focus on the options_values / options_sources
    # NamedTuples exposed via _options / _option_sources.

    Test.@testset "ADNLPModeler constructor" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Default constructor should use the values from ctmodels/default.jl
        backend_default = CTModels.ADNLPModeler()
        vals_default = CTModels._options_values(backend_default)
        srcs_default = CTModels._option_sources(backend_default)

        Test.@test vals_default.show_time == CTModels.__adnlp_model_show_time()
        Test.@test vals_default.backend == CTModels.__adnlp_model_backend()
        Test.@test all(srcs_default[k] == :ct_default for k in propertynames(srcs_default))

        # Custom backend and extra kwargs should be stored with provenance
        backend_manual = CTModels.ADNLPModeler(; backend=:toto, foo=1)
        vals_manual = CTModels._options_values(backend_manual)
        srcs_manual = CTModels._option_sources(backend_manual)

        Test.@test vals_manual.backend == :toto
        Test.@test srcs_manual.backend == :user
        Test.@test vals_manual.foo == 1
        Test.@test srcs_manual.foo == :user
    end

    Test.@testset "ExaModeler constructor" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Default constructor should use backend from ctmodels/default.jl
        exa_default = CTModels.ExaModeler()
        vals_default = CTModels._options_values(exa_default)
        srcs_default = CTModels._option_sources(exa_default)

        Test.@test vals_default.backend === CTModels.__exa_model_backend()
        Test.@test srcs_default.backend == :ct_default

        # Custom base_type and kwargs: base_type is reflected in the modeler type,
        # while remaining options and their provenance are tracked as usual.
        exa_custom = CTModels.ExaModeler(; base_type=Float32)
        vals_custom = CTModels._options_values(exa_custom)
        srcs_custom = CTModels._option_sources(exa_custom)

        Test.@test exa_custom isa CTModels.ExaModeler{Float32}
        Test.@test vals_custom.backend === CTModels.__exa_model_backend()
        Test.@test srcs_custom.backend == :ct_default

        # Unknown options should now be rejected for ExaModeler (strict_keys=true).
        err = nothing
        try
            CTModels.ExaModeler(; base_type=Float32, foo=2)
        catch e
            err = e
        end
        Test.@test err isa CTBase.IncorrectArgument
        buf = sprint(showerror, err)
        Test.@test occursin("Unknown option foo", buf)
        Test.@test occursin("show_options(ExaModeler)", buf)
    end

    # ------------------------------------------------------------------
    # Options metadata and validation helpers for ADNLPModeler/ExaModeler
    # ------------------------------------------------------------------

    Test.@testset "ADNLPModeler options metadata and validation" verbose=VERBOSE showtiming=SHOWTIMING begin
        keys_ad = CTModels.options_keys(CTModels.ADNLPModeler)
        Test.@test :show_time in keys_ad
        Test.@test :backend in keys_ad

        ad_backend = CTModels.ADNLPModeler()
        ad_type_from_instance = typeof(ad_backend)

        keys_ad_inst = CTModels.options_keys(ad_type_from_instance)
        Test.@test Set(keys_ad_inst) == Set(keys_ad)

        Test.@test CTModels.option_type(:show_time, CTModels.ADNLPModeler) == Bool
        Test.@test CTModels.option_type(:backend, CTModels.ADNLPModeler) == Symbol

        Test.@test CTModels.option_type(:show_time, ad_type_from_instance) == Bool
        Test.@test CTModels.option_type(:backend, ad_type_from_instance) == Symbol

        desc_backend = CTModels.option_description(:backend, CTModels.ADNLPModeler)
        Test.@test desc_backend isa AbstractString
        Test.@test !isempty(desc_backend)

        desc_backend_inst = CTModels.option_description(:backend, ad_type_from_instance)
        Test.@test desc_backend_inst isa AbstractString
        Test.@test !isempty(desc_backend_inst)

        # Invalid type for a known option should trigger a CTBase.IncorrectArgument
        Test.@test_throws CTBase.IncorrectArgument CTModels.ADNLPModeler(; show_time="yes")
    end

    Test.@testset "ExaModeler options metadata and validation" verbose=VERBOSE showtiming=SHOWTIMING begin
        keys_exa = CTModels.options_keys(CTModels.ExaModeler)
        Test.@test :base_type in keys_exa
        Test.@test :backend in keys_exa
        Test.@test :minimize in keys_exa

        exa_backend = CTModels.ExaModeler()
        exa_type_from_instance = typeof(exa_backend)

        keys_exa_inst = CTModels.options_keys(exa_type_from_instance)
        Test.@test Set(keys_exa_inst) == Set(keys_exa)

        Test.@test CTModels.option_type(:base_type, CTModels.ExaModeler) <:
            Type{<:AbstractFloat}
        Test.@test CTModels.option_type(:minimize, CTModels.ExaModeler) == Bool

        Test.@test CTModels.option_type(:base_type, exa_type_from_instance) <:
            Type{<:AbstractFloat}
        Test.@test CTModels.option_type(:minimize, exa_type_from_instance) == Bool

        # Invalid type for a known option should trigger a CTBase.IncorrectArgument
        Test.@test_throws CTBase.IncorrectArgument CTModels.ExaModeler(; minimize=1)
    end

    Test.@testset "ExaModeler unknown option suggestions" verbose=VERBOSE showtiming=SHOWTIMING begin
        err = nothing
        try
            CTModels._validate_option_kwargs(
                (minimise=true,), CTModels.ExaModeler; strict_keys=true
            )
        catch e
            err = e
        end
        Test.@test err isa CTBase.IncorrectArgument
        buf = sprint(showerror, err)
        Test.@test occursin("Unknown option minimise", buf)
        Test.@test occursin("minimize", buf)
        Test.@test occursin("show_options(ExaModeler)", buf)
    end

    Test.@testset "default_options and option_default" verbose=VERBOSE showtiming=SHOWTIMING begin
        # ADNLPModeler defaults should be consistent between helpers and metadata.
        opts_ad = CTModels.default_options(CTModels.ADNLPModeler)
        Test.@test opts_ad.show_time == CTModels.__adnlp_model_show_time()
        Test.@test opts_ad.backend == CTModels.__adnlp_model_backend()

        ad_backend = CTModels.ADNLPModeler()
        ad_type_from_instance = typeof(ad_backend)

        opts_ad_inst = CTModels.default_options(ad_type_from_instance)
        Test.@test opts_ad_inst == opts_ad

        Test.@test CTModels.option_default(:show_time, CTModels.ADNLPModeler) ==
            CTModels.__adnlp_model_show_time()
        Test.@test CTModels.option_default(:backend, CTModels.ADNLPModeler) ==
            CTModels.__adnlp_model_backend()

        Test.@test CTModels.option_default(:show_time, ad_type_from_instance) ==
            CTModels.__adnlp_model_show_time()
        Test.@test CTModels.option_default(:backend, ad_type_from_instance) ==
            CTModels.__adnlp_model_backend()

        # ExaModeler defaults: base_type and backend have defaults, minimize has none.
        opts_exa = CTModels.default_options(CTModels.ExaModeler)
        Test.@test opts_exa.base_type === CTModels.__exa_model_base_type()
        Test.@test opts_exa.backend === CTModels.__exa_model_backend()
        Test.@test :minimize ∉ propertynames(opts_exa)

        exa_backend = CTModels.ExaModeler()
        exa_type_from_instance = typeof(exa_backend)

        opts_exa_inst = CTModels.default_options(exa_type_from_instance)
        Test.@test opts_exa_inst == opts_exa

        Test.@test CTModels.option_default(:base_type, CTModels.ExaModeler) ===
            CTModels.__exa_model_base_type()
        Test.@test CTModels.option_default(:backend, CTModels.ExaModeler) ===
            CTModels.__exa_model_backend()
        Test.@test CTModels.option_default(:minimize, CTModels.ExaModeler) === missing

        Test.@test CTModels.option_default(:base_type, exa_type_from_instance) ===
            CTModels.__exa_model_base_type()
        Test.@test CTModels.option_default(:backend, exa_type_from_instance) ===
            CTModels.__exa_model_backend()
        Test.@test CTModels.option_default(:minimize, exa_type_from_instance) === missing
    end

    Test.@testset "modeler symbols and registry" verbose=VERBOSE showtiming=SHOWTIMING begin
        # get_symbol on types and instances
        Test.@test CTModels.get_symbol(CTModels.ADNLPModeler) == :adnlp
        Test.@test CTModels.get_symbol(CTModels.ExaModeler) == :exa
        Test.@test CTModels.get_symbol(CTModels.ADNLPModeler()) == :adnlp
        Test.@test CTModels.get_symbol(CTModels.ExaModeler()) == :exa

        # tool_package_name on types and instances
        Test.@test CTModels.tool_package_name(CTModels.ADNLPModeler) == "ADNLPModels"
        Test.@test CTModels.tool_package_name(CTModels.ExaModeler) == "ExaModels"
        Test.@test CTModels.tool_package_name(CTModels.ADNLPModeler()) == "ADNLPModels"
        Test.@test CTModels.tool_package_name(CTModels.ExaModeler()) == "ExaModels"

        regs = CTModels.registered_modeler_types()
        Test.@test CTModels.ADNLPModeler in regs
        Test.@test CTModels.ExaModeler in regs

        syms = CTModels.modeler_symbols()
        Test.@test :adnlp in syms
        Test.@test :exa in syms

        # build_modeler_from_symbol should construct proper concrete modelers.
        m_ad = CTModels.build_modeler_from_symbol(:adnlp; backend=:manual)
        Test.@test m_ad isa CTModels.ADNLPModeler
        vals_ad = CTModels._options_values(m_ad)
        Test.@test vals_ad.backend == :manual

        m_exa = CTModels.build_modeler_from_symbol(:exa; base_type=Float32)
        Test.@test m_exa isa CTModels.ExaModeler{Float32}
    end

    Test.@testset "build_modeler_from_symbol unknown symbol" verbose=VERBOSE showtiming=SHOWTIMING begin
        err = nothing
        try
            CTModels.build_modeler_from_symbol(:foo)
        catch e
            err = e
        end
        Test.@test err isa CTBase.IncorrectArgument

        buf = sprint(showerror, err)
        Test.@test occursin("Unknown NLP model symbol", buf)
        Test.@test occursin("foo", buf)
        # The message should list the supported symbols from modeler_symbols().
        for sym in CTModels.modeler_symbols()
            Test.@test occursin(string(sym), buf)
        end
    end

    Test.@testset "tool_package_name default implementation" verbose=VERBOSE showtiming=SHOWTIMING begin
        # For types without specialization, tool_package_name should return missing.
        dummy = CM_DummyModelerMissing()
        Test.@test CTModels.tool_package_name(CM_DummyModelerMissing) === missing
        Test.@test CTModels.tool_package_name(dummy) === missing
    end

    # ------------------------------------------------------------------
    # Solution-building via ADNLPModeler/ExaModeler(prob, nlp_solution)
    # ------------------------------------------------------------------
    # For OptimizationProblem (defined in test/problems/problems_definition.jl),
    # get_adnlp_solution_builder and get_exa_solution_builder return custom
    # solution builders (ADNLPSolutionBuilder, ExaSolutionBuilder) that are
    # callable on the nlp_solution and simply return it unchanged. Here we
    # verify that the backends correctly route through those builders.

    Test.@testset "ADNLPModeler solution building" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Build an OptimizationProblem with dummy builders (unused in this test)
        dummy_ad_builder = CTModels.ADNLPModelBuilder(x -> error("unused"))
        function dummy_exa_builder_f(::Type{T}, x; kwargs...) where {T}
            error("unused")
        end
        dummy_exa_builder = CTModels.ExaModelBuilder(dummy_exa_builder_f)
        prob = OptimizationProblem(
            dummy_ad_builder,
            dummy_exa_builder,
            ADNLPSolutionBuilder(),
            ExaSolutionBuilder(),
        )

        stats = CM_DummyBackendStats()
        modeler = CTModels.ADNLPModeler()
        # Should call get_adnlp_solution_builder(prob) and then
        # builder(stats), which is implemented in problems_definition.jl
        # to return stats unchanged.
        result = modeler(prob, stats)
        Test.@test result === stats
    end

    Test.@testset "ExaModeler solution building" verbose=VERBOSE showtiming=SHOWTIMING begin
        dummy_ad_builder = CTModels.ADNLPModelBuilder(x -> error("unused"))
        function dummy_exa_builder_f2(::Type{T}, x; kwargs...) where {T}
            error("unused")
        end
        dummy_exa_builder = CTModels.ExaModelBuilder(dummy_exa_builder_f2)
        prob = OptimizationProblem(
            dummy_ad_builder,
            dummy_exa_builder,
            ADNLPSolutionBuilder(),
            ExaSolutionBuilder(),
        )

        stats = CM_DummyBackendStats()
        modeler = CTModels.ExaModeler()
        # Should call get_exa_solution_builder(prob) and then
        # builder(stats), which returns stats.
        result = modeler(prob, stats)
        Test.@test result === stats
    end
end
