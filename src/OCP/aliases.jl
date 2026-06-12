# Type aliases for CTModels

"""
Type alias for a dimension, used for the state, costate, control and variable spaces.

```julia
const Dimension = Int
```
"""
const Dimension = Int

"""
Type alias for a real number.

```julia
const ctNumber = Real
```
"""
const ctNumber = Real

"""
Type alias for a (continuous) time.

```julia
const Time = ctNumber
```

See also: [`CTModels.OCP.ctNumber`](@ref), [`CTModels.OCP.Times`](@ref), [`CTModels.OCP.TimesDisc`](@ref).
"""
const Time = ctNumber

"""
Type alias for a vector of real numbers.

```julia
const ctVector = AbstractVector{<:ctNumber}
```

See also: [`CTModels.OCP.ctNumber`](@ref).
"""
const ctVector = AbstractVector{<:ctNumber}

"""
Type alias for a vector of times.

```julia
const Times = AbstractVector{<:Time}
```

See also: [`CTModels.OCP.Time`](@ref), [`CTModels.OCP.TimesDisc`](@ref).
"""
const Times = AbstractVector{<:Time}

"""
Type alias for a grid of times, used to discretize the time interval given to solvers.

```julia
const TimesDisc = Union{Times,StepRangeLen}
```

See also: [`CTModels.OCP.Time`](@ref), [`CTModels.OCP.Times`](@ref).
"""
const TimesDisc = Union{Times,StepRangeLen}

"""
Type alias for a dictionary of constraints, used to store constraints before building the model.

```julia
const ConstraintsDictType = OrderedCollections.OrderedDict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}
```

See also: [`CTModels.OCP.ConstraintsModel`](@ref), [`CTModels.OCP.PreModel`](@ref),
[`CTModels.OCP.Model`](@ref).
"""
const ConstraintsDictType = OrderedCollections.OrderedDict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}
