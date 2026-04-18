# ------------------------------------------------------------------------------ #
# GETTERS
#
# Constraints and multipliers from a DualModel
# ------------------------------------------------------------------------------ #
"""
$(TYPEDSIGNATURES)

Return the dual variable associated with a constraint identified by its `label`.

Searches through all constraint types (path, boundary, state, control, and variable constraints)
defined in the model and returns the corresponding dual value from the solution.

# Arguments
- `sol::Solution`: Solution object containing dual variables.
- `model::Model`: Model containing constraint definitions.
- `label::Symbol`: Symbol corresponding to a constraint label.

# Returns
A function of time `t` for time-dependent constraints, or a scalar/vector for time-invariant duals.
If the label is not found, throws an `IncorrectArgument` exception.

# Notes
- For path/boundary constraints, duals are indexed per declaration (one column per
  row of the stacked nonlinear constraint vector).
- For box constraints (state/control/variable), the dual matrices/vectors stored
  in the `Solution` are indexed **by primal component** (i.e.
  `state_dimension(model)` columns for state, etc.), following the CTDirect
  convention. For a label targeting component indices `rg`, this function
  returns `duals_lb[:, rg] - duals_ub[:, rg]` (or the time-independent analogue
  for variables). Components never constrained carry a zero multiplier.
- If several labels target the same component, `dual(sol, model, :label)` returns
  the (same) per-component multiplier for each: CTModels does not track which
  declaration "owns" the multiplier, because the solver only sees the effective
  (intersected) bound.
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

    # Box constraints: resolve `label` via the `aliases` field (cp[5]) of each
    # box tuple. `cp[2][k]` gives the primal component index for row `k`, which
    # is used to slice the per-component dual matrix/vector.
    function _box_idxs(cp)
        aliases = cp[5]
        out = Int[]
        for k in eachindex(aliases)
            if label in aliases[k]
                push!(out, cp[2][k])
            end
        end
        return out
    end

    # state box
    cp = state_constraints_box(model)
    idxs = _box_idxs(cp)
    if !isempty(idxs)
        duals_lb = state_constraints_lb_dual(sol)
        duals_ub = state_constraints_ub_dual(sol)
        if length(idxs) == 1
            i = idxs[1]
            return t -> (duals_lb(t)[i] - duals_ub(t)[i])
        else
            return t -> (duals_lb(t)[idxs] - duals_ub(t)[idxs])
        end
    end

    # control box
    cp = control_constraints_box(model)
    idxs = _box_idxs(cp)
    if !isempty(idxs)
        duals_lb = control_constraints_lb_dual(sol)
        duals_ub = control_constraints_ub_dual(sol)
        if length(idxs) == 1
            i = idxs[1]
            return t -> (duals_lb(t)[i] - duals_ub(t)[i])
        else
            return t -> (duals_lb(t)[idxs] - duals_ub(t)[idxs])
        end
    end

    # variable box
    cp = variable_constraints_box(model)
    idxs = _box_idxs(cp)
    if !isempty(idxs)
        duals_lb = variable_constraints_lb_dual(sol)
        duals_ub = variable_constraints_ub_dual(sol)
        if length(idxs) == 1
            i = idxs[1]
            return duals_lb[i] - duals_ub[i]
        else
            return duals_lb[idxs] - duals_ub[idxs]
        end
    end

    # throw an exception if the label is not found
    throw(
        Exceptions.IncorrectArgument(
            "Label not found in model";
            got="label=$label",
            expected="existing label in the model",
            suggestion="Check available labels in the model or use a valid label",
            context="get_constraint_dual - looking up constraint label in dual model",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the dual function associated with the nonlinear path constraints.

# Arguments
- `model::DualModel`: A model including dual variables for path constraints.

# Returns
A function mapping time `t` to the vector of dual values, or `nothing` if not set.
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

Return the dual vector associated with the boundary constraints.

# Arguments
- `model::DualModel`: A model including dual variables for boundary constraints.

# Returns
A vector of dual values, or `nothing` if not set.
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

Return the dual function associated with the lower bounds of state constraints.

# Arguments
- `model::DualModel`: A model including dual variables for state lower bounds.

# Returns
A function mapping time `t` to a vector of dual values, or `nothing` if not set.
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

Return the dual function associated with the upper bounds of state constraints.

# Arguments
- `model::DualModel`: A model including dual variables for state upper bounds.

# Returns
A function mapping time `t` to a vector of dual values, or `nothing` if not set.
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

Return the dual function associated with the lower bounds of control constraints.

# Arguments
- `model::DualModel`: A model including dual variables for control lower bounds.

# Returns
A function mapping time `t` to a vector of dual values, or `nothing` if not set.
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

Return the dual function associated with the upper bounds of control constraints.

# Arguments
- `model::DualModel`: A model including dual variables for control upper bounds.

# Returns
A function mapping time `t` to a vector of dual values, or `nothing` if not set.
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

Return the dual vector associated with the lower bounds of variable constraints.

# Arguments
- `model::DualModel`: A model including dual variables for variable lower bounds.

# Returns
A vector of dual values, or `nothing` if not set.
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

Return the dual vector associated with the upper bounds of variable constraints.

# Arguments
- `model::DualModel`: A model including dual variables for variable upper bounds.

# Returns
A vector of dual values, or `nothing` if not set.
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
