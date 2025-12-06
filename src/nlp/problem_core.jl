# builders of NLP models
function (builder::ADNLPModelBuilder)(initial_guess; kwargs...)::ADNLPModels.ADNLPModel
    return builder.f(initial_guess; kwargs...)
end

function (builder::ExaModelBuilder)(
    ::Type{BaseType}, initial_guess; kwargs...
)::ExaModels.ExaModel where {BaseType<:AbstractFloat}
    return builder.f(BaseType, initial_guess; kwargs...)
end

# helpers to build solutions

# problem

function get_exa_model_builder(prob::AbstractOptimizationProblem)
    throw(
        CTBase.NotImplemented("get_exa_model_builder not implemented for $(typeof(prob))")
    )
end

function get_adnlp_model_builder(prob::AbstractOptimizationProblem)
    throw(
        CTBase.NotImplemented("get_adnlp_model_builder not implemented for $(typeof(prob))")
    )
end

function get_adnlp_solution_builder(prob::AbstractOptimizationProblem)
    throw(
        CTBase.NotImplemented(
            "get_adnlp_solution_builder not implemented for $(typeof(prob))"
        ),
    )
end

function get_exa_solution_builder(prob::AbstractOptimizationProblem)
    throw(
        CTBase.NotImplemented(
            "get_exa_solution_builder not implemented for $(typeof(prob))"
        ),
    )
end