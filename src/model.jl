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
        constraints_function::Function # only one function
    )
        @assert constraints_number == 1
        return constraints_function
    end

    function make_path_cons_nl(
        constraints_number::Int, 
        constraints_dimensions::Vector{Int}, 
        constraints_functions::Function...
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
        constraints_function::Function # only one function
    )
        @assert constraints_number == 1
        return constraints_function
    end

    function make_boundary_cons_nl(
        constraints_number::Int, 
        constraints_dimensions::Vector{Int}, 
        constraints_functions::Function...
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
        length_path_cons_nl, 
        path_cons_nl_dim, 
        path_cons_nl_f...)

    boundary_cons_nl! = make_boundary_cons_nl(
        length_boundary_cons_nl, 
        boundary_cons_nl_dim, 
        boundary_cons_nl_f...)

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
