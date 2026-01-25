# ============================================================================
# Tests for Orchestration method builder wrappers
# ============================================================================

using Test
using CTModels.Orchestration
using CTModels.Strategies
using CTModels.Options
using CTBase

# ============================================================================
# Test fixtures (minimal strategy setup)
# ============================================================================

abstract type BuilderTestDiscretizer <: Strategies.AbstractStrategy end
abstract type BuilderTestModeler <: Strategies.AbstractStrategy end

struct BuilderCollocation <: BuilderTestDiscretizer
    options::Strategies.StrategyOptions
end

Strategies.id(::Type{BuilderCollocation}) = :collocation
Strategies.metadata(::Type{BuilderCollocation}) = Strategies.StrategyMetadata(
    Options.OptionDefinition(
        name = :grid_size,
        type = Int,
        default = 100,
        description = "Grid size"
    )
)
Strategies.options(s::BuilderCollocation) = s.options

struct BuilderADNLP <: BuilderTestModeler
    options::Strategies.StrategyOptions
end

Strategies.id(::Type{BuilderADNLP}) = :adnlp
Strategies.metadata(::Type{BuilderADNLP}) = Strategies.StrategyMetadata(
    Options.OptionDefinition(
        name = :backend,
        type = Symbol,
        default = :dense,
        description = "Backend type"
    ),
    Options.OptionDefinition(
        name = :show_time,
        type = Bool,
        default = false,
        description = "Show timing"
    )
)
Strategies.options(s::BuilderADNLP) = s.options

# Constructors
function BuilderCollocation(; kwargs...)
    meta = Strategies.metadata(BuilderCollocation)
    defs = collect(values(meta.specs))
    extracted, _ = Options.extract_options((; kwargs...), defs)
    opts = Strategies.StrategyOptions(NamedTuple(extracted))
    return BuilderCollocation(opts)
end

function BuilderADNLP(; kwargs...)
    meta = Strategies.metadata(BuilderADNLP)
    defs = collect(values(meta.specs))
    extracted, _ = Options.extract_options((; kwargs...), defs)
    opts = Strategies.StrategyOptions(NamedTuple(extracted))
    return BuilderADNLP(opts)
end

const BUILDER_REGISTRY = Strategies.create_registry(
    BuilderTestDiscretizer => (BuilderCollocation,),
    BuilderTestModeler => (BuilderADNLP,)
)

const BUILDER_METHOD = (:collocation, :adnlp)

# ============================================================================
# Test function
# ============================================================================

function test_method_builders()
    @testset "Orchestration Method Builders" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # build_strategy_from_method - Wrapper Tests
        # ====================================================================
        
        @testset "build_strategy_from_method" begin
            # Build with default options
            discretizer = Orchestration.build_strategy_from_method(
                BUILDER_METHOD,
                BuilderTestDiscretizer,
                BUILDER_REGISTRY
            )
            
            @test discretizer isa BuilderCollocation
            @test Strategies.option_value(discretizer, :grid_size) == 100
            
            # Build with custom options
            discretizer2 = Orchestration.build_strategy_from_method(
                BUILDER_METHOD,
                BuilderTestDiscretizer,
                BUILDER_REGISTRY;
                grid_size = 200
            )
            
            @test discretizer2 isa BuilderCollocation
            @test Strategies.option_value(discretizer2, :grid_size) == 200
            
            # Build modeler
            modeler = Orchestration.build_strategy_from_method(
                BUILDER_METHOD,
                BuilderTestModeler,
                BUILDER_REGISTRY;
                backend = :sparse,
                show_time = true
            )
            
            @test modeler isa BuilderADNLP
            @test Strategies.option_value(modeler, :backend) === :sparse
            @test Strategies.option_value(modeler, :show_time) === true
        end
        
        # ====================================================================
        # option_names_from_method - Wrapper Tests
        # ====================================================================
        
        @testset "option_names_from_method" begin
            # Get option names for discretizer
            names = Orchestration.option_names_from_method(
                BUILDER_METHOD,
                BuilderTestDiscretizer,
                BUILDER_REGISTRY
            )
            
            @test names isa Tuple
            @test :grid_size in names
            @test length(names) == 1
            
            # Get option names for modeler
            names2 = Orchestration.option_names_from_method(
                BUILDER_METHOD,
                BuilderTestModeler,
                BUILDER_REGISTRY
            )
            
            @test names2 isa Tuple
            @test :backend in names2
            @test :show_time in names2
            @test length(names2) == 2
        end
        
        # ====================================================================
        # Integration: Build and inspect
        # ====================================================================
        
        @testset "Integration: Build and inspect workflow" begin
            # 1. Get option names
            discretizer_opts = Orchestration.option_names_from_method(
                BUILDER_METHOD,
                BuilderTestDiscretizer,
                BUILDER_REGISTRY
            )
            modeler_opts = Orchestration.option_names_from_method(
                BUILDER_METHOD,
                BuilderTestModeler,
                BUILDER_REGISTRY
            )
            
            @test :grid_size in discretizer_opts
            @test :backend in modeler_opts
            
            # 2. Build strategies with those options
            discretizer = Orchestration.build_strategy_from_method(
                BUILDER_METHOD,
                BuilderTestDiscretizer,
                BUILDER_REGISTRY;
                grid_size = 150
            )
            modeler = Orchestration.build_strategy_from_method(
                BUILDER_METHOD,
                BuilderTestModeler,
                BUILDER_REGISTRY;
                backend = :sparse
            )
            
            # 3. Verify strategies were built correctly
            @test discretizer isa BuilderCollocation
            @test modeler isa BuilderADNLP
            @test Strategies.option_value(discretizer, :grid_size) == 150
            @test Strategies.option_value(modeler, :backend) === :sparse
        end
    end
end
