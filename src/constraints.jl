"""
$(TYPEDSIGNATURES)

Add a constraint to a dictionary of constraints.

## Arguments

- `ocp_constraints`: The dictionary of constraints to which the constraint will be added.
- `type`: The type of the constraint. It can be :state, :control, :variable, :boundary or :path.
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
- The lower bound `lb` and the upper bound `ub` cannot be both nothing.
- The lower bound `lb` and the upper bound `ub` must have the same length, if both provided.

If `rg` and `f` are not provided then, 

- `type` must be :state, :control or :variable
- `lb` and `ub` must be of dimension n, m or q respectively, when provided.

If `rg` is provided, then:

- `f` must not be provided.
- `type` must be :state, :control or :variable.
- `rg` must be a range of integers, and must be contained in 1:n, 1:m or 1:q respectively.

If `f` is provided, then:

- `rg` must not be provided.
- `type` must be :boundary or :path.
- `f` must be a function that returns a vector of the same dimension as the constraint.
- `lb` and `ub` must be of the same dimension as the output of `f`, when provided.

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
    label ∈ keys(ocp_constraints) && throw(
        CTBase.UnauthorizedCall(
            "the constraint named " * String(label) * " already exists."
        ),
    )

    # checkings: lb and ub cannot be both nothing
    (isnothing(lb) && isnothing(ub)) && throw(
        CTBase.UnauthorizedCall(
            "The lower bound `lb` and the upper bound `ub` cannot be both nothing."
        ),
    )

    # bounds
    isnothing(lb) && (lb = -Inf * ones(eltype(ub), length(ub)))
    isnothing(ub) && (ub = Inf * ones(eltype(lb), length(lb)))

    # lb and ub must have the same length
    length(lb) != length(ub) && throw(
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
            (length(rg) != length(lb)) && throw(CTBase.IncorrectArgument(txt))
            __constraint!(ocp_constraints, type, n, m, q; rg=rg, lb=lb, ub=ub, label=label)
        end

        (::OrdinalRange{<:Int}, ::Nothing, ::ctVector, ::ctVector) => begin
            txt = "the range `rg`, the lower bound `lb` and the upper bound `ub` must have the same dimension"
            (length(rg) != length(lb)) && throw(CTBase.IncorrectArgument(txt))
            # check if the range is valid
            if type == :state
                !all(1 .≤ rg .≤ n) && throw(
                    CTBase.IncorrectArgument(
                        "the range of the state constraint must be contained in 1:$n",
                    ),
                )
            elseif type == :control
                !all(1 .≤ rg .≤ m) && throw(
                    CTBase.IncorrectArgument(
                        "the range of the control constraint must be contained in 1:$m",
                    ),
                )
            elseif type == :variable
                !all(1 .≤ rg .≤ q) && throw(
                    CTBase.IncorrectArgument(
                        "the range of the variable constraint must be contained in 1:$q",
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

Add a constraint to a pre-model. See `[__constraint!](@ref)` for more details.
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
    !__is_state_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the state must be set before adding constraints."))
    !__is_control_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the control must be set before adding constraints."))
    !__is_times_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the times must be set before adding constraints."))

    # checkings: if the ocp has no variable, then the constraint! function cannot be used with type=:variable
    !__is_variable_set(ocp) &&
        type == :variable &&
        throw(
            CTBase.UnauthorizedCall(
                "the ocp has no variable" *
                ", you cannot use constraint! function with type=:variable. If it is a mistake, please set the variable first.",
            ),
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

Return if the constraints model is not empty.
"""
function Base.isempty(model::ConstraintsModel)::Bool
    return Base.isempty(model.dict)
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear path constraints from the model.
"""
function path_constraints_nl(
    model::ConstraintsModel{TP,<:Tuple,<:Tuple,<:Tuple,<:Tuple,<:ConstraintsDictType}
) where {TP}
    return model.path_nl
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear boundary constraints from the model.
"""
function boundary_constraints_nl(
    model::ConstraintsModel{<:Tuple,TB,<:Tuple,<:Tuple,<:Tuple,<:ConstraintsDictType}
) where {TB}
    return model.boundary_nl
end

"""
$(TYPEDSIGNATURES)

Get the state box constraints from the model.
"""
function state_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,TS,<:Tuple,<:Tuple,<:ConstraintsDictType}
) where {TS}
    return model.state_box
end

"""
$(TYPEDSIGNATURES)

Get the control box constraints from the model.
"""
function control_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,TC,<:Tuple,<:ConstraintsDictType}
) where {TC}
    return model.control_box
end

"""
$(TYPEDSIGNATURES)

Get the variable box constraints from the model.
"""
function variable_constraints_box(
    model::ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,<:Tuple,TV,<:ConstraintsDictType}
) where {TV}
    return model.variable_box
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.
"""
function dim_path_constraints_nl(model::ConstraintsModel)::Dimension
    return length(path_constraints_nl(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear boundary constraints.
"""
function dim_boundary_constraints_nl(model::ConstraintsModel)::Dimension
    return length(boundary_constraints_nl(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of state box constraints.
"""
function dim_state_constraints_box(model::ConstraintsModel)::Dimension
    return length(state_constraints_box(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of control box constraints.
"""
function dim_control_constraints_box(model::ConstraintsModel)::Dimension
    return length(control_constraints_box(model)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of variable box constraints.
"""
function dim_variable_constraints_box(model::ConstraintsModel)::Dimension
    return length(variable_constraints_box(model)[1])
end
