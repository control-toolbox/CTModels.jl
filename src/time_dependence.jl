function time_dependence!(
    ocp::PreModel;
    autonomous::Bool
)::Nothing

    # checkings
    @ensure !__is_autonomous_set(ocp) CTBase.UnauthorizedCall("the time dependence has already been set.")

    # set the state
    ocp.autonomous = autonomous

    return nothing
end

is_autonomous(ocp::PreModel) = ocp.autonomous