"""
$(TYPEDSIGNATURES)

Append box constraint data to the provided flat vectors.

This is an internal helper used by `build(::ConstraintsDictType)`. It simply
accumulates declarations. Deduplication (one entry per component with
intersection semantics) and associated warnings are handled later by
`_dedup_box_constraints!`.

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
- No deduplication or warning emitted here; see `_dedup_box_constraints!`.
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
`IncorrectArgument` is thrown.

# Arguments
- `inds`, `lbs`, `ubs`, `labels`: in-place flat vectors produced by successive
  calls to [`append_box_constraints!`](@ref).
- `aliases`: in-place empty `Vector{Vector{Symbol}}` to be populated with the
  per-component list of all declaring labels.
- `kind::String`: human-readable descriptor (e.g. "state", "control",
  "variable") used in diagnostic messages.

# Throws
- `Exceptions.IncorrectArgument` if the intersection of declared bounds is
  empty for some component.
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
            @ensure lb_eff <= ub_eff Exceptions.IncorrectArgument(
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
    resize!(inds, length(new_inds)); inds .= new_inds[perm]
    resize!(lbs, length(new_lbs)); lbs .= new_lbs[perm]
    resize!(ubs, length(new_ubs)); ubs .= new_ubs[perm]
    resize!(labels, length(new_labels)); labels .= new_labels[perm]
    empty!(aliases)
    append!(aliases, new_aliases[perm])
    return nothing
end

"""
$(TYPEDSIGNATURES)

Constructs a `ConstraintsModel` from a dictionary of constraints.

This function processes a dictionary where each entry defines a constraint with its type, function or index range, lower and upper bounds, and label. It categorizes constraints into path, boundary, state, control, and variable constraints, assembling them into a structured `ConstraintsModel`.

# Arguments
- `constraints::ConstraintsDictType`: A dictionary mapping constraint labels to tuples of the form `(type, function_or_range, lower_bound, upper_bound)`.

# Returns
- `ConstraintsModel`: A structured model encapsulating all provided constraints.

# Example
```julia-repl
julia> constraints = OrderedDict(
    :c1 => (:path, f1, [0.0], [1.0]),
    :c2 => (:state, 1:2, [-1.0, -1.0], [1.0, 1.0])
)
julia> model = build(constraints)
```
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
        let
            # Create local copies of the inputs to capture them safely
            cn = constraints_number
            cd = constraints_dimensions
            cf = constraints_functions

            function path_cons_nl!(val, t, x, u, v)
                j = 1
                for i in 1:cn
                    li = cd[i]
                    cf[i](@view(val[j:(j + li - 1)]), t, x, u, v)
                    j += li
                end
                return nothing
            end

            return path_cons_nl!
        end
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
        let cfs = constraints_functions
            function boundary_cons_nl!(val, x0, xf, v)
                j = 1
                for i in 1:constraints_number
                    li = constraints_dimensions[i]
                    cfs[i](@view(val[j:(j + li - 1)]), x0, xf, v)
                    j += li
                end
                return nothing
            end
            return boundary_cons_nl!
        end
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

Converts a mutable `PreModel` into an immutable `Model`.

This function finalizes a pre-defined optimal control problem (`PreModel`) by verifying that all
necessary components (times, state, dynamics, objective) are set. It then constructs a `Model`
instance, incorporating optional components like control, variable, and constraints.

!!! note
    Control is **optional**: calling `control!` is not required. When omitted, the model is
    built with `control_dimension == 0` (an `EmptyControlModel`). This is useful for problems
    where the dynamics depend only on the state, such as pure state-space systems.

# Arguments
- `pre_ocp::PreModel`: The pre-defined optimal control problem to be finalized.

# Returns
- `Model`: A fully constructed model ready for solving.

# Example without control
```julia-repl
julia> pre_ocp = PreModel()
julia> times!(pre_ocp, 0.0, 1.0, 100)
julia> state!(pre_ocp, 2, "x", ["x1", "x2"])
julia> dynamics!(pre_ocp, (t, x, u) -> [-x[2], x[1]])
julia> objective!(pre_ocp, :min, mayer=(x0, xf) -> xf[1]^2)
julia> model = build(pre_ocp)
julia> control_dimension(model)  # 0
```

# Example with control
```julia-repl
julia> pre_ocp = PreModel()
julia> times!(pre_ocp, 0.0, 1.0, 100)
julia> state!(pre_ocp, 2, "x", ["x1", "x2"])
julia> control!(pre_ocp, 1, "u", ["u1"])
julia> dynamics!(pre_ocp, (dx, t, x, u, v) -> dx .= x + u)
julia> model = build(pre_ocp)
```
"""
function build(pre_ocp::PreModel; build_examodel=nothing)::Model
    @ensure __is_times_set(pre_ocp) Exceptions.PreconditionError(
        "Times must be set before building model",
        reason="time horizon has not been defined yet",
        suggestion="Call times!(pre_ocp, t0, tf) or times!(pre_ocp, N) before building",
        context="build function - times validation",
    )
    @ensure __is_state_set(pre_ocp) Exceptions.PreconditionError(
        "State must be set before building model",
        reason="state has not been defined yet",
        suggestion="Call state!(pre_ocp, dimension) before building",
        context="build function - state validation",
    )
    @ensure __is_dynamics_set(pre_ocp) Exceptions.PreconditionError(
        "Dynamics must be set before building model",
        reason="dynamics have not been defined yet",
        suggestion="Call dynamics!(pre_ocp, f) or partial_dynamics! before building",
        context="build function - dynamics validation",
    )
    @ensure __is_dynamics_complete(pre_ocp) Exceptions.PreconditionError(
        "Dynamics must be complete before building model",
        reason="not all state components are covered by dynamics",
        suggestion="Complete dynamics definition with partial_dynamics! or use full dynamics!",
        context="build function - dynamics completeness validation",
    )
    @ensure __is_objective_set(pre_ocp) Exceptions.PreconditionError(
        "Objective must be set before building model",
        reason="objective has not been defined yet",
        suggestion="Call objective!(pre_ocp, ...) before building",
        context="build function - objective validation",
    )
    @ensure __is_autonomous_set(pre_ocp) Exceptions.PreconditionError(
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
    TD = is_autonomous(pre_ocp) ? Autonomous : NonAutonomous

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

This function is an alias for `build(pre_ocp; build_examodel=build_examodel)` and constructs
a fully validated `Model` from a `PreModel` by extracting and organizing all components
(times, state, control, variable, dynamics, objective, constraints).

# Arguments
- `pre_ocp::PreModel`: The pre-model containing all problem components
- `build_examodel=nothing`: Optional ExaModel builder function for GPU acceleration

# Returns
- `Model`: A complete, validated optimal control problem model

# Throws
- `Exceptions.PreconditionError`: If time dependence has not been set via `time_dependence!`

# Example
```julia
using CTModels

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

See also: `build`, `PreModel`, `Model`, `time_dependence!`
"""
function build_model(pre_ocp::PreModel; build_examodel=nothing)::Model
    return build(pre_ocp; build_examodel=build_examodel)
end

# ------------------------------------------------------------------------------ #
# Getters
# ------------------------------------------------------------------------------ #

# time dependence
"""
$(TYPEDSIGNATURES)

Return `true` for an autonomous model.
"""
function is_autonomous(
    ::Model{
        Autonomous,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)
    return true
end

"""
$(TYPEDSIGNATURES)

Return `false` for a non-autonomous model.
"""
function is_autonomous(
    ::Model{
        NonAutonomous,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)
    return false
end

"""
$(TYPEDSIGNATURES)

Check whether the problem has optimisation variables.
"""
function is_variable(ocp::Model)::Bool
    return variable_dimension(ocp) > 0
end

"""
$(TYPEDSIGNATURES)

Check whether the problem is control-free (no control input).
"""
function is_control_free(ocp::Model)::Bool
    return control_dimension(ocp) == 0
end

# State
"""
$(TYPEDSIGNATURES)

Return the state struct.
"""
function state(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        T,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:AbstractStateModel}
    return ocp.state
end

"""
$(TYPEDSIGNATURES)

Return the name of the state.
"""
function state_name(ocp::Model)::String
    return name(state(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the state.
"""
function state_components(ocp::Model)::Vector{String}
    return components(state(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the state dimension.
"""
function state_dimension(ocp::Model)::Dimension
    return dimension(state(ocp))
end

# Control
"""
$(TYPEDSIGNATURES)

Return the control struct.
"""
function control(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        T,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:AbstractControlModel}
    return ocp.control
end

"""
$(TYPEDSIGNATURES)

Return the name of the control.
"""
function control_name(ocp::Model)::String
    return name(control(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the control.
"""
function control_components(ocp::Model)::Vector{String}
    return components(control(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the control dimension.
"""
function control_dimension(ocp::Model)::Dimension
    return dimension(control(ocp))
end

# Variable 
"""
$(TYPEDSIGNATURES)

Return the variable struct.
"""
function variable(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        T,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:AbstractVariableModel}
    return ocp.variable
end

"""
$(TYPEDSIGNATURES)

Return the name of the variable.
"""
function variable_name(ocp::Model)::String
    return name(variable(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the names of the components of the variable.
"""
function variable_components(ocp::Model)::Vector{String}
    return components(variable(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the variable dimension.
"""
function variable_dimension(ocp::Model)::Dimension
    return dimension(variable(ocp))
end

# Times
"""
$(TYPEDSIGNATURES)

Return the times struct.
"""
function times(
    ocp::Model{
        <:TimeDependence,
        T,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:TimesModel}
    return ocp.times
end

# Time name
"""
$(TYPEDSIGNATURES)

Return the name of the time.
"""
function time_name(ocp::Model)::String
    return time_name(times(ocp))
end

# Initial time
"""
$(TYPEDSIGNATURES)

Throw an error for unsupported initial time access.
"""
function initial_time(ocp::AbstractModel)
    throw(
        Exceptions.PreconditionError(
            "Cannot get initial time with this function";
            reason="This model type does not support direct initial time access",
            suggestion="Use initial_time(ocp) on a Model with FixedTimeModel or use initial_time(ocp, variable) for variable initial time",
            context="initial_time on AbstractModel",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Throw an error for unsupported initial time access with variable.
"""
function initial_time(ocp::AbstractModel, variable::AbstractVector)
    throw(
        Exceptions.PreconditionError(
            "Cannot get initial time with this function";
            reason="This model type does not support initial time access with variable",
            suggestion="Ensure the model has variable initial time configured, or use initial_time(ocp) for fixed initial time",
            context="initial_time with variable on AbstractModel",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the initial time, for a fixed initial time.
"""
function initial_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{FixedTimeModel{T},<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:Time}
    return initial_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the initial time, for a free initial time.
"""
function initial_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{FreeTimeModel,<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
    variable::AbstractVector{T},
)::T where {T<:ctNumber}
    return initial_time(times(ocp), variable)
end

"""
$(TYPEDSIGNATURES)

Return the initial time, for a free initial time.
"""
function initial_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{FreeTimeModel,<:AbstractTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
    variable::T,
)::T where {T<:ctNumber}
    return initial_time(times(ocp), [variable])
end

"""
$(TYPEDSIGNATURES)

Return the name of the initial time.
"""
function initial_time_name(ocp::Model)::String
    return initial_time_name(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is fixed.
"""
function has_fixed_initial_time(ocp::Model)::Bool
    return has_fixed_initial_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is free.
"""
function has_free_initial_time(ocp::Model)::Bool
    return has_free_initial_time(times(ocp))
end

# Final time
"""
$(TYPEDSIGNATURES)

Throw an error for unsupported final time access.
"""
function final_time(ocp::AbstractModel)
    throw(
        Exceptions.PreconditionError(
            "Cannot get final time with this function";
            reason="This model type does not support direct final time access",
            suggestion="Use final_time(ocp) on a Model with FixedTimeModel or use final_time(ocp, variable) for variable final time",
            context="final_time on AbstractModel",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Throw an error for unsupported final time access with variable.
"""
function final_time(ocp::AbstractModel, variable::AbstractVector)
    throw(
        Exceptions.PreconditionError(
            "Cannot get final time with this function";
            reason="This model type does not support final time access with variable",
            suggestion="Ensure the model has variable final time configured, or use final_time(ocp) for fixed final time",
            context="final_time with variable on AbstractModel",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the final time, for a fixed final time.
"""
function final_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{<:AbstractTimeModel,FixedTimeModel{T}},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::T where {T<:Time}
    return final_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the final time, for a free final time.
"""
function final_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{<:AbstractTimeModel,FreeTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
    variable::AbstractVector{T},
)::T where {T<:ctNumber}
    return final_time(times(ocp), variable)
end

"""
$(TYPEDSIGNATURES)

Return the final time, for a free final time.
"""
function final_time(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel{<:AbstractTimeModel,FreeTimeModel},
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
    variable::T,
)::T where {T<:ctNumber}
    return final_time(times(ocp), [variable])
end

"""
$(TYPEDSIGNATURES)

Return the name of the final time.
"""
function final_time_name(ocp::Model)::String
    return final_time_name(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the final time is fixed.
"""
function has_fixed_final_time(ocp::Model)::Bool
    return has_fixed_final_time(times(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the final time is free.
"""
function has_free_final_time(ocp::Model)::Bool
    return has_free_final_time(times(ocp))
end

# Objective
"""
$(TYPEDSIGNATURES)

Return the objective struct.
"""
function objective(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        O,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::O where {O<:AbstractObjectiveModel}
    return ocp.objective
end

"""
$(TYPEDSIGNATURES)

Return the type of criterion (:min or :max).
"""
function criterion(ocp::Model)::Symbol
    return criterion(objective(ocp))
end

# Mayer
"""
$(TYPEDSIGNATURES)

Throw an error when accessing Mayer cost on a model without one.
"""
function mayer(ocp::AbstractModel)
    throw(
        Exceptions.PreconditionError(
            "Cannot access Mayer cost";
            reason="This OCP has no Mayer objective defined",
            suggestion="Define a Mayer objective using objective!(ocp, :min/:max, mayer=...) before accessing it",
            context="mayer accessor",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the Mayer cost.
"""
function mayer(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:MayerObjectiveModel{M},
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::M where {M<:Function}
    return mayer(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the Mayer cost.
"""
function mayer(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:BolzaObjectiveModel{M,<:Function},
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::M where {M<:Function}
    return mayer(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the model has a Mayer cost.
"""
function has_mayer_cost(ocp::Model)::Bool
    return has_mayer_cost(objective(ocp))
end

# Lagrange
"""
$(TYPEDSIGNATURES)

Throw an error when accessing Lagrange cost on a model without one.
"""
function lagrange(ocp::AbstractModel)
    throw(
        Exceptions.PreconditionError(
            "Cannot access Lagrange cost";
            reason="This OCP has no Lagrange objective defined",
            suggestion="Define a Lagrange objective using objective!(ocp, :min/:max, lagrange=...) before accessing it",
            context="lagrange accessor",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange cost.
"""
function lagrange(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        LagrangeObjectiveModel{L},
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::L where {L<:Function}
    return lagrange(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange cost.
"""
function lagrange(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:BolzaObjectiveModel{<:Function,L},
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::L where {L<:Function}
    return lagrange(objective(ocp))
end

"""
$(TYPEDSIGNATURES)

Check if the model has a Lagrange cost.
"""
function has_lagrange_cost(ocp::Model)::Bool
    return has_lagrange_cost(objective(ocp))
end

# Dynamics
"""
$(TYPEDSIGNATURES)

Return the dynamics.
"""
function dynamics(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        D,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::D where {D<:Function}
    return ocp.dynamics
end

# build_examodel
"""
$(TYPEDSIGNATURES)

Return the build_examodel.
"""
function get_build_examodel(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        BE,
    },
)::BE where {BE<:Function}
    return ocp.build_examodel
end

"""
$(TYPEDSIGNATURES)

Return an error (PreconditionError) since the model is not built with the :exa backend.
"""
function get_build_examodel(
    ::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:AbstractConstraintsModel,
        <:AbstractDefinition,
        <:Nothing,
    },
)
    throw(
        Exceptions.PreconditionError(
            "Cannot access dynamics";
            reason="Model must be parsed with :exa backend first",
            suggestion="Parse the OCP with backend=:exa before accessing dynamics",
            context="dynamics accessor on unparsed model",
        ),
    )
end

# Constraints
"""
$(TYPEDSIGNATURES)

Return the constraints struct.
"""
function constraints(
    ocp::Model{
        <:TimeDependence,
        <:AbstractTimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        C,
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::C where {C<:AbstractConstraintsModel}
    return ocp.constraints
end

"""
$(TYPEDSIGNATURES)

Return true if the model has constraints or false if not.
"""
function isempty_constraints(ocp::Model)::Bool
    return Base.isempty(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the nonlinear path constraints.
"""
function path_constraints_nl(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{TP,<:Tuple,<:Tuple,<:Tuple,<:Tuple},
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::TP where {TP<:Tuple}
    return constraints(ocp).path_nl
end

"""
$(TYPEDSIGNATURES)

Return the nonlinear boundary constraints.
"""
function boundary_constraints_nl(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,TB,<:Tuple,<:Tuple,<:Tuple},
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::TB where {TB<:Tuple}
    return constraints(ocp).boundary_nl
end

"""
$(TYPEDSIGNATURES)

Return the box constraints on state.
"""
function state_constraints_box(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,<:Tuple,TS,<:Tuple,<:Tuple},
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::TS where {TS<:Tuple}
    return constraints(ocp).state_box
end

"""
$(TYPEDSIGNATURES)

Return the box constraints on control.
"""
function control_constraints_box(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,TC,<:Tuple},
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::TC where {TC<:Tuple}
    return constraints(ocp).control_box
end

"""
$(TYPEDSIGNATURES)

Return the box constraints on variable.
"""
function variable_constraints_box(
    ocp::Model{
        <:TimeDependence,
        <:TimesModel,
        <:AbstractStateModel,
        <:AbstractControlModel,
        <:AbstractVariableModel,
        <:Function,
        <:AbstractObjectiveModel,
        <:ConstraintsModel{<:Tuple,<:Tuple,<:Tuple,<:Tuple,TV},
        <:AbstractDefinition,
        <:Union{Function,Nothing},
    },
)::TV where {TV<:Tuple}
    return constraints(ocp).variable_box
end

"""
$(TYPEDSIGNATURES)

Return the dimension of nonlinear path constraints.
"""
function dim_path_constraints_nl(ocp::Model)::Dimension
    return dim_path_constraints_nl(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the dimension of the boundary constraints.
"""
function dim_boundary_constraints_nl(ocp::Model)::Dimension
    return dim_boundary_constraints_nl(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on state.
"""
function dim_state_constraints_box(ocp::Model)::Dimension
    return dim_state_constraints_box(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on control.
"""
function dim_control_constraints_box(ocp::Model)::Dimension
    return dim_control_constraints_box(constraints(ocp))
end

"""
$(TYPEDSIGNATURES)

Return the dimension of box constraints on variable.
"""
function dim_variable_constraints_box(ocp::Model)::Dimension
    return dim_variable_constraints_box(constraints(ocp))
end
