# Strategies Module - registry.jl

"""
    StrategyRegistry

Registry mapping strategy families to their concrete types.

# Fields
- `families::Dict{Type{<:AbstractStrategy}, Vector{Type}}` - Family => [Strategy types]

# Example
```julia
registry = create_registry(
    AbstractOptimizationModeler => (ADNLPModeler, ExaModeler),
    AbstractOptimizationSolver => (IpoptSolver, MadNLPSolver)
)
```
"""
struct StrategyRegistry
    families::Dict{Type{<:AbstractStrategy}, Vector{Type}}
end

"""
    create_registry(pairs::Pair{Type{<:AbstractStrategy}, <:Tuple}...)

Create a strategy registry from family => strategies pairs.

# Validation
- All strategy IDs must be unique within a family
- All strategies must be subtypes of their family

# Example
```julia
registry = create_registry(
    AbstractOptimizationModeler => (ADNLPModeler, ExaModeler),
    AbstractOptimizationSolver => (IpoptSolver, MadNLPSolver, KnitroSolver)
)
```
"""
function create_registry(pairs::Pair{Type{<:AbstractStrategy}, <:Tuple}...)
    families = Dict{Type{<:AbstractStrategy}, Vector{Type}}()
    
    for (family, strategies) in pairs
        # Validate uniqueness of IDs
        ids = [symbol(T) for T in strategies]
        if length(ids) != length(unique(ids))
            duplicates = [id for id in ids if count(==(id), ids) > 1]
            error("Duplicate IDs in family $family: $duplicates")
        end
        
        # Validate all strategies are subtypes of family
        for T in strategies
            if !(T <: family)
                error("Type $T is not a subtype of $family")
            end
        end
        
        families[family] = collect(strategies)
    end
    
    return StrategyRegistry(families)
end

"""
    strategy_ids(family::Type{<:AbstractStrategy}, registry::StrategyRegistry)

Get all strategy IDs for a family.

# Example
```julia
ids = strategy_ids(AbstractOptimizationModeler, registry)
# => (:adnlp, :exa)
```
"""
function strategy_ids(family::Type{<:AbstractStrategy}, registry::StrategyRegistry)
    if !haskey(registry.families, family)
        error("Family $family not found in registry")
    end
    strategies = registry.families[family]
    return Tuple(symbol(T) for T in strategies)
end

"""
    type_from_id(id::Symbol, family::Type{<:AbstractStrategy}, registry::StrategyRegistry)

Lookup a strategy type from its ID within a family.

# Example
```julia
T = type_from_id(:adnlp, AbstractOptimizationModeler, registry)
# => ADNLPModeler
```
"""
function type_from_id(
    id::Symbol,
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry
)
    if !haskey(registry.families, family)
        error("Family $family not found in registry")
    end
    
    for T in registry.families[family]
        if symbol(T) === id
            return T
        end
    end
    
    available = strategy_ids(family, registry)
    error("Unknown ID :$id for family $family. Available: $available")
end
