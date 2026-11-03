# ------------------------------------------------------------------------------ #
# Duals given by label: placement into the stacked layout of the model
#
# `build_solution(...; duals=Dict(label => value))` gives the duals of the path and
# boundary constraints by label. The layout (the rows of each label in the stacked
# constraint vector) is a CTModels internal, given by `Models.constraint_rows`. A label
# absent from `duals` is unknown: its rows hold `NaN` and the mask of the known rows
# says so, so that `dual` throws instead of returning a value nobody computed.
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Place the duals given by label in `duals` into the stacked layout of `ocp`.

Returns `((path, path_known), (boundary, boundary_known))`: the path duals (`nothing`, a
matrix on the path grid `T_path`, or a [`CTModels.Solutions.StackedDuals`](@extref)), the
boundary duals (`nothing` or a vector), and their canonical masks of the known rows (see
[`CTModels.Solutions._canonical_mask`](@extref)).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if a label is not a constraint of
  `ocp`, is a box label, or its value has a wrong type or size.
"""
function _place_duals(ocp::Model, duals::AbstractDict{Symbol}, T_path)
    path = Pair{UnitRange{Int},Any}[]
    boundary = Pair{UnitRange{Int},Any}[]
    for (label, value) in duals
        kind, rows = constraint_rows(ocp, label)
        if kind === :path
            push!(path, first(rows):last(rows) => _checked_path_dual(label, rows, value, T_path))
        elseif kind === :boundary
            push!(boundary, first(rows):last(rows) => _checked_boundary_dual(label, rows, value))
        else
            throw(
                Exceptions.IncorrectArgument(
                    "a box label cannot be given in `duals`";
                    got="label :$label (a $kind box)",
                    expected="the label of a path or boundary constraint",
                    suggestion="Give the box duals by component with `$(kind)_constraints_lb_dual` and `$(kind)_constraints_ub_dual`.",
                    context="build_solution - placing the duals given by label",
                ),
            )
        end
    end
    return (
        _place_path_duals(path, dim_path_constraints_nl(ocp), T_path),
        _place_boundary_duals(boundary, dim_boundary_constraints_nl(ocp)),
    )
end

"""
$(TYPEDSIGNATURES)

Check the dual `value` given for the path label `label` of rows `rows`: a `Function`
`t -> value` (its size is checked at the first time of `T_path`), or a matrix with one
row per time of `T_path` and one column per row of the label (a vector for a one-row
label). Returns the value, a vector being turned into a one-column matrix.
"""
function _checked_path_dual(label::Symbol, rows::Vector{Int}, value, T_path)
    n = length(rows)
    if value isa Function
        if !isnothing(T_path) && !isempty(T_path)
            _ensure_dual_size(label, n, length(value(first(T_path))), "value at t = $(first(T_path))")
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
            "invalid dual for the path constraint :$label";
            got="a value of type $(typeof(value))",
            expected="a Function `t -> value`, or a Matrix (times × $n rows)" *
                     (n == 1 ? " or a Vector (one entry per time)" : ""),
            suggestion="Give the dual of :$label as a function of time or sampled on the path grid.",
            context="build_solution - placing the duals given by label",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Check the dual `value` given for the boundary label `label` of rows `rows`: a `Number` for
a one-row label, a vector with one entry per row otherwise.
"""
function _checked_boundary_dual(label::Symbol, rows::Vector{Int}, value)
    n = length(rows)
    if value isa Real || value isa AbstractVector{<:Real}
        _ensure_dual_size(label, n, length(value), "length")
        return value
    end
    return throw(
        Exceptions.IncorrectArgument(
            "invalid dual for the boundary constraint :$label";
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

A matrix part of the path duals as a function of time on `T_path` (a scalar for one row).
"""
function _interpolate_part(value::Matrix{Float64}, T_path, n::Int)
    return build_interpolated_function(value, T_path, n, Matrix{Float64}; expected_dim=n)
end

"""
$(TYPEDSIGNATURES)

The boundary duals of the parts `rows => value` on `dim` stacked rows (`NaN` in the unknown
rows), with their canonical mask.
"""
function _place_boundary_duals(parts::Vector{Pair{UnitRange{Int},Any}}, dim::Int)
    isempty(parts) && return (nothing, nothing)
    duals = fill(NaN, dim)
    for (rows, value) in parts
        duals[rows] .= value
    end
    return (duals, _known_rows(parts, dim))
end

"""
$(TYPEDSIGNATURES)

The canonical mask of the rows covered by `parts` among `dim` rows.
"""
function _known_rows(parts::Vector{Pair{UnitRange{Int},Any}}, dim::Int)
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

_as_mask(known::Nothing) = nothing
_as_mask(known::AbstractVector{Bool}) = Vector{Bool}(known)

"""
$(TYPEDSIGNATURES)

The canonical masks of the known rows of the path and boundary duals of `sol`, `(path,
boundary)`: `nothing` when every row of the stored duals is known, or when the solution
carries no duals.
"""
function _dual_masks(sol::Solution)
    has_duals(sol) || return (nothing, nothing)
    dm = dual_model(sol)
    return (dm.path_constraints_dual_known, dm.boundary_constraints_dual_known)
end
