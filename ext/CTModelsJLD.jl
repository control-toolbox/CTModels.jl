module CTModelsJLD

using CTBase
using CTModels
using DocStringExtensions
using JLD2

"""
$(TYPEDSIGNATURES)
  
Export OCP solution in JLD format
"""
function CTModels.export_ocp_solution(
    ::CTModels.JLD2Tag, sol::CTModels.Solution; filename_prefix="solution"
)
    save_object(filename_prefix * ".jld2", sol)
    return nothing
end

"""
$(TYPEDSIGNATURES)
  
Import OCP solution in JLD format
"""
function CTModels.import_ocp_solution(
    ::CTModels.JLD2Tag, ocp::CTModels.Model; filename_prefix="solution"
)
    return load_object(filename_prefix * ".jld2")
end

end
