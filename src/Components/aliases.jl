# Type aliases for CTModels

"""
Type alias for a dimension, used for the state, costate, control and variable spaces.

```julia
const Dimension = Int
```

See also: [`CTModels.Components.ctNumber`](@ref).
"""
const Dimension = Int

"""
Type alias for a real number.

```julia
const ctNumber = Real
```

See also: [`CTModels.Components.Dimension`](@ref), [`CTModels.Components.Time`](@ref), [`CTModels.Components.ctVector`](@ref).
"""
const ctNumber = Real

"""
Type alias for a (continuous) time.

```julia
const Time = ctNumber
```

See also: [`CTModels.Components.ctNumber`](@ref), [`CTModels.Components.Times`](@ref),
[`CTModels.Components.TimesDisc`](@ref).
"""
const Time = ctNumber

"""
Type alias for a vector of real numbers.

```julia
const ctVector = AbstractVector{<:ctNumber}
```

See also: [`CTModels.Components.ctNumber`](@ref), [`CTModels.Components.Dimension`](@ref).
"""
const ctVector = AbstractVector{<:ctNumber}

"""
Type alias for a vector of times.

```julia
const Times = AbstractVector{<:Time}
```

See also: [`CTModels.Components.Time`](@ref), [`CTModels.Components.TimesDisc`](@ref).
"""
const Times = AbstractVector{<:Time}

"""
Type alias for a grid of times, used to discretize the time interval given to solvers.

```julia
const TimesDisc = Union{Times,StepRangeLen}
```

See also: [`CTModels.Components.Time`](@ref), [`CTModels.Components.Times`](@ref).
"""
const TimesDisc = Union{Times,StepRangeLen}

"""
Type alias for a dictionary of constraints, used to store constraints before building the model.

```julia
const ConstraintsDictType = OrderedCollections.OrderedDict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}
```

See also: [`CTModels.Components.ConstraintsModel`](@ref).
"""
const ConstraintsDictType = OrderedCollections.OrderedDict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}
