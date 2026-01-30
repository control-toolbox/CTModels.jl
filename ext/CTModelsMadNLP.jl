"""
Extension for CTModels to support MadNLP solver.

This extension provides a specialized implementation of `extract_solver_infos`
for MadNLP solver execution statistics, handling MadNLP-specific behavior such as
objective sign handling and status codes.
"""
module CTModelsMadNLP

using CTModels
using MadNLP
using DocStringExtensions

"""
$(TYPEDSIGNATURES)

Extract solver information from MadNLP execution statistics.

This method handles MadNLP-specific behavior:
- Objective sign depends on whether the problem is a minimization or maximization
- Status codes are MadNLP-specific (e.g., `:SOLVE_SUCCEEDED`, `:SOLVED_TO_ACCEPTABLE_LEVEL`)

# Arguments

- `nlp_solution::MadNLP.MadNLPExecutionStats`: MadNLP execution statistics
- `minimize::Bool`: Whether the problem is a minimization problem or not

# Returns

A 6-element tuple `(objective, iterations, constraints_violation, message, status, successful)`:
- `objective::Float64`: The final objective value (sign corrected for minimization)
- `iterations::Int`: Number of iterations performed
- `constraints_violation::Float64`: Maximum constraint violation (primal feasibility)
- `message::String`: Solver identifier string ("MadNLP")
- `status::Symbol`: MadNLP termination status
- `successful::Bool`: Whether the solver converged successfully

# Example

```julia-repl
julia> using CTModels, MadNLP

julia> # After solving with MadNLP
julia> obj, iter, viol, msg, stat, success = extract_solver_infos(nlp_solution, minimize)
(1.23, 15, 1.0e-6, "MadNLP", :SOLVE_SUCCEEDED, true)
```
"""
function CTModels.extract_solver_infos(
    nlp_solution::MadNLP.MadNLPExecutionStats,
    minimize::Bool, # whether the problem is a minimization problem or not
)
    # Get minimization flag and adjust objective sign accordingly
    objective = minimize ? nlp_solution.objective : -nlp_solution.objective

    # Extract standard fields
    iterations = nlp_solution.iter
    constraints_violation = nlp_solution.primal_feas

    # Convert MadNLP status to Symbol
    status = Symbol(nlp_solution.status)

    # Check if solution is successful based on MadNLP status codes
    successful = (status == :SOLVE_SUCCEEDED) || (status == :SOLVED_TO_ACCEPTABLE_LEVEL)

    return objective, iterations, constraints_violation, "MadNLP", status, successful
end

end # module CTModelsMadNLP