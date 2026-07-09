# ------------------------------------------------------------------------------ #
# Base.show for Solution
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print the solution to `io` with semantic ANSI formatting.

Displays the solver summary (status, iterations, objective, constraints violation),
the optimisation variable (if defined), and boundary constraint duals (if present).

# Returns
- `Nothing`: Prints to `io` and returns nothing.

See also: [`CTModels.Solutions.Solution`](@ref)
"""
function Base.show(io::IO, ::MIME"text/plain", sol::Solution)
    fmt = Core.get_format_codes(io)

    # Solver summary
    ok = Solutions.successful(sol)
    ok_code = ok ? fmt.success : fmt.error
    println(io, fmt.name, "• Solver:", fmt.reset)
    println(io, "  ", ok_code, "✓ Successful  : ", ok, fmt.reset)
    println(
        io,
        "  ",
        fmt.label,
        "│  Status     : ",
        fmt.reset,
        fmt.value,
        Solutions.status(sol),
        fmt.reset,
    )
    println(
        io,
        "  ",
        fmt.label,
        "│  Message    : ",
        fmt.reset,
        fmt.value,
        Solutions.message(sol),
        fmt.reset,
    )
    println(
        io,
        "  ",
        fmt.label,
        "│  Iterations : ",
        fmt.reset,
        fmt.value,
        Solutions.iterations(sol),
        fmt.reset,
    )
    println(
        io,
        "  ",
        fmt.label,
        "│  Objective  : ",
        fmt.reset,
        fmt.value,
        Components.objective(sol),
        fmt.reset,
    )
    println(
        io,
        "  ",
        fmt.label,
        "└─ Constraints violation : ",
        fmt.reset,
        fmt.value,
        Solutions.constraints_violation(sol),
        fmt.reset,
    )

    # Variable (if defined)
    if Models.variable_dimension(sol) > 0
        components = Models.variable_components(sol)
        var_name = Models.variable_name(sol)

        # Simplified case: dimension 1 and name identical
        if Models.variable_dimension(sol) == 1 && var_name == components[1]
            println(
                io,
                "\n",
                fmt.name,
                "• Variable:",
                fmt.reset,
                " ",
                fmt.value,
                var_name,
                fmt.reset,
                " = ",
                fmt.value,
                Components.variable(sol),
                fmt.reset,
            )
        else
            println(
                io,
                "\n",
                fmt.name,
                "• Variable:",
                fmt.reset,
                " ",
                fmt.value,
                var_name,
                fmt.reset,
                " = (",
                fmt.value,
                join(components, ", "),
                fmt.reset,
                ") = ",
                fmt.value,
                Components.variable(sol),
                fmt.reset,
            )
        end
        if Solutions.has_duals(sol) &&
            Solutions.dim_dual_variable_constraints_box(sol) > 0 &&
            Components.dim_variable_constraints_box(Solutions.model(sol)) > 0
            println(
                io,
                "  ",
                fmt.label,
                "│  Var dual (lb) : ",
                fmt.reset,
                fmt.value,
                Solutions.variable_constraints_lb_dual(sol),
                fmt.reset,
            )
            println(
                io,
                "  ",
                fmt.label,
                "└─ Var dual (ub) : ",
                fmt.reset,
                fmt.value,
                Solutions.variable_constraints_ub_dual(sol),
                fmt.reset,
            )
        end
    end

    # Boundary constraints duals
    if Solutions.has_duals(sol) && Components.dim_boundary_constraints_nl(sol) > 0
        println(
            io,
            "\n",
            fmt.name,
            "• Boundary duals:",
            fmt.reset,
            " ",
            fmt.value,
            Solutions.boundary_constraints_dual(sol),
            fmt.reset,
        )
    end
end
