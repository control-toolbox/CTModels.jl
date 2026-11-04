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

Insert the left and right limits of `component` (`:state`, `:costate`, `:control` or
`:path_dual`) at the switching times of `sol` into the samples `(T, M)` of that component, with
[`CTBase.Plotting.splice_jumps`](@extref): a jump is drawn as a vertical segment. The samples
are returned unchanged when the solution has no switching time or the limits of
`component` are not known. With `connect = false`, the curve is broken between the two
limits instead of drawing the vertical segment. With `cols`, `M` holds only those columns
of `component`, and only their limits are used.

A limit may be unknown for some columns only (`NaN`: the limits of the duals given by label,
for a label whose limits were not given). Such a limit is replaced by the value of the
samples at the switching time (see [`CTModels.PlotCase._fill_unknown_limits`](@extref)), so
that no jump is drawn for that column, instead of a break in the curve.

# Returns
- `(T, M)`: the time grid (with each switching time twice) and the matrix of samples.
"""
function _spliced_samples(
    sol,
    T::AbstractVector,
    M::AbstractMatrix,
    component::Symbol;
    connect::Bool=true,
    cols::Union{Nothing,AbstractVector{Int}}=nothing,
)
    left, right = Solutions.limits(CTModels.switching_model(sol), component)
    if !isnothing(cols) && size(left, 2) > 0
        left, right = left[:, cols], right[:, cols]
    end
    times = CTModels.switching_times(sol)
    # piecewise-constant samples: a control, or a control-box dual, with a constant control
    constant =
        component in (:control, :control_dual) &&
        CTModels.control_interpolation(sol) === :constant
    left = _fill_unknown_limits(T, M, times, left; constant=constant)
    right = _fill_unknown_limits(T, M, times, right; constant=constant)
    return Plotting.splice_jumps(T, M, times, left, right; connect=connect)
end

"""
$(TYPEDSIGNATURES)

The limits `L` (one row per switching time in `times`, one column per column of the samples
`(T, M)`) with each `NaN` entry replaced by the value of the samples at that switching time
(see [`CTModels.PlotCase._sample_at`](@extref)): linearly interpolated between the two
samples around it, or, for piecewise-constant samples (`constant = true`), the sample that
holds on the interval. Returns `L` itself when it has no `NaN`, or when its shape does not
match the samples (left to [`CTBase.Plotting.splice_jumps`](@extref) to report).
"""
function _fill_unknown_limits(
    T::AbstractVector,
    M::AbstractMatrix,
    times::AbstractVector,
    L::AbstractMatrix;
    constant::Bool=false,
)
    any(isnan, L) || return L
    size(L) == (length(times), size(M, 2)) || return L
    filled = Matrix{Float64}(L)
    for i in axes(filled, 1), j in axes(filled, 2)
        isnan(filled[i, j]) &&
            (filled[i, j] = _sample_at(T, view(M, :, j), times[i]; constant=constant))
    end
    return filled
end

"""
$(TYPEDSIGNATURES)

The value at time `τ` of the samples `y` on the grid `T`: linear interpolation between the
two samples around `τ`, or, with `constant = true` (piecewise-constant samples, drawn as
steps), the last sample at or before `τ`; the first or last sample outside the grid.
"""
function _sample_at(
    T::AbstractVector, y::AbstractVector, τ::Real; constant::Bool=false
)::Float64
    n = min(length(T), length(y))
    k = searchsortedlast(view(T, 1:n), τ)
    k == 0 && return y[1]
    k >= n && return y[n]
    (constant || T[k] == τ) && return y[k]
    w = (τ - T[k]) / (T[k + 1] - T[k])
    return (1 - w) * y[k] + w * y[k + 1]
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
function _state_panel(sol, style::NamedTuple; connect::Bool=true)
    Tx = CTModels.time_grid(sol, :state)
    T, M = _spliced_samples(
        sol, Tx, _sample(CTModels.state(sol), Tx), :state; connect=connect
    )
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
function _costate_panel(
    sol, style::NamedTuple; layout::Symbol, state_shown::Bool, connect::Bool=true
)
    Tc = CTModels.time_grid(sol, :costate)
    T, M = _spliced_samples(
        sol, Tc, _sample(CTModels.costate(sol), Tc), :costate; connect=connect
    )
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
function _control_panels(
    sol, control::Symbol, style::NamedTuple, layout::Symbol; connect::Bool=true
)
    Tu = CTModels.time_grid(sol, :control)
    T, U = _spliced_samples(
        sol, Tu, _sample(CTModels.control(sol), Tu), :control; connect=connect
    )
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
# (n_times × nc) matrix, once for the whole figure; each constraint row takes its columns.
"""
$(TYPEDSIGNATURES)

The samples of the nonlinear path constraints of `model` along `sol`, for every row of the
stacked constraint: `(T, data, left, right)`, with `T` the path grid, `data` the `length(T) ×
nc` matrix of values, and `left`, `right` the values at the left and right limits of the
state and control at the switching times (one row per switching time), or `nothing` when
those limits are not known. Computed once per figure, then sliced per constraint row (see
[`CTModels.PlotCase._path_panel`](@extref)).
"""
function _path_samples(sol, model)
    Tp = CTModels.time_grid(sol, :path)
    v = CTModels.variable(sol)
    cp = CTModels.path_constraints_nl(model)
    nc = length(cp[1])
    g = zeros(Float64, nc)
    constraint(t, x, u) = (cp[2](g, t, x, u, v); copy(g))
    x, u = CTModels.state(sol), CTModels.control(sol)
    data = zeros(Float64, length(Tp), nc)
    for k in eachindex(Tp)
        data[k, :] .= constraint(Tp[k], x(Tp[k]), u(Tp[k]))
    end
    # at the switching times, the constraints at both limits of the state and control
    # (when both are known)
    taus = CTModels.switching_times(sol)
    sw = CTModels.switching_model(sol)
    (xl, xr), (ul, ur) = Solutions.limits(sw, :state), Solutions.limits(sw, :control)
    if isempty(taus) || size(xl, 2) == 0 || size(ul, 2) == 0
        return (Tp, data, nothing, nothing)
    end
    at(X, U) = permutedims(
        reduce(
            hcat,
            (
                constraint(taus[i], _as_value(X[i, :]), _as_value(U[i, :])) for
                i in eachindex(taus)
            ),
        ),
    )
    return (Tp, data, at(xl, ul), at(xr, ur))
end

"""
$(TYPEDSIGNATURES)

Build a [`CTBase.Plotting.Panel`](@extref) for the nonlinear path constraints: all of them,
or the rows `rows` (those of one label). `samples` are the values of the constraints (see
[`CTModels.PlotCase._path_samples`](@extref)), computed here when not given.
"""
function _path_panel(
    sol,
    model,
    style::NamedTuple;
    connect::Bool=true,
    rows::Union{Nothing,AbstractVector{Int}}=nothing,
    title::String="path constraints",
    samples=_path_samples(sol, model),
)
    Tp, data, left, right = samples
    cp = CTModels.path_constraints_nl(model)
    idx = isnothing(rows) ? collect(axes(data, 2)) : collect(rows)
    T, M = Tp, data[:, idx]
    if !isnothing(left)
        T, M = Plotting.splice_jumps(
            Tp,
            M,
            CTModels.switching_times(sol),
            left[:, idx],
            right[:, idx];
            connect=connect,
        )
    end
    labels = string.(cp[4][idx])
    return Plotting.Panel(T, M; title=title, labels=labels, style=_base_style(style))
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

Build a [`CTBase.Plotting.Panel`](@extref) for the dual variables of the path constraints:
all of them, or the rows `rows` (those of one label). `samples` are the duals sampled on
the path grid, computed here when not given. At a switching time whose dual limits are
known, the jump is drawn as for the state (see
[`CTModels.PlotCase._spliced_samples`](@extref)).
"""
function _dual_panel(
    sol,
    model,
    style::NamedTuple;
    path_shown::Bool,
    connect::Bool=true,
    rows::Union{Nothing,AbstractVector{Int}}=nothing,
    title::String="dual",
    samples=nothing,
)
    Tp = CTModels.time_grid(sol, :path)
    # the samples of every row, computed once per figure when given (see `_build_root`)
    M = isnothing(samples) ? _sample(CTModels.path_constraints_dual(sol), Tp) : samples
    cp = CTModels.path_constraints_nl(model)
    idx = isnothing(rows) ? collect(axes(M, 2)) : collect(rows)
    T, M = _spliced_samples(
        sol,
        Tp,
        M[:, idx],
        :path_dual;
        connect=connect,
        cols=isnothing(rows) ? nothing : idx,
    )
    labels = path_shown ? fill("", length(idx)) : ("dual " .* string.(cp[4][idx]))
    return Plotting.Panel(T, M; title=title, labels=labels, style=_base_style(style))
end
