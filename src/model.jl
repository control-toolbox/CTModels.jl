"""
$(TYPEDSIGNATURES)

Build a concrete type constraints model from a dictionary of constraints.

"""
function build_constraints(constraints::ConstraintsDictType)::ConstraintsModel
    path_cons_nl_f = Vector{Function}() # nonlinear path constraints
    path_cons_nl_dim = Vector{Int}()
    path_cons_nl_lb = Vector{ctNumber}()
    path_cons_nl_ub = Vector{ctNumber}()

    boundary_cons_nl_f = Vector{Function}() # nonlinear boundary constraints
    boundary_cons_nl_dim = Vector{Int}()
    boundary_cons_nl_lb = Vector{ctNumber}()
    boundary_cons_nl_ub = Vector{ctNumber}()

    state_cons_box_ind = Vector{Int}() # state range
    state_cons_box_lb = Vector{ctNumber}()
    state_cons_box_ub = Vector{ctNumber}()

    control_cons_box_ind = Vector{Int}() # control range
    control_cons_box_lb = Vector{ctNumber}()
    control_cons_box_ub = Vector{ctNumber}()

    variable_cons_box_ind = Vector{Int}() # variable range
    variable_cons_box_lb = Vector{ctNumber}()
    variable_cons_box_ub = Vector{ctNumber}()

    for (_, c) in constraints
        type = c[1]
        lb = c[3]
        ub = c[4]
        if type == :path
            f = c[2]
            push!(path_cons_nl_f, f)
            push!(path_cons_nl_dim, length(lb))
            append!(path_cons_nl_lb, lb)
            append!(path_cons_nl_ub, ub)
        elseif type == :boundary
            f = c[2]
            push!(boundary_cons_nl_f, f)
            push!(boundary_cons_nl_dim, length(lb))
            append!(boundary_cons_nl_lb, lb)
            append!(boundary_cons_nl_ub, ub)
        elseif type == :state
            rg = c[2]
            append!(state_cons_box_ind, rg)
            append!(state_cons_box_lb, lb)
            append!(state_cons_box_ub, ub)
        elseif type == :control
            rg = c[2]
            append!(control_cons_box_ind, rg)
            append!(control_cons_box_lb, lb)
            append!(control_cons_box_ub, ub)
        elseif type == :variable
            rg = c[2]
            append!(variable_cons_box_ind, rg)
            append!(variable_cons_box_lb, lb)
            append!(variable_cons_box_ub, ub)
        else
            error("Internal error")
        end
    end

    #
    @assert length(path_cons_nl_f) == length(path_cons_nl_dim)
    @assert length(path_cons_nl_lb) == length(path_cons_nl_ub)
    @assert length(boundary_cons_nl_f) == length(boundary_cons_nl_dim)
    @assert length(boundary_cons_nl_lb) == length(boundary_cons_nl_ub)
    #
    @assert length(state_cons_box_ind) == length(state_cons_box_lb)
    @assert length(state_cons_box_lb) == length(state_cons_box_ub)
    @assert length(control_cons_box_ind) == length(control_cons_box_lb)
    @assert length(control_cons_box_lb) == length(control_cons_box_ub)
    @assert length(variable_cons_box_ind) == length(variable_cons_box_lb)
    @assert length(variable_cons_box_lb) == length(variable_cons_box_ub)

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
        function path_cons_nl!(val, t, x, u, v)
            j = 1
            for i in 1:constraints_number
                li = constraints_dimensions[i]
                constraints_functions[i](@view(val[j:(j + li - 1)]), t, x, u, v)
                j += li
            end
            return nothing
        end
        return path_cons_nl!
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
        function boundary_cons_nl!(val, x0, xf, v)
            j = 1
            for i in 1:constraints_number
                li = constraints_dimensions[i]
                constraints_functions[i](@view(val[j:(j + li - 1)]), x0, xf, v)
                j += li
            end
            return nothing
        end
        return boundary_cons_nl!
    end

    path_cons_nl! = make_path_cons_nl(
        length_path_cons_nl, path_cons_nl_dim, path_cons_nl_f...
    )

    boundary_cons_nl! = make_boundary_cons_nl(
        length_boundary_cons_nl, boundary_cons_nl_dim, boundary_cons_nl_f...
    )

    return ConstraintsModel(
        (path_cons_nl_lb, path_cons_nl!, path_cons_nl_ub),
        (boundary_cons_nl_lb, boundary_cons_nl!, boundary_cons_nl_ub),
        (state_cons_box_lb, state_cons_box_ind, state_cons_box_ub),
        (control_cons_box_lb, control_cons_box_ind, control_cons_box_ub),
        (variable_cons_box_lb, variable_cons_box_ind, variable_cons_box_ub),
        constraints,
    )
end

"""
$(TYPEDSIGNATURES)

Build a concrete type model from a pre-model.

"""
function build_model(pre_ocp::PreModel)::Model

    # checkings: times must be set
    __is_times_set(pre_ocp) ||
        throw(CTBase.UnauthorizedCall("the times must be set before building the model."))

    # checkings: state must be set
    __is_state_set(pre_ocp) ||
        throw(CTBase.UnauthorizedCall("the state must be set before building the model."))

    # checkings: control must be set
    __is_control_set(pre_ocp) ||
        throw(CTBase.UnauthorizedCall("the control must be set before building the model."))

    # checkings: dynamics must be set
    __is_dynamics_set(pre_ocp) || throw(
        CTBase.UnauthorizedCall("the dynamics must be set before building the model.")
    )

    # checkings: objective must be set
    __is_objective_set(pre_ocp) || throw(
        CTBase.UnauthorizedCall("the objective must be set before building the model.")
    )

    # checkings: definition must be set
    isnothing(pre_ocp.definition) && throw(
        CTBase.UnauthorizedCall("the definition must be set before building the model.")
    )

    # get all necessary fields
    times = pre_ocp.times
    state = pre_ocp.state
    control = pre_ocp.control
    variable = pre_ocp.variable
    dynamics = pre_ocp.dynamics
    objective = pre_ocp.objective
    constraints = build_constraints(pre_ocp.constraints)
    definition = pre_ocp.definition

    # create the model
    model = Model(
        times, state, control, variable, dynamics, objective, constraints, definition
    )

    return model
end

# ------------------------------------------------------------------------------ #
# Getters
# ------------------------------------------------------------------------------ #

# State
"""
$(TYPEDSIGNATURES)

Get the state from the model.
"""
function state(
    ocp::Model{
        <:TimesModel,
        T,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
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
        <:TimesModel,
        <:AbstractStateModel,
        T,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
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
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        T,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
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
        T,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
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
"""
$(TYPEDSIGNATURES)

Get the initial time from the model, for a fixed initial time.
"""
function initial_time(
    ocp::Model{
        <:TimesModel{FixedTimeModel{T},<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
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
        <:TimesModel{FreeTimeModel,<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
    },
    variable::AbstractVector{T},
)::T where {T<:ctNumber}
    return initial_time(times(ocp), variable)
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

Get the final time from the model, for a fixed final time.
"""
function final_time(
    ocp::Model{
        <:TimesModel{<:AbstractTimeModel,FixedTimeModel{T}},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
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
        <:TimesModel{<:AbstractTimeModel,FreeTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
    },
    variable::AbstractVector{T},
)::T where {T<:ctNumber}
    return final_time(times(ocp), variable)
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
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        O,
        <:AbstractConstraintsModel,
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
"""
$(TYPEDSIGNATURES)

Get the Mayer cost from the model.
"""
function mayer(
    ocp::Model{
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:MayerObjectiveModel{M},
        <:AbstractConstraintsModel,
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
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:BolzaObjectiveModel{M,<:Function},
        <:AbstractConstraintsModel,
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
"""
$(TYPEDSIGNATURES)

Get the Lagrange cost from the model.
"""
function lagrange(
    ocp::Model{
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        LagrangeObjectiveModel{L},
        <:AbstractConstraintsModel,
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
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:BolzaObjectiveModel{<:Function,L},
        <:AbstractConstraintsModel,
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
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        D,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
    },
)::D where {D<:Function}
    return ocp.dynamics
end

# Constraints
"""
$(TYPEDSIGNATURES)

Get the constraints from the model.
"""
function constraints(
    ocp::Model{
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        C,
    },
)::C where {C<:AbstractConstraintsModel}
    return ocp.constraints
end

"""
$(TYPEDSIGNATURES)

Get a labelled constraint from the model.
"""
function constraint(ocp::Model, label::Symbol)::Tuple # not type stable
    return constraints(ocp).dict[label]
end

"""
$(TYPEDSIGNATURES)

Get the nonlinear path constraints from the model.
"""
function path_constraints_nl(
    ocp::Model{
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{TP,<:Tuple,<:Tuple,<:Tuple,<:Tuple,<:ConstraintsDictType},
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
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,TB,<:Tuple,<:Tuple,<:Tuple,<:ConstraintsDictType},
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
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,<:Tuple,TS,<:Tuple,<:Tuple,<:ConstraintsDictType},
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
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,TC,<:Tuple,<:ConstraintsDictType},
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
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,<:Tuple,TV,<:ConstraintsDictType},
    },
)::TV where {TV<:Tuple}
    return constraints(ocp).variable_box
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.
"""
function dim_path_constraints_nl(ocp::Model)::Dimension
    return length(path_constraints_nl(ocp)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the boundary constraints.
"""
function dim_boundary_constraints_nl(ocp::Model)::Dimension
    return length(boundary_constraints_nl(ocp)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on state.
"""
function dim_state_constraints_box(ocp::Model)::Dimension
    return length(state_constraints_box(ocp)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on control.
"""
function dim_control_constraints_box(ocp::Model)::Dimension
    return length(control_constraints_box(ocp)[1])
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on variable.
"""
function dim_variable_constraints_box(ocp::Model)::Dimension
    return length(variable_constraints_box(ocp)[1])
end
