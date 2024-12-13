function build_model(pre_ocp::PreModel)::Model

    # checkings: times must be set
    __is_times_set(pre_ocp) || throw(CTBase.UnauthorizedCall("the times must be set before building the model."))

    # checkings: state must be set
    __is_state_set(pre_ocp) || throw(CTBase.UnauthorizedCall("the state must be set before building the model."))

    # checkings: control must be set
    __is_control_set(pre_ocp) || throw(CTBase.UnauthorizedCall("the control must be set before building the model."))

    # checkings: dynamics must be set
    __is_dynamics_set(pre_ocp) || throw(CTBase.UnauthorizedCall("the dynamics must be set before building the model."))

    # checkings: objective must be set
    __is_objective_set(pre_ocp) || throw(CTBase.UnauthorizedCall("the objective must be set before building the model."))

    # checkings: definition must be set
    isnothing(pre_ocp.definition) && throw(CTBase.UnauthorizedCall("the definition must be set before building the model."))

    # get all necessary fields
    times = pre_ocp.times
    state = pre_ocp.state
    control = pre_ocp.control
    variable = pre_ocp.variable
    dynamics = pre_ocp.dynamics
    objective = pre_ocp.objective
    constraints = pre_ocp.constraints
    definition = pre_ocp.definition

    # create the model
    model = Model(times, state, control, variable, dynamics, objective, constraints, definition)

    return model

end