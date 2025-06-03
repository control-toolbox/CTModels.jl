"""
$(TYPEDSIGNATURES)

Appends box constraint data to the provided vectors.

# Arguments
- `inds::Vector{Int}`: Vector of indices to which the range `rg` will be appended.
- `lbs::Vector{<:Real}`: Vector of lower bounds to which `lb` will be appended.
- `ubs::Vector{<:Real}`: Vector of upper bounds to which `ub` will be appended.
- `labels::Vector{String}`: Vector of labels to which the `label` will be repeated and appended.
- `rg::AbstractVector{Int}`: Index range corresponding to the constraint variables.
- `lb::AbstractVector{<:Real}`: Lower bounds associated with `rg`.
- `ub::AbstractVector{<:Real}`: Upper bounds associated with `rg`.
- `label::String`: Label describing the constraint block (e.g., "state", "control").

# Notes
- All input vectors (`rg`, `lb`, `ub`) must have the same length.
- The function modifies the `inds`, `lbs`, `ubs`, and `labels` vectors in-place.
"""
function append_box_constraints!(inds, lbs, ubs, labels, rg, lb, ub, label)
    append!(inds, rg)
    append!(lbs, lb)
    append!(ubs, ub)
    for _ in 1:length(lb)
        push!(labels, label)
    end
end

"""
$(TYPEDSIGNATURES)

Constructs a `ConstraintsModel` from a dictionary of constraints.

This function processes a dictionary where each entry defines a constraint with its type, function or index range, lower and upper bounds, and label. It categorizes constraints into path, boundary, state, control, and variable constraints, assembling them into a structured `ConstraintsModel`.

# Arguments
- `constraints::ConstraintsDictType`: A dictionary mapping constraint labels to tuples of the form `(type, function_or_range, lower_bound, upper_bound)`.

# Returns
- `ConstraintsModel`: A structured model encapsulating all provided constraints.

# Example
```julia-repl
constraints = OrderedDict(
    :c1 => (:path, f1, [0.0], [1.0]),
    :c2 => (:state, 1:2, [-1.0, -1.0], [1.0, 1.0])
)
model = build(constraints)
```
"""
function build(constraints::ConstraintsDictType)::ConstraintsModel
    LocalNumber = Float64

    path_cons_nl_f = Vector{Function}() # nonlinear path constraints
    path_cons_nl_dim = Vector{Int}()
    path_cons_nl_lb = Vector{LocalNumber}()
    path_cons_nl_ub = Vector{LocalNumber}()
    path_cons_nl_labels = Vector{Symbol}()

    boundary_cons_nl_f = Vector{Function}() # nonlinear boundary constraints
    boundary_cons_nl_dim = Vector{Int}()
    boundary_cons_nl_lb = Vector{LocalNumber}()
    boundary_cons_nl_ub = Vector{LocalNumber}()
    boundary_cons_nl_labels = Vector{Symbol}()

    state_cons_box_ind = Vector{Int}() # state range
    state_cons_box_lb = Vector{LocalNumber}()
    state_cons_box_ub = Vector{LocalNumber}()
    state_cons_box_labels = Vector{Symbol}()

    control_cons_box_ind = Vector{Int}() # control range
    control_cons_box_lb = Vector{LocalNumber}()
    control_cons_box_ub = Vector{LocalNumber}()
    control_cons_box_labels = Vector{Symbol}()

    variable_cons_box_ind = Vector{Int}() # variable range
    variable_cons_box_lb = Vector{LocalNumber}()
    variable_cons_box_ub = Vector{LocalNumber}()
    variable_cons_box_labels = Vector{Symbol}()

    for (label, c) in constraints
        type = c[1]
        lb = c[3]
        ub = c[4]
        if type == :path
            f = c[2]
            push!(path_cons_nl_f, f)
            push!(path_cons_nl_dim, length(lb))
            append!(path_cons_nl_lb, lb)
            append!(path_cons_nl_ub, ub)
            for i in 1:length(lb)
                push!(path_cons_nl_labels, label)
            end
        elseif type == :boundary
            f = c[2]
            push!(boundary_cons_nl_f, f)
            push!(boundary_cons_nl_dim, length(lb))
            append!(boundary_cons_nl_lb, lb)
            append!(boundary_cons_nl_ub, ub)
            for i in 1:length(lb)
                push!(boundary_cons_nl_labels, label)
            end
        elseif type == :state
            append_box_constraints!(
                state_cons_box_ind,
                state_cons_box_lb,
                state_cons_box_ub,
                state_cons_box_labels,
                c[2],
                lb,
                ub,
                label,
            )
        elseif type == :control
            append_box_constraints!(
                control_cons_box_ind,
                control_cons_box_lb,
                control_cons_box_ub,
                control_cons_box_labels,
                c[2],
                lb,
                ub,
                label,
            )
        elseif type == :variable
            append_box_constraints!(
                variable_cons_box_ind,
                variable_cons_box_lb,
                variable_cons_box_ub,
                variable_cons_box_labels,
                c[2],
                lb,
                ub,
                label,
            )
        else
            throw(
                CTBase.UnauthorizedCall("Unknown constraint type: $type for label $label.")
            )
        end
    end

    length_path_cons_nl::Int = length(path_cons_nl_f)
    length_boundary_cons_nl::Int = length(boundary_cons_nl_f)

    function make_path_cons_nl(
        constraints_number::Int,
        constraints_dimensions::Vector{Int},
        constraints_function::Function, # only one function
    )
        @assert constraints_number == 1
        return constraints_function
    end

    function make_path_cons_nl(
        constraints_number::Int,
        constraints_dimensions::Vector{Int},
        constraints_functions::Function...,
    )
        let
            # Create local copies of the inputs to capture them safely
            cn = constraints_number
            cd = constraints_dimensions
            cf = constraints_functions

            function path_cons_nl!(val, t, x, u, v)
                j = 1
                for i in 1:cn
                    li = cd[i]
                    cf[i](@view(val[j:(j + li - 1)]), t, x, u, v)
                    j += li
                end
                return nothing
            end

            return path_cons_nl!
        end
    end

    function make_boundary_cons_nl(
        constraints_number::Int,
        constraints_dimensions::Vector{Int},
        constraints_function::Function, # only one function
    )
        @assert constraints_number == 1
        return constraints_function
    end

    function make_boundary_cons_nl(
        constraints_number::Int,
        constraints_dimensions::Vector{Int},
        constraints_functions::Function...,
    )
        let cfs = constraints_functions
            function boundary_cons_nl!(val, x0, xf, v)
                j = 1
                for i in 1:constraints_number
                    li = constraints_dimensions[i]
                    cfs[i](@view(val[j:(j + li - 1)]), x0, xf, v)
                    j += li
                end
                return nothing
            end
            return boundary_cons_nl!
        end
    end

    path_cons_nl! = make_path_cons_nl(
        length_path_cons_nl, path_cons_nl_dim, path_cons_nl_f...
    )

    boundary_cons_nl! = make_boundary_cons_nl(
        length_boundary_cons_nl, boundary_cons_nl_dim, boundary_cons_nl_f...
    )

    return ConstraintsModel(
        (path_cons_nl_lb, path_cons_nl!, path_cons_nl_ub, path_cons_nl_labels),
        (
            boundary_cons_nl_lb,
            boundary_cons_nl!,
            boundary_cons_nl_ub,
            boundary_cons_nl_labels,
        ),
        (state_cons_box_lb, state_cons_box_ind, state_cons_box_ub, state_cons_box_labels),
        (
            control_cons_box_lb,
            control_cons_box_ind,
            control_cons_box_ub,
            control_cons_box_labels,
        ),
        (
            variable_cons_box_lb,
            variable_cons_box_ind,
            variable_cons_box_ub,
            variable_cons_box_labels,
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Converts a mutable `PreModel` into an immutable `Model`.

This function finalizes a pre-defined optimal control problem (`PreModel`) by verifying that all necessary components (times, state, control, dynamics) are set. It then constructs a `Model` instance, incorporating optional components like objective and constraints if they are defined.

# Arguments
- `pre_ocp::PreModel`: The pre-defined optimal control problem to be finalized.

# Returns
- `Model`: A fully constructed model ready for solving.

# Example
```julia-repl
pre_ocp = PreModel()
times!(pre_ocp, 0.0, 1.0, 100)
state!(pre_ocp, 2, "x", ["x1", "x2"])
control!(pre_ocp, 1, "u", ["u1"])
dynamics!(pre_ocp, (dx, t, x, u, v) -> dx .= x + u)
model = build(pre_ocp)
```
"""
function build(pre_ocp::PreModel; build_examodel = nothing)::Model
    @ensure __is_times_set(pre_ocp) CTBase.UnauthorizedCall(
        "the times must be set before building the model."
    )
    @ensure __is_state_set(pre_ocp) CTBase.UnauthorizedCall(
        "the state must be set before building the model."
    )
    @ensure __is_control_set(pre_ocp) CTBase.UnauthorizedCall(
        "the control must be set before building the model."
    )
    @ensure __is_dynamics_set(pre_ocp) CTBase.UnauthorizedCall(
        "the dynamics must be set before building the model."
    )
    @ensure __is_dynamics_complete(pre_ocp) CTBase.UnauthorizedCall(
        "all the components of the dynamics must be set before building the model."
    )
    @ensure __is_objective_set(pre_ocp) CTBase.UnauthorizedCall(
        "the objective must be set before building the model."
    )
    @ensure __is_definition_set(pre_ocp) CTBase.UnauthorizedCall(
        "the definition must be set before building the model."
    )
    @ensure __is_autonomous_set(pre_ocp) CTBase.UnauthorizedCall(
        "the time dependence, autonomous=true or false, must be set before building the model.",
    )

    # extract components from PreModel
    times = pre_ocp.times
    state = pre_ocp.state
    control = pre_ocp.control
    variable = pre_ocp.variable
    dynamics = if pre_ocp.dynamics isa Function
        pre_ocp.dynamics
    else
        __build_dynamics_from_parts(pre_ocp.dynamics)
    end
    objective = pre_ocp.objective
    constraints = build(pre_ocp.constraints)
    definition = pre_ocp.definition
    TD = is_autonomous(pre_ocp) ? Autonomous : NonAutonomous

    # create the model
    model = Model{TD}(
        times, state, control, variable, dynamics, objective, constraints, definition, build_examodel
    )

    return model
end

# ------------------------------------------------------------------------------ #
# Getters
# ------------------------------------------------------------------------------ #

# time dependence
"""
$(TYPEDSIGNATURES)

Return `true` if the model is autonomous.
"""
function is_autonomous(
    ::Model{
        Autonomous,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)
    return true
end

function is_autonomous(
    ::Model{
        NonAutonomous,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)
    return false
end

# State
"""
$(TYPEDSIGNATURES)

Get the state from the model.
"""
function state(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        T,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::T where {T<:AbstractStateModel}
    return ocp.state
end

"""
$(TYPEDSIGNATURES)

Get the name of the state from the model.
"""
function state_name(ocp::Model)::String
    return name(state(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the components names of the state from the model.
"""
function state_components(ocp::Model)::Vector{String}
    return components(state(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the state dimension from the model.
"""
function state_dimension(ocp::Model)::Dimension
    return dimension(state(ocp))
end

# Control
"""
$(TYPEDSIGNATURES)

Get the control from the model.
"""
function control(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        T,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::T where {T<:AbstractControlModel}
    return ocp.control
end

"""
$(TYPEDSIGNATURES)

Get the name of the control from the model.
"""
function control_name(ocp::Model)::String
    return name(control(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the components names of the control from the model.
"""
function control_components(ocp::Model)::Vector{String}
    return components(control(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the control dimension from the model.
"""
function control_dimension(ocp::Model)::Dimension
    return dimension(control(ocp))
end

# Variable 
"""
$(TYPEDSIGNATURES)

Get the variable from the model.
"""
function variable(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        T,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::T where {T<:AbstractVariableModel}
    return ocp.variable
end

"""
$(TYPEDSIGNATURES)

Get the name of the variable from the model.
"""
function variable_name(ocp::Model)::String
    return name(variable(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the components names of the variable from the model.
"""
function variable_components(ocp::Model)::Vector{String}
    return components(variable(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the variable dimension from the model.
"""
function variable_dimension(ocp::Model)::Dimension
    return dimension(variable(ocp))
end

# Times
"""
$(TYPEDSIGNATURES)

Get the times from the model.
"""
function times(
    ocp::Model{
        <:TimeDependence,
        T,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::T where {T<:TimesModel}
    return ocp.times
end

# Time name
"""
$(TYPEDSIGNATURES)

Get the name of the time from the model.
"""
function time_name(ocp::Model)::String
    return time_name(times(ocp))
end

# Initial time
function initial_time(ocp::AbstractModel)
    throw(CTBase.UnauthorizedCall("You cannot get the initial time with this function."))
end

function initial_time(ocp::AbstractModel, variable::AbstractVector)
    throw(CTBase.UnauthorizedCall("You cannot get the initial time with this function."))
end

"""
$(TYPEDSIGNATURES)

Get the initial time from the model, for a fixed initial time.
"""
function initial_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{FixedTimeModel{T},<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::T where {T<:Time}
    return initial_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the initial time from the model, for a free initial time.
"""
function initial_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{FreeTimeModel,<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
    variable::AbstractVector{T},
)::T where {T<:ctNumber}
    return initial_time(times(ocp), variable)
end

"""
$(TYPEDSIGNATURES)

Get the initial time from the model, for a free initial time.
"""
function initial_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{FreeTimeModel,<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
    variable::T,
)::T where {T<:ctNumber}
    return initial_time(times(ocp), [variable])
end

"""
$(TYPEDSIGNATURES)

Get the name of the initial time from the model.
"""
function initial_time_name(ocp::Model)::String
    return initial_time_name(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is fixed.
"""
function has_fixed_initial_time(ocp::Model)::Bool
    return has_fixed_initial_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is free.
"""
function has_free_initial_time(ocp::Model)::Bool
    return has_free_initial_time(times(ocp))
end

# Final time
"""
$(TYPEDSIGNATURES)

"""
function final_time(ocp::AbstractModel)
    throw(CTBase.UnauthorizedCall("You cannot get the final time with this function."))
end

"""
$(TYPEDSIGNATURES)

"""
function final_time(ocp::AbstractModel, variable::AbstractVector)
    throw(CTBase.UnauthorizedCall("You cannot get the final time with this function."))
end

"""
$(TYPEDSIGNATURES)

Get the final time from the model, for a fixed final time.
"""
function final_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{<:AbstractTimeModel,FixedTimeModel{T}},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::T where {T<:Time}
    return final_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the final time from the model, for a free final time.
"""
function final_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{<:AbstractTimeModel,FreeTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
    variable::AbstractVector{T},
)::T where {T<:ctNumber}
    return final_time(times(ocp), variable)
end

"""
$(TYPEDSIGNATURES)

Get the final time from the model, for a free final time.
"""
function final_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{<:AbstractTimeModel,FreeTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
    variable::T,
)::T where {T<:ctNumber}
    return final_time(times(ocp), [variable])
end

"""
$(TYPEDSIGNATURES)

Get the name of the final time from the model.
"""
function final_time_name(ocp::Model)::String
    return final_time_name(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the final time is fixed.
"""
function has_fixed_final_time(ocp::Model)::Bool
    return has_fixed_final_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the final time is free.
"""
function has_free_final_time(ocp::Model)::Bool
    return has_free_final_time(times(ocp))
end

# Objective
"""
$(TYPEDSIGNATURES)

Get the objective from the model.
"""
function objective(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        O,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::O where {O<:AbstractObjectiveModel}
    return ocp.objective
end

"""
$(TYPEDSIGNATURES)

Get the type of criterion (:min or :max) from the model.
"""
function criterion(ocp::Model)::Symbol
    return criterion(objective(ocp))
end

# Mayer
function mayer(ocp::AbstractModel)
    throw(CTBase.UnauthorizedCall("This ocp has no Mayer objective."))
end

"""
$(TYPEDSIGNATURES)

Get the Mayer cost from the model.
"""
function mayer(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:MayerObjectiveModel{M},
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::M where {M<:Function}
    return mayer(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the Mayer cost from the model.
"""
function mayer(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:BolzaObjectiveModel{M,<:Function},
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::M where {M<:Function}
    return mayer(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the model has a Mayer cost.
"""
function has_mayer_cost(ocp::Model)::Bool
    return has_mayer_cost(objective(ocp))
end

# Lagrange
function lagrange(ocp::AbstractModel)
    throw(CTBase.UnauthorizedCall("This ocp has no Lagrange objective."))
end

"""
$(TYPEDSIGNATURES)

Get the Lagrange cost from the model.
"""
function lagrange(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        LagrangeObjectiveModel{L},
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::L where {L<:Function}
    return lagrange(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the Lagrange cost from the model.
"""
function lagrange(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:BolzaObjectiveModel{<:Function,L},
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::L where {L<:Function}
    return lagrange(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the model has a Lagrange cost.
"""
function has_lagrange_cost(ocp::Model)::Bool
    return has_lagrange_cost(objective(ocp))
end

# Dynamics
"""
$(TYPEDSIGNATURES)

Get the dynamics from the model.
"""
function dynamics(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        D,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Union{Function,Nothing},
    },
)::D where {D<:Function}
    return ocp.dynamics
end

# build_examodel
"""
$(TYPEDSIGNATURES)

Get the build_examodel from the model.
"""
function get_build_examodel(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Function,
    },
)
    return ocp.build_examodel
end

"""
$(TYPEDSIGNATURES)

Return an error (UnauthorizedCall) since the model is not built with the :exa backend.
"""
function get_build_examodel(
    ::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:Nothing,
    },
)
    throw(CTBase.UnauthorizedCall("first parse with :exa backend"))
end

# Constraints
"""
$(TYPEDSIGNATURES)

Get the constraints from the model.
"""
function constraints(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        C,
        <:Union{Function,Nothing},
    },
)::C where {C<:AbstractConstraintsModel}
    return ocp.constraints
end

"""
$(TYPEDSIGNATURES)

Return true if the model has constraints or false if not.
"""
function isempty_constraints(ocp::Model)::Bool
    return Base.isempty(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear path constraints from the model.
"""
function path_constraints_nl(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{TP,<:Tuple,<:Tuple,<:Tuple,<:Tuple},
        <:Union{Function,Nothing},
    },
)::TP where {TP<:Tuple}
    return constraints(ocp).path_nl
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear boundary constraints from the model.
"""
function boundary_constraints_nl(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,TB,<:Tuple,<:Tuple,<:Tuple},
        <:Union{Function,Nothing},
    },
)::TB where {TB<:Tuple}
    return constraints(ocp).boundary_nl
end

"""
$(TYPEDSIGNATURES)

Get the box constraints on state from the model.
"""
function state_constraints_box(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,<:Tuple,TS,<:Tuple,<:Tuple},
        <:Union{Function,Nothing},
    },
)::TS where {TS<:Tuple}
    return constraints(ocp).state_box
end

"""
$(TYPEDSIGNATURES)

Get the box constraints on control from the model.
"""
function control_constraints_box(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,TC,<:Tuple},
        <:Union{Function,Nothing},
    },
)::TC where {TC<:Tuple}
    return constraints(ocp).control_box
end

"""
$(TYPEDSIGNATURES)

Get the box constraints on variable from the model.
"""
function variable_constraints_box(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,<:Tuple,TV},
        <:Union{Function,Nothing},
    },
)::TV where {TV<:Tuple}
    return constraints(ocp).variable_box
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.
"""
function dim_path_constraints_nl(ocp::Model)::Dimension
    return dim_path_constraints_nl(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the boundary constraints.
"""
function dim_boundary_constraints_nl(ocp::Model)::Dimension
    return dim_boundary_constraints_nl(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on state.
"""
function dim_state_constraints_box(ocp::Model)::Dimension
    return dim_state_constraints_box(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on control.
"""
function dim_control_constraints_box(ocp::Model)::Dimension
    return dim_control_constraints_box(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on variable.
"""
function dim_variable_constraints_box(ocp::Model)::Dimension
    return dim_variable_constraints_box(constraints(ocp))
end
