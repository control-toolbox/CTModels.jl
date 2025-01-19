"""
$(TYPEDSIGNATURES)

Used to set the default value of the label of a constraint.
A unique value is given to each constraint using the `gensym` function and prefixing by `:unamed`.
"""
__constraint_label() = gensym(:unamed)

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

function constraint!(
    ocp::PreModel,
    type::Symbol;
    rg::Union{OrdinalRange{<:Int},Nothing}=nothing,
    f::Union{Function,Nothing}=nothing,
    lb::Union{ctVector,Nothing}=nothing,
    ub::Union{ctVector,Nothing}=nothing,
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
        ocp.constraints, type, n, m, q; rg=rg, f=f, lb=lb, ub=ub, label=label
    )
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# From ContraintsModel
constraint(ocp::Model, label::Symbol)::Tuple = ocp.constraints.dict[label]

(
    path_constraints_nl(
        ocp::Model{T,S,C,V,D,O,ConstraintsModel{TP,TB,TS,TC,TV,ConstraintsDictType}}
    )::TP
) where {
    T<:TimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    TP,
    TB,
    TS,
    TC,
    TV,
} = ocp.constraints.path_nl

(
    boundary_constraints_nl(
        ocp::Model{T,S,C,V,D,O,ConstraintsModel{TP,TB,TS,TC,TV,ConstraintsDictType}}
    )::TB
) where {
    T<:TimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    TP,
    TB,
    TS,
    TC,
    TV,
} = ocp.constraints.boundary_nl

(
    state_constraints_box(
        ocp::Model{T,S,C,V,D,O,ConstraintsModel{TP,TB,TS,TC,TV,ConstraintsDictType}}
    )::TS
) where {
    T<:TimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    TP,
    TB,
    TS,
    TC,
    TV,
} = ocp.constraints.state_box

(
    control_constraints_box(
        ocp::Model{T,S,C,V,D,O,ConstraintsModel{TP,TB,TS,TC,TV,ConstraintsDictType}}
    )::TC
) where {
    T<:TimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    TP,
    TB,
    TS,
    TC,
    TV,
} = ocp.constraints.control_box

(
    variable_constraints_box(
        ocp::Model{T,S,C,V,D,O,ConstraintsModel{TP,TB,TS,TC,TV,ConstraintsDictType}}
    )::TV
) where {
    T<:TimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    TP,
    TB,
    TS,
    TC,
    TV,
} = ocp.constraints.variable_box

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.
"""
dim_path_constraints_nl(ocp::Model)::Dimension = length(path_constraints_nl(ocp)[1])

"""
$(TYPEDSIGNATURES)

Return the dimension of the boundary constraints.
"""
dim_boundary_constraints_nl(ocp::Model)::Dimension = length(boundary_constraints_nl(ocp)[1])

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on state.
"""
dim_state_constraints_box(ocp::Model)::Dimension = length(state_constraints_box(ocp)[1])

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on control.
"""
dim_control_constraints_box(ocp::Model)::Dimension = length(control_constraints_box(ocp)[1])

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on variable.
"""
dim_variable_constraints_box(ocp::Model)::Dimension =
    length(variable_constraints_box(ocp)[1])
