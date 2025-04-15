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

function path_constraints(
    model::DualModel{
        PC,
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
    },
)::PC where {PC<:Union{Function, Nothing}}
    return model.path_constraints
end

function path_constraints_dual(
    model::DualModel{
        <:Union{Function, Nothing},
        PC_Dual,
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
    },
)::PC_Dual where {PC_Dual<:Union{Function, Nothing}}
    return model.path_constraints_dual
end

function boundary_constraints(
    model::DualModel{
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        BC,
        <:Union{ctVector, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
    },
)::BC where {BC<:Union{Function, Nothing}}
    return model.boundary_constraints
end

function boundary_constraints_dual(
    model::DualModel{
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        BC_Dual,
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
    },
)::BC_Dual where {BC_Dual<:Union{Function, Nothing}}
    return model.boundary_constraints_dual
end

function state_constraints_lb_dual(
    model::DualModel{
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
        SC_LB_Dual,
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
    },
)::SC_LB_Dual where {SC_LB_Dual<:Union{Function, Nothing}}
    return model.state_constraints_lb_dual
end

function state_constraints_ub_dual(
    model::DualModel{
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{Function, Nothing},
        SC_UB_Dual,
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
    },
)::SC_UB_Dual where {SC_UB_Dual<:Union{Function, Nothing}}
    return model.state_constraints_ub_dual
end

function control_constraints_lb_dual(
    model::DualModel{
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        CC_LB_Dual,
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
    },
)::CC_LB_Dual where {CC_LB_Dual<:Union{Function, Nothing}}
    return model.control_constraints_lb_dual
end

function control_constraints_ub_dual(
    model::DualModel{
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        CC_UB_Dual,
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
    },
)::CC_UB_Dual where {CC_UB_Dual<:Union{Function, Nothing}}
    return model.control_constraints_ub_dual
end

function variable_constraints_lb_dual(
    model::DualModel{
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        VC_LB_Dual,
        <:Union{ctVector, Nothing},
    },
)::VC_LB_Dual where {VC_LB_Dual<:Union{Function, Nothing}}
    return model.variable_constraints_lb_dual
end

function variable_constraints_ub_dual(
    model::DualModel{
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{ctVector, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{Function, Nothing},
        <:Union{ctVector, Nothing},
        VC_UB_Dual,
    },
)::VC_UB_Dual where {VC_UB_Dual<:Union{Function, Nothing}}
    return model.variable_constraints_ub_dual
end
