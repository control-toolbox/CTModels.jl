# ------------------------------------------------------------------------------ #
# GETTERS
#
# Constraints and multipliers from a DualModel
# ------------------------------------------------------------------------------ #
"""
$(TYPEDSIGNATURES)

"""
function dual(sol::Solution, model::Model, label::Symbol)

    # check if the label is in the path constraints
    cp = path_constraints_nl(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices = findall(x -> x == label, labels)
        # get the corresponding dual values
        duals = path_constraints_dual(sol)
        if length(indices) == 1
            return t -> duals(t)[indices[1]]
        else
            return t -> duals(t)[indices]
        end
    end

    # check if the label is in the boundary constraints
    cp = boundary_constraints_nl(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices = findall(x -> x == label, labels)
        # get the corresponding dual values
        duals = boundary_constraints_dual(sol)
        if length(indices) == 1
            return duals[indices[1]]
        else
            return duals[indices]
        end
    end

    # check if the label is in the state constraints
    cp = state_constraints_box(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices = findall(x -> x == label, labels)
        # get the corresponding dual values
        duals_lb = state_constraints_lb_dual(sol)
        duals_ub = state_constraints_ub_dual(sol)
        if length(indices) == 1
            return t -> ( duals_lb(t)[indices[1]] - duals_ub(t)[indices[1]] )
        else
            return t -> ( duals_lb(t)[indices] - duals_ub(t)[indices] )
        end
    end

    # check if the label is in the control constraints
    cp = control_constraints_box(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices = findall(x -> x == label, labels)
        # get the corresponding dual values, either lower or upper bound
        duals_lb = control_constraints_lb_dual(sol)
        duals_ub = control_constraints_ub_dual(sol)
        if length(indices) == 1
            return t -> ( duals_lb(t)[indices[1]] - duals_ub(t)[indices[1]] )
        else
            return t -> ( duals_lb(t)[indices] - duals_ub(t)[indices] )
        end
    end

    # check if the label is in the variable constraints
    cp = variable_constraints_box(model)
    labels = cp[4] # vector of labels
    if label in labels
        # get all the indices of the label
        indices = findall(x -> x == label, labels)
        # get the corresponding dual values, either lower or upper bound
        duals_lb = variable_constraints_lb_dual(sol)
        duals_ub = variable_constraints_ub_dual(sol)
        if length(indices) == 1
            return duals_lb[indices[1]] - duals_ub[indices[1]]
        else
            return duals_lb[indices] - duals_ub[indices]
        end
    end

    # return an exception if the label is not found
    return CTBase.IncorrectArgument("Label $label not found in the model.")
end

"""
$(TYPEDSIGNATURES)

"""
function path_constraints_dual(
    model::DualModel{
        PC_Dual,
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{ctVector,Nothing},
    },
)::PC_Dual where {PC_Dual<:Union{Function,Nothing}}
    return model.path_constraints_dual
end

"""
$(TYPEDSIGNATURES)

"""
function boundary_constraints_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        BC_Dual,
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{ctVector,Nothing},
    },
)::BC_Dual where {BC_Dual<:Union{ctVector,Nothing}}
    return model.boundary_constraints_dual
end

"""
$(TYPEDSIGNATURES)

"""
function state_constraints_lb_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        SC_LB_Dual,
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{ctVector,Nothing},
    },
)::SC_LB_Dual where {SC_LB_Dual<:Union{Function,Nothing}}
    return model.state_constraints_lb_dual
end

"""
$(TYPEDSIGNATURES)

"""
function state_constraints_ub_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        SC_UB_Dual,
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{ctVector,Nothing},
    },
)::SC_UB_Dual where {SC_UB_Dual<:Union{Function,Nothing}}
    return model.state_constraints_ub_dual
end

"""
$(TYPEDSIGNATURES)

"""
function control_constraints_lb_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        CC_LB_Dual,
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{ctVector,Nothing},
    },
)::CC_LB_Dual where {CC_LB_Dual<:Union{Function,Nothing}}
    return model.control_constraints_lb_dual
end

"""
$(TYPEDSIGNATURES)

"""
function control_constraints_ub_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        CC_UB_Dual,
        <:Union{ctVector,Nothing},
        <:Union{ctVector,Nothing},
    },
)::CC_UB_Dual where {CC_UB_Dual<:Union{Function,Nothing}}
    return model.control_constraints_ub_dual
end

"""
$(TYPEDSIGNATURES)

"""
function variable_constraints_lb_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        VC_LB_Dual,
        <:Union{ctVector,Nothing},
    },
)::VC_LB_Dual where {VC_LB_Dual<:Union{ctVector,Nothing}}
    return model.variable_constraints_lb_dual
end

"""
$(TYPEDSIGNATURES)

"""
function variable_constraints_ub_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        VC_UB_Dual,
    },
)::VC_UB_Dual where {VC_UB_Dual<:Union{ctVector,Nothing}}
    return model.variable_constraints_ub_dual
end
