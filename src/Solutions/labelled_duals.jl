# ------------------------------------------------------------------------------ #
# Duals given by label: placement into the stacked layout of the model
#
# `build_solution(...; duals=Dict(label => value))` gives the duals of the constraints by
# label. The layout (the rows of each label in the stacked constraint vector, or the
# components of a box) is a CTModels internal, given by `Models.constraint_rows`. A label
# absent from `duals` is unknown: its rows hold `NaN` and the mask of the known rows
# says so, so that `dual` throws instead of returning a value nobody computed.
#
# A box label takes the signed dual of ct-conventions SGN2/SGN3 (what `dual` returns); it
# is split back into the lower- and upper-bound multipliers `zL`, `zU` stored by component
# (see `_split_lower`, `_split_upper`).
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Place the duals given by label in `duals` into the stacked layout of `ocp`.

Returns a named tuple, one entry per kind of constraint, whose kinds with no label in
`duals` are `nothing`:
- `path = (duals, known)`: the path duals (a matrix on the path grid `T_path`, or a
  [`CTModels.Solutions.StackedDuals`](@extref)) and their canonical mask;
- `boundary = (duals, known)`: a vector and its mask;
- `state`, `control = (lb, ub, known)`: the lower- and upper-bound multipliers, by component
  (matrices on `T_state` / `T_control`, or functions of time), and the mask of the known
  components;
- `variable = (lb, ub, known)`: vectors and their mask.

The masks are canonical (see [`CTModels.Solutions._canonical_mask`](@extref)).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if a label is not a constraint of
  `ocp`, or its value has a wrong type or size.
"""
function _place_duals(
    ocp::Model,
    duals::AbstractDict{Symbol},
    T_path;
    T_state=T_path,
    T_control=T_path,
    control_interpolation::Symbol=:constant,
)
    parts = Dict(k => Pair{Vector{Int},Any}[] for k in (:path, :boundary, :state, :control, :variable))
    grids = (path=T_path, state=T_state, control=T_control)
    owners = Dict{Tuple{Symbol,Int},Symbol}()   # (box kind, component) => label
    for (label, value) in duals
        kind, rows = constraint_rows(ocp, label)
        kind in (:state, :control, :variable) && _claim_components!(owners, kind, rows, label)
        checked = if kind in (:boundary, :variable)
            _checked_static_dual(label, kind, rows, value)
        else
            _checked_timed_dual(label, kind, rows, value, getproperty(grids, kind))
        end
        push!(parts[kind], rows => checked)
    end
    path = Pair{UnitRange{Int},Any}[first(r):last(r) => v for (r, v) in parts[:path]]
    return (
        path=_place_path_duals(path, dim_path_constraints_nl(ocp), T_path),
        boundary=_place_boundary_duals(parts[:boundary], dim_boundary_constraints_nl(ocp)),
        state=_place_box_duals(
            parts[:state], state_constraints_box(ocp), state_dimension(ocp), T_state, :linear
        ),
        control=_place_box_duals(
            parts[:control],
            control_constraints_box(ocp),
            control_dimension(ocp),
            T_control,
            control_interpolation,
        ),
        variable=_place_variable_box_duals(
            parts[:variable], variable_constraints_box(ocp), variable_dimension(ocp)
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Record that the box label `label` gives the dual of the `kind` components `rows`, in
`owners` (`(kind, component) => label`).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if a component is already given by
  another label. Several labels on one component (aliases) share its single multiplier, so
  it is given by one of them only: two values would leave one silently overwritten.
"""
function _claim_components!(
    owners::Dict{Tuple{Symbol,Int},Symbol}, kind::Symbol, rows::Vector{Int}, label::Symbol
)
    for i in rows
        other = get(owners, (kind, i), nothing)
        Core.@ensure isnothing(other) Exceptions.IncorrectArgument(
            "the $kind box component $i is given by two labels";
            got="labels :$other and :$label, which both bound component $i",
            expected="each box component given by one label",
            suggestion="The labels on one component share its multiplier: give the dual by one of them only (the other reads the same dual).",
            context="build_solution - placing the duals given by label",
        )
        owners[(kind, i)] = label
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Check the dual `value` given for the label `label` of a time-dependent constraint (`kind`
`:path`, `:state` or `:control`) of rows `rows`: a `Function` `t -> value` (its size is
checked at the first time of the grid `T`), or a matrix with one row per time of `T` and
one column per row of the label (a vector for a one-row label). Returns the value, a vector
being turned into a one-column matrix.
"""
function _checked_timed_dual(label::Symbol, kind::Symbol, rows::Vector{Int}, value, T)
    n = length(rows)
    what = kind === :path ? "path constraint" : "$kind box"
    if value isa Function
        if !isnothing(T) && !isempty(T)
            _ensure_dual_size(label, n, length(value(first(T))), "value at t = $(first(T))")
        end
        return value
    elseif value isa AbstractVector{<:Real} && n == 1
        return reshape(Vector{Float64}(value), :, 1)
    elseif value isa AbstractMatrix{<:Real}
        _ensure_dual_size(label, n, size(value, 2), "number of columns")
        return Matrix{Float64}(value)
    end
    return throw(
        Exceptions.IncorrectArgument(
            "invalid dual for the $what :$label";
            got="a value of type $(typeof(value))",
            expected="a Function `t -> value`, or a Matrix (times × $n rows)" *
                     (n == 1 ? " or a Vector (one entry per time)" : ""),
            suggestion="Give the dual of :$label as a function of time or sampled on the $(kind === :path ? "path" : kind) grid.",
            context="build_solution - placing the duals given by label",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Check the dual `value` given for the label `label` of a time-independent constraint (`kind`
`:boundary` or `:variable`) of rows `rows`: a `Number` for a one-row label, a vector with
one entry per row otherwise.
"""
function _checked_static_dual(label::Symbol, kind::Symbol, rows::Vector{Int}, value)
    n = length(rows)
    what = kind === :boundary ? "boundary constraint" : "variable box"
    if value isa Real || value isa AbstractVector{<:Real}
        _ensure_dual_size(label, n, length(value), "length")
        return value
    end
    return throw(
        Exceptions.IncorrectArgument(
            "invalid dual for the $what :$label";
            got="a value of type $(typeof(value))",
            expected=n == 1 ? "a Number" : "a Vector of length $n",
            suggestion="Give the dual of :$label as a number (one row) or a vector (one entry per row).",
            context="build_solution - placing the duals given by label",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Throw an [`CTBase.Exceptions.IncorrectArgument`](@extref) when the dual given for `label`
has `got` entries instead of the `n` rows of the label.
"""
function _ensure_dual_size(label::Symbol, n::Int, got::Int, what::String)
    got == n && return nothing
    return throw(
        Exceptions.IncorrectArgument(
            "dual size mismatch for the constraint :$label";
            got="$what = $got",
            expected="$n (the number of rows of :$label)",
            suggestion="Give one entry per row of the constraint :$label; `CTModels.Models.constraint_rows(model, :$label)` gives its rows.",
            context="build_solution - placing the duals given by label",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

The path duals of the parts `rows => value` on `dim` stacked rows, with their canonical
mask. When every value is a matrix, they are stacked into one matrix (`NaN` in the unknown
rows), interpolated afterwards as positional path duals are. Otherwise every part becomes
a function of time (a matrix is interpolated on `T_path`) and the parts are combined into a
[`CTModels.Solutions.StackedDuals`](@extref).
"""
function _place_path_duals(parts::Vector{Pair{UnitRange{Int},Any}}, dim::Int, T_path)
    isempty(parts) && return (nothing, nothing)
    known = _known_rows(parts, dim)
    if all(p -> p.second isa Matrix{Float64}, parts)
        N = size(first(parts).second, 1)
        Core.@ensure all(p -> size(p.second, 1) == N, parts) Exceptions.IncorrectArgument(
            "the path duals given by label have different numbers of times";
            got="numbers of rows $(sort(unique(size(p.second, 1) for p in parts)))",
            expected="one row per time of the path grid for every label",
            suggestion="Sample every path dual on the same path grid `T_path`.",
            context="build_solution - placing the duals given by label",
        )
        M = fill(NaN, N, dim)
        for (rows, value) in parts
            M[:, rows] .= value
        end
        return (M, known)
    end
    functions = Tuple(
        (rows, value isa Function ? value : _interpolate_part(value, T_path, length(rows)))
        for (rows, value) in parts
    )
    return (StackedDuals(dim, functions), known)
end

"""
$(TYPEDSIGNATURES)

A matrix part of the duals as a function of time on the grid `T`, with `interpolation`
(a scalar for one row).
"""
function _interpolate_part(
    value::Matrix{Float64}, T, n::Int, interpolation::Symbol=:linear
)
    return build_interpolated_function(
        value, T, n, Matrix{Float64}; expected_dim=n, interpolation=interpolation
    )
end

"""
$(TYPEDSIGNATURES)

The boundary duals of the parts `rows => value` on `dim` stacked rows (`NaN` in the unknown
rows), with their canonical mask.
"""
function _place_boundary_duals(parts::Vector{<:Pair{<:AbstractVector{Int},Any}}, dim::Int)
    isempty(parts) && return (nothing, nothing)
    duals = fill(NaN, dim)
    for (rows, value) in parts
        duals[rows] .= value
    end
    return (duals, _known_rows(parts, dim))
end

"""
$(TYPEDSIGNATURES)

The lower-bound multiplier `zL` of a box component whose signed dual is `d` (ct-conventions
`SGN2`/`SGN3`), from the coefficients `(cl, cu)` of the component (see
[`CTModels.Solutions._box_dual_coefficients`](@extref)): `d` for a lower bound only (`(1,
0)`), `0` for an upper bound only (`(0, 1)`), `max(-d, 0)` for two bounds or a fixed
component (`(-1, 1)`). With [`CTModels.Solutions._split_upper`](@extref), the inverse of
`cl * zL + cu * zU`: lossless, since at most one side of a component is active.
"""
_split_lower(d::Real, cl::Real, cu::Real) = cl == 1 ? float(d) : cl == -1 ? max(-d, 0.0) : 0.0

"""
$(TYPEDSIGNATURES)

The upper-bound multiplier `zU` of a box component whose signed dual is `d`: `0` for a
lower bound only, `d` for an upper bound only, `max(d, 0)` for two bounds or a fixed
component (see [`CTModels.Solutions._split_lower`](@extref)).
"""
_split_upper(d::Real, cl::Real, cu::Real) = cl == 1 ? 0.0 : cl == -1 ? max(d, 0.0) : float(d)

"""
$(TYPEDSIGNATURES)

The state or control box duals of the parts `components => value` (the signed duals given
by label), on `dim` components, split into `(lb, ub, known)`: the lower- and upper-bound
multipliers and the canonical mask of the known components. A component bounded by no
label carries a known `0`, as with the box keywords; a bounded component whose label is not
given holds `NaN`.

When every value is a matrix (sampled on `T`), the multipliers are matrices, interpolated
afterwards as the box keywords are. Otherwise each part becomes a function of time (a
matrix is interpolated on `T` with `interpolation`) and each side is a
[`CTModels.Solutions.StackedDuals`](@extref) of [`CTModels.Solutions.BoxDualSplit`](@extref).
"""
function _place_box_duals(
    parts::Vector{Pair{Vector{Int},Any}}, cp::Tuple, dim::Int, T, interpolation::Symbol
)
    isempty(parts) && return nothing
    known, unknown = _box_known(parts, cp, dim)
    coefficients = [_box_dual_coefficients(cp, rows) for (rows, _) in parts]
    if all(p -> p.second isa Matrix{Float64}, parts)
        N = size(first(parts).second, 1)
        Core.@ensure all(p -> size(p.second, 1) == N, parts) Exceptions.IncorrectArgument(
            "the box duals given by label have different numbers of times";
            got="numbers of rows $(sort(unique(size(p.second, 1) for p in parts)))",
            expected="one row per time of the grid for every label",
            suggestion="Sample every box dual of a kind on the same grid.",
            context="build_solution - placing the duals given by label",
        )
        lb, ub = zeros(N, dim), zeros(N, dim)
        lb[:, unknown] .= NaN
        ub[:, unknown] .= NaN
        for ((rows, d), (cl, cu)) in zip(parts, coefficients)
            lb[:, rows] .= _split_lower.(d, cl', cu')
            ub[:, rows] .= _split_upper.(d, cl', cu')
        end
        return (lb, ub, known)
    end
    functions = [
        rows => (d isa Function ? d : _interpolate_part(d, T, length(rows), interpolation))
        for (rows, d) in parts
    ]
    # the bounded components whose label is not given are unknown: one more part, NaN
    unknown_part = isempty(unknown) ? () : ((unknown, Returns(NaN)),)
    function side(S)
        split = Tuple(
            (rows, BoxDualSplit{S}(g, cl, cu)) for
            ((rows, g), (cl, cu)) in zip(functions, coefficients)
        )
        return StackedDuals(dim, (split..., unknown_part...), 0.0)
    end
    return (side(:lower), side(:upper), known)
end

"""
$(TYPEDSIGNATURES)

The variable box duals of the parts `components => value`, on `dim` components, split into
`(lb, ub, known)` vectors (see [`CTModels.Solutions._place_box_duals`](@extref)).
"""
function _place_variable_box_duals(parts::Vector{Pair{Vector{Int},Any}}, cp::Tuple, dim::Int)
    isempty(parts) && return nothing
    known, unknown = _box_known(parts, cp, dim)
    lb, ub = zeros(dim), zeros(dim)
    lb[unknown] .= NaN
    ub[unknown] .= NaN
    for (rows, d) in parts
        cl, cu = _box_dual_coefficients(cp, rows)
        lb[rows] .= _split_lower.(d, cl, cu)
        ub[rows] .= _split_upper.(d, cl, cu)
    end
    return (lb, ub, known)
end

"""
$(TYPEDSIGNATURES)

The canonical mask of the known components of a box given by the parts `components =>
value`, and the components left unknown: the bounded components of the box tuple `cp`
whose label is not among the parts. A component bounded by no label is known (its dual is
`0`).
"""
function _box_known(parts::Vector{Pair{Vector{Int},Any}}, cp::Tuple, dim::Int)
    known = fill(true, dim)
    known[unique(cp[2])] .= false
    for (rows, _) in parts
        known[rows] .= true
    end
    return _canonical_mask(known), findall(!, known)
end

"""
$(TYPEDSIGNATURES)

The canonical mask of the rows covered by `parts` among `dim` rows.
"""
function _known_rows(parts::Vector{<:Pair{<:AbstractVector{Int},Any}}, dim::Int)
    known = fill(false, dim)
    for (rows, _) in parts
        known[rows] .= true
    end
    return _canonical_mask(known)
end

"""
$(TYPEDSIGNATURES)

The canonical form of a mask of the known rows: `nothing` when every row is known, the mask
itself otherwise. A mask with no known row never reaches this function: a kind of
constraint with no known dual is stored as `nothing`.
"""
_canonical_mask(known::Vector{Bool}) = all(known) ? nothing : known

"""
$(TYPEDSIGNATURES)

The inverse of the placement: the path and boundary duals stored on the stacked layout of
`ocp` (`path`: a matrix with one column per row, or `nothing`; `boundary`: a vector or
`nothing`), with their canonical masks, given back by label, as
[`CTModels.Solutions.build_solution`](@extref) takes them in `duals`. A label with an
unknown row is left out. Used to rebuild a solution read from a file.
"""
function _duals_by_label(
    ocp::Model,
    path::Union{Nothing,AbstractMatrix{<:Real}},
    boundary::Union{Nothing,AbstractVector{<:Real}},
    path_known::Union{Nothing,AbstractVector{Bool}},
    boundary_known::Union{Nothing,AbstractVector{Bool}},
)::Dict{Symbol,Any}
    duals = Dict{Symbol,Any}()
    if !isnothing(path)
        for label in unique(path_constraints_nl(ocp)[4])
            _, rows = constraint_rows(ocp, label)
            _rows_known(_as_mask(path_known), rows) && (duals[label] = path[:, rows])
        end
    end
    if !isnothing(boundary)
        for label in unique(boundary_constraints_nl(ocp)[4])
            _, rows = constraint_rows(ocp, label)
            _rows_known(_as_mask(boundary_known), rows) || continue
            duals[label] = length(rows) == 1 ? boundary[rows[1]] : boundary[rows]
        end
    end
    return duals
end

"""
$(TYPEDSIGNATURES)

A mask of the known rows read from a file as a `Vector{Bool}` (`nothing`: every row known).
"""
_as_mask(::Nothing) = nothing
_as_mask(known::AbstractVector{Bool}) = Vector{Bool}(known)

"""
$(TYPEDSIGNATURES)

`sol` with the masks of the known components of its box duals replaced by `state`,
`control` and `variable` (see [`CTModels.Solutions.DualMasks`](@extref)); the duals and the
other masks are unchanged. Used to rebuild a solution read from a file: its box multipliers
are passed by component as they were stored (`NaN` for the unknown components), then their
masks are restored, which holds whatever the aliases of the box labels.
"""
function _with_box_masks(
    sol::Solution,
    state::Union{Nothing,Vector{Bool}},
    control::Union{Nothing,Vector{Bool}},
    variable::Union{Nothing,Vector{Bool}},
)::Solution
    all(isnothing, (state, control, variable)) && return sol
    dm = dual_model(sol)
    dm isa DualModel || return sol
    known = DualMasks(dm.known.path, dm.known.boundary, state, control, variable)
    dm2 = DualModel(
        dm.path_constraints_dual,
        dm.boundary_constraints_dual,
        dm.state_constraints_lb_dual,
        dm.state_constraints_ub_dual,
        dm.control_constraints_lb_dual,
        dm.control_constraints_ub_dual,
        dm.variable_constraints_lb_dual,
        dm.variable_constraints_ub_dual,
        known,
    )
    return Solution(
        sol.time_grid,
        sol.times,
        sol.state,
        sol.control,
        sol.variable,
        sol.model,
        sol.costate,
        sol.objective,
        dm2,
        sol.solver_infos,
        sol.switching,
    )
end

"""
$(TYPEDSIGNATURES)

The masks of the known rows of the duals of `sol` (see
[`CTModels.Solutions.DualMasks`](@extref)); every mask `nothing` when the solution carries
no duals.
"""
_dual_masks(sol::Solution)::DualMasks = has_duals(sol) ? dual_model(sol).known : DualMasks()
