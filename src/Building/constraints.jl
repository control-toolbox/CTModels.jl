"""
$(TYPEDSIGNATURES)

Add a constraint to a dictionary of constraints.

# Arguments

- `ocp_constraints`: The dictionary of constraints to which the constraint will be added.
- `type`: The type of the constraint. It can be `:state`, `:control`, `:variable`, `:boundary`, or `:path`.
- `n`: The dimension of the state.
- `m`: The dimension of the control.
- `q`: The dimension of the variable.
- `rg`: The range of the constraint. It can be an integer or a range of integers.
- `f`: The function that defines the constraint. It must return a vector of the same dimension as the constraint.
- `lb`: The lower bound of the constraint. It can be a number or a vector.
- `ub`: The upper bound of the constraint. It can be a number or a vector.
- `label`: The label of the constraint. It must be unique in the dictionary of constraints.

# Requirements

- The constraint must not be set before.
- The lower bound `lb` and the upper bound `ub` cannot be both `nothing`.
- The lower bound `lb` and the upper bound `ub` must have the same length, if both provided.

If `rg` and `f` are not provided then, 

- `type` must be `:state`, `:control`, or `:variable`.
- `lb` and `ub` must be of dimension `n`, `m`, or `q` respectively, when provided.

If `rg` is provided, then:

- `f` must not be provided.
- `type` must be `:state`, `:control`, or `:variable`.
- `rg` must be a range of integers, and must be contained in `1:n`, `1:m`, or `1:q` respectively.

If `f` is provided, then:

- `rg` must not be provided.
- `type` must be `:boundary` or `:path`.
- `f` must be a function that returns a vector of the same dimension as the constraint.
- `lb` and `ub` must be of the same dimension as the output of `f`, when provided.

# Example

```julia-repl
julia> using CTModels

julia> ocp_constraints = CTModels.Components.ConstraintsDictType()

julia> CTModels.Building.__constraint!(ocp_constraints, :state, 3, 2, 1; rg=1:2, lb=[-1.0, -1.0], ub=[1.0, 1.0], label=:x_box);
```
"""
function __constraint!(
    ocp_constraints::ConstraintsDictType,
    type::Symbol,
    n::Dimension,
    m::Dimension,
    q::Dimension;
    rg::Union{Int,OrdinalRange{Int},Nothing}=nothing,
    f::Union{Function,Nothing}=nothing,
    lb::Union{ctNumber,ctVector,Nothing}=nothing,
    ub::Union{ctNumber,ctVector,Nothing}=nothing,
    label::Symbol=__constraint_label(),
    codim_f::Union{Dimension,Nothing}=nothing,
)

    # checks: the constraint must not be set before
    Core.@ensure(
        !(label ∈ keys(ocp_constraints)),
        Exceptions.PreconditionError(
            "Constraint already exists",
            reason="constraint with label '$(label)' is already defined",
            suggestion="Use a different label or remove the existing constraint first",
            context="constraint! function - duplicate label validation",
        ),
    )

    # checks: lb and ub cannot be both nothing
    Core.@ensure(
        !(isnothing(lb) && isnothing(ub)),
        Exceptions.PreconditionError(
            "Both bounds cannot be nothing",
            reason="constraint requires at least one bound (lower or upper)",
            suggestion="Provide lb (lower bound), ub (upper bound), or both",
            context="constraint! function - bounds validation",
        ),
    )

    # bounds
    isnothing(lb) && (lb = -Inf * ones(eltype(ub), length(ub)))
    isnothing(ub) && (ub = Inf * ones(eltype(lb), length(lb)))

    # lb and ub must have the same length
    Core.@ensure(
        length(lb) == length(ub),
        Exceptions.IncorrectArgument(
            "Bounds dimension mismatch",
            got="lb length=$(length(lb)), ub length=$(length(ub))",
            expected="lb and ub with same length",
            suggestion="Use constraint!(ocp, type, lb=[...], ub=[...]) with equal-length vectors",
            context="constraint!(ocp, type=:$type, lb=[...], ub=[...]) - validating bounds dimensions",
        ),
    )

    # NEW: Validate lb ≤ ub element-wise
    Core.@ensure(
        all(lb .<= ub),
        Exceptions.IncorrectArgument(
            "Invalid bounds: lower > upper",
            got="some lb[i] > ub[i] violations",
            expected="lb[i] ≤ ub[i] for all i",
            suggestion="Check bounds values: lb=[$(lb[1]),...] ≤ ub=[$(ub[1]),...]",
            context="constraint!(ocp, type=:$type, lb=[...], ub=[...]) - validating bounds order",
        ),
    )

    # add the constraint
    MLStyle.@match (rg, f, lb, ub) begin
        (::Nothing, ::Nothing, ::ctVector, ::ctVector) => begin
            if type == :state
                rg = 1:n
                txt = "the lower bound `lb` and the upper bound `ub` must be of dimension $n"
            elseif type == :control
                rg = 1:m
                txt = "the lower bound `lb` and the upper bound `ub` must be of dimension $m"
            elseif type == :variable
                rg = 1:q
                txt = "the lower bound `lb` and the upper bound `ub` must be of dimension $q"
            else
                throw(
                    Exceptions.IncorrectArgument(
                        "Invalid constraint type",
                        got="type=$type",
                        expected=":control, :state, or :variable",
                        suggestion="Choose a valid constraint type or check constraint! method arguments",
                        context="constraint! type validation",
                    ),
                )
            end
            Core.@ensure(
                length(rg) == length(lb),
                Exceptions.IncorrectArgument(
                    "Bounds dimension mismatch with implicit range",
                    got="range length=$(length(rg)), bounds length=$(length(lb))",
                    expected="range and bounds must have same dimension",
                    suggestion="Ensure bounds length matches implicit range (type only)",
                    context="constraint! with type but no explicit range - validating bounds dimension",
                )
            )
            __constraint!(ocp_constraints, type, n, m, q; rg=rg, lb=lb, ub=ub, label=label)
        end

        (::OrdinalRange{<:Int}, ::Nothing, ::ctVector, ::ctVector) => begin
            Core.@ensure(
                length(rg) == length(lb),
                Exceptions.IncorrectArgument(
                    "Range-bounds dimension mismatch with explicit range",
                    got="range length=$(length(rg)), bounds length=$(length(lb))",
                    expected="range and bounds must have same dimension",
                    suggestion="Ensure bounds length matches explicit range parameter",
                    context="constraint! with explicit range parameter - validating range-bounds match",
                )
            )
            # check if the range is valid
            if type == :state
                Core.@ensure(
                    all(1 .≤ rg .≤ n),
                    Exceptions.IncorrectArgument(
                        "Constraint range out of bounds",
                        got="range=$rg for state dimension $n",
                        expected="all indices in 1:$n",
                        suggestion="Use constraint!(ocp, :state, 1:$n, ...) or subset like 1:2",
                        context="constraint!(ocp, type=:state, rg=$rg) - validating range bounds",
                    ),
                )
            elseif type == :control
                Core.@ensure(
                    all(1 .≤ rg .≤ m),
                    Exceptions.IncorrectArgument(
                        "Constraint range out of bounds",
                        got="range=$rg for control dimension $m",
                        expected="all indices in 1:$m",
                        suggestion="Use constraint!(ocp, :control, 1:$m, ...) or subset like 1:2",
                        context="constraint!(ocp, type=:control, rg=$rg) - validating range bounds",
                    ),
                )
            elseif type == :variable
                Core.@ensure(
                    all(1 .≤ rg .≤ q),
                    Exceptions.IncorrectArgument(
                        "Constraint range out of bounds",
                        got="range=$rg for variable dimension $q",
                        expected="all indices in 1:$q",
                        suggestion="Use constraint!(ocp, :variable, 1:$q, ...) or subset like 1:2",
                        context="constraint!(ocp, type=:variable, rg=$rg) - validating range bounds",
                    ),
                )
            else
                throw(
                    Exceptions.IncorrectArgument(
                        "Invalid constraint type",
                        got="type=$type",
                        expected=":control, :state, or :variable",
                        suggestion="Choose a valid constraint type or check constraint! method arguments",
                        context="constraint! type validation",
                    ),
                )
            end
            # set the constraint
            ocp_constraints[label] = (type, rg, lb, ub)
        end

        (::Nothing, ::Function, ::ctVector, ::ctVector) => begin
            # ensure that codim_f has same length as lb if codim_f is not nothing
            if codim_f !== nothing
                Core.@ensure(
                    length(lb) == codim_f,
                    Exceptions.IncorrectArgument(
                        "Function bounds dimension mismatch",
                        got="bounds length=$(length(lb))",
                        expected="bounds length=codim_f=$codim_f",
                        suggestion="Ensure bounds length matches function output dimension",
                        context="constraint! function bounds validation",
                    )
                )
            end

            # set the constraint
            if type ∈ [:boundary, :path]
                ocp_constraints[label] = (type, f, lb, ub)
            else
                throw(
                    Exceptions.IncorrectArgument(
                        "Invalid constraint type",
                        got="type=$type",
                        expected=":boundary or :path",
                        suggestion="Choose a valid constraint type for function-based constraints",
                        context="constraint! function type validation",
                    ),
                )
            end
        end

        _ => throw(
            Exceptions.IncorrectArgument(
                "Inconsistent constraint arguments",
                got="arguments that don't match any valid constraint pattern",
                expected="valid combination of type, range, function, bounds, and label",
                suggestion="Check constraint! documentation for valid argument combinations. Common patterns: constraint!(ocp, :state, rg, f, lb, ub) or constraint!(ocp, :boundary, f)",
                context="constraint! argument validation",
            ),
        )
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Add a constraint to a pre-model. See [`CTModels.Building.__constraint!`](@ref) for more details.

# Arguments

- `ocp`: The pre-model to which the constraint will be added.
- `type`: The type of the constraint. It can be `:state`, `:control`, `:variable`, `:boundary`, or `:path`.
- `rg`: The range of the constraint. It can be an integer or a range of integers.
- `f`: The function that defines the constraint. It must return a vector of the same dimension as the constraint.
- `lb`: The lower bound of the constraint. It can be a number or a vector.
- `ub`: The upper bound of the constraint. It can be a number or a vector.
- `label`: The label of the constraint. It must be unique in the pre-model.

# Examples
```julia-repl
julia> using CTModels

julia> ocp = CTModels.PreModel(); CTModels.variable!(ocp, 0); CTModels.time!(ocp; t0=0, tf=1);

julia> CTModels.state!(ocp, 2); CTModels.control!(ocp, 2);

julia> CTModels.constraint!(ocp, :control; rg=1:2, lb=[-1.0, -1.0], ub=[1.0, 1.0], label=:u_box);
```

# Throws

- `Exceptions.PreconditionError`: If state has not been set
- `Exceptions.PreconditionError`: If times has not been set
- `Exceptions.PreconditionError`: If control has not been set **and** `type == :control`
- `Exceptions.PreconditionError`: If variable has not been set (when type=:variable)
- `Exceptions.PreconditionError`: If constraint with same label already exists
- `Exceptions.PreconditionError`: If both lb and ub are nothing
- `Exceptions.IncorrectArgument`: If lb and ub have different lengths
- `Exceptions.IncorrectArgument`: If lb > ub element-wise
- `Exceptions.IncorrectArgument`: If dimensions don't match expected sizes

# Returns
- `Nothing`

See also: [`CTModels.Building.state!`](@ref), [`CTModels.Building.control!`](@ref), [`CTModels.Building.variable!`](@ref).

!!! note
    Control is only required for `type == :control` constraints. All other types
    (`:state`, `:boundary`, `:path`, `:variable`) are valid even when no control
    is defined (control dimension 0).
"""
function constraint!(
    ocp::PreModel,
    type::Symbol;
    rg::Union{Int,OrdinalRange{Int},Nothing}=nothing,
    f::Union{Function,Nothing}=nothing,
    lb::Union{ctNumber,ctVector,Nothing}=nothing,
    ub::Union{ctNumber,ctVector,Nothing}=nothing,
    label::Symbol=__constraint_label(),
    codim_f::Union{Dimension,Nothing}=nothing,
)

    # checks: times and state must be set before adding constraints
    Core.@ensure __is_state_set(ocp) Exceptions.PreconditionError(
        "State must be set before adding constraints",
        reason="state has not been defined yet",
        suggestion="Call state!(ocp, dimension) before adding constraints",
        context="constraint! function - state validation",
    )
    Core.@ensure __is_times_set(ocp) Exceptions.PreconditionError(
        "Times must be set before adding constraints",
        reason="time horizon has not been defined yet",
        suggestion="Call times!(ocp, t0, tf) or times!(ocp, N) before adding constraints",
        context="constraint! function - times validation",
    )

    # checks: control must be set for :control constraint type
    if type == :control
        Core.@ensure !__is_control_empty(ocp) Exceptions.PreconditionError(
            "Control must be set for type=:control constraints",
            reason="control has not been defined yet but constraint type requires it",
            suggestion="Call control!(ocp, dimension) before adding :control constraints, or use a different constraint type",
            context="constraint! function - control validation for type=:control",
        )
    end

    # checks: variable must be set if using type=:variable
    Core.@ensure (type != :variable || !__is_variable_empty(ocp)) Exceptions.PreconditionError(
        "Variable must be set for type=:variable constraints",
        reason="OCP has no variable defined but constraint type requires it",
        suggestion="Call variable!(ocp, dimension) before adding variable constraints, or use a different constraint type",
        context="constraint! function - variable type validation",
    )

    # dimensions
    n = dimension(ocp.state)
    m = dimension(ocp.control)
    q = dimension(ocp.variable)

    # add the constraint
    return __constraint!(
        ocp.constraints,
        type,
        n,
        m,
        q;
        rg=as_range(rg),
        f=f,
        lb=as_vector(lb),
        ub=as_vector(ub),
        label=label,
        codim_f=codim_f,
    )
end

"""
    as_vector(::Nothing) -> Nothing

Return `nothing` unchanged.

# Returns
- `Nothing`
"""
as_vector(::Nothing) = nothing

"""
    as_vector(x::T) -> Vector{T} where {T<:ctNumber}

Wrap a scalar number into a single-element vector.

# Arguments
- `x::T`: A scalar number.

# Returns
- `Vector{T}`: A single-element vector containing `x`.

# Example
```julia-repl
julia> as_vector(1.0)
1-element Vector{Float64}:
 1.0
```
"""
(as_vector(x::T)::Vector{T}) where {T<:ctNumber} = [x]

"""
    as_vector(x::AbstractVector{T}) -> AbstractVector{T} where {T<:ctNumber}

Return a vector unchanged.

# Arguments
- `x::AbstractVector{T}`: A vector of numbers.

# Returns
- `AbstractVector{T}`: The input vector unchanged.

# Example
```julia-repl
julia> as_vector([1.0, 2.0, 3.0])
3-element Vector{Float64}:
 1.0
 2.0
 3.0
```
"""
as_vector(x::AbstractVector{T}) where {T<:ctNumber} = x

"""
    as_range(::Nothing) -> Nothing

Return `nothing` unchanged.

# Returns
- `Nothing`
"""
as_range(::Nothing) = nothing

"""
    as_range(r::Int) -> UnitRange{Int}

Convert a scalar integer to a single-element range `r:r`.

# Arguments
- `r::Int`: An integer index.

# Returns
- `UnitRange{Int}`: A range containing only `r`.

# Example
```julia-repl
julia> as_range(3)
3:3
```
"""
as_range(r::T) where {T<:Int} = r:r

"""
    as_range(r::OrdinalRange{Int}) -> OrdinalRange{Int}

Return an ordinal range unchanged.

# Arguments
- `r::OrdinalRange{Int}`: A range of integers.

# Returns
- `OrdinalRange{Int}`: The input range unchanged.

# Example
```julia-repl
julia> as_range(1:5)
1:5
```
"""
as_range(r::OrdinalRange{T}) where {T<:Int} = r

# Getters for ConstraintsModel are now in src/Components/constraints_accessors.jl.
# constraint(::Model, ::Symbol) is now in src/Models/model.jl.
