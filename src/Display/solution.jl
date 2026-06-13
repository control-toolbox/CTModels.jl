# ------------------------------------------------------------------------------ #
# Base.show for Solution
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Print the solution.
"""
function Base.show(io::IO, ::MIME"text/plain", sol::Solutions.Solution)
    # Solver summary
    println(io, "• Solver:")
    println(io, "  ✓ Successful  : ", Solutions.successful(sol))
    println(io, "  │  Status     : ", Solutions.status(sol))
    println(io, "  │  Message    : ", Solutions.message(sol))
    println(io, "  │  Iterations : ", Solutions.iterations(sol))
    println(io, "  │  Objective  : ", Models.objective(sol))
    println(io, "  └─ Constraints violation : ", Solutions.constraints_violation(sol))

    # Variable (if defined)
    if Models.variable_dimension(sol) > 0
        components = Models.variable_components(sol)
        var_name = Models.variable_name(sol)

        # Simplified case: dimension 1 and name identical
        if Models.variable_dimension(sol) == 1 && var_name == components[1]
            println(io, "\n• Variable: ", var_name, " = ", Models.variable(sol))
        else
            println(
                io,
                "\n• Variable: ",
                var_name,
                " = (",
                join(components, ", "),
                ") = ",
                Models.variable(sol),
            )
        end
        if Solutions.dim_dual_variable_constraints_box(sol) > 0 &&
            Components.dim_variable_constraints_box(Solutions.model(sol)) > 0
            println(io, "  │  Var dual (lb) : ", Solutions.variable_constraints_lb_dual(sol))
            println(io, "  └─ Var dual (ub) : ", Solutions.variable_constraints_ub_dual(sol))
        end
    end

    # Boundary constraints duals
    if Components.dim_boundary_constraints_nl(sol) > 0
        println(io, "\n• Boundary duals: ", Solutions.boundary_constraints_dual(sol))
    end
end
