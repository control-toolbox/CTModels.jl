# Type aliases for CTModels

"""
Type alias for a dimension, used for the state, costate, control and variable spaces.

```julia
const Dimension = Int
```

See also: [`CTModels.Components.ctNumber`](@extref).
"""
const Dimension = Int

"""
Type alias for a real number.

```julia
const ctNumber = Real
```

See also: [`CTModels.Components.Dimension`](@extref), [`CTModels.Components.Time`](@extref), [`CTModels.Components.ctVector`](@extref).
"""
const ctNumber = Real

"""
Type alias for a (continuous) time.

```julia
const Time = ctNumber
```

See also: [`CTModels.Components.ctNumber`](@extref), [`CTModels.Components.Times`](@extref),
[`CTModels.Components.TimesDisc`](@extref).
"""
const Time = ctNumber

"""
Type alias for a vector of real numbers.

```julia
const ctVector = AbstractVector{<:ctNumber}
```

See also: [`CTModels.Components.ctNumber`](@extref), [`CTModels.Components.Dimension`](@extref).
"""
const ctVector = AbstractVector{<:ctNumber}

"""
Type alias for a vector of times.

```julia
const Times = AbstractVector{<:Time}
```

See also: [`CTModels.Components.Time`](@extref), [`CTModels.Components.TimesDisc`](@extref).
"""
const Times = AbstractVector{<:Time}

"""
Type alias for a grid of times, used to discretize the time interval given to solvers.

```julia
const TimesDisc = Union{Times,StepRangeLen}
```

See also: [`CTModels.Components.Time`](@extref), [`CTModels.Components.Times`](@extref).
"""
const TimesDisc = Union{Times,StepRangeLen}

"""
Type alias for a dictionary of constraints, used to store constraints before building the model.

```julia
const ConstraintsDictType = OrderedCollections.OrderedDict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}
```

See also: [`CTModels.Components.ConstraintsModel`](@extref).
"""
const ConstraintsDictType = OrderedCollections.OrderedDict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}
