"""
Module for extracting solver information from NLP execution statistics.
"""

"""
$(TYPEDSIGNATURES)

Retrieve convergence information from an NLP solution.

This function extracts standardized solver information from NLP solver execution
statistics. It returns a 6-element tuple that can be used to construct solver
metadata for optimal control solutions.

# Arguments

- `nlp_solution::SolverCore.AbstractExecutionStats`: A solver execution statistics object.
- `nlp::NLPModels.AbstractNLPModel`: The NLP model (unused in generic implementation).

# Returns

A 6-element tuple `(objective, iterations, constraints_violation, message, status, successful)`:
- `objective::Float64`: The final objective value
- `iterations::Int`: Number of iterations performed
- `constraints_violation::Float64`: Maximum constraint violation (primal feasibility)
- `message::String`: Solver identifier string (e.g., "Ipopt/generic")
- `status::Symbol`: Termination status (e.g., `:first_order`, `:acceptable`)
- `successful::Bool`: Whether the solver converged successfully

# Notes

The tuple order is different from the `SolverInfos` struct constructor. This function
returns `(objective, ...)` first, but the struct doesn't have an `objective` field
(it's stored separately in the `Solution` object).

# Example

```julia-repl
julia> using CTModels, SolverCore, NLPModels

julia> # After solving an NLP problem with a solver
julia> obj, iter, viol, msg, stat, success = extract_solver_infos(nlp_solution, nlp)
(1.23, 15, 1.0e-6, "Ipopt/generic", :first_order, true)
```

See also: [`SolverInfos`](@ref)
"""
function extract_solver_infos(
    nlp_solution::SolverCore.AbstractExecutionStats,
    ::NLPModels.AbstractNLPModel
)
    objective = nlp_solution.objective
    iterations = nlp_solution.iter
    constraints_violation = nlp_solution.primal_feas
    status = nlp_solution.status
    successful = (status == :first_order) || (status == :acceptable)
    return objective, iterations, constraints_violation, "Ipopt/generic", status, successful
end
