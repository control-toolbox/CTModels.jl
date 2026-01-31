module TestOrchestrationRouting

using Test
using CTModels
using CTModels.Orchestration
using CTModels.Strategies
using CTModels.Options
using CTBase
using Main.TestOptions: VERBOSE, SHOWTIMING

# ============================================================================
# Test fixtures
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
    Test.@testset "Orchestration Routing" verbose = VERBOSE showtiming = SHOWTIMING begin
        
        # ====================================================================
        # Auto-routing (unambiguous options)
        # ====================================================================
        
        Test.@testset "Auto-routing unambiguous options" begin
            kwargs = (
                grid_size = 200,
                max_iter = 2000,
                display = false
            )
            
            routed = Orchestration.route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
            
            # Check action options (Dict of OptionValue wrappers)
            Test.@test haskey(routed.action, :display)
            Test.@test routed.action[:display].value === false
            Test.@test routed.action[:display].source === :user
            
            # Check strategy options (raw NamedTuples)
            Test.@test haskey(routed.strategies, :discretizer)
            Test.@test haskey(routed.strategies, :modeler)
            Test.@test haskey(routed.strategies, :solver)
            
            # Access raw values from NamedTuples
            Test.@test haskey(routed.strategies.discretizer, :grid_size)
            Test.@test routed.strategies.discretizer[:grid_size] == 200
            Test.@test haskey(routed.strategies.solver, :max_iter)
            Test.@test routed.strategies.solver[:max_iter] == 2000
        end
        
        # ====================================================================
        # Single strategy disambiguation
        # ====================================================================
        
        Test.@testset "Single strategy disambiguation" begin
            kwargs = (
                backend = (:sparse, :adnlp),
                display = true
            )
            
            routed = Orchestration.route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
            
            # backend should be routed to modeler only
            Test.@test haskey(routed.strategies.modeler, :backend)
            Test.@test routed.strategies.modeler[:backend] === :sparse
            Test.@test !haskey(routed.strategies.solver, :backend)
        end
        
        # ====================================================================
        # Multi-strategy disambiguation
        # ====================================================================
        
        Test.@testset "Multi-strategy disambiguation" begin
            kwargs = (
                backend = ((:sparse, :adnlp), (:cpu, :ipopt)),
            )
            
            routed = Orchestration.route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
            
            # backend should be routed to both
            Test.@test haskey(routed.strategies.modeler, :backend)
            Test.@test routed.strategies.modeler[:backend] === :sparse
            Test.@test haskey(routed.strategies.solver, :backend)
            Test.@test routed.strategies.solver[:backend] === :cpu
        end
        
        # ====================================================================
        # Error: Unknown option
        # ====================================================================
        
        Test.@testset "Error on unknown option" begin
            kwargs = (unknown_option = 123,)
            
            Test.@test_throws CTModels.Exceptions.IncorrectArgument Orchestration.route_all_options(
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
        
        Test.@testset "Error on ambiguous option" begin
            kwargs = (backend = :sparse,)  # No disambiguation
            
            Test.@test_throws CTModels.Exceptions.IncorrectArgument Orchestration.route_all_options(
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
        
        Test.@testset "Error on invalid disambiguation" begin
            # Try to route max_iter to modeler (wrong family)
            kwargs = (max_iter = (1000, :adnlp),)
            
            Test.@test_throws CTModels.Exceptions.IncorrectArgument Orchestration.route_all_options(
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
        
        Test.@testset "Integration: Mixed routing" begin
            kwargs = (
                grid_size = 150,
                backend = ((:sparse, :adnlp), (:gpu, :ipopt)),
                max_iter = 500,
                display = false,
                initial_guess = :warm
            )
            
            routed = Orchestration.route_all_options(
                ROUTING_METHOD,
                ROUTING_FAMILIES,
                ROUTING_ACTION_DEFS,
                kwargs,
                ROUTING_REGISTRY
            )
            
            # Action options (Dict of OptionValue wrappers)
            Test.@test routed.action[:display].value === false
            Test.@test routed.action[:initial_guess].value === :warm
            
            # Strategy options (raw NamedTuples)
            Test.@test routed.strategies.discretizer[:grid_size] == 150
            Test.@test routed.strategies.modeler[:backend] === :sparse
            Test.@test routed.strategies.solver[:backend] === :gpu
            Test.@test routed.strategies.solver[:max_iter] == 500
        end
    end
end

end # module

test_routing() = TestOrchestrationRouting.test_routing()
