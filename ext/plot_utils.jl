"""
$(TYPEDSIGNATURES)

Clean and standardize the `description` tuple for plot selection.

# Behavior
- Converts plural forms (`:states`, `:costates`, etc.) to their singular equivalents.
- Maps ambiguous terms (`:constraint`, `:constraints`, `:cons`) to `:path`.
- Removes duplicate symbols.

# Arguments
- `description`: A tuple of symbols passed by the user, typically from plot arguments.

# Returns
- A cleaned `Tuple{Symbol...}` of unique, standardized symbols.

# Example
```julia-repl
julia> clean((:states, :controls, :costate, :constraint, :duals))
# → (:state, :control, :costate, :path, :dual)
```
"""
function clean(description)
    # remove the nouns in plural form
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
    # remove the duplicates
    return tuple(Set(description)...)
end

"""
$(TYPEDSIGNATURES)

Determine which components should be plotted based on the `description` and style settings.

# Arguments
- `sol`: The optimal control solution.
- `description`: A cleaned tuple of plot description symbols (`:state`, `:costate`, `:control`, `:path`, `:dual`).

# Keyword Arguments
- `*_style`: The plotting style (a `NamedTuple` or `:none`). If a style is `:none`, that component is skipped.

# Returns
- A 5-tuple of booleans:
  `(do_plot_state, do_plot_costate, do_plot_control, do_plot_path, do_plot_dual)`

# Notes
- Duals are only plotted if `sol` contains path constraint dual variables.
- A style must not be `:none` for the component to be included.

# Example
```julia-repl
julia> do_plot(sol, :state, :control, :path; state_style=NamedTuple(), control_style=:none, path_style=NamedTuple(), ...)
# → (true, false, false, true, false)
```
"""
function do_plot(
    sol::CTModels.Solution,
    description::Symbol...;
    state_style::Union{NamedTuple,Symbol},
    control_style::Union{NamedTuple,Symbol},
    costate_style::Union{NamedTuple,Symbol},
    path_style::Union{NamedTuple,Symbol},
    dual_style::Union{NamedTuple,Symbol},
)
    do_plot_state = :state ∈ description && state_style != :none
    do_plot_costate = :costate ∈ description && costate_style != :none
    do_plot_control = :control ∈ description && control_style != :none
    do_plot_path = :path ∈ description && path_style != :none
    do_plot_dual = :dual ∈ description && dual_style != :none && !isnothing(CTModels.path_constraints_dual(sol))

    return (do_plot_state, do_plot_costate, do_plot_control, do_plot_path, do_plot_dual)
end

"""
$(TYPEDSIGNATURES)

Determine whether to decorate plots with bounds or time annotations.

# Keyword Arguments
- `model`: The associated OCP model. If `nothing`, decorations are skipped.
- `time_style`: Style used for vertical lines marking initial/final time.
- `state_bounds_style`: Style for state bounds lines.
- `control_bounds_style`: Style for control bounds lines.
- `path_bounds_style`: Style for path constraint bounds.

# Returns
- A 4-tuple of booleans:
  `(do_decorate_time, do_decorate_state_bounds, do_decorate_control_bounds, do_decorate_path_bounds)`

# Notes
Each decoration is applied only if:
- A non-`:none` style is provided, and
- A model is available (not `nothing`).

# Example
```julia-repl
julia> do_decorate(model=my_model, time_style=NamedTuple(), state_bounds_style=:none, ...)
# → (true, false, ...)
```
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
