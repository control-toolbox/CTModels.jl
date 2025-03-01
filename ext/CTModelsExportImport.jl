module CTModelsExportImport

using CTBase
using CTModels
using DocStringExtensions

using JLD2
using JSON3

"""
$(TYPEDSIGNATURES)
  
Export OCP solution in JLD / JSON format
"""
function CTModels.export_ocp_solution(
    sol::CTModels.Solution; filename_prefix="solution", format=:JLD
)
    if format == :JLD
        save_object(filename_prefix * ".jld2", sol)
    elseif format == :JSON
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
        )
        open(filename_prefix * ".json", "w") do io
            JSON3.pretty(io, blob)
        end
    else
        throw(
            CTBase.IncorrectArgument(
                "Export_ocp_solution: unknown format (should be :JLD or :JSON): ", format
            ),
        )
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)
  
Read OCP solution in JLD / JSON format
"""
function CTModels.import_ocp_solution(
    ocp::CTModels.Model; filename_prefix="solution", format=:JLD
)
    if format == :JLD
        return load_object(filename_prefix * ".jld2")
    elseif format == :JSON
        json_string = read(filename_prefix * ".json", String)
        blob = JSON3.read(json_string)

        # get state
        X = stack(blob["state"]; dims=1)
        # if X is a Vector, convert it to a Matrix
        if X isa Vector
            X = Matrix{Float64}(reduce(hcat, X)')
        end
        #println("typeof(state): ", typeof(X))
        #println("size(state): ", size(X))

        # get control
        U = stack(blob["control"]; dims=1)
        # if U is a Vector, convert it to a Matrix
        if U isa Vector
            U = Matrix{Float64}(reduce(hcat, U)')
        end
        #println("typeof(control): ", typeof(U))

        # get costate
        P = stack(blob["costate"]; dims=1)
        # if P is a Vector, convert it to a Matrix
        if P isa Vector
            P = Matrix{Float64}(reduce(hcat, P)')
        end
        #println("typeof(costate): ", typeof(P))

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
        )
    else
        throw(
            CTBase.IncorrectArgument(
                "Export_ocp_solution: unknown format (should be :JLD or :JSON): ", format
            ),
        )
    end
end

end
