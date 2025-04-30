module CTModelsJLD

using CTModels
using DocStringExtensions
using JLD2

"""
$(TYPEDSIGNATURES)
  
Export OCP solution in JLD format
"""
function CTModels.export_ocp_solution(
    ::CTModels.JLD2Tag, sol::CTModels.Solution; filename::String="solution"
)
    save_object(filename * ".jld2", sol)
    return nothing
end

"""
$(TYPEDSIGNATURES)
  
Import OCP solution in JLD format
"""
function CTModels.import_ocp_solution(
    ::CTModels.JLD2Tag, ocp::CTModels.Model; filename::String="solution"
)
    return load_object(filename * ".jld2")
end

end
