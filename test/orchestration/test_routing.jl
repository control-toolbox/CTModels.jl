# ============================================================================
# Integration tests for Orchestration route_all_options
# ============================================================================

using Test
using CTModels.Orchestration
using CTModels.Strategies
using CTModels.Options
using CTBase

# ============================================================================
# Test fixtures (reuse from test_disambiguation for consistency)
# ============================================================================

abstract type RoutingTestDiscretizer <: Strategies.AbstractStrategy end
abstract type RoutingTestModeler <: Strategies.AbstractStrategy end
abstract type RoutingTestSolver <: Strategies.AbstractStrategy end

struct RoutingCollocation <: RoutingTestDiscretizer end
Strategies.id(::Type{RoutingCollocation}) = :collocation
Strategies.metadata(::Type{RoutingCollocation}) = Strategies.StrategyMetadata(
    Options.OptionDefinition(
        name = :grid_size,
        type = Int,
        default = 100,
        description = "Grid size"
    )
)

struct RoutingADNLP <: RoutingTestModeler end
Strategies.id(::Type{RoutingADNLP}) = :adnlp
Strategies.metadata(::Type{RoutingADNLP}) = Strategies.StrategyMetadata(
    Options.OptionDefinition(
        name = :backend,
        type = Symbol,
        default = :dense,
        description = "Backend type"
    )
)

struct RoutingIpopt <: RoutingTestSolver end
Strategies.id(::Type{RoutingIpopt}) = :ipopt
Strategies.metadata(::Type{RoutingIpopt}) = Strategies.StrategyMetadata(
    Options.OptionDefinition(
        name = :max_iter,
        type = Int,
        default = 1000,
        description = "Maximum iterations"
    ),
    Options.OptionDefinition(
        name = :backend,
        type = Symbol,
        default = :cpu,
        description = "Solver backend"
    )
)

const ROUTING_REGISTRY = Strategies.create_registry(
    RoutingTestDiscretizer => (RoutingCollocation,),
    RoutingTestModeler => (RoutingADNLP,),
    RoutingTestSolver => (RoutingIpopt,)
)

const ROUTING_METHOD = (:collocation, :adnlp, :ipopt)

const ROUTING_FAMILIES = (
    discretizer = RoutingTestDiscretizer,
    modeler = RoutingTestModeler,
    solver = RoutingTestSolver
)

const ROUTING_ACTION_DEFS = [
    Options.OptionDefinition(
        name = :display,
        type = Bool,
        default = true,
        description = "Display progress"
    ),
    Options.OptionDefinition(
        name = :initial_guess,
        type = Any,
        default = nothing,
        description = "Initial guess"
    )
]

# ============================================================================
# Test function
# ============================================================================

function test_routing()
    @testset "Orchestration Routing" verbose=VERBOSE showtiming=SHOWTIMING begin
        
        # ====================================================================
        # Auto-routing (unambiguous options)
        # ====================================================================
        
        @testset "Auto-routing unambiguous options" begin
            kwargs = (
                grid_size = 200,
                max_iter = 2000,
                display = false
            )
            
            routed = route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
            
            # Check action options (Dict of OptionValue wrappers)
            @test haskey(routed.action, :display)
            @test routed.action[:display].value === false
            @test routed.action[:display].source === :user
            
            # Check strategy options (raw NamedTuples)
            @test haskey(routed.strategies, :discretizer)
            @test haskey(routed.strategies, :modeler)
            @test haskey(routed.strategies, :solver)
            
            # Access raw values from NamedTuples
            @test haskey(routed.strategies.discretizer, :grid_size)
            @test routed.strategies.discretizer[:grid_size] == 200
            @test haskey(routed.strategies.solver, :max_iter)
            @test routed.strategies.solver[:max_iter] == 2000
        end
        
        # ====================================================================
        # Single strategy disambiguation
        # ====================================================================
        
        @testset "Single strategy disambiguation" begin
            kwargs = (
                backend = (:sparse, :adnlp),
                display = true
            )
            
            routed = route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
            
            # backend should be routed to modeler only
            @test haskey(routed.strategies.modeler, :backend)
            @test routed.strategies.modeler[:backend] === :sparse
            @test !haskey(routed.strategies.solver, :backend)
        end
        
        # ====================================================================
        # Multi-strategy disambiguation
        # ====================================================================
        
        @testset "Multi-strategy disambiguation" begin
            kwargs = (
                backend = ((:sparse, :adnlp), (:cpu, :ipopt)),
            )
            
            routed = route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
            
            # backend should be routed to both
            @test haskey(routed.strategies.modeler, :backend)
            @test routed.strategies.modeler[:backend] === :sparse
            @test haskey(routed.strategies.solver, :backend)
            @test routed.strategies.solver[:backend] === :cpu
        end
        
        # ====================================================================
        # Error: Unknown option
        # ====================================================================
        
        @testset "Error on unknown option" begin
            kwargs = (unknown_option = 123,)
            
            @test_throws CTBase.IncorrectArgument route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
        end
        
        # ====================================================================
        # Error: Ambiguous option without disambiguation
        # ====================================================================
        
        @testset "Error on ambiguous option" begin
            kwargs = (backend = :sparse,)  # No disambiguation
            
            @test_throws CTBase.IncorrectArgument route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
        end
        
        # ====================================================================
        # Error: Invalid disambiguation target
        # ====================================================================
        
        @testset "Error on invalid disambiguation" begin
            # Try to route max_iter to modeler (wrong family)
            kwargs = (max_iter = (1000, :adnlp),)
            
            @test_throws CTBase.IncorrectArgument route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
        end
        
        # ====================================================================
        # Integration: Mixed routing
        # ====================================================================
        
        @testset "Integration: Mixed routing" begin
            kwargs = (
                grid_size = 150,
                backend = ((:sparse, :adnlp), (:gpu, :ipopt)),
                max_iter = 500,
                display = false,
                initial_guess = :warm
            )
            
            routed = route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
            
            # Action options (Dict of OptionValue wrappers)
            @test routed.action[:display].value === false
            @test routed.action[:initial_guess].value === :warm
            
            # Strategy options (raw NamedTuples)
            @test routed.strategies.discretizer[:grid_size] == 150
            @test routed.strategies.modeler[:backend] === :sparse
            @test routed.strategies.solver[:backend] === :gpu
            @test routed.strategies.solver[:max_iter] == 500
        end
    end
end
