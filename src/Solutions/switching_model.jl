# ------------------------------------------------------------------------------ #
# Switching structure of a solution
# ------------------------------------------------------------------------------ #
#
# An indirect method fixes the structure of the solution: the switching times, the jumps
# of the state or costate, the changes of control law. `SwitchingModel` keeps it. The
# trajectories of a `Solution` stay single-valued (left-continuous at a switching time);
# the left and right limits at every switching time are stored here, so that plots draw
# vertical jumps and a solution rebuilt from sampled data keeps its jumps.

"""
$(TYPEDEF)

Switching structure of a solution with no switching information: no switching time and no
phase label. This is the default of [`CTModels.Solutions.build_solution`](@extref).

See also: [`CTModels.Solutions.SwitchingModel`](@extref).
"""
struct EmptySwitchingModel <: AbstractSwitchingModel end

"""
$(TYPEDEF)

Switching structure of a solution made of consecutive phases, typically computed by an
indirect method where the structure is fixed: the switching times, a label per phase, and
the left and right limits of the state, costate and control at every switching time.

The trajectories of the solution are left-continuous: at a switching time `tᵢ`, they
return the left limit. The right limit, after a jump of the state or costate or a change
of control law, is stored here.

Build it with the keyword constructor, which checks the shapes.

# Fields

- `times::Vector{Float64}`: the switching times, strictly increasing (may be empty).
- `labels::Vector{String}`: one label per phase (`length(times) + 1`); `""` for no label.
- `state::NTuple{2,Matrix{Float64}}`: `(left, right)` limits of the state, one row per
  switching time, one column per component.
- `costate::NTuple{2,Matrix{Float64}}`: `(left, right)` limits of the costate.
- `control::NTuple{2,Matrix{Float64}}`: `(left, right)` limits of the control.

# Example

```julia-repl
julia> using CTModels

julia> sw = CTModels.SwitchingModel(;
           times=[0.5],
           labels=["bang", "singular"],
           state=([1.0;;], [2.0;;]),
           costate=([0.0;;], [0.0;;]),
           control=([1.0;;], [0.5;;]),
       );

julia> CTModels.switching_times(sw)
1-element Vector{Float64}:
 0.5
```

See also: [`CTModels.Solutions.EmptySwitchingModel`](@extref), [`CTModels.Solutions.switching_times`](@extref),
[`CTModels.Solutions.phase_labels`](@extref), [`CTModels.Solutions.left_limit`](@extref),
[`CTModels.Solutions.right_limit`](@extref).
"""
struct SwitchingModel <: AbstractSwitchingModel
    times::Vector{Float64}
    labels::Vector{String}
    state::NTuple{2,Matrix{Float64}}
    costate::NTuple{2,Matrix{Float64}}
    control::NTuple{2,Matrix{Float64}}
end

"""
$(TYPEDSIGNATURES)

Build a [`CTModels.Solutions.SwitchingModel`](@extref) and check its shapes.

# Keyword Arguments

- `times::AbstractVector{<:Real}`: the switching times, strictly increasing.
- `labels::AbstractVector{<:AbstractString}`: one label per phase; default: no label
  (`""` for each of the `length(times) + 1` phases).
- `state`, `costate`, `control`: `(left, right)` pairs of matrices with one row per
  switching time. Default: matrices with no column, for a solution whose limits are not
  known (e.g. a single phase, with no switching time).

# Throws

- [`CTBase.Exceptions.IncorrectArgument`](@extref): if the switching times are not strictly
  increasing or not finite, if the number of labels is not `length(times) + 1`, or if a
  matrix does not have one row per switching time, or its left and right matrices differ in
  size.
"""
function SwitchingModel(;
    times::AbstractVector{<:Real},
    labels::AbstractVector{<:AbstractString}=fill("", length(times) + 1),
    state::Tuple{AbstractMatrix{<:Real},AbstractMatrix{<:Real}}=_no_limits(length(times)),
    costate::Tuple{AbstractMatrix{<:Real},AbstractMatrix{<:Real}}=_no_limits(length(times)),
    control::Tuple{AbstractMatrix{<:Real},AbstractMatrix{<:Real}}=_no_limits(length(times)),
)
    ts = collect(Float64, times)
    all(isfinite, ts) || throw(
        Exceptions.IncorrectArgument(
            "switching times must be finite";
            got="times=$ts",
            expected="finite times",
            suggestion="Give the switching times as finite numbers",
            context="SwitchingModel",
        ),
    )
    all(i -> ts[i] < ts[i + 1], 1:(length(ts) - 1)) || throw(
        Exceptions.IncorrectArgument(
            "switching times must be strictly increasing";
            got="times=$ts",
            expected="t₁ < t₂ < … (no repeated time)",
            suggestion="Merge the phases that start at the same time, or sort the times",
            context="SwitchingModel",
        ),
    )
    length(labels) == length(ts) + 1 || throw(
        Exceptions.IncorrectArgument(
            "one label per phase";
            got="$(length(labels)) label(s) for $(length(ts) + 1) phase(s)",
            expected="$(length(ts) + 1) labels (length(times) + 1)",
            suggestion="Give one label per phase, \"\" for a phase with no label",
            context="SwitchingModel",
        ),
    )
    return SwitchingModel(
        ts,
        collect(String, labels),
        _checked_limits(state, length(ts), "state"),
        _checked_limits(costate, length(ts), "costate"),
        _checked_limits(control, length(ts), "control"),
    )
end

"""
$(TYPEDSIGNATURES)

Default `(left, right)` limits: two matrices with `n` rows and no column (limits not known).
"""
_no_limits(n::Integer) = (zeros(n, 0), zeros(n, 0))

"""
$(TYPEDSIGNATURES)

Check a `(left, right)` pair of limits for `n` switching times and convert it to
`NTuple{2,Matrix{Float64}}`.

# Throws

- [`CTBase.Exceptions.IncorrectArgument`](@extref): if a matrix does not have `n` rows, or the
  two matrices differ in size.
"""
function _checked_limits(lr, n::Integer, name::String)
    left, right = lr
    size(left, 1) == n && size(right, 1) == n || throw(
        Exceptions.IncorrectArgument(
            "one row of $name limits per switching time";
            got="$(size(left, 1)) and $(size(right, 1)) rows (left, right)",
            expected="$n rows (one per switching time)",
            suggestion="Give the $name limit at the i-th switching time in row i",
            context="SwitchingModel - $name limits",
        ),
    )
    size(left) == size(right) || throw(
        Exceptions.IncorrectArgument(
            "left and right $name limits must have the same size";
            got="left $(size(left)), right $(size(right))",
            expected="two matrices of the same size",
            suggestion="Give the left and right $name limits for the same components",
            context="SwitchingModel - $name limits",
        ),
    )
    return (Matrix{Float64}(left), Matrix{Float64}(right))
end

# ------------------------------------------------------------------------------ #
# Accessors on the switching model
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the switching times: empty for an [`CTModels.Solutions.EmptySwitchingModel`](@extref).
"""
switching_times(::EmptySwitchingModel)::Vector{Float64} = Float64[]

"""
$(TYPEDSIGNATURES)

Return the switching times, strictly increasing.
"""
switching_times(m::SwitchingModel)::Vector{Float64} = m.times

"""
$(TYPEDSIGNATURES)

Return the phase labels: empty for an [`CTModels.Solutions.EmptySwitchingModel`](@extref).
"""
phase_labels(::EmptySwitchingModel)::Vector{String} = String[]

"""
$(TYPEDSIGNATURES)

Return the phase labels, one per phase (`""` for a phase with no label).
"""
phase_labels(m::SwitchingModel)::Vector{String} = m.labels

"""
$(TYPEDSIGNATURES)

Return whether the model holds at least one switching time.
"""
has_switching(m::AbstractSwitchingModel)::Bool = !isempty(switching_times(m))

"""
$(TYPEDSIGNATURES)

Return the `(left, right)` matrices of limits of `component` (`:state`, `:costate` or
`:control`), one row per switching time.

# Throws

- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `component` is not one of these.
"""
function limits(m::SwitchingModel, component::Symbol)::NTuple{2,Matrix{Float64}}
    _check_limit_component(component)
    component === :state && return m.state
    component === :costate && return m.costate
    return m.control
end

"""
$(TYPEDSIGNATURES)

Return the `(left, right)` limits of `component`: none for an
[`CTModels.Solutions.EmptySwitchingModel`](@extref) (two `0 × 0` matrices).
"""
function limits(::EmptySwitchingModel, component::Symbol)::NTuple{2,Matrix{Float64}}
    _check_limit_component(component)
    return (zeros(0, 0), zeros(0, 0))
end

"""
$(TYPEDSIGNATURES)

Check that `component` is a component with switching limits: `:state`, `:costate` or
`:control`.

# Throws

- [`CTBase.Exceptions.IncorrectArgument`](@extref): if it is not.
"""
function _check_limit_component(component::Symbol)
    component in (:state, :costate, :control) || throw(
        Exceptions.IncorrectArgument(
            "unknown component for switching limits";
            got=":$component",
            expected=":state, :costate or :control",
            suggestion="Use :state, :costate or :control",
            context="switching limits",
        ),
    )
    return nothing
end

# ------------------------------------------------------------------------------ #
# Accessors on the solution
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the switching model of a solution: an [`CTModels.Solutions.EmptySwitchingModel`](@extref)
or a [`CTModels.Solutions.SwitchingModel`](@extref).
"""
switching_model(sol::Solution)::AbstractSwitchingModel = sol.switching

"""
$(TYPEDSIGNATURES)

Return the switching times of a solution, strictly increasing; empty if the solution holds
no switching structure.

# Example

```julia-repl
julia> CTModels.switching_times(sol)
2-element Vector{Float64}:
 0.31
 0.72
```

See also: [`CTModels.Solutions.phase_labels`](@extref), [`CTModels.Solutions.left_limit`](@extref),
[`CTModels.Solutions.right_limit`](@extref).
"""
switching_times(sol::Solution)::Vector{Float64} = switching_times(switching_model(sol))

"""
$(TYPEDSIGNATURES)

Return the phase labels of a solution, one per phase (`""` for a phase with no label);
empty if the solution holds no switching structure.

See also: [`CTModels.Solutions.switching_times`](@extref).
"""
phase_labels(sol::Solution)::Vector{String} = phase_labels(switching_model(sol))

"""
$(TYPEDSIGNATURES)

Return whether the solution holds at least one switching time.

See also: [`CTModels.Solutions.switching_times`](@extref).
"""
has_switching(sol::Solution)::Bool = has_switching(switching_model(sol))

"""
$(TYPEDSIGNATURES)

Return the left limit of `component` (`:state`, `:costate` or `:control`) at the `i`-th
switching time: the value before the jump, which the trajectory itself returns at that time.
A one-dimensional component is returned as a scalar.

# Throws

- [`CTBase.Exceptions.IncorrectArgument`](@extref): if the solution has no `i`-th switching
  time, or if `component` is unknown.
- [`CTBase.Exceptions.PreconditionError`](@extref): if the limits of `component` are not
  stored in the switching model of the solution.

See also: [`CTModels.Solutions.right_limit`](@extref).
"""
left_limit(sol::Solution, component::Symbol, i::Integer) = _limit(sol, component, i, 1)

"""
$(TYPEDSIGNATURES)

Return the right limit of `component` (`:state`, `:costate` or `:control`) at the `i`-th
switching time: the value after a jump of the state or costate, or after a change of
control law. A one-dimensional component is returned as a scalar.

# Throws

- [`CTBase.Exceptions.IncorrectArgument`](@extref): if the solution has no `i`-th switching
  time, or if `component` is unknown.
- [`CTBase.Exceptions.PreconditionError`](@extref): if the limits of `component` are not
  stored in the switching model of the solution.

See also: [`CTModels.Solutions.left_limit`](@extref).
"""
right_limit(sol::Solution, component::Symbol, i::Integer) = _limit(sol, component, i, 2)

"""
$(TYPEDSIGNATURES)

Shared implementation of [`CTModels.Solutions.left_limit`](@extref) (`side = 1`) and
[`CTModels.Solutions.right_limit`](@extref) (`side = 2`).
"""
function _limit(sol::Solution, component::Symbol, i::Integer, side::Int)
    m = switching_model(sol)
    M = limits(m, component)[side]
    n = length(switching_times(m))
    1 <= i <= n || throw(
        Exceptions.IncorrectArgument(
            "no switching time with this index";
            got="i = $i",
            expected=if n == 0
                "no index: the solution has no switching time"
            else
                "1 ≤ i ≤ $n"
            end,
            suggestion="Use an index of switching_times(sol)",
            context=(side == 1 ? "left_limit" : "right_limit"),
        ),
    )
    size(M, 2) == 0 && throw(
        Exceptions.PreconditionError(
            "the $component limits at the switching times are not known";
            reason="the switching model of the solution stores no $component limit",
            suggestion="Build the solution with " *
                       "switching=SwitchingModel(; $component=(left, right), ...)",
            context=(side == 1 ? "left_limit" : "right_limit"),
        ),
    )
    return size(M, 2) == 1 ? M[i, 1] : M[i, :]
end

# ------------------------------------------------------------------------------ #
# Jump-aware interpolation of sampled data
# ------------------------------------------------------------------------------ #

"""
$(TYPEDEF)

Interpolant of sampled data that keeps the jumps at the switching times.

Around a switching time `τ`, a plain interpolant of the grid values would join the last
point before `τ` to the first point after it, smearing the jump. This one interpolates
between the last grid point before `τ` and the left limit at `τ`, then between the right
limit at `τ` and the first grid point after it. With `constant = true` (piecewise-constant
control), it returns the right limit until the next grid point. Elsewhere it returns the
base interpolant. At `τ` it returns the left limit (left continuity).

# Fields

- `base::F`: the interpolant of the grid values (returns a vector).
- `grid::Vector{Float64}`: the grid of the data.
- `times::Vector{Float64}`: the switching times.
- `left::Matrix{Float64}`, `right::Matrix{Float64}`: the limits, one row per switching time.
- `constant::Bool`: piecewise-constant interpolation.
"""
struct _JumpInterpolant{F}
    base::F
    grid::Vector{Float64}
    times::Vector{Float64}
    left::Matrix{Float64}
    right::Matrix{Float64}
    constant::Bool
end

"""
$(TYPEDSIGNATURES)

Evaluate the jump-aware interpolant at time `t` (see
[`CTModels.Solutions._JumpInterpolant`](@extref)).
"""
function (J::_JumpInterpolant)(t::Real)
    T = J.grid
    for i in eachindex(J.times)
        τ = J.times[i]
        t == τ && return J.left[i, :]
        if t < τ
            k = searchsortedlast(T, t)               # T[k] ≤ t < τ
            (k >= 1 && k < length(T) && T[k + 1] >= τ) || continue
            # last grid point before τ is T[k]: interpolate towards the left limit
            J.constant && return J.base(t)
            T[k] == t && return J.base(t)
            a = J.base(T[k])
            θ = (t - T[k]) / (τ - T[k])
            return a .+ θ .* (J.left[i, :] .- a)
        else
            k = searchsortedfirst(T, t)              # T[k] ≥ t > τ
            (k <= length(T) && k >= 2 && T[k - 1] <= τ) || continue
            # first grid point after τ is T[k]: interpolate from the right limit
            J.constant && return J.right[i, :]
            T[k] == t && return J.base(t)
            b = J.base(T[k])
            θ = (t - τ) / (T[k] - τ)
            return J.right[i, :] .+ θ .* (b .- J.right[i, :])
        end
    end
    return J.base(t)
end

"""
$(TYPEDSIGNATURES)

Wrap the interpolant `base` of sampled data on `grid` so that it keeps the jumps of
`component` stored in the switching model `sw`. Returned unchanged when `sw` holds no
switching time, or no limit of `component`.
"""
function _with_jumps(
    base,
    grid::Vector{Float64},
    sw::AbstractSwitchingModel,
    component::Symbol;
    constant=false,
)
    has_switching(sw) || return base
    left, right = limits(sw, component)
    size(left, 2) == 0 && return base
    return _JumpInterpolant(base, grid, switching_times(sw), left, right, constant)
end

# ------------------------------------------------------------------------------ #
# Display
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Return the sequence of phase labels as written by the displays, e.g. `"bang → · → singular"`:
the labels joined by arrows, a phase with no label written `·` so that every phase keeps
its place between the switching times.
"""
function _phase_sequence(labels::AbstractVector{<:AbstractString})::String
    return join((isempty(l) ? "·" : l for l in labels), " → ")
end

"""
$(TYPEDSIGNATURES)

Return the components whose limits a switching model stores, e.g. `"state, costate"`, or
`"none"`.
"""
function _stored_limits(m::SwitchingModel)::String
    stored = [
        String(c) for c in (:state, :costate, :control) if size(limits(m, c)[1], 2) > 0
    ]
    return isempty(stored) ? "none" : join(stored, ", ")
end

"""
$(TYPEDSIGNATURES)

Compact display of an [`CTModels.Solutions.EmptySwitchingModel`](@extref).
"""
function Base.show(io::IO, ::EmptySwitchingModel)
    fmt = CTBase.Core.get_format_codes(io)
    return print(io, fmt.name, "EmptySwitchingModel", fmt.reset, "()")
end

"""
$(TYPEDSIGNATURES)

Display of an [`CTModels.Solutions.EmptySwitchingModel`](@extref): no switching time, no
phase label.
"""
function Base.show(io::IO, ::MIME"text/plain", ::EmptySwitchingModel)
    fmt = CTBase.Core.get_format_codes(io)
    return print(
        io,
        fmt.name,
        "EmptySwitchingModel",
        fmt.reset,
        fmt.muted,
        "  (no switching)",
        fmt.reset,
    )
end

"""
$(TYPEDSIGNATURES)

Compact one-line display of a [`CTModels.Solutions.SwitchingModel`](@extref): its switching
times and its sequence of phases.
"""
function Base.show(io::IO, m::SwitchingModel)
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "SwitchingModel", fmt.reset, "(")
    print(io, fmt.label, "times=", fmt.reset, fmt.value, m.times, fmt.reset)
    if any(!isempty, m.labels)
        print(
            io, ", ", fmt.label, "phases=", fmt.reset, fmt.value, _phase_sequence(m.labels)
        )
        print(io, fmt.reset)
    end
    return print(io, ")")
end

"""
$(TYPEDSIGNATURES)

Display of a [`CTModels.Solutions.SwitchingModel`](@extref) as a tree, in the style of the
display of a [`CTModels.Solutions.Solution`](@extref): the switching times, the sequence of
phases (an unlabelled phase shows as `·`) and the components whose limits are stored.

# Example
```julia-repl
julia> CTModels.SwitchingModel(; times=[0.5], labels=["bang", "singular"])
SwitchingModel
  │  Switching times : [0.5]
  │  Phases : bang → singular
  └─ Limits : none
```
"""
function Base.show(io::IO, ::MIME"text/plain", m::SwitchingModel)
    fmt = CTBase.Core.get_format_codes(io)
    print(io, fmt.name, "SwitchingModel", fmt.reset)
    rows = (
        ("Switching times", string(m.times)),
        ("Phases", _phase_sequence(m.labels)),
        ("Limits", _stored_limits(m)),
    )
    for (k, (label, value)) in enumerate(rows)
        c = k == length(rows) ? "  └─ " : "  │  "
        print(io, "\n", fmt.muted, c, fmt.reset, fmt.label, label, " : ", fmt.reset)
        print(io, fmt.value, value, fmt.reset)
    end
    return nothing
end
