# ------------------------------------------------------------------------------ #
# GETTERS
#
# Constraints and multipliers from a DualModel
# ------------------------------------------------------------------------------ #

# path_constraints::PC
# path_constraints_dual::PC_Dual
# boundary_constraints::BC
# boundary_constraints_dual::BC_Dual
# state_constraints_lb_dual::SC_LB_Dual
# state_constraints_ub_dual::SC_UB_Dual
# control_constraints_lb_dual::CC_LB_Dual
# control_constraints_ub_dual::CC_UB_Dual
# variable_constraints_lb_dual::VC_LB_Dual
# variable_constraints_ub_dual::VC_UB_Dual

function path_constraints(model::DualModel{
    PC,
    Function,
    ctVector,
    ctVector,
    Function,
    Function,
    Function,
    Function,
    ctVector,
    ctVector,
})::PC where {PC<:Function}
    return model.path_constraints
end

function path_constraints_dual(model::DualModel{
    Function,
    PC_Dual,
    ctVector,
    ctVector,
    Function,
    Function,
    Function,
    Function,
    ctVector,
    ctVector,
})::PC_Dual where {PC_Dual<:Function}
    return model.path_constraints_dual
end

function boundary_constraints(model::DualModel{
    Function,
    Function,
    BC,
    ctVector,
    Function,
    Function,
    Function,
    Function,
    ctVector,
    ctVector,
})::BC where {BC<:ctVector}
    return model.boundary_constraints
end

function boundary_constraints_dual(model::DualModel{
    Function,
    Function,
    ctVector,
    BC_Dual,
    Function,
    Function,
    Function,
    Function,
    ctVector,
    ctVector,
})::BC_Dual where {BC_Dual<:ctVector}
    return model.boundary_constraints_dual
end

function state_constraints_lb_dual(model::DualModel{
    Function,
    Function,
    ctVector,
    ctVector,
    SC_LB_Dual,
    Function,
    Function,
    Function,
    ctVector,
    ctVector,
})::SC_LB_Dual where {SC_LB_Dual<:Function}
    return model.state_constraints_lb_dual
end

function state_constraints_ub_dual(model::DualModel{
    Function,
    Function,
    ctVector,
    ctVector,
    Function,
    SC_UB_Dual,
    Function,
    Function,
    ctVector,
    ctVector,
})::SC_UB_Dual where {SC_UB_Dual<:Function}
    return model.state_constraints_ub_dual
end

function control_constraints_lb_dual(model::DualModel{
    Function,
    Function,
    ctVector,
    ctVector,
    Function,
    Function,
    CC_LB_Dual,
    Function,
    ctVector,
    ctVector,
})::CC_LB_Dual where {CC_LB_Dual<:Function}
    return model.control_constraints_lb_dual
end

function control_constraints_ub_dual(model::DualModel{
    Function,
    Function,
    ctVector,
    ctVector,
    Function,
    Function,
    Function,
    CC_UB_Dual,
    ctVector,
    ctVector,
})::CC_UB_Dual where {CC_UB_Dual<:Function}
    return model.control_constraints_ub_dual
end

function variable_constraints_lb_dual(model::DualModel{
    Function,
    Function,
    ctVector,
    ctVector,
    Function,
    Function,
    Function,
    Function,
    VC_LB_Dual,
    ctVector,
})::VC_LB_Dual where {VC_LB_Dual<:ctVector}
    return model.variable_constraints_lb_dual
end

function variable_constraints_ub_dual(model::DualModel{
    Function,
    Function,
    ctVector,
    ctVector,
    Function,
    Function,
    Function,
    Function,
    ctVector,
    VC_UB_Dual,
})::VC_UB_Dual where {VC_UB_Dual<:ctVector}
    return model.variable_constraints_ub_dual
end

