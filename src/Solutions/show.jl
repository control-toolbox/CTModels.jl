# ------------------------------------------------------------------------------ #
# Base.show for Solution
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print the solution to `io` with semantic ANSI formatting.

Displays the objective, the optimisation variable (if defined), boundary constraint
duals (if present), and solver metadata (iterations, status, message, constraints
violation) — each field only when it has been provided (not `NotProvided`).

The display is a single tree rooted at "Solution":
- `│  label : value` for interior rows
- `└─ label : value` for the last row
- `│  ├─ / └─` for nested sub-rows (variable duals)
- An empty `│` separator appears between primal data and solver metadata
  when both sections are non-empty.

# Returns
- `Nothing`: Prints to `io` and returns nothing.

See also: [`CTModels.Solutions.Solution`](@ref)
"""
function Base.show(io::IO, ::MIME"text/plain", sol::Solution)
    fmt = Core.get_format_codes(io)

    # ── Header ──────────────────────────────────────────────────────────────
    ok      = Solutions.successful(sol)
    ok_code = ok ? fmt.success : fmt.error
    ok_sym  = ok ? "✓ successful" : "✗ failed"
    println(io, fmt.name, "Solution", fmt.reset, "  ", ok_code, ok_sym, fmt.reset)

    # ── Optional solver-metadata — only display when provided ────────────────
    _np     = Core.NotProvidedType
    _iter   = Solutions.iterations(sol)
    _status = Solutions.status(sol)
    _msg    = Solutions.message(sol)
    _cv     = Solutions.constraints_violation(sol)
    has_iter   = !(_iter   isa _np)
    has_status = !(_status isa _np)
    has_msg    = !(_msg    isa _np)
    has_cv     = !(_cv     isa _np)

    # ── Primal-extra presence ────────────────────────────────────────────────
    has_var = Models.variable_dimension(sol) > 0
    has_bd  = Solutions.has_duals(sol) && Components.dim_boundary_constraints_nl(sol) > 0
    has_vd  = has_var &&
              Solutions.has_duals(sol) &&
              Solutions.dim_dual_variable_constraints_box(sol) > 0 &&
              Components.dim_variable_constraints_box(Solutions.model(sol)) > 0

    has_solver_meta  = has_iter || has_status || has_msg || has_cv
    has_primal_extra = has_var || has_bd

    # ── Build ordered list of top-level item tags ────────────────────────────
    tags = Symbol[]
    push!(tags, :obj)
    has_var    && push!(tags, :var)
    has_bd     && push!(tags, :bd)
    has_iter   && push!(tags, :iter)
    has_status && push!(tags, :status)
    has_msg    && push!(tags, :msg)
    has_cv     && push!(tags, :cv)

    last_tag = last(tags)

    # ── Connector for each top-level tag ─────────────────────────────────────
    conn(tag) = tag === last_tag ? "  └─ " : "  │  "

    # ── Print one labeled field row ──────────────────────────────────────────
    function _row(c, label, value)
        println(
            io,
            fmt.muted, c, fmt.reset,
            fmt.label, label, " : ", fmt.reset,
            fmt.value, value, fmt.reset,
        )
    end

    # ── Objective ────────────────────────────────────────────────────────────
    _row(conn(:obj), "Objective", string(Components.objective(sol)))

    # ── Variable (optional) ──────────────────────────────────────────────────
    if has_var
        dim_v     = Models.variable_dimension(sol)
        var_val   = Components.variable(sol)
        var_name  = Models.variable_name(sol)
        var_comps = Models.variable_components(sol)

        var_label =
            if dim_v == 1 || var_name == var_comps[1]
                var_name
            else
                var_name * " = (" * join(var_comps, ", ") * ")"
            end

        c = conn(:var)
        _row(c, var_label, string(var_val))

        if has_vd
            lb = Solutions.variable_constraints_lb_dual(sol)
            ub = Solutions.variable_constraints_ub_dual(sol)
            if c == "  └─ "
                println(io, fmt.muted, "     ├─ ", fmt.reset, fmt.label, "dual lb : ", fmt.reset, fmt.value, string(lb), fmt.reset)
                println(io, fmt.muted, "     └─ ", fmt.reset, fmt.label, "dual ub : ", fmt.reset, fmt.value, string(ub), fmt.reset)
            else
                println(io, fmt.muted, "  │  ├─ ", fmt.reset, fmt.label, "dual lb : ", fmt.reset, fmt.value, string(lb), fmt.reset)
                println(io, fmt.muted, "  │  └─ ", fmt.reset, fmt.label, "dual ub : ", fmt.reset, fmt.value, string(ub), fmt.reset)
            end
        end
    end

    # ── Boundary duals (optional) ─────────────────────────────────────────────
    if has_bd
        _row(conn(:bd), "Boundary duals", string(Solutions.boundary_constraints_dual(sol)))
    end

    # ── Separator between primal data and solver metadata ────────────────────
    if has_solver_meta && has_primal_extra
        println(io, fmt.muted, "  │", fmt.reset)
    end

    # ── Solver metadata ───────────────────────────────────────────────────────
    has_iter   && _row(conn(:iter),   "Iterations",            string(_iter))
    has_status && _row(conn(:status), "Status",                string(_status))
    has_msg    && _row(conn(:msg),    "Message",               string(_msg))
    has_cv     && _row(conn(:cv),     "Constraints violation", string(_cv))

    return nothing
end
