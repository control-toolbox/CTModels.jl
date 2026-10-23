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
  convention, with nonnegative lower and upper multipliers `zL`, `zU`. The dual of a
  component follows the sign convention of the ecosystem (ct-conventions `SGN2`,
  `SGN3`): `zL` for a component with a lower bound only, `zU` for an upper bound only
  (both `≥ 0`, as for a path constraint with a single bound), and the signed `zU − zL`
  for two finite bounds or a fixed component. Components never constrained carry a zero
  multiplier.
- If several labels target the same component, `dual(sol, model, :label)` returns
  the (same) per-component multiplier for each: CTModels does not track which
  declaration "owns" the multiplier, because the solver only sees the effective
  (intersected) bound.
- A solution may hold the duals of some kinds of constraints only (the solution of a CTFlows
  flow holds the path duals only). For a label whose duals were not stored, `dual` throws a
  `PreconditionError`; its suggestion is the note `infos(sol)[:missing_duals]` left by the
  producer of the solution, which explains why the duals are missing and how to get them,
  or a generic one.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `label` is not a constraint of the
  model.
- [`CTBase.Exceptions.PreconditionError`](@extref): if the solution holds no dual for the
  kind of constraint of `label`.
"""
function dual(sol::Solution, model::Model, label::Symbol)

    # an unknown label is an error whatever the solution
    _is_constraint_label(model, label) || _throw_label_not_found(label)

    # the solution must carry dual variables
    has_duals(sol) || throw(
        Exceptions.PreconditionError(
            "the solution carries no dual variables";
            reason="the solution's dual model is empty (EmptyDualModel)",
            suggestion=_missing_duals_note(
                sol,
                "a direct solve returns the duals; a solution built by a CTFlows flow carries the duals of the path constraints only, when they are given to `Flow(ocp, law; constraint=:label, multiplier=μ)` by their label",
            ),
            context="dual - looking up a constraint dual on a dual-free solution",
        ),
    )

    # check if the label is in the path constraints
    cp = path_constraints_nl(model)
    labels = cp[4] # vector of labels
    if label in labels
        indices = findall(x -> x == label, labels)
        duals = path_constraints_dual(sol)
        _ensure_dual(sol, duals, label, "path")
        idx = length(indices) == 1 ? indices[1] : indices
        return DualSlice(duals, idx)
    end

    # check if the label is in the boundary constraints
    cp = boundary_constraints_nl(model)
    labels = cp[4] # vector of labels
    if label in labels
        indices = findall(x -> x == label, labels)
        duals = boundary_constraints_dual(sol)
        _ensure_dual(sol, duals, label, "boundary")
        if length(indices) == 1
            return duals[indices[1]]
        else
            return duals[indices]
        end
    end

    # Box constraints: resolve `label` via the `aliases` field (cp[5]) of each
    # box tuple. `cp[2][k]` gives the primal component index for row `k`, which
    # is used to slice the per-component dual matrix/vector.
    function _box_idxs(cp, lbl)
        aliases = cp[5]
        out = Int[]
        for k in eachindex(aliases)
            if lbl in aliases[k]
                push!(out, cp[2][k])
            end
        end
        return out
    end

    # state box
    cp = state_constraints_box(model)
    idxs = _box_idxs(cp, label)
    if !isempty(idxs)
        duals_lb = state_constraints_lb_dual(sol)
        duals_ub = state_constraints_ub_dual(sol)
        _ensure_dual(sol, duals_lb, label, "state box")
        _ensure_dual(sol, duals_ub, label, "state box")
        return _box_dual(duals_lb, duals_ub, cp, idxs)
    end

    # control box
    cp = control_constraints_box(model)
    idxs = _box_idxs(cp, label)
    if !isempty(idxs)
        duals_lb = control_constraints_lb_dual(sol)
        duals_ub = control_constraints_ub_dual(sol)
        _ensure_dual(sol, duals_lb, label, "control box")
        _ensure_dual(sol, duals_ub, label, "control box")
        return _box_dual(duals_lb, duals_ub, cp, idxs)
    end

    # variable box
    cp = variable_constraints_box(model)
    idxs = _box_idxs(cp, label)
    if !isempty(idxs)
        duals_lb = variable_constraints_lb_dual(sol)
        duals_ub = variable_constraints_ub_dual(sol)
        _ensure_dual(sol, duals_lb, label, "variable box")
        _ensure_dual(sol, duals_ub, label, "variable box")
        cl, cu = _box_dual_coefficients(cp, idxs)
        if length(idxs) == 1
            i = idxs[1]
            return cl[1] * duals_lb[i] + cu[1] * duals_ub[i]
        else
            return cl .* duals_lb[idxs] .+ cu .* duals_ub[idxs]
        end
    end

    # unreachable: the label was found above
    return _throw_label_not_found(label)
end

"""
$(TYPEDSIGNATURES)

Coefficients `(cl, cu)` of the lower- and upper-bound multipliers in the dual of each box
component `idxs` (ct-conventions `SGN2`, `SGN3`): `(1, 0)` for a component with a finite
lower bound only (the dual is `zL ≥ 0`), `(0, 1)` for a finite upper bound only
(`zU ≥ 0`), `(-1, 1)` for two finite bounds or a fixed component (the signed
`zU − zL`). The bounds of a component are those of all its declarations in the box tuple
`cp` (effective bounds: the largest lower and the smallest upper bound).
"""
function _box_dual_coefficients(cp, idxs::Vector{Int})
    cl = zeros(length(idxs))
    cu = zeros(length(idxs))
    for (j, i) in enumerate(idxs)
        rows = findall(==(i), cp[2])
        lo, up = maximum(cp[1][rows]), minimum(cp[3][rows])
        if isfinite(lo) && !isfinite(up)
            cl[j], cu[j] = 1.0, 0.0
        elseif !isfinite(lo) && isfinite(up)
            cl[j], cu[j] = 0.0, 1.0
        else
            cl[j], cu[j] = -1.0, 1.0
        end
    end
    return cl, cu
end

"""
$(TYPEDSIGNATURES)

The dual of the state or control box components `idxs`, as a function of time (a
[`CTModels.Solutions.BoxDualDiff`](@extref) with the coefficients of
[`CTModels.Solutions._box_dual_coefficients`](@extref)): a scalar for one component.
"""
function _box_dual(duals_lb, duals_ub, cp, idxs::Vector{Int})
    cl, cu = _box_dual_coefficients(cp, idxs)
    length(idxs) == 1 && return BoxDualDiff(duals_lb, duals_ub, idxs[1], cl[1], cu[1])
    return BoxDualDiff(duals_lb, duals_ub, idxs, cl, cu)
end

"""
$(TYPEDSIGNATURES)

Whether `label` is a constraint of `model`: a path or boundary constraint, or an alias of
a state, control or variable box.
"""
function _is_constraint_label(model::Model, label::Symbol)::Bool
    label in path_constraints_nl(model)[4] && return true
    label in boundary_constraints_nl(model)[4] && return true
    for cp in (
        state_constraints_box(model),
        control_constraints_box(model),
        variable_constraints_box(model),
    )
        any(aliases -> label in aliases, cp[5]) && return true
    end
    return false
end

"""
$(TYPEDSIGNATURES)

Throw the [`CTBase.Exceptions.IncorrectArgument`](@extref) of an unknown constraint label.
"""
function _throw_label_not_found(label::Symbol)
    return throw(
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

The explanation of the missing duals of `sol`: the note `infos(sol)[:missing_duals]` left by
the producer of the solution (e.g. CTFlows, which knows why a dual could not be rebuilt and
how to get it), or `default` when there is none.
"""
function _missing_duals_note(sol::Solution, default::AbstractString)::String
    note = get(infos(sol), :missing_duals, nothing)
    return note isa AbstractString && !isempty(note) ? String(note) : String(default)
end

"""
$(TYPEDSIGNATURES)

Throw a [`CTBase.Exceptions.PreconditionError`](@extref) when the solution holds no dual
for the `kind` constraints (`duals === nothing`), although it holds others: the label
`label` exists in the model, but its dual was not computed. A flow solution, for
instance, carries the duals of the path constraints only. The suggestion is the note
`infos(sol)[:missing_duals]` left by the producer of the solution, when there is one (see
[`CTModels.Solutions._missing_duals_note`](@extref)).
"""
function _ensure_dual(sol::Solution, duals, label::Symbol, kind::String)
    isnothing(duals) || return nothing
    return throw(
        Exceptions.PreconditionError(
            "the solution carries no dual for the $kind constraint :$label";
            reason="the label :$label is a $kind constraint of the model, but the duals of the $kind constraints were not stored in the solution",
            suggestion=_missing_duals_note(
                sol,
                "a direct solve returns every dual; a solution built by a CTFlows flow carries the duals of the path constraints only, when they are given to `Flow(ocp, law; constraint=:label, multiplier=μ)` by their label",
            ),
            context="dual - looking up the dual of a constraint",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the dual function associated with the nonlinear path constraints.

# Arguments
- `model::DualModel`: A model including dual variables for path constraints.

# Returns
- `PC_Dual`: A function mapping time `t` to the vector of dual values, or `nothing` if not set.

See also: [`CTModels.Solutions.boundary_constraints_dual`](@extref), [`CTModels.Solutions.state_constraints_lb_dual`](@extref).
"""
function path_constraints_dual(
    model::DualModel{
        PC_Dual,
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
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
- `BC_Dual`: A vector of dual values, or `nothing` if not set.

See also: [`CTModels.Solutions.path_constraints_dual`](@extref), [`CTModels.Solutions.state_constraints_lb_dual`](@extref).
"""
function boundary_constraints_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        BC_Dual,
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
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
- `SC_LB_Dual`: A function mapping time `t` to a vector of dual values, or `nothing` if not set.

See also: [`CTModels.Solutions.state_constraints_ub_dual`](@extref), [`CTModels.Solutions.control_constraints_lb_dual`](@extref).
"""
function state_constraints_lb_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        SC_LB_Dual,
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
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
- `SC_UB_Dual`: A function mapping time `t` to a vector of dual values, or `nothing` if not set.

See also: [`CTModels.Solutions.state_constraints_lb_dual`](@extref), [`CTModels.Solutions.control_constraints_ub_dual`](@extref).
"""
function state_constraints_ub_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        SC_UB_Dual,
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
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
- `CC_LB_Dual`: A function mapping time `t` to a vector of dual values, or `nothing` if not set.

See also: [`CTModels.Solutions.control_constraints_ub_dual`](@extref), [`CTModels.Solutions.state_constraints_lb_dual`](@extref).
"""
function control_constraints_lb_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        CC_LB_Dual,
        <:Union{Function,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
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
- `CC_UB_Dual`: A function mapping time `t` to a vector of dual values, or `nothing` if not set.

See also: [`CTModels.Solutions.control_constraints_lb_dual`](@extref), [`CTModels.Solutions.state_constraints_ub_dual`](@extref).
"""
function control_constraints_ub_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        CC_UB_Dual,
        <:Union{ctNumber,ctVector,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
    },
)::CC_UB_Dual where {CC_UB_Dual<:Union{Function,Nothing}}
    return model.control_constraints_ub_dual
end

"""
$(TYPEDSIGNATURES)

Return the dual associated with the lower bounds of variable constraints.

# Arguments
- `model::DualModel`: A model including dual variables for variable lower bounds.

# Returns
- `VC_LB_Dual`: A scalar for a 1-D variable, a vector otherwise, or `nothing` if not set.

See also: [`CTModels.Solutions.variable_constraints_ub_dual`](@extref), [`CTModels.Solutions.state_constraints_lb_dual`](@extref).
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
        <:Union{ctNumber,ctVector,Nothing},
    },
)::VC_LB_Dual where {VC_LB_Dual<:Union{ctNumber,ctVector,Nothing}}
    return model.variable_constraints_lb_dual
end

"""
$(TYPEDSIGNATURES)

Return the dual associated with the upper bounds of variable constraints.

# Arguments
- `model::DualModel`: A model including dual variables for variable upper bounds.

# Returns
- `VC_UB_Dual`: A scalar for a 1-D variable, a vector otherwise, or `nothing` if not set.

See also: [`CTModels.Solutions.variable_constraints_lb_dual`](@extref), [`CTModels.Solutions.state_constraints_ub_dual`](@extref).
"""
function variable_constraints_ub_dual(
    model::DualModel{
        <:Union{Function,Nothing},
        <:Union{ctVector,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{Function,Nothing},
        <:Union{ctNumber,ctVector,Nothing},
        VC_UB_Dual,
    },
)::VC_UB_Dual where {VC_UB_Dual<:Union{ctNumber,ctVector,Nothing}}
    return model.variable_constraints_ub_dual
end

# ------------------------------------------------------------------------------ #
# Empty dual model
#
# A solution carrying no dual variables (e.g. built by a flow) stores an
# `EmptyDualModel`. Every dual accessor returns `nothing` for it, so the
# Solution-level delegating accessors and `show` behave as with an all-`nothing`
# `DualModel`.
# ------------------------------------------------------------------------------ #
"""
$(TYPEDSIGNATURES)

Return `nothing` for an empty dual model: the path constraints dual is absent.
"""
path_constraints_dual(::EmptyDualModel) = nothing

"""
$(TYPEDSIGNATURES)

Return `nothing` for an empty dual model: the boundary constraints dual is absent.
"""
boundary_constraints_dual(::EmptyDualModel) = nothing

"""
$(TYPEDSIGNATURES)

Return `nothing` for an empty dual model: the state lower-bound dual is absent.
"""
state_constraints_lb_dual(::EmptyDualModel) = nothing

"""
$(TYPEDSIGNATURES)

Return `nothing` for an empty dual model: the state upper-bound dual is absent.
"""
state_constraints_ub_dual(::EmptyDualModel) = nothing

"""
$(TYPEDSIGNATURES)

Return `nothing` for an empty dual model: the control lower-bound dual is absent.
"""
control_constraints_lb_dual(::EmptyDualModel) = nothing

"""
$(TYPEDSIGNATURES)

Return `nothing` for an empty dual model: the control upper-bound dual is absent.
"""
control_constraints_ub_dual(::EmptyDualModel) = nothing

"""
$(TYPEDSIGNATURES)

Return `nothing` for an empty dual model: the variable lower-bound dual is absent.
"""
variable_constraints_lb_dual(::EmptyDualModel) = nothing

"""
$(TYPEDSIGNATURES)

Return `nothing` for an empty dual model: the variable upper-bound dual is absent.
"""
variable_constraints_ub_dual(::EmptyDualModel) = nothing
