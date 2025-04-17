module CTModelsJSON

using CTModels
using DocStringExtensions

using JSON3

"""
$(TYPEDSIGNATURES)
  
Export OCP solution in JSON format
"""
function CTModels.export_ocp_solution(
    ::CTModels.JSON3Tag, sol::CTModels.Solution; filename_prefix="solution"
)
    T = CTModels.time_grid(sol)

    blob = Dict(
        "time_grid" => CTModels.time_grid(sol),
        "state" => CTModels.state_discretized(sol),
        "control" => CTModels.control_discretized(sol),
        "variable" => CTModels.variable(sol),
        "costate" => CTModels.costate_discretized(sol)[1:(end - 1), :],
        "objective" => CTModels.objective(sol),
        "iterations" => CTModels.iterations(sol),
        "constraints_violation" => CTModels.constraints_violation(sol),
        "message" => CTModels.message(sol),
        "stopping" => CTModels.stopping(sol),
        "success" => CTModels.success(sol),
        "path_constraints" => CTModels.discretize(CTModels.path_constraints(sol), T),
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
        "boundary_constraints" => CTModels.boundary_constraints(sol),            # ctVector or Nothing
        "boundary_constraints_dual" => CTModels.boundary_constraints_dual(sol),       # ctVector or Nothing
        "variable_constraints_lb_dual" => CTModels.variable_constraints_lb_dual(sol),    # ctVector or Nothing
        "variable_constraints_ub_dual" => CTModels.variable_constraints_ub_dual(sol),    # ctVector or Nothing
    )

    open(filename_prefix * ".json", "w") do io
        JSON3.pretty(io, blob)
    end

    return nothing
end

"""
$(TYPEDSIGNATURES)
  
Read OCP solution in JSON format
"""
function CTModels.import_ocp_solution(
    ::CTModels.JSON3Tag, ocp::CTModels.Model; filename_prefix="solution"
)
    json_string = read(filename_prefix * ".json", String)
    blob = JSON3.read(json_string)

    # get state
    X = stack(blob["state"]; dims=1)
    if X isa Vector # if X is a Vector, convert it to a Matrix
        X = Matrix{Float64}(reduce(hcat, X)')
    end

    # get control
    U = stack(blob["control"]; dims=1)
    if U isa Vector # if U is a Vector, convert it to a Matrix
        U = Matrix{Float64}(reduce(hcat, U)')
    end

    # get costate
    P = stack(blob["costate"]; dims=1)
    if P isa Vector # if P is a Vector, convert it to a Matrix
        P = Matrix{Float64}(reduce(hcat, P)')
    end

    # get path constraints (and dual): convert to matrix
    path_constraints = if isnothing(blob["path_constraints"])
        nothing
    else
        stack(blob["path_constraints"]; dims=1)
    end
    if path_constraints isa Vector # if path_constraints is a Vector, convert it to a Matrix
        path_constraints = Matrix{Float64}(reduce(hcat, path_constraints)')
    end
    path_constraints_dual = if isnothing(blob["path_constraints_dual"])
        nothing
    else
        stack(blob["path_constraints_dual"]; dims=1)
    end
    if path_constraints_dual isa Vector # if path_constraints_dual is a Vector, convert it to a Matrix
        path_constraints_dual = Matrix{Float64}(reduce(hcat, path_constraints_dual)')
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
    end

    # get boundary constraints (and dual): no conversion needed
    boundary_constraints = blob["boundary_constraints"]
    boundary_constraints_dual = blob["boundary_constraints_dual"]

    # get variable constraints dual: no conversion needed
    variable_constraints_lb_dual = blob["variable_constraints_lb_dual"]
    variable_constraints_ub_dual = blob["variable_constraints_ub_dual"]

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
        stopping=Symbol(blob.stopping),
        success=blob.success,
        path_constraints=path_constraints,
        path_constraints_dual=path_constraints_dual,
        state_constraints_lb_dual=state_constraints_lb_dual,
        state_constraints_ub_dual=state_constraints_ub_dual,
        control_constraints_lb_dual=control_constraints_lb_dual,
        control_constraints_ub_dual=control_constraints_ub_dual,
        boundary_constraints=boundary_constraints,
        boundary_constraints_dual=boundary_constraints_dual,
        variable_constraints_lb_dual=variable_constraints_lb_dual,
        variable_constraints_ub_dual=variable_constraints_ub_dual,
    )
end

end
