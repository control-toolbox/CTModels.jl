"""
$(TYPEDSIGNATURES)

Add a constraint to a dictionary of constraints.

## Arguments

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

## Requirements

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

## Example

```julia-repl
# Example of adding a state constraint
julia> ocp_constraints = Dict()
julia> __constraint!(ocp_constraints, :state, 3, 2, 1, lb=[0.0], ub=[1.0], label=:my_constraint)
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
    @ensure(
        !(label ∈ keys(ocp_constraints)),
        Exceptions.PreconditionError(
            "Constraint already exists",
            reason="constraint with label '$(label)' is already defined",
            suggestion="Use a different label or remove the existing constraint first",
            context="constraint! function - duplicate label validation",
        ),
    )

    # checks: lb and ub cannot be both nothing
    @ensure(
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
    @ensure(
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
    @ensure(
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
            @ensure(
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
            @ensure(
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
                @ensure(
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
                @ensure(
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
                @ensure(
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
                @ensure(
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

Add a constraint to a pre-model. See [__constraint!](@ref) for more details.

## Arguments

- `ocp`: The pre-model to which the constraint will be added.
- `type`: The type of the constraint. It can be `:state`, `:control`, `:variable`, `:boundary`, or `:path`.
- `rg`: The range of the constraint. It can be an integer or a range of integers.
- `f`: The function that defines the constraint. It must return a vector of the same dimension as the constraint.
- `lb`: The lower bound of the constraint. It can be a number or a vector.
- `ub`: The upper bound of the constraint. It can be a number or a vector.
- `label`: The label of the constraint. It must be unique in the pre-model.

## Example

```julia-repl
# Example of adding a control constraint to a pre-model
julia> ocp = PreModel()
julia> constraint!(ocp, :control, rg=1:2, lb=[0.0], ub=[1.0], label=:control_constraint)
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
    @ensure __is_state_set(ocp) Exceptions.PreconditionError(
        "State must be set before adding constraints",
        reason="state has not been defined yet",
        suggestion="Call state!(ocp, dimension) before adding constraints",
        context="constraint! function - state validation",
    )
    @ensure __is_times_set(ocp) Exceptions.PreconditionError(
        "Times must be set before adding constraints",
        reason="time horizon has not been defined yet",
        suggestion="Call times!(ocp, t0, tf) or times!(ocp, N) before adding constraints",
        context="constraint! function - times validation",
    )

    # checks: control must be set for :control constraint type
    if type == :control
        @ensure __is_control_set(ocp) Exceptions.PreconditionError(
            "Control must be set for type=:control constraints",
            reason="control has not been defined yet but constraint type requires it",
            suggestion="Call control!(ocp, dimension) before adding :control constraints, or use a different constraint type",
            context="constraint! function - control validation for type=:control",
        )
    end

    # checks: variable must be set if using type=:variable
    @ensure (type != :variable || __is_variable_set(ocp)) Exceptions.PreconditionError(
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
"""
as_vector(::Nothing) = nothing

"""
    as_vector(x::T) -> Vector{T} where {T<:ctNumber}

Wrap a scalar number into a single-element vector.
"""
(as_vector(x::T)::Vector{T}) where {T<:ctNumber} = [x]

"""
    as_vector(x::AbstractVector{T}) -> AbstractVector{T} where {T<:ctNumber}

Return a vector unchanged.
"""
as_vector(x::AbstractVector{T}) where {T<:ctNumber} = x

"""
    as_range(::Nothing) -> Nothing

Return `nothing` unchanged.
"""
as_range(::Nothing) = nothing

"""
    as_range(r::Int) -> UnitRange{Int}

Convert a scalar integer to a single-element range `r:r`.
"""
as_range(r::T) where {T<:Int} = r:r

"""
    as_range(r::OrdinalRange{Int}) -> OrdinalRange{Int}

Return an ordinal range unchanged.
"""
as_range(r::OrdinalRange{T}) where {T<:Int} = r

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #
"""
$(TYPEDSIGNATURES)

Return if the constraints model is empty or not.

## Arguments

- `model`: The constraints model to check for emptiness.

## Returns

- `Bool`: Returns `true` if the model has no constraints, `false` otherwise.

## Example

```julia-repl
# Example of checking if a constraints model is empty
julia> model = ConstraintsModel(...)
julia> isempty(model)  # Returns true if there are no constraints
```
"""
function Base.isempty(model::ConstraintsModel)::Bool
    return length(path_constraints_nl(model)[1]) == 0 &&
           length(boundary_constraints_nl(model)[1]) == 0 &&
           length(state_constraints_box(model)[1]) == 0 &&
           length(control_constraints_box(model)[1]) == 0 &&
           length(variable_constraints_box(model)[1]) == 0
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear path constraints from the model.

## Arguments

- `model`: The constraints model from which to retrieve the path constraints.

## Returns

- The nonlinear path constraints.

## Example

```julia-repl
# Example of retrieving nonlinear path constraints
julia> model = ConstraintsModel(...)
julia> path_constraints = path_constraints_nl(model)
```
"""
function path_constraints_nl(
    model::ConstraintsModel{TP,<:Tuple,<:Tuple,<:Tuple,<:Tuple}, # ,<:ConstraintsDictType}
) where {TP}
    return model.path_nl
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear boundary constraints from the model.

## Arguments

- `model`: The constraints model from which to retrieve the boundary constraints.

## Returns

- The nonlinear boundary constraints.

## Example

```julia-repl
# Example of retrieving nonlinear boundary constraints
julia> model = ConstraintsModel(...)
julia> boundary_constraints = boundary_constraints_nl(model)
```
"""
function boundary_constraints_nl(
    model::ConstraintsModel{<:Tuple,TB,<:Tuple,<:Tuple,<:Tuple}, # ,<:ConstraintsDictType}
) where {TB}
    return model.boundary_nl
end

"""
$(TYPEDSIGNATURES)

Get the state box constraints from the model.

## Arguments

- `model`: The constraints model from which to retrieve the state box constraints.

## Returns

- The state box constraints.

## Example

```julia-repl
# Example of retrieving state box constraints
julia> model = ConstraintsModel(...)
julia> state_constraints = state_constraints_box(model)
```
"""
function state_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,TS,<:Tuple,<:Tuple}, # ,<:ConstraintsDictType}
) where {TS}
    return model.state_box
end

"""
$(TYPEDSIGNATURES)

Get the control box constraints from the model.

## Arguments

- `model`: The constraints model from which to retrieve the control box constraints.

## Returns

- The control box constraints.

## Example

```julia-repl
# Example of retrieving control box constraints
julia> model = ConstraintsModel(...)
julia> control_constraints = control_constraints_box(model)
```
"""
function control_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,TC,<:Tuple}, # ,<:ConstraintsDictType}
) where {TC}
    return model.control_box
end

"""
$(TYPEDSIGNATURES)

Get the variable box constraints from the model.

## Arguments

- `model`: The constraints model from which to retrieve the variable box constraints.

## Returns

- The variable box constraints.

## Example

```julia-repl
# Example of retrieving variable box constraints
julia> model = ConstraintsModel(...)
julia> variable_constraints = variable_constraints_box(model)
```
"""
function variable_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,<:Tuple,TV}, # ,<:ConstraintsDictType}
) where {TV}
    return model.variable_box
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.

## Arguments

- `model`: The constraints model from which to retrieve the dimension of path constraints.

## Returns

- `Dimension`: The dimension of the nonlinear path constraints.

## Example

```julia-repl
# Example of getting the dimension of nonlinear path constraints
julia> model = ConstraintsModel(...)
julia> dim_path = dim_path_constraints_nl(model)
```
"""
function dim_path_constraints_nl(model::ConstraintsModel)::Dimension
    return length(path_constraints_nl(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear boundary constraints.

## Arguments

- `model`: The constraints model from which to retrieve the dimension of boundary constraints.

## Returns

- `Dimension`: The dimension of the nonlinear boundary constraints.

## Example

```julia-repl
# Example of getting the dimension of nonlinear boundary constraints
julia> model = ConstraintsModel(...)
julia> dim_boundary = dim_boundary_constraints_nl(model)
```
"""
function dim_boundary_constraints_nl(model::ConstraintsModel)::Dimension
    return length(boundary_constraints_nl(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of state box constraints.

## Arguments

- `model`: The constraints model from which to retrieve the dimension of state box constraints.

## Returns

- `Dimension`: The dimension of the state box constraints.

## Example

```julia-repl
julia> # Example of getting the dimension of state box constraints
julia> model = ConstraintsModel(...)
julia> dim_state = dim_state_constraints_box(model)
```
"""
function dim_state_constraints_box(model::ConstraintsModel)::Dimension
    return length(state_constraints_box(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of control box constraints.

## Arguments

- `model`: The constraints model from which to retrieve the dimension of control box constraints.

## Returns

- `Dimension`: The dimension of the control box constraints.

## Example

```julia-repl
julia> # Example of getting the dimension of control box constraints
julia> model = ConstraintsModel(...)
julia> dim_control = dim_control_constraints_box(model)
```
"""
function dim_control_constraints_box(model::ConstraintsModel)::Dimension
    return length(control_constraints_box(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of variable box constraints.

## Arguments

- `model`: The constraints model from which to retrieve the dimension of variable box constraints.

## Returns

- `Dimension`: The dimension of the variable box constraints.

## Example

```julia-repl
julia> # Example of getting the dimension of variable box constraints
julia> model = ConstraintsModel(...)
julia> dim_variable = dim_variable_constraints_box(model)
```
"""
function dim_variable_constraints_box(model::ConstraintsModel)::Dimension
    return length(variable_constraints_box(model)[1])
end

# ------------------------------------------------------------------------------ #
"""
$(TYPEDSIGNATURES)

Get a labelled constraint from the model. Returns a tuple of the form
`(type, f, lb, ub)` where `type` is the type of the constraint, `f` is the function, 
`lb` is the lower bound and `ub` is the upper bound. 

The function returns an exception if the label is not found in the model.

## Arguments

- `model`: The model from which to retrieve the constraint.
- `label`: The label of the constraint to retrieve.

## Returns

- `Tuple`: A tuple containing the type, function, lower bound, and upper bound of the constraint.
"""
function constraint(model::Model, label::Symbol)::Tuple # not type stable

    # check if the label is in the path constraints
    cp = path_constraints_nl(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices = findall(x -> x == label, labels)
        fc! = (r, t, x, u, v) -> begin
            r_ = zeros(length(cp[1]))
            cp[2](r_, t, x, u, v)
            r .= r_[indices]
        end
        return (
            :path, # type of the constraint
            to_out_of_place(fc!, length(indices)), # function
            length(indices) == 1 ? cp[1][indices[1]] : cp[1][indices], # lower bound
            length(indices) == 1 ? cp[3][indices[1]] : cp[3][indices], # upper bound
        )
    end

    # check if the label is in the boundary constraints
    cp = boundary_constraints_nl(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices = findall(x -> x == label, labels)
        fc! = (r, x0, xf, v) -> begin
            r_ = zeros(length(cp[1]))
            cp[2](r_, x0, xf, v)
            r .= r_[indices]
        end
        return (
            :boundary, # type of the constraint
            to_out_of_place(fc!, length(indices)),
            length(indices)==1 ? cp[1][indices[1]] : cp[1][indices], # lower bound
            length(indices) == 1 ? cp[3][indices[1]] : cp[3][indices], # upper bound
        )
    end

    # Box constraints: each box tuple has the form
    #   (lb, ind, ub, labels, aliases)
    # where `aliases[k]` lists every label that declared component `ind[k]`.
    # We look up `label` in that field (rather than in `labels[k]`, which only
    # stores the *first* label per component after dedup). The returned bounds
    # are the **effective** (intersected) bounds stored in `lb`/`ub`, not the
    # bounds as initially declared for that specific label.
    function _lookup_box(cp)
        aliases = cp[5]
        idxs = Int[]
        for k in eachindex(aliases)
            if label in aliases[k]
                push!(idxs, k)
            end
        end
        return idxs
    end

    # state box
    cp = state_constraints_box(model)
    idxs = _lookup_box(cp)
    if !isempty(idxs)
        component_idxs = cp[2][idxs]
        fc =
            (t, x, u, v) -> begin
                length(component_idxs) == 1 ? x[component_idxs[1]] : x[component_idxs]
            end
        return (
            :state,
            fc,
            length(idxs) == 1 ? cp[1][idxs[1]] : cp[1][idxs],
            length(idxs) == 1 ? cp[3][idxs[1]] : cp[3][idxs],
        )
    end

    # control box
    cp = control_constraints_box(model)
    idxs = _lookup_box(cp)
    if !isempty(idxs)
        component_idxs = cp[2][idxs]
        fc =
            (t, x, u, v) -> begin
                length(component_idxs) == 1 ? u[component_idxs[1]] : u[component_idxs]
            end
        return (
            :control,
            fc,
            length(idxs) == 1 ? cp[1][idxs[1]] : cp[1][idxs],
            length(idxs) == 1 ? cp[3][idxs[1]] : cp[3][idxs],
        )
    end

    # variable box
    cp = variable_constraints_box(model)
    idxs = _lookup_box(cp)
    if !isempty(idxs)
        component_idxs = cp[2][idxs]
        fc =
            (x0, xf, v) -> begin
                length(component_idxs) == 1 ? v[component_idxs[1]] : v[component_idxs]
            end
        return (
            :variable,
            fc,
            length(idxs) == 1 ? cp[1][idxs[1]] : cp[1][idxs],
            length(idxs) == 1 ? cp[3][idxs[1]] : cp[3][idxs],
        )
    end

    # throw an exception if the label is not found
    throw(
        Exceptions.IncorrectArgument(
            "Constraint label not found";
            got="label :$label",
            expected="existing constraint label in the model",
            suggestion="Check available constraint labels or add a constraint with this label first",
            context="constraint lookup by label",
        ),
    )
end
