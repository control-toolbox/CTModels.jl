# Strategies Module - builders.jl

"""
    build_strategy(id::Symbol, family::Type{<:AbstractStrategy}, registry::StrategyRegistry; kwargs...)

Build a strategy instance from its ID and options.

# Example
```julia
modeler = build_strategy(:adnlp, AbstractOptimizationModeler, registry; backend=:sparse)
# => ADNLPModeler(backend=:sparse)
```
"""
function build_strategy(
    id::Symbol,
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry;
    kwargs...
)
    T = type_from_id(id, family, registry)
    return T(; kwargs...)
end

"""
    extract_id_from_method(method::Tuple{Vararg{Symbol}}, family::Type{<:AbstractStrategy}, registry::StrategyRegistry)

Extract the ID for a specific family from a method tuple.

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
id = extract_id_from_method(method, AbstractOptimizationModeler, registry)
# => :adnlp
```
"""
function extract_id_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry
)
    allowed = strategy_ids(family, registry)
    hits = Symbol[]
    
    for s in method
        if s in allowed
            push!(hits, s)
        end
    end
    
    if length(hits) == 1
        return hits[1]
    elseif isempty(hits)
        error("No ID for family $family found in method $method. Available: $allowed")
    else
        error("Multiple IDs $hits for family $family found in method $method")
    end
end

"""
    option_names_from_method(method::Tuple{Vararg{Symbol}}, family::Type{<:AbstractStrategy}, registry::StrategyRegistry)

Get option names for a family from a method tuple.

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
keys = option_names_from_method(method, AbstractOptimizationModeler, registry)
# => (:backend, :show_time)
```
"""
function option_names_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry
)
    id = extract_id_from_method(method, family, registry)
    strategy_type = type_from_id(id, family, registry)
    return option_names(strategy_type)
end

"""
    build_strategy_from_method(method::Tuple{Vararg{Symbol}}, family::Type{<:AbstractStrategy}, registry::StrategyRegistry; kwargs...)

Build a strategy from a method tuple and options.

# Example
```julia
method = (:collocation, :adnlp, :ipopt)
modeler = build_strategy_from_method(method, AbstractOptimizationModeler, registry; backend=:sparse)
# => ADNLPModeler(backend=:sparse)
```
"""
function build_strategy_from_method(
    method::Tuple{Vararg{Symbol}},
    family::Type{<:AbstractStrategy},
    registry::StrategyRegistry;
    kwargs...
)
    id = extract_id_from_method(method, family, registry)
    return build_strategy(id, family, registry; kwargs...)
end
