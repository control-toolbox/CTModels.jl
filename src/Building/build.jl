"""
$(TYPEDSIGNATURES)

Append box constraint data to the provided flat vectors.

This is an internal helper used by [`CTModels.Building.build`](@ref). It simply
accumulates declarations. Deduplication (one entry per component with
intersection semantics) and associated warnings are handled later by
[`CTModels.Building._dedup_box_constraints!`](@ref).

# Arguments
- `inds::Vector{Int}`: Vector of component indices to append to.
- `lbs::Vector{<:Real}`: Vector of lower bounds to append to.
- `ubs::Vector{<:Real}`: Vector of upper bounds to append to.
- `labels::Vector{Symbol}`: Vector of labels (one entry per declared component).
- `rg::AbstractVector{Int}`: Component indices declared by the new constraint.
- `lb::AbstractVector{<:Real}`: Lower bounds associated with `rg`.
- `ub::AbstractVector{<:Real}`: Upper bounds associated with `rg`.
- `label::Symbol`: Label describing the declaration.

# Notes
- Modifies `inds`, `lbs`, `ubs`, `labels` in-place.
- No deduplication or warning emitted here; see [`CTModels.Building._dedup_box_constraints!`](@ref).

# Returns
- `Nothing`
"""
function append_box_constraints!(inds, lbs, ubs, labels, rg, lb, ub, label)
    append!(inds, rg)
    append!(lbs, lb)
    append!(ubs, ub)
    for _ in 1:length(lb)
        push!(labels, label)
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Deduplicate box-constraint declarations by component, applying the intersection
of all declared bounds for each repeated component. Produces an `aliases` vector
recording every label that targeted each component.

After this function returns, the vectors satisfy the invariant:

- `allunique(inds)` — each component appears at most once.
- `lbs[k]` = `max` of all declared lower bounds for component `inds[k]`.
- `ubs[k]` = `min` of all declared upper bounds for component `inds[k]`.
- `labels[k]` = the first label that declared component `inds[k]` (stable order).
- `aliases[k]` = all distinct labels that declared component `inds[k]`, in
  first-seen order (always starts with `labels[k]`).
- Vectors are sorted by `inds`.

A `@warn` is emitted once for each duplicated component, listing all contributing
labels. If the intersection is empty (i.e. `max(lbs_k) > min(ubs_k)`), an
`CTBase.Exceptions.IncorrectArgument` is thrown.

# Arguments
- `inds`, `lbs`, `ubs`, `labels`: in-place flat vectors produced by successive
  calls to [`CTModels.Building.append_box_constraints!`](@ref).
- `aliases`: in-place empty `Vector{Vector{Symbol}}` to be populated with the
  per-component list of all declaring labels.
- `kind::String`: human-readable descriptor (e.g. "state", "control",
  "variable") used in diagnostic messages.

# Throws
- `CTBase.Exceptions.IncorrectArgument` if the intersection of declared bounds is
  empty for some component.

# Returns
- `Nothing`
"""
function _dedup_box_constraints!(
    inds::Vector{Int},
    lbs::Vector{T},
    ubs::Vector{T},
    labels::Vector{Symbol},
    aliases::Vector{Vector{Symbol}},
    kind::String,
) where {T<:Real}
    if isempty(inds)
        empty!(aliases)
        return nothing
    end

    # group declaration positions by component index, preserving first-seen order
    unique_order = Int[]
    positions = Dict{Int,Vector{Int}}()
    @inbounds for (k, i) in pairs(inds)
        if haskey(positions, i)
            push!(positions[i], k)
        else
            positions[i] = [k]
            push!(unique_order, i)
        end
    end

    # build deduped vectors; emit warning for each duplicated component
    new_inds = Int[]
    new_lbs = T[]
    new_ubs = T[]
    new_labels = Symbol[]
    new_aliases = Vector{Symbol}[]
    for i in unique_order
        ks = positions[i]
        # distinct labels for component i, in first-seen order
        dup_labels = Symbol[]
        for k in ks
            l = labels[k]
            if l ∉ dup_labels
                push!(dup_labels, l)
            end
        end
        if length(ks) == 1
            k = ks[1]
            push!(new_inds, i)
            push!(new_lbs, lbs[k])
            push!(new_ubs, ubs[k])
            push!(new_labels, labels[k])
            push!(new_aliases, dup_labels)
        else
            lb_eff = maximum(lbs[ks])
            ub_eff = minimum(ubs[ks])
            @warn "Multiple bound declarations for $kind component $i " *
                "(labels: $(join(dup_labels, ", "))). " *
                "Intersection applied: effective lb = $lb_eff, effective ub = $ub_eff."
            Core.@ensure lb_eff <= ub_eff Exceptions.IncorrectArgument(
                "Empty feasible set for $kind component $i";
                got="max(lbs)=$lb_eff > min(ubs)=$ub_eff",
                expected="max(lbs) ≤ min(ubs)",
                suggestion="Check the declared bounds for labels $(join(dup_labels, ", ")).",
                context="_dedup_box_constraints! - infeasibility check",
            )
            push!(new_inds, i)
            push!(new_lbs, lb_eff)
            push!(new_ubs, ub_eff)
            push!(new_labels, dup_labels[1])
            push!(new_aliases, dup_labels)
        end
    end

    # sort by component index for readability
    perm = sortperm(new_inds)
    resize!(inds, length(new_inds));
    inds .= new_inds[perm]
    resize!(lbs, length(new_lbs));
    lbs .= new_lbs[perm]
    resize!(ubs, length(new_ubs));
    ubs .= new_ubs[perm]
    resize!(labels, length(new_labels));
    labels .= new_labels[perm]
    empty!(aliases)
    append!(aliases, new_aliases[perm])
    return nothing
end

"""
$(TYPEDSIGNATURES)

Constructs a [`CTModels.Components.ConstraintsModel`](@ref) from a dictionary of constraints.

This function processes a dictionary where each entry defines a constraint with its type, function or index range, lower and upper bounds, and label. It categorizes constraints into path, boundary, state, control, and variable constraints, assembling them into a structured [`CTModels.Components.ConstraintsModel`](@ref).

# Arguments
- `constraints::CTModels.Components.ConstraintsDictType`: A dictionary mapping constraint labels to tuples of the form `(type, function_or_range, lower_bound, upper_bound)`.

# Returns
- `CTModels.Components.ConstraintsModel`: A structured model encapsulating all provided constraints.

# Example
```julia
using CTModels.Building
using OrderedCollections

f1(t, x, u, v) = x[1]
constraints = OrderedDict(
    :c1 => (:path, f1, [0.0], [1.0]),
    :c2 => (:state, 1:2, [-1.0, -1.0], [1.0, 1.0])
)
model = build(constraints)
```

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If an unknown constraint type is encountered

See also: [`CTModels.Building.append_box_constraints!`](@ref), [`CTModels.Building._dedup_box_constraints!`](@ref)
"""
function build(constraints::ConstraintsDictType)::ConstraintsModel
    LocalNumber = Float64

    path_cons_nl_f = Vector{Function}() # nonlinear path constraints
    path_cons_nl_dim = Vector{Int}()
    path_cons_nl_lb = Vector{LocalNumber}()
    path_cons_nl_ub = Vector{LocalNumber}()
    path_cons_nl_labels = Vector{Symbol}()

    boundary_cons_nl_f = Vector{Function}() # nonlinear boundary constraints
    boundary_cons_nl_dim = Vector{Int}()
    boundary_cons_nl_lb = Vector{LocalNumber}()
    boundary_cons_nl_ub = Vector{LocalNumber}()
    boundary_cons_nl_labels = Vector{Symbol}()

    state_cons_box_ind = Vector{Int}() # state range
    state_cons_box_lb = Vector{LocalNumber}()
    state_cons_box_ub = Vector{LocalNumber}()
    state_cons_box_labels = Vector{Symbol}()
    state_cons_box_aliases = Vector{Vector{Symbol}}()

    control_cons_box_ind = Vector{Int}() # control range
    control_cons_box_lb = Vector{LocalNumber}()
    control_cons_box_ub = Vector{LocalNumber}()
    control_cons_box_labels = Vector{Symbol}()
    control_cons_box_aliases = Vector{Vector{Symbol}}()

    variable_cons_box_ind = Vector{Int}() # variable range
    variable_cons_box_lb = Vector{LocalNumber}()
    variable_cons_box_ub = Vector{LocalNumber}()
    variable_cons_box_labels = Vector{Symbol}()
    variable_cons_box_aliases = Vector{Vector{Symbol}}()

    for (label, c) in constraints
        type = c[1]
        lb = c[3]
        ub = c[4]
        if type == :path
            f = c[2]
            push!(path_cons_nl_f, f)
            push!(path_cons_nl_dim, length(lb))
            append!(path_cons_nl_lb, lb)
            append!(path_cons_nl_ub, ub)
            for i in 1:length(lb)
                push!(path_cons_nl_labels, label)
            end
        elseif type == :boundary
            f = c[2]
            push!(boundary_cons_nl_f, f)
            push!(boundary_cons_nl_dim, length(lb))
            append!(boundary_cons_nl_lb, lb)
            append!(boundary_cons_nl_ub, ub)
            for i in 1:length(lb)
                push!(boundary_cons_nl_labels, label)
            end
        elseif type == :state
            append_box_constraints!(
                state_cons_box_ind,
                state_cons_box_lb,
                state_cons_box_ub,
                state_cons_box_labels,
                c[2],
                lb,
                ub,
                label,
            )
        elseif type == :control
            append_box_constraints!(
                control_cons_box_ind,
                control_cons_box_lb,
                control_cons_box_ub,
                control_cons_box_labels,
                c[2],
                lb,
                ub,
                label,
            )
        elseif type == :variable
            append_box_constraints!(
                variable_cons_box_ind,
                variable_cons_box_lb,
                variable_cons_box_ub,
                variable_cons_box_labels,
                c[2],
                lb,
                ub,
                label,
            )
        else
            throw(
                Exceptions.IncorrectArgument(
                    "Unknown constraint type";
                    got="constraint type $type for label $label",
                    expected="one of :state, :control, :variable, :boundary, :path",
                    suggestion="Check constraint type or use valid constraint type",
                    context="get_constraint_dual - validating constraint type",
                ),
            )
        end
    end

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
        return CompositeConstraint{:path}(
            constraints_number, constraints_dimensions, constraints_functions
        )
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
        return CompositeConstraint{:boundary}(
            constraints_number, constraints_dimensions, constraints_functions
        )
    end

    path_cons_nl! = make_path_cons_nl(
        length_path_cons_nl, path_cons_nl_dim, path_cons_nl_f...
    )

    boundary_cons_nl! = make_boundary_cons_nl(
        length_boundary_cons_nl, boundary_cons_nl_dim, boundary_cons_nl_f...
    )

    # Enforce the per-component uniqueness invariant for box constraints:
    # deduplicate by component, applying intersection (max of lbs, min of ubs)
    # and emitting a warning for each duplicated component.
    _dedup_box_constraints!(
        state_cons_box_ind,
        state_cons_box_lb,
        state_cons_box_ub,
        state_cons_box_labels,
        state_cons_box_aliases,
        "state",
    )
    _dedup_box_constraints!(
        control_cons_box_ind,
        control_cons_box_lb,
        control_cons_box_ub,
        control_cons_box_labels,
        control_cons_box_aliases,
        "control",
    )
    _dedup_box_constraints!(
        variable_cons_box_ind,
        variable_cons_box_lb,
        variable_cons_box_ub,
        variable_cons_box_labels,
        variable_cons_box_aliases,
        "variable",
    )

    return ConstraintsModel(
        (path_cons_nl_lb, path_cons_nl!, path_cons_nl_ub, path_cons_nl_labels),
        (
            boundary_cons_nl_lb,
            boundary_cons_nl!,
            boundary_cons_nl_ub,
            boundary_cons_nl_labels,
        ),
        (
            state_cons_box_lb,
            state_cons_box_ind,
            state_cons_box_ub,
            state_cons_box_labels,
            state_cons_box_aliases,
        ),
        (
            control_cons_box_lb,
            control_cons_box_ind,
            control_cons_box_ub,
            control_cons_box_labels,
            control_cons_box_aliases,
        ),
        (
            variable_cons_box_lb,
            variable_cons_box_ind,
            variable_cons_box_ub,
            variable_cons_box_labels,
            variable_cons_box_aliases,
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Converts a mutable [`CTModels.Building.PreModel`](@ref) into an immutable [`CTModels.Models.Model`](@ref).

This function finalizes a pre-defined optimal control problem ([`CTModels.Building.PreModel`](@ref)) by verifying that all
necessary components (times, state, dynamics, objective) are set. It then constructs a [`CTModels.Models.Model`](@ref)
instance, incorporating optional components like control, variable, and constraints.

!!! note
    Control is **optional**: calling [`CTModels.Building.control!`](@ref) is not required. When omitted, the model is
    built with `control_dimension == 0` (an [`CTModels.Components.EmptyControlModel`](@ref)). This is useful for problems
    where the dynamics depend only on the state, such as pure state-space systems.

# Arguments
- `pre_ocp::CTModels.Building.PreModel`: The pre-defined optimal control problem to be finalized.
- `build_examodel=nothing`: Optional ExaModel builder function for GPU acceleration.

# Returns
- `CTModels.Models.Model`: A fully constructed model ready for solving.

# Examples

Minimal Mayer problem (no control):

```julia
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2, "x", ["x1", "x2"])
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = -x[2]; r[2] = x[1]; nothing))
CTModels.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1]^2)
CTModels.time_dependence!(pre; autonomous=true)
model = CTModels.build(pre)
CTModels.control_dimension(model)  # 0
```

Bolza problem with control:

```julia
using CTModels

pre = CTModels.PreModel()
CTModels.variable!(pre, 0)
CTModels.time!(pre; t0=0.0, tf=1.0)
CTModels.state!(pre, 2)
CTModels.control!(pre, 1)
CTModels.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = u[1]; nothing))
CTModels.objective!(pre, :min; lagrange=(t, x, u, v) -> u[1]^2)
CTModels.time_dependence!(pre; autonomous=true)
model = CTModels.build(pre)
```

# Throws
- `CTBase.Exceptions.PreconditionError`: If times, state, dynamics, objective, or time dependence are not set
- `CTBase.Exceptions.PreconditionError`: If dynamics are incomplete

See also: [`CTModels.Building.build_model`](@ref), [`CTModels.Building.PreModel`](@ref), [`CTModels.Models.Model`](@ref)
"""
function build(pre_ocp::PreModel; build_examodel=nothing)::Model
    Core.@ensure __is_times_set(pre_ocp) Exceptions.PreconditionError(
        "Times must be set before building model",
        reason="time horizon has not been defined yet",
        suggestion="Call times!(pre_ocp, t0, tf) or times!(pre_ocp, N) before building",
        context="build function - times validation",
    )
    Core.@ensure __is_state_set(pre_ocp) Exceptions.PreconditionError(
        "State must be set before building model",
        reason="state has not been defined yet",
        suggestion="Call state!(pre_ocp, dimension) before building",
        context="build function - state validation",
    )
    Core.@ensure __is_dynamics_set(pre_ocp) Exceptions.PreconditionError(
        "Dynamics must be set before building model",
        reason="dynamics have not been defined yet",
        suggestion="Call dynamics!(pre_ocp, f) or partial_dynamics! before building",
        context="build function - dynamics validation",
    )
    Core.@ensure __is_dynamics_complete(pre_ocp) Exceptions.PreconditionError(
        "Dynamics must be complete before building model",
        reason="not all state components are covered by dynamics",
        suggestion="Complete dynamics definition with partial_dynamics! or use full dynamics!",
        context="build function - dynamics completeness validation",
    )
    Core.@ensure __is_objective_set(pre_ocp) Exceptions.PreconditionError(
        "Objective must be set before building model",
        reason="objective has not been defined yet",
        suggestion="Call objective!(pre_ocp, ...) before building",
        context="build function - objective validation",
    )
    Core.@ensure __is_autonomous_set(pre_ocp) Exceptions.PreconditionError(
        "Time dependence must be set before building model",
        reason="autonomous status has not been defined yet",
        suggestion="Call time_dependence!(pre_ocp, autonomous=true/false) before building",
        context="build function - time dependence validation",
    )

    # extract components from PreModel
    times = pre_ocp.times
    state = pre_ocp.state
    control = pre_ocp.control
    variable = pre_ocp.variable
    dynamics = if pre_ocp.dynamics isa Function
        pre_ocp.dynamics
    else
        __build_dynamics_from_parts(pre_ocp.dynamics)
    end
    objective = pre_ocp.objective
    constraints = build(pre_ocp.constraints)
    definition = pre_ocp.definition
    TD = pre_ocp.autonomous ? Autonomous : NonAutonomous

    # create the model
    model = Model{TD}(
        times,
        state,
        control,
        variable,
        dynamics,
        objective,
        constraints,
        definition,
        build_examodel,
    )

    return model
end

"""
$(TYPEDSIGNATURES)

Build a complete optimal control problem model from a pre-model.

This function is an alias for [`CTModels.Building.build`](@ref) and constructs
a fully validated [`CTModels.Models.Model`](@ref) from a [`CTModels.Building.PreModel`](@ref) by extracting and organizing all components
(times, state, control, variable, dynamics, objective, constraints).

# Arguments
- `pre_ocp::CTModels.Building.PreModel`: The pre-model containing all problem components
- `build_examodel=nothing`: Optional ExaModel builder function for GPU acceleration

# Returns
- `CTModels.Models.Model`: A complete, validated optimal control problem model

# Throws
- `CTBase.Exceptions.PreconditionError`: If time dependence has not been set via [`CTModels.Building.time_dependence!`](@ref)

# Example
```julia
using CTModels.Building

# Create and configure a pre-model
pre_ocp = PreModel()
time_dependence!(pre_ocp, autonomous=true)
state!(pre_ocp, 2)
control!(pre_ocp, 1)
dynamics!(pre_ocp, (x, u) -> [x[2], u[1]])
objective!(pre_ocp, :mayer, (x0, xf) -> xf[1]^2)

# Build the model
ocp = build_model(pre_ocp)
```

See also: [`CTModels.Building.build`](@ref), [`CTModels.Building.PreModel`](@ref),
[`CTModels.Models.Model`](@ref), [`CTModels.Building.time_dependence!`](@ref).
"""
function build_model(pre_ocp::PreModel; build_examodel=nothing)::Model
    return build(pre_ocp; build_examodel=build_examodel)
end

# Model accessor methods are now in src/Models/model.jl.
