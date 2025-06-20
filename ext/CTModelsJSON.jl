module CTModelsJSON

using CTModels
using DocStringExtensions

using JSON3

"""
$(TYPEDSIGNATURES)

Export an optimal control solution to a `.json` file using the JSON3 format.

This function serializes a `CTModels.Solution` into a structured JSON dictionary,
including all primal and dual information, which can be read by external tools.

# Arguments
- `::CTModels.JSON3Tag`: A tag used to dispatch the export method for JSON3.
- `sol::CTModels.Solution`: The solution to be saved.

# Keyword Arguments
- `filename::String = "solution"`: Base filename. The `.json` extension is automatically appended.

# Notes
The exported JSON includes the time grid, state, control, costate, objective, solver info, and all constraint duals (if available).

# Example
```julia-repl
julia> using JSON3
julia> export_ocp_solution(JSON3Tag(), sol; filename="mysolution")
# → creates "mysolution.json"
```
"""
function CTModels.export_ocp_solution(
    ::CTModels.JSON3Tag, sol::CTModels.Solution; filename::String
)
    T = CTModels.time_grid(sol)

    blob = Dict(
        "time_grid" => CTModels.time_grid(sol),
        "state" => CTModels.discretize(CTModels.state(sol), T),
        "control" => CTModels.discretize(CTModels.control(sol), T),
        "variable" => CTModels.variable(sol),
        "costate" => CTModels.discretize(CTModels.costate(sol), T),
        "objective" => CTModels.objective(sol),
        "iterations" => CTModels.iterations(sol),
        "constraints_violation" => CTModels.constraints_violation(sol),
        "message" => CTModels.message(sol),
        "status" => CTModels.status(sol),
        "successful" => CTModels.successful(sol),
        "path_constraints_dual" =>
            CTModels.discretize(CTModels.path_constraints_dual(sol), T),
        "state_constraints_lb_dual" =>
            CTModels.discretize(CTModels.state_constraints_lb_dual(sol), T),
        "state_constraints_ub_dual" =>
            CTModels.discretize(CTModels.state_constraints_ub_dual(sol), T),
        "control_constraints_lb_dual" =>
            CTModels.discretize(CTModels.control_constraints_lb_dual(sol), T),
        "control_constraints_ub_dual" =>
            CTModels.discretize(CTModels.control_constraints_ub_dual(sol), T),
        "boundary_constraints_dual" => CTModels.boundary_constraints_dual(sol),       # ctVector or Nothing
        "variable_constraints_lb_dual" => CTModels.variable_constraints_lb_dual(sol),    # ctVector or Nothing
        "variable_constraints_ub_dual" => CTModels.variable_constraints_ub_dual(sol),    # ctVector or Nothing
    )

    open(filename * ".json", "w") do io
        JSON3.pretty(io, blob)
    end

    return nothing
end

"""
$(TYPEDSIGNATURES)

Import an optimal control solution from a `.json` file exported with `export_ocp_solution`.

This function reads the JSON contents and reconstructs a `CTModels.Solution` object,
including the discretized primal and dual trajectories.

# Arguments
- `::CTModels.JSON3Tag`: A tag used to dispatch the import method for JSON3.
- `ocp::CTModels.Model`: The model associated with the optimal control problem. Used to rebuild the full solution.

# Keyword Arguments
- `filename::String = "solution"`: Base filename. The `.json` extension is automatically appended.

# Returns
- `CTModels.Solution`: A reconstructed solution instance.

# Notes
Handles both vector and matrix encodings of signals. If dual fields are missing or `null`, the corresponding attributes are set to `nothing`.

# Example
```julia-repl
julia> using JSON3
julia> sol = import_ocp_solution(JSON3Tag(), model; filename="mysolution")
```
"""
function CTModels.import_ocp_solution(
    ::CTModels.JSON3Tag, ocp::CTModels.Model; filename::String
)
    json_string = read(filename * ".json", String)
    blob = JSON3.read(json_string)

    # get state
    X = stack(blob["state"]; dims=1)
    if X isa Vector # if X is a Vector, convert it to a Matrix
        X = Matrix{Float64}(reduce(hcat, X)')
    else
        X = Matrix{Float64}(X)
    end

    # get control
    U = stack(blob["control"]; dims=1)
    if U isa Vector # if U is a Vector, convert it to a Matrix
        U = Matrix{Float64}(reduce(hcat, U)')
    else
        U = Matrix{Float64}(U)
    end

    # get costate
    P = stack(blob["costate"]; dims=1)
    if P isa Vector # if P is a Vector, convert it to a Matrix
        P = Matrix{Float64}(reduce(hcat, P)')
    else
        P = Matrix{Float64}(P)
    end

    # get dual path constraints: convert to matrix
    path_constraints_dual = if isnothing(blob["path_constraints_dual"])
        nothing
    else
        stack(blob["path_constraints_dual"]; dims=1)
    end
    if path_constraints_dual isa Vector # if path_constraints_dual is a Vector, convert it to a Matrix
        path_constraints_dual = Matrix{Float64}(reduce(hcat, path_constraints_dual)')
    elseif !isnothing(path_constraints_dual)
        path_constraints_dual = Matrix{Float64}(path_constraints_dual)
    end

    # get state constraints (and dual): convert to matrix
    state_constraints_lb_dual = if isnothing(blob["state_constraints_lb_dual"])
        nothing
    else
        stack(blob["state_constraints_lb_dual"]; dims=1)
    end
    if state_constraints_lb_dual isa Vector # if state_constraints_lb_dual is a Vector, convert it to a Matrix
        state_constraints_lb_dual = Matrix{Float64}(
            reduce(hcat, state_constraints_lb_dual)'
        )
    elseif !isnothing(state_constraints_lb_dual)
        state_constraints_lb_dual = Matrix{Float64}(state_constraints_lb_dual)
    end
    state_constraints_ub_dual = if isnothing(blob["state_constraints_ub_dual"])
        nothing
    else
        stack(blob["state_constraints_ub_dual"]; dims=1)
    end
    if state_constraints_ub_dual isa Vector # if state_constraints_ub_dual is a Vector, convert it to a Matrix
        state_constraints_ub_dual = Matrix{Float64}(
            reduce(hcat, state_constraints_ub_dual)'
        )
    elseif !isnothing(state_constraints_ub_dual)
        state_constraints_ub_dual = Matrix{Float64}(state_constraints_ub_dual)
    end

    # get control constraints (and dual): convert to matrix
    control_constraints_lb_dual = if isnothing(blob["control_constraints_lb_dual"])
        nothing
    else
        stack(blob["control_constraints_lb_dual"]; dims=1)
    end
    if control_constraints_lb_dual isa Vector # if control_constraints_lb_dual is a Vector, convert it to a Matrix
        control_constraints_lb_dual = Matrix{Float64}(
            reduce(hcat, control_constraints_lb_dual)'
        )
    elseif !isnothing(control_constraints_lb_dual)
        control_constraints_lb_dual = Matrix{Float64}(control_constraints_lb_dual)
    end
    control_constraints_ub_dual = if isnothing(blob["control_constraints_ub_dual"])
        nothing
    else
        stack(blob["control_constraints_ub_dual"]; dims=1)
    end
    if control_constraints_ub_dual isa Vector # if control_constraints_ub_dual is a Vector, convert it to a Matrix
        control_constraints_ub_dual = Matrix{Float64}(
            reduce(hcat, control_constraints_ub_dual)'
        )
    elseif !isnothing(control_constraints_ub_dual)
        control_constraints_ub_dual = Matrix{Float64}(control_constraints_ub_dual)
    end

    # get dual of boundary constraints: no conversion needed
    boundary_constraints_dual = blob["boundary_constraints_dual"]
    if !isnothing(boundary_constraints_dual)
        boundary_constraints_dual = Vector{Float64}(boundary_constraints_dual)
    end

    # get variable constraints dual: no conversion needed
    variable_constraints_lb_dual = blob["variable_constraints_lb_dual"]
    if !isnothing(variable_constraints_lb_dual)
        variable_constraints_lb_dual = Vector{Float64}(blob["variable_constraints_lb_dual"])
    end
    variable_constraints_ub_dual = blob["variable_constraints_ub_dual"]
    if !isnothing(variable_constraints_ub_dual)
        variable_constraints_ub_dual = Vector{Float64}(blob["variable_constraints_ub_dual"])
    end

    # NB. convert vect{vect} to matrix
    return CTModels.build_solution(
        ocp,
        Vector{Float64}(blob.time_grid),
        X,
        U,
        Vector{Float64}(blob.variable),
        P;
        objective=Float64(blob.objective),
        iterations=blob.iterations,
        constraints_violation=Float64(blob.constraints_violation),
        message=blob.message,
        status=Symbol(blob.status),
        successful=blob.successful,
        path_constraints_dual=path_constraints_dual,
        state_constraints_lb_dual=state_constraints_lb_dual,
        state_constraints_ub_dual=state_constraints_ub_dual,
        control_constraints_lb_dual=control_constraints_lb_dual,
        control_constraints_ub_dual=control_constraints_ub_dual,
        boundary_constraints_dual=boundary_constraints_dual,
        variable_constraints_lb_dual=variable_constraints_lb_dual,
        variable_constraints_ub_dual=variable_constraints_ub_dual,
    )
end

end
