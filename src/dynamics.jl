function dynamics!(ocp::OptimalControlModelMutable, f::Function)::Nothing

    # checkings: state and control must be set before the dynamics
    !__is_state_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the state must be set before the dynamics."))
    !__is_control_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the control must be set before the dynamics."))

    # checkings: times must be set before the dynamics
    !__is_times_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the times must be set before the dynamics."))

    # checkings: the dynamics must not be set before
    __is_dynamics_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the dynamics has already been set."))

    # set the dynamics
    ocp.dynamics = f

    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# From OptimalControlModel
(
    dynamics(model::OptimalControlModel{T,S,C,V,D,O})::D
) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel,
    D<:Function,
    O<:AbstractObjectiveModel,
} = model.dynamics
