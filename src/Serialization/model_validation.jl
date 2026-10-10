# ------------------------------------------------------------------------------ #
# Check that an imported solution is compatible with the model it is rebuilt against
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Record a difference `(what, file_value, model_value)` in `list`, unless `file_value` is
`nothing` (unknown) or equal to `model_value`, or `what` is already recorded.

# Arguments
- `list`: Vector of differences, modified in place.
- `what::String`: Description of the compared quantity.
- `file_value`: Value found in the file (`nothing` if it cannot be known).
- `model_value`: Value found in the model.

# Returns
- `Nothing`
"""
function _record_difference!(list, what::String, file_value, model_value)::Nothing
    isnothing(file_value) && return nothing
    file_value == model_value && return nothing
    any(d -> d[1] == what, list) && return nothing
    push!(list, (what, file_value, model_value))
    return nothing
end

_ncols(::Nothing) = nothing
_ncols(x::AbstractMatrix) = size(x, 2)
_nrows(::Nothing) = nothing
_nrows(x::AbstractArray) = size(x, 1)
_nlength(::Nothing) = nothing
_nlength(x) = length(_extract_time_vector(x))

_format_difference(d, side::Int) = "$(d[1]) = $(repr(d[side + 1]))"

"""
$(TYPEDSIGNATURES)

Time grids stored in the data, as a vector of `(component, grid)` pairs.

# Arguments
- `data`: Dictionary containing the imported solution data.

# Returns
- `Vector{Tuple{Symbol,Vector{Float64}}}`: The grid of each of `:state`, `:control`,
  `:costate` and `:path` (all equal to `"time_grid"` in the unified format); empty if the
  data has no time grid.
"""
function _data_time_grids(data)
    if haskey(data, "time_grid_state")
        return [
            (:state, _extract_time_vector(data["time_grid_state"])),
            (:control, _extract_time_vector(data["time_grid_control"])),
            (:costate, _extract_time_vector(data["time_grid_costate"])),
            (:path, _extract_time_vector(data["time_grid_path"])),
        ]
    elseif haskey(data, "time_grid")
        T = _extract_time_vector(data["time_grid"])
        return [(c, T) for c in (:state, :control, :costate, :path)]
    end
    return Tuple{Symbol,Vector{Float64}}[]
end

"""
$(TYPEDSIGNATURES)

Compare what can be deduced from the arrays of the file (dimensions of the trajectories and
of the duals, number of samples) with the model. Works on files of any age.

# Arguments
- `errors`: Vector of differences, modified in place.
- `ocp`: The model.
- `data`: Dictionary containing the imported solution data.

# Returns
- `Nothing`
"""
function _check_data_dimensions!(errors, ocp, data)::Nothing
    dim_x = Models.state_dimension(ocp)
    dim_u = Models.control_dimension(ocp)
    dim_v = Models.variable_dimension(ocp)
    cons = Models.constraints(ocp)
    g(key) = get(data, key, nothing)

    _record_difference!(errors, "state dimension", _ncols(g("state")), dim_x)
    _record_difference!(errors, "costate dimension", _ncols(g("costate")), dim_x)
    _record_difference!(errors, "control dimension", _ncols(g("control")), dim_u)
    _record_difference!(errors, "variable dimension", _nlength(g("variable")), dim_v)
    _record_difference!(
        errors,
        "path constraints",
        _ncols(g("path_constraints_dual")),
        Components.dim_path_constraints_nl(cons),
    )
    bcd = g("boundary_constraints_dual")
    _record_difference!(
        errors,
        "boundary constraints",
        isnothing(bcd) ? nothing : length(bcd),
        Components.dim_boundary_constraints_nl(cons),
    )
    for lu in ("lb", "ub")
        _record_difference!(
            errors,
            "state box dual dimension ($lu)",
            _ncols(g("state_constraints_$(lu)_dual")),
            dim_x,
        )
        _record_difference!(
            errors,
            "control box dual dimension ($lu)",
            _ncols(g("control_constraints_$(lu)_dual")),
            dim_u,
        )
        vd = g("variable_constraints_$(lu)_dual")
        _record_difference!(
            errors,
            "variable box dual dimension ($lu)",
            isnothing(vd) ? nothing : _nlength(vd),
            dim_v,
        )
    end

    # number of samples vs time grids (file consistency)
    grids = Dict(_data_time_grids(data))
    for (key, comp) in (
        ("state", :state),
        ("costate", :costate),
        ("control", :control),
        ("path_constraints_dual", :path),
        ("state_constraints_lb_dual", :state),
        ("state_constraints_ub_dual", :state),
        ("control_constraints_lb_dual", :control),
        ("control_constraints_ub_dual", :control),
    )
        rows = _nrows(g(key))
        (isnothing(rows) || !haskey(grids, comp)) && continue
        N = length(grids[comp])
        rows > N && push!(
            errors,
            (
                "number of samples of $key",
                rows,
                "at most $N (length of the $comp time grid)",
            ),
        )
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Compare the model signature stored in the file with the signature of the model. Only used
for files exported with a model signature.

Differences that can make the solution unusable (dimensions, number and labels of the
constraints, fixed versus free times) are recorded in `errors`; the others (names,
objective, values of fixed times) in `warnings`.

# Arguments
- `errors`: Vector of differences, modified in place.
- `warnings`: Vector of differences, modified in place.
- `ocp`: The model.
- `sig`: The signature stored in the file.

# Returns
- `Nothing`
"""
function _check_signature!(errors, warnings, ocp, sig)::Nothing
    msig = Models._model_signature(ocp)
    g(key) = get(sig, key, nothing)
    asint(x) = isnothing(x) ? nothing : Int(x)
    asstrs(x) = isnothing(x) ? nothing : String[string(e) for e in x]
    asstr(x) = isnothing(x) ? nothing : string(x)

    for (key, what) in (
        ("dim_x", "state dimension"),
        ("dim_u", "control dimension"),
        ("dim_v", "variable dimension"),
        ("dim_path_nl", "path constraints"),
        ("dim_boundary_nl", "boundary constraints"),
        ("dim_state_box", "state box constraints"),
        ("dim_control_box", "control box constraints"),
        ("dim_variable_box", "variable box constraints"),
    )
        _record_difference!(errors, what, asint(g(key)), msig[key])
    end
    for (key, what) in (
        ("labels_path_nl", "path constraint labels"),
        ("labels_boundary_nl", "boundary constraint labels"),
        ("labels_state_box", "state box constraint labels"),
        ("labels_control_box", "control box constraint labels"),
        ("labels_variable_box", "variable box constraint labels"),
    )
        _record_difference!(errors, what, asstrs(g(key)), msig[key])
    end

    kind(b) = b ? "fixed" : "free"
    for (fixkey, valkey, what) in (
        ("fixed_initial_time", "initial_time", "initial time"),
        ("fixed_final_time", "final_time", "final time"),
    )
        ff = g(fixkey)
        isnothing(ff) && continue
        if Bool(ff) != msig[fixkey]
            _record_difference!(
                errors, "$what (fixed or free)", kind(Bool(ff)), kind(msig[fixkey])
            )
        elseif Bool(ff)
            fv = g(valkey)
            if !isnothing(fv) && !isapprox(Float64(fv), msig[valkey]; rtol=1e-8, atol=1e-8)
                _record_difference!(warnings, what, Float64(fv), msig[valkey])
            end
        end
    end

    for (key, what) in (
        ("state_name", "state name"),
        ("control_name", "control name"),
        ("variable_name", "variable name"),
        ("time_name", "time name"),
        ("initial_time_name", "initial time name"),
        ("final_time_name", "final time name"),
        ("criterion", "criterion"),
    )
        _record_difference!(warnings, what, asstr(g(key)), msig[key])
    end
    for (key, what) in (
        ("state_components", "state components"),
        ("control_components", "control components"),
        ("variable_components", "variable components"),
    )
        _record_difference!(warnings, what, asstrs(g(key)), msig[key])
    end
    for (key, what) in (("has_mayer", "Mayer cost"), ("has_lagrange", "Lagrange cost"))
        fv = g(key)
        _record_difference!(warnings, what, isnothing(fv) ? nothing : Bool(fv), msig[key])
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Check that imported solution data is compatible with the model it is going to be rebuilt
against, before calling `build_solution`.

The check is performed in two stages:

- from the arrays of the file only (dimensions of the trajectories and of the duals,
  number of samples versus time grids, fixed times versus the first and last grid points):
  works for files of any age;
- from the model signature stored in the file (see
  [`CTModels.Models._model_signature`](@extref)), if present: also catches differences that
  the arrays cannot show (absent duals, constraint labels, names, fixed versus free times).

# Arguments
- `ocp`: The model the solution is rebuilt against.
- `data`: Dictionary containing the imported solution data.

# Returns
- `Nothing`

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if the file cannot belong to a solution of `ocp`
  (dimensions, number or labels of constraints, fixed versus free times, corrupted
  arrays). All differences are reported in the same error.

# Notes
Differences which cannot make the solution unusable (names of the components, criterion,
cost type, values of fixed times) only produce a warning. A file without model signature
produces an informational message.

See also: [`CTModels.Serialization._reconstruct_solution_from_data`](@extref).
"""
function _validate_solution_against_model(ocp, data)::Nothing
    errors = Tuple{String,Any,Any}[]
    warnings = Tuple{String,Any,Any}[]

    sig = get(data, "model_signature", nothing)
    if isnothing(sig)
        @info "The solution file has no model signature (it was exported with an older version of CTModels): only the dimensions and the time grids are checked against the model."
    end

    _check_data_dimensions!(errors, ocp, data)

    if isnothing(sig)
        tm = Components.times(ocp)
        grids = _data_time_grids(data)
        if !isempty(grids)
            T = grids[1][2]
            if Components.has_fixed_initial_time(tm)
                t0 = Float64(Components.initial_time(tm))
                isapprox(T[1], t0; rtol=1e-8, atol=1e-8) ||
                    _record_difference!(warnings, "initial time", T[1], t0)
            end
            if Components.has_fixed_final_time(tm)
                tf = Float64(Components.final_time(tm))
                isapprox(T[end], tf; rtol=1e-8, atol=1e-8) ||
                    _record_difference!(warnings, "final time", T[end], tf)
            end
        end
    else
        _check_signature!(errors, warnings, ocp, sig)
    end

    if !isempty(errors)
        throw(
            Exceptions.IncorrectArgument(
                "The solution in the file does not match the model";
                got=join((_format_difference(d, 1) * " (file)" for d in errors), "\n"),
                expected=join(
                    (_format_difference(d, 2) * " (model)" for d in errors), "\n"
                ),
                suggestion="Pass the model the solution was computed from.",
                context="import_ocp_solution - checking the file against the model",
            ),
        )
    end

    if !isempty(warnings)
        lines = join(
            (
                "  $(d[1]): $(repr(d[2])) in the file, $(repr(d[3])) in the model" for
                d in warnings
            ),
            "\n",
        )
        @warn "The solution in the file differs from the model, but it can still be used. Make sure to pass the model the solution was computed from.\n$lines"
    end
    return nothing
end
