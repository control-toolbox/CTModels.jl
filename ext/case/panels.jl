# =============================================================================
# panels.jl — build CTBase.Plotting.Panel objects from a CTModels solution.
#
# Each group (state, costate, control, …) becomes one Panel carrying its own time
# grid (state/costate/control/path grids may differ) and the naming/seriestype
# conventions of optimal control. Sampling is done here provisionally; it will move
# to CTModels/src/Display in Phase 3d.
#
# Docstrings deferred (Handbook convention).
# =============================================================================

# Sample a callable `f` (state/control/costate accessor) over grid `T` into an
# (n_times × n_components) matrix, uniformly for scalar and vector-valued `f`.
_sample(f, T) = Matrix{Float64}(reduce(hcat, f.(T))')

# Euclidean norm of a matrix row.
_rownorm(row) = sqrt(sum(abs2, row))

# Default per-series style shared by every group; user group styles merge on top.
_base_style(style::NamedTuple) = merge((linewidth=2,), style)

# --- state / costate ---------------------------------------------------------

function _state_panel(sol, style::NamedTuple)
    T = CTModels.time_grid(sol, :state)
    M = _sample(CTModels.state(sol), T)
    return Plotting.Panel(
        T, M; title="state", labels=CTModels.state_components(sol), style=_base_style(style)
    )
end

# Costate labels follow the CTModels convention: in `:group` (a legend) they are
# `p·xᵢ`; in `:split` they label the rows, but when state is shown alongside (paired
# columns) the shared state ylabels already do that, so the costate carries none.
function _costate_panel(sol, style::NamedTuple; layout::Symbol, state_shown::Bool)
    T = CTModels.time_grid(sol, :costate)
    M = _sample(CTModels.costate(sol), T)
    n = size(M, 2)
    p_labels = "p" .* CTModels.state_components(sol)
    labels = (layout === :split && state_shown) ? fill("", n) : p_labels
    return Plotting.Panel(T, M; title="costate", labels=labels, style=_base_style(style))
end

# --- control -----------------------------------------------------------------

# One control cell shows `:components` (a curve per component), `:norm` (‖u‖) or, in
# `:group`, `:all` splits into two cells (components then norm); in `:split`, `:all`
# is a single column of m+1 components. Return a Vector of panels accordingly.
function _control_panels(sol, control::Symbol, style::NamedTuple, layout::Symbol)
    T = CTModels.time_grid(sol, :control)
    U = _sample(CTModels.control(sol), T)
    u_labels = CTModels.control_components(sol)
    u_norm_label = "‖" * CTModels.control_name(sol) * "‖"
    st = CTModels.control_interpolation(sol) == :constant ? :steppost : :path
    base = _base_style(merge((seriestype=st,), style))
    _norm(U) = reshape([_rownorm(@view U[k, :]) for k in axes(U, 1)], :, 1)
    _panel(data, labels, title) = Plotting.Panel(
        T, data; title=title, labels=labels, style=base
    )

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
                context="CTModelsPlots._control_panels",
            ),
        )
    end
end

# --- path constraints / duals ------------------------------------------------

# Evaluate the nonlinear path constraints g(t, x, u, v) over the path grid into an
# (n_times × nc) matrix; labels are the constraint labels carried by the model.
function _path_panel(sol, model, style::NamedTuple)
    T = CTModels.time_grid(sol, :path)
    X = CTModels.state(sol).(T)
    U = CTModels.control(sol).(T)
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

# Duals of the path constraints. As for the costate, the ylabels are dropped when the
# path column is shown alongside (paired), otherwise prefixed with "dual ".
function _dual_panel(sol, model, style::NamedTuple; path_shown::Bool)
    T = CTModels.time_grid(sol, :path)
    M = _sample(CTModels.path_constraints_dual(sol), T)
    nc = size(M, 2)
    cp = CTModels.path_constraints_nl(model)
    labels = path_shown ? fill("", nc) : ("dual " .* string.(cp[4]))
    return Plotting.Panel(T, M; title="dual", labels=labels, style=_base_style(style))
end
