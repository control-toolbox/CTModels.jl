# Tutorial: Creating a Strategy Family

In this tutorial, we will group multiple related strategies into a **Strategy Family** and create a **Registry**. This allows users to select between different implementations at runtime.

We will create a family of `AbstractGreeter` strategies that print messages in different styles.

## Step 1: Define the Family Abstract Type

All members of the family must share a common abstract supertype unique to that family.

```julia
using CTModels.Strategies

abstract type AbstractGreeter <: AbstractStrategy end
```

## Step 2: Implement Family Members

Let's create two strategies: `PoliteGreeter` and `CasualGreeter`.

### Member 1: PoliteGreeter

```julia
struct PoliteGreeter <: AbstractGreeter
    options::StrategyOptions
end

Strategies.id(::Type{PoliteGreeter}) = :polite

Strategies.metadata(::Type{PoliteGreeter}) = StrategyMetadata(
    OptionDefinition(
        name = :honorific,
        type = String,
        default = "Mr./Ms.",
        description = "Title to use"
    )
)

function PoliteGreeter(; kwargs...)
    PoliteGreeter(Strategies.build_strategy_options(PoliteGreeter; kwargs...))
end
```

### Member 2: CasualGreeter

```julia
struct CasualGreeter <: AbstractGreeter
    options::StrategyOptions
end

Strategies.id(::Type{CasualGreeter}) = :casual

Strategies.metadata(::Type{CasualGreeter}) = StrategyMetadata(
    OptionDefinition(
        name = :slang,
        type = Bool,
        default = false,
        description = "Use slang"
    )
)

function CasualGreeter(; kwargs...)
    CasualGreeter(Strategies.build_strategy_options(CasualGreeter; kwargs...))
end
```

## Step 3: Create a Registry

Now we create a registry that tells the system which IDs map to which Types for the `AbstractGreeter` family.

```julia
const GREETER_REGISTRY = Strategies.create_registry(
    AbstractGreeter => (PoliteGreeter, CasualGreeter)
)
```

## Step 4: Use the Registry to Build Strategies

We can now write a generic function that takes a symbol (the ID) and returns the correct greeter.

```julia
function get_greeter(style::Symbol; kwargs...)
    # Use the registry to build the correct strategy
    return Strategies.build_strategy(
        style,              # :polite or :casual
        AbstractGreeter,    # The family we expect
        GREETER_REGISTRY;   # The registry to look in
        kwargs...           # Options to pass to the constructor
    )
end

# Usage:
g1 = get_greeter(:polite)
# PoliteGreeter(...)

g2 = get_greeter(:casual, slang=true)
# CasualGreeter(...)
```

## Step 5: Introspection

The registry and strategy Metadata allow us to inspect what is available.

```julia
# What greeters are available?
ids = Strategies.strategy_ids(AbstractGreeter, GREETER_REGISTRY)
# (:polite, :casual)

# What options does the :polite greeter have?
g_type = Strategies.type_from_id(:polite, AbstractGreeter, GREETER_REGISTRY)
opts = Strategies.option_names(g_type)
# (:honorific,)
```

## Complete Code

```julia
using CTModels.Strategies

# 1. Family
abstract type AbstractGreeter <: AbstractStrategy end

# 2. Members
struct PoliteGreeter <: AbstractGreeter
    options::StrategyOptions
end
Strategies.id(::Type{PoliteGreeter}) = :polite
Strategies.metadata(::Type{PoliteGreeter}) = StrategyMetadata(
    OptionDefinition(name=:honorific, type=String, default="Sir")
)
PoliteGreeter(; kw...) = PoliteGreeter(Strategies.build_strategy_options(PoliteGreeter; kw...))

struct CasualGreeter <: AbstractGreeter
    options::StrategyOptions
end
Strategies.id(::Type{CasualGreeter}) = :casual
Strategies.metadata(::Type{CasualGreeter}) = StrategyMetadata(
    OptionDefinition(name=:slang, type=Bool, default=false)
)
CasualGreeter(; kw...) = CasualGreeter(Strategies.build_strategy_options(CasualGreeter; kw...))

# 3. Registry
const GREETER_REGISTRY = Strategies.create_registry(
    AbstractGreeter => (PoliteGreeter, CasualGreeter)
)

# 4. Usage
using Test
g = Strategies.build_strategy(:polite, AbstractGreeter, GREETER_REGISTRY; honorific="Madam")
@test g isa PoliteGreeter
@test Strategies.option_value(g, :honorific) == "Madam"
```

## Next Steps

This pattern is the foundation for how `CTModels` handles Solvers, Modelers, and other interchangeable components.
