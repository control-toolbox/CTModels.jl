# Type aliases for CTModels

"""
Type alias for a dimension. This is used to define the dimension of the state space, 
the costate space, the control space, etc.

```@example
julia> const Dimension = Integer
```
"""
const Dimension = Int

"""
Type alias for a real number.

```@example
julia> const ctNumber = Real
```
"""
const ctNumber = Real

"""
Type alias for a time.

```@example
julia> const Time = ctNumber
```

See also: [`ctNumber`](@ref), [`Times`](@ref CTModels.OCP.Times), [`TimesDisc`](@ref).
"""
const Time = ctNumber

"""
Type alias for a vector of real numbers.

```@example
julia> const ctVector = AbstractVector{<:ctNumber}
```

See also: [`ctNumber`](@ref).
"""
const ctVector = AbstractVector{<:ctNumber}

"""
Type alias for a vector of times.

```@example
julia> const Times = AbstractVector{<:Time}
```

See also: [`Time`](@ref), [`TimesDisc`](@ref).
"""
const Times = AbstractVector{<:Time}

"""
Type alias for a grid of times. This is used to define a discretization of time interval given to solvers.

```@example
julia> const TimesDisc = Union{Times, StepRangeLen}
```

See also: [`Time`](@ref), [`Times`](@ref CTModels.OCP.Times).
"""
const TimesDisc = Union{Times,StepRangeLen}

"""
Type alias for a dictionary of constraints. This is used to store constraints before building the model.

```@example
julia> const TimesDisc = Union{Times, StepRangeLen}
```

See also: [`ConstraintsModel`](@ref), [`PreModel`](@ref) and [`Model`](@ref CTModels.OCP.Model).
"""
const ConstraintsDictType = OrderedDict{
    Symbol,Tuple{Symbol,Union{Function,OrdinalRange{<:Int}},ctVector,ctVector}
}
