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
__constraint!(ocp_constraints, :state, 3, 2, 1, lb=[0.0], ub=[1.0], label=:my_constraint)
```
"""
function __constraint!(
    ocp_constraints::ConstraintsDictType,
    type::Symbol,
    n::Dimension,
    m::Dimension,
    q::Dimension;
    rg::Union{OrdinalRange{<:Int},Nothing}=nothing,
    f::Union{Function,Nothing}=nothing,
    lb::Union{ctVector,Nothing}=nothing,
    ub::Union{ctVector,Nothing}=nothing,
    label::Symbol=__constraint_label(),
)

    # checkings: the constraint must not be set before
    @ensure(
        !(label ∈ keys(ocp_constraints)),
        CTBase.UnauthorizedCall(
            "the constraint named " * String(label) * " already exists."
        ),
    )

    # checkings: lb and ub cannot be both nothing
    @ensure(
        !(isnothing(lb) && isnothing(ub)),
        CTBase.UnauthorizedCall(
            "The lower bound `lb` and the upper bound `ub` cannot be both nothing."
        ),
    )

    # bounds
    isnothing(lb) && (lb = -Inf * ones(eltype(ub), length(ub)))
    isnothing(ub) && (ub = Inf * ones(eltype(lb), length(lb)))

    # lb and ub must have the same length
    @ensure(
        length(lb) == length(ub),
        CTBase.IncorrectArgument(
            "the lower bound `lb` and the upper bound `ub` must have the same length."
        ),
    )

    # add the constraint
    @match (rg, f, lb, ub) begin
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
                    CTBase.IncorrectArgument(
                        "the following type of constraint is not valid: " *
                        String(type) *
                        ". Please choose in [ :control, :state, :variable ] or check the arguments of the constraint! method.",
                    ),
                )
            end
            @ensure(length(rg) == length(lb), CTBase.IncorrectArgument(txt))
            __constraint!(ocp_constraints, type, n, m, q; rg=rg, lb=lb, ub=ub, label=label)
        end

        (::OrdinalRange{<:Int}, ::Nothing, ::ctVector, ::ctVector) => begin
            txt = "the range `rg`, the lower bound `lb` and the upper bound `ub` must have the same dimension"
            @ensure(length(rg) == length(lb), CTBase.IncorrectArgument(txt))
            # check if the range is valid
            if type == :state
                @ensure(
                    all(1 .≤ rg .≤ n),
                    CTBase.IncorrectArgument(
                        "the range of the state constraint must be contained in 1:$n"
                    ),
                )
            elseif type == :control
                @ensure(
                    all(1 .≤ rg .≤ m),
                    CTBase.IncorrectArgument(
                        "the range of the control constraint must be contained in 1:$m"
                    ),
                )
            elseif type == :variable
                @ensure(
                    all(1 .≤ rg .≤ q),
                    CTBase.IncorrectArgument(
                        "the range of the variable constraint must be contained in 1:$q"
                    ),
                )
            else
                throw(
                    CTBase.IncorrectArgument(
                        "the following type of constraint is not valid: " *
                        String(type) *
                        ". Please choose in [ :control, :state, :variable ] or check the arguments of the constraint! method.",
                    ),
                )
            end
            # set the constraint
            ocp_constraints[label] = (type, rg, lb, ub)
        end

        (::Nothing, ::Function, ::ctVector, ::ctVector) => begin
            # set the constraint
            if type ∈ [:boundary, :path]
                ocp_constraints[label] = (type, f, lb, ub)
            else
                throw(
                    CTBase.IncorrectArgument(
                        "the following type of constraint is not valid: " *
                        String(type) *
                        ". Please choose in [ :boundary, :path ] or check the arguments of the constraint! method.",
                    ),
                )
            end
        end

        _ => throw(CTBase.IncorrectArgument("Provided arguments are inconsistent."))
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
"""
function constraint!(
    ocp::PreModel,
    type::Symbol;
    rg::Union{Int,OrdinalRange{Int},Nothing}=nothing,
    f::Union{Function,Nothing}=nothing,
    lb::Union{ctNumber,ctVector,Nothing}=nothing,
    ub::Union{ctNumber,ctVector,Nothing}=nothing,
    label::Symbol=__constraint_label(),
)

    # checkings: times, state and control must be set before adding constraints
    @ensure __is_state_set(ocp) CTBase.UnauthorizedCall(
        "the state must be set before adding constraints."
    )
    @ensure __is_control_set(ocp) CTBase.UnauthorizedCall(
        "the control must be set before adding constraints."
    )
    @ensure __is_times_set(ocp) CTBase.UnauthorizedCall(
        "the times must be set before adding constraints."
    )

    # checkings: variable must be set if using type=:variable
    @ensure (type != :variable || __is_variable_set(ocp)) CTBase.UnauthorizedCall(
        "the ocp has no variable, you cannot use constraint! function with type=:variable. If it is a mistake, please set the variable first.",
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
    )
end

as_vector(::Nothing) = nothing
(as_vector(x::T)::Vector{T}) where {T<:ctNumber} = [x]
as_vector(x::Vector{T}) where {T<:ctNumber} = x

as_range(::Nothing) = nothing
as_range(r::T) where {T<:Int} = r:r
as_range(r::OrdinalRange{T}) where {T<:Int} = r

discretize(constraint::Function, grid::Vector{T}) where {T<:ctNumber} = constraint.(grid)
discretize(::Nothing, grid::Vector{T}) where {T<:ctNumber} = nothing

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
`(type, f, lb, ub)` where `type` is the type of the constraint, `f` is the function
of the constraint, `lb` is the lower bound of the constraint and `ub` is the upper
bound of the constraint. 

The function returns an exception if the label is not found in the model.

## Arguments

- `model`: The model from which to retrieve the constraint.
- `label`: The label of the constraint to retrieve.

## Returns

- `Tuple`: A tuple containing the type, function, lower bound, and upper bound of the constraint.

## Example

```julia-repl
julia> # Example of getting a labelled constraint from the model
julia> model = Model(...)
julia> constraint_info = constraint(model, :my_constraint)
```
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

    # check if the label is in the state constraints
    cp = state_constraints_box(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices_state = Int[]
        indices_bound = Int[]
        for i in eachindex(labels)
            if labels[i] == label
                push!(indices_state, cp[2][i])
                push!(indices_bound, i)
            end
        end
        fc =
            (t, x, u, v) -> begin
                length(indices_state) == 1 ? x[indices_state[1]] : x[indices_state]
            end
        return (
            :state, # type of the constraint
            fc,
            length(indices_bound)==1 ? cp[1][indices_bound[1]] : cp[1][indices_bound], # lower bound
            length(indices_bound) == 1 ? cp[3][indices_bound[1]] : cp[3][indices_bound], # upper bound
        )
    end

    # check if the label is in the control constraints
    cp = control_constraints_box(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices_state = Int[]
        indices_bound = Int[]
        for i in eachindex(labels)
            if labels[i] == label
                push!(indices_state, cp[2][i])
                push!(indices_bound, i)
            end
        end
        fc =
            (t, x, u, v) -> begin
                length(indices_state) == 1 ? u[indices_state[1]] : u[indices_state]
            end
        return (
            :control, # type of the constraint
            fc,
            length(indices_bound)==1 ? cp[1][indices_bound[1]] : cp[1][indices_bound], # lower bound
            length(indices_bound) == 1 ? cp[3][indices_bound[1]] : cp[3][indices_bound], # upper bound
        )
    end

    # check if the label is in the variable constraints
    cp = variable_constraints_box(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices_state = Int[]
        indices_bound = Int[]
        for i in eachindex(labels)
            if labels[i] == label
                push!(indices_state, cp[2][i])
                push!(indices_bound, i)
            end
        end
        fc =
            (x0, xf, v) -> begin
                length(indices_state) == 1 ? v[indices_state[1]] : v[indices_state]
            end
        return (
            :variable, # type of the constraint
            fc,
            length(indices_bound)==1 ? cp[1][indices_bound[1]] : cp[1][indices_bound], # lower bound
            length(indices_bound) == 1 ? cp[3][indices_bound[1]] : cp[3][indices_bound], # upper bound
        )
    end

    # return an exception if the label is not found
    return CTBase.IncorrectArgument("Label $label not found in the model.")
end
