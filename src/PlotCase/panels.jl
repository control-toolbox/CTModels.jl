# =============================================================================
# panels.jl — build CTBase.Plotting.Panel objects from a CTModels solution.
#
# Each group (state, costate, control, …) becomes one Panel carrying its own time
# grid (state/costate/control/path grids may differ) and the naming/seriestype
# conventions of optimal control. Sampling is done here provisionally; it will move
# to CTModels/src/Display in Phase 3d.
# =============================================================================

# Sample a callable `f` (state/control/costate accessor) over grid `T` into an
# (n_times × n_components) matrix, uniformly for scalar and vector-valued `f`.
"""
$(TYPEDSIGNATURES)

Sample a callable `f` over grid `T` into an `(n_times, n_components)` matrix.

Uniform for scalar and vector-valued `f`.
"""
_sample(f, T) = Matrix{Float64}(reduce(hcat, f.(T))')

# Insert the left and right limits at the switching times into sampled data, so that a
# jump is drawn as a vertical segment.
"""
$(TYPEDSIGNATURES)

Insert the left and right limits of `component` (`:state`, `:costate` or `:control`) at the
switching times of `sol` into the samples `(T, M)` of that component, with
[`CTBase.Plotting.splice_jumps`](@extref): a jump is drawn as a vertical segment. The samples
are returned unchanged when the solution has no switching time or the limits of
`component` are not known.

# Returns
- `(T, M)`: the time grid (with each switching time twice) and the matrix of samples.
"""
function _spliced_samples(sol, T::AbstractVector, M::AbstractMatrix, component::Symbol)
    left, right = Solutions.limits(CTModels.switching_model(sol), component)
    return Plotting.splice_jumps(T, M, CTModels.switching_times(sol), left, right)
end

# Euclidean norm of a matrix row.
"""
$(TYPEDSIGNATURES)

Return the Euclidean norm of a matrix row.
"""
_rownorm(row) = sqrt(sum(abs2, row))

# Default per-series style shared by every group; user group styles merge on top.
"""
$(TYPEDSIGNATURES)

Return the default per-series style, merged with any user-supplied group style.
"""
_base_style(style::NamedTuple) = merge((linewidth=2,), style)

# --- state / costate ---------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Build a [`CTBase.Plotting.Panel`](@extref) for the state trajectory.
"""
function _state_panel(sol, style::NamedTuple)
    Tx = CTModels.time_grid(sol, :state)
    T, M = _spliced_samples(sol, Tx, _sample(CTModels.state(sol), Tx), :state)
    return Plotting.Panel(
        T, M; title="state", labels=CTModels.state_components(sol), style=_base_style(style)
    )
end

# Costate labels follow the CTModels convention: in `:group` (a legend) they are
# `p·xᵢ`; in `:split` they label the rows, but when state is shown alongside (paired
# columns) the shared state ylabels already do that, so the costate carries none.
"""
$(TYPEDSIGNATURES)

Build a [`CTBase.Plotting.Panel`](@extref) for the costate trajectory.

Labels depend on `layout` and whether the state panel is shown alongside.
"""
function _costate_panel(sol, style::NamedTuple; layout::Symbol, state_shown::Bool)
    Tc = CTModels.time_grid(sol, :costate)
    T, M = _spliced_samples(sol, Tc, _sample(CTModels.costate(sol), Tc), :costate)
    n = size(M, 2)
    p_labels = "p" .* CTModels.state_components(sol)
    labels = (layout === :split && state_shown) ? fill("", n) : p_labels
    return Plotting.Panel(T, M; title="costate", labels=labels, style=_base_style(style))
end

# --- control -----------------------------------------------------------------

# One control cell shows `:components` (a curve per component), `:norm` (‖u‖) or, in
# `:group`, `:all` splits into two cells (components then norm); in `:split`, `:all`
# is a single column of m+1 components. Return a Vector of panels accordingly.
"""
$(TYPEDSIGNATURES)

Build one or more [`CTBase.Plotting.Panel`](@extref) objects for the control trajectory.

- `control = :components`: one panel with a curve per control component.
- `control = :norm`: one panel with the Euclidean norm of the control.
- `control = :all`: both panels (in `:group`) or a single panel with components and norm (in `:split`).

# Returns
- `Vector{Plotting.Panel}`: The panels to be assembled into the layout.
"""
function _control_panels(sol, control::Symbol, style::NamedTuple, layout::Symbol)
    Tu = CTModels.time_grid(sol, :control)
    T, U = _spliced_samples(sol, Tu, _sample(CTModels.control(sol), Tu), :control)
    u_labels = CTModels.control_components(sol)
    u_norm_label = "‖" * CTModels.control_name(sol) * "‖"
    st = CTModels.control_interpolation(sol) == :constant ? :steppost : :path
    base = _base_style(merge((seriestype=st,), style))
    _norm(U) = reshape([_rownorm(@view U[k, :]) for k in axes(U, 1)], :, 1)
    _panel(data, labels, title) =
        Plotting.Panel(T, data; title=title, labels=labels, style=base)

    if control === :components
        return [_panel(U, u_labels, "control")]
    elseif control === :norm
        # title differs by layout in the historical behaviour
        title = layout === :group ? "control norm" : "control"
        return [_panel(_norm(U), [u_norm_label], title)]
    elseif control === :all
        if layout === :group
            return [
                _panel(U, u_labels, "control"),
                _panel(_norm(U), [u_norm_label], "control norm"),
            ]
        else  # :split -> one column of m+1 components
            return [_panel(hcat(U, _norm(U)), vcat(u_labels, [u_norm_label]), "control")]
        end
    else
        throw(
            Exceptions.IncorrectArgument(
                "Invalid control choice";
                got="control=$control",
                expected=":components, :norm or :all",
                context="CTModels.PlotCase._control_panels",
            ),
        )
    end
end

# --- path constraints / duals ------------------------------------------------

# Evaluate the nonlinear path constraints g(t, x, u, v) over the path grid into an
# (n_times × nc) matrix; labels are the constraint labels carried by the model.
"""
$(TYPEDSIGNATURES)

Build a [`CTBase.Plotting.Panel`](@extref) for the nonlinear path constraints.
"""
function _path_panel(sol, model, style::NamedTuple)
    Tp = CTModels.time_grid(sol, :path)
    X, U = CTModels.state(sol).(Tp), CTModels.control(sol).(Tp)
    # at the switching times, evaluate the constraints at both limits of the state and
    # control (when both are known)
    T, MX = _spliced_samples(sol, Tp, _sample(CTModels.state(sol), Tp), :state)
    Tu, MU = _spliced_samples(sol, Tp, _sample(CTModels.control(sol), Tp), :control)
    if length(T) != length(Tp) && T == Tu
        X = [_as_value(MX[k, :]) for k in axes(MX, 1)]
        U = [_as_value(MU[k, :]) for k in axes(MU, 1)]
    else
        T = Tp
    end
    v = CTModels.variable(sol)
    cp = CTModels.path_constraints_nl(model)
    nc = length(cp[1])
    data = zeros(Float64, length(T), nc)
    g = zeros(Float64, nc)
    for k in eachindex(T)
        cp[2](g, T[k], X[k], U[k], v)
        data[k, :] .= g
    end
    labels = string.(cp[4])
    return Plotting.Panel(
        T, data; title="path constraints", labels=labels, style=_base_style(style)
    )
end

# A sampled row as the value of a trajectory: a scalar for a one-dimensional component.
"""
$(TYPEDSIGNATURES)

Return a sampled row as the value of a trajectory: a scalar for one component (the
"1-D is a scalar" convention), the vector otherwise.
"""
_as_value(row::AbstractVector) = length(row) == 1 ? row[1] : collect(row)

# Duals of the path constraints. As for the costate, the ylabels are dropped when the
# path column is shown alongside (paired), otherwise prefixed with "dual ".
"""
$(TYPEDSIGNATURES)

Build a [`CTBase.Plotting.Panel`](@extref) for the dual variables of the path constraints.
"""
function _dual_panel(sol, model, style::NamedTuple; path_shown::Bool)
    T = CTModels.time_grid(sol, :path)
    M = _sample(CTModels.path_constraints_dual(sol), T)
    nc = size(M, 2)
    cp = CTModels.path_constraints_nl(model)
    labels = path_shown ? fill("", nc) : ("dual " .* string.(cp[4]))
    return Plotting.Panel(T, M; title="dual", labels=labels, style=_base_style(style))
end
