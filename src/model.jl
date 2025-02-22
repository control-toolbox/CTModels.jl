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

state_name(ocp::Model)::String = name(ocp.state)
state_components(ocp::Model)::Vector{String} = components(ocp.state)
state_dimension(ocp::Model)::Dimension = dimension(ocp.state)

control_name(ocp::Model)::String = name(ocp.control)
control_components(ocp::Model)::Vector{String} = components(ocp.control)
control_dimension(ocp::Model)::Dimension = dimension(ocp.control)

variable_name(ocp::Model)::String = name(ocp.variable)
variable_components(ocp::Model)::Vector{String} = components(ocp.variable)
variable_dimension(ocp::Model)::Dimension = dimension(ocp.variable)

# TIMES
(
    times(ocp::Model{
            T,
            AbstractStateModel,
            AbstractControlModel,
            AbstractVariableModel,
            Function,
            AbstractObjectiveModel,
            AbstractConstraintsModel
        })::T
) where {
    T<:TimesModel
} = ocp.times

time_name(ocp::Model)::String = time_name(ocp.times)

(
    initial_time(ocp::Model{T,S,C,V,D,O,B})::Time
) where {
    T<:TimesModel{FixedTimeModel,<:AbstractTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = initial_time(ocp.times)

(
    initial_time(ocp::Model{T,S,C,V,D,O,B}, ::Variable)::Time
) where {
    T<:TimesModel{FixedTimeModel,<:AbstractTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = initial_time(ocp.times)

(
    final_time(ocp::Model{T,S,C,V,D,O,B})::Time
) where {
    T<:TimesModel{<:AbstractTimeModel,FixedTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = final_time(ocp.times)

(
    final_time(ocp::Model{T,S,C,V,D,O,B}, ::Variable)::Time
) where {
    T<:TimesModel{<:AbstractTimeModel,FixedTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = final_time(ocp.times)

(
    initial_time(ocp::Model{T,S,C,V,D,O,B}, variable::Variable)::Time
) where {
    T<:TimesModel{FreeTimeModel,<:AbstractTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = initial_time(ocp.times, variable)

(
    final_time(ocp::Model{T,S,C,V,D,O,B}, variable::Variable)::Time
) where {
    T<:TimesModel{<:AbstractTimeModel,FreeTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = final_time(ocp.times, variable)

initial_time_name(ocp::Model)::String = name(initial(ocp.times))

final_time_name(ocp::Model)::String = name(final(ocp.times))

(
    has_fixed_initial_time(ocp::Model{T,S,C,V,D,O,B})::Bool
) where {
    T<:TimesModel{FixedTimeModel,<:AbstractTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = true

(
    has_fixed_initial_time(ocp::Model{T,S,C,V,D,O,B})::Bool
) where {
    T<:TimesModel{FreeTimeModel,<:AbstractTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = false

(
    has_fixed_final_time(ocp::Model{T,S,C,V,D,O,B})::Bool
) where {
    T<:TimesModel{<:AbstractTimeModel,FixedTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = true

(
    has_fixed_final_time(ocp::Model{T,S,C,V,D,O,B})::Bool
) where {
    T<:TimesModel{<:AbstractTimeModel,FreeTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = false

has_free_initial_time(ocp::Model)::Bool = !has_fixed_initial_time(ocp)
has_free_final_time(ocp::Model)::Bool = !has_fixed_final_time(ocp)


# OBJECTIVE
(
    objective(ocp::Model{T,S,C,V,D,O,B})::O
) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = ocp.objective

criterion(ocp::Model)::Symbol = criterion(objective(ocp))

(
    mayer(ocp::Model{T,S,C,V,D,MayerObjectiveModel{M},B})::M
) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    M<:Function,
    B<:AbstractConstraintsModel,
} = mayer(objective(ocp))
(
    mayer(ocp::Model{T,S,C,V,D,BolzaObjectiveModel{M,L},B})::M
) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    M<:Function,
    L<:Function,
    B<:AbstractConstraintsModel,
} = mayer(objective(ocp))
function mayer(
    ocp::Model{T,S,C,V,D,<:LagrangeObjectiveModel,B}
) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    D<:Function,
    V<:AbstractVariableModel,
    B<:AbstractConstraintsModel,
}
    throw(
        CTBase.UnauthorizedCall("a Lagrange objective ocp does not have a Mayer function.")
    )
end

(
    lagrange(ocp::Model{T,S,C,V,D,LagrangeObjectiveModel{L},B})::L
) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    L<:Function,
    B<:AbstractConstraintsModel,
} = lagrange(objective(ocp))
(
    lagrange(ocp::Model{T,S,C,V,D,BolzaObjectiveModel{M,L},B})::L
) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    M<:Function,
    L<:Function,
    B<:AbstractConstraintsModel,
} = lagrange(objective(ocp))
function lagrange(
    ocp::Model{T,S,C,V,D,<:MayerObjectiveModel,B}
) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    D<:Function,
    V<:AbstractVariableModel,
    B<:AbstractConstraintsModel,
}
    throw(
        CTBase.UnauthorizedCall("a Mayer objective ocp does not have a Lagrange function.")
    )
end

has_mayer_cost(ocp::Model)::Bool = has_mayer_cost(objective(ocp))
has_lagrange_cost(ocp::Model)::Bool = has_lagrange_cost(objective(ocp))

# DYNAMICS
(
    dynamics(ocp::Model{T,S,C,V,D,O,B})::D
) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
    B<:AbstractConstraintsModel,
} = ocp.dynamics

# CONSTRAINTS
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
