# =============================================================================
# vocabulary.jl — case-layer vocabulary and gating for CTModels solutions.
#
# What to plot (`clean`, `__description`, `do_plot`) and what to decorate
# (`do_decorate`), plus the user-facing defaults. No geometry, no Plots: the
# layout/rendering all lives in `CTBase.Plotting`.
#
# Docstrings deferred (Handbook convention).
# =============================================================================

# --- defaults ----------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Return the default plot layout (`:split`).
"""
__plot_layout() = :split

"""
$(TYPEDSIGNATURES)

Return the default control representation (`:components`).
"""
__control_layout() = :components

"""
$(TYPEDSIGNATURES)

Return the default time-axis normalization (`:default`).
"""
__time_normalization() = :default

"""
$(TYPEDSIGNATURES)

Return the default plotting style (empty `NamedTuple`).
"""
__plot_style() = NamedTuple()

"""
$(TYPEDSIGNATURES)

Return the default suffix appended to plot labels (empty string).
"""
__plot_label_suffix() = ""

# Default description when the user gives none: everything (aliases included, so
# `clean` collapses them to the canonical set).
"""
$(TYPEDSIGNATURES)

Return the default description tuple used when the user gives none.

Aliases are included so that [`clean`](@ref) collapses them to the canonical set.
"""
function __description()
    return (
        :state,
        :states,
        :costate,
        :costates,
        :control,
        :controls,
        :constraint,
        :constraints,
        :cons,
        :path,
        :dual,
        :duals,
    )
end

# Collapse plural/alias forms to the canonical singular symbols and drop
# duplicates: (:states, :controls, :cons, :duals) -> (:state, :control, :path, :dual).
"""
$(TYPEDSIGNATURES)

Collapse plural/alias forms to canonical singular symbols and drop duplicates.

For example, `(:states, :controls, :cons, :duals)` becomes `(:state, :control, :path, :dual)`.

# Arguments
- `description`: A tuple of symbols from the caller.

# Returns
- `Tuple{Symbol...}`: Cleaned, unique, canonical symbols.
"""
function clean(description)
    description = replace(
        description,
        :states => :state,
        :costates => :costate,
        :controls => :control,
        :constraints => :path,
        :constraint => :path,
        :cons => :path,
        :duals => :dual,
    )
    return tuple(Set(description)...)
end

# Which signal groups to draw. A group is drawn when it is requested, its style is
# not `:none`, and it actually exists in the solution (control needs m > 0, path
# needs constraints, dual needs the multipliers to be present).
"""
$(TYPEDSIGNATURES)

Decide which signal groups to draw for the given solution and description.

A group is drawn when it is requested, its style is not `:none`, and it actually exists in the solution:
- control needs `control_dimension(sol) > 0`,
- path needs `dim_path_constraints_nl(ocp) > 0`,
- dual needs `path_constraints_dual(sol)` to be present.

# Returns
- `NTuple{5, Bool}`: flags for `(state, costate, control, path, dual)`.
"""
function do_plot(
    sol::CTModels.AbstractSolution,
    description::Symbol...;
    state_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    path_style::Union{NamedTuple,Symbol},
    dual_style::Union{NamedTuple,Symbol},
)
    do_plot_state = :state ∈ description && state_style != :none
    do_plot_costate = :costate ∈ description && costate_style != :none
    do_plot_control =
        :control ∈ description &&
        control_style != :none &&
        CTModels.control_dimension(sol) > 0
    ocp = CTModels.model(sol)
    do_plot_path =
        :path ∈ description &&
        path_style != :none &&
        CTModels.dim_path_constraints_nl(ocp) > 0
    do_plot_dual =
        :dual ∈ description &&
        dual_style != :none &&
        !isnothing(CTModels.path_constraints_dual(sol))

    return (do_plot_state, do_plot_costate, do_plot_control, do_plot_path, do_plot_dual)
end

# Which decorations to draw (bounds lines, initial/final time lines). Each needs a
# non-`:none` style and a model to read the bounds/times from.
"""
$(TYPEDSIGNATURES)

Decide which decorations to draw (bounds lines and initial/final time lines).

Each decoration needs a non-`:none` style and a model to read the bounds/times from.

# Returns
- `NTuple{4, Bool}`: flags for `(time, state_bounds, control_bounds, path_bounds)`.
"""
function do_decorate(;
    model::Union{CTModels.Model,Nothing},
    time_style::Union{NamedTuple,Symbol},
    state_bounds_style::Union{NamedTuple,Symbol},
    control_bounds_style::Union{NamedTuple,Symbol},
    path_bounds_style::Union{NamedTuple,Symbol},
)
    do_decorate_time = time_style != :none && model !== nothing
    do_decorate_state_bounds = state_bounds_style != :none && model !== nothing
    do_decorate_control_bounds = control_bounds_style != :none && model !== nothing
    do_decorate_path_bounds = path_bounds_style != :none && model !== nothing
    return (
        do_decorate_time,
        do_decorate_state_bounds,
        do_decorate_control_bounds,
        do_decorate_path_bounds,
    )
end
