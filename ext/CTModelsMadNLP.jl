"""
Extension for CTModels to support MadNLP solver.

This extension provides a specialized implementation of `extract_solver_infos`
for MadNLP solver execution statistics, handling MadNLP-specific behavior such as
objective sign handling and status codes.
"""
module CTModelsMadNLP

using CTModels
using MadNLP
using NLPModels
using DocStringExtensions

"""
$(TYPEDSIGNATURES)

Extract solver information from MadNLP execution statistics.

This method handles MadNLP-specific behavior:
- Objective sign depends on whether the problem is a minimization or maximization
- Status codes are MadNLP-specific (e.g., `:SOLVE_SUCCEEDED`, `:SOLVED_TO_ACCEPTABLE_LEVEL`)

# Arguments

- `nlp_solution::MadNLP.MadNLPExecutionStats`: MadNLP execution statistics
- `nlp::NLPModels.AbstractNLPModel`: The NLP model

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
julia> using CTModels, MadNLP, NLPModels

julia> # After solving with MadNLP
julia> obj, iter, viol, msg, stat, success = extract_solver_infos(nlp_solution, nlp)
(1.23, 15, 1.0e-6, "MadNLP", :SOLVE_SUCCEEDED, true)
```
"""
function CTModels.extract_solver_infos(
    nlp_solution::MadNLP.MadNLPExecutionStats,
    nlp::NLPModels.AbstractNLPModel
)
    # Get minimization flag and adjust objective sign accordingly
    minimize = NLPModels.get_minimize(nlp)
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
