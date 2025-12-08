# builders of NLP models
"""
$(TYPEDSIGNATURES)

Invoke the ADNLPModels model builder to construct an NLP model from an initial guess.
"""
function (builder::ADNLPModelBuilder)(initial_guess; kwargs...)::ADNLPModels.ADNLPModel
    return builder.f(initial_guess; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Invoke the ExaModels model builder to construct an NLP model from an initial guess.

The `BaseType` parameter specifies the floating-point type for the model.
"""
function (builder::ExaModelBuilder)(
    ::Type{BaseType}, initial_guess; kwargs...
)::ExaModels.ExaModel where {BaseType<:AbstractFloat}
    return builder.f(BaseType, initial_guess; kwargs...)
end

# helpers to build solutions

# problem

"""
$(TYPEDSIGNATURES)

Interface method for [`AbstractOptimizationProblem`](@ref).

Concrete problem types that support the ExaModels back-end must
specialize this function to return the [`ExaModelBuilder`](@ref) used to
construct the corresponding NLP model. The default implementation throws
`CTBase.NotImplemented`.
"""
function get_exa_model_builder(prob::AbstractOptimizationProblem)
    throw(
        CTBase.NotImplemented("get_exa_model_builder not implemented for $(typeof(prob))"),
    )
end

"""
$(TYPEDSIGNATURES)

Interface method for [`AbstractOptimizationProblem`](@ref).

Concrete problem types that support the ADNLPModels back-end must
specialize this function to return the [`ADNLPModelBuilder`](@ref) used
to construct the corresponding NLP model. The default implementation
throws `CTBase.NotImplemented`.
"""
function get_adnlp_model_builder(prob::AbstractOptimizationProblem)
    throw(
        CTBase.NotImplemented("get_adnlp_model_builder not implemented for $(typeof(prob))"),
    )
end

"""
$(TYPEDSIGNATURES)

Interface method for [`AbstractOptimizationProblem`](@ref).

Concrete problem types that support ADNLPModels must specialize this
function to return the [`ADNLPSolutionBuilder`](@ref) used to convert NLP
solutions into the desired representation. The default implementation
throws `CTBase.NotImplemented`.
"""
function get_adnlp_solution_builder(prob::AbstractOptimizationProblem)
    throw(
        CTBase.NotImplemented(
            "get_adnlp_solution_builder not implemented for $(typeof(prob))",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Interface method for [`AbstractOptimizationProblem`](@ref).

Concrete problem types that support ExaModels must specialize this
function to return the [`ExaSolutionBuilder`](@ref) used to convert NLP
solutions into the desired representation. The default implementation
throws `CTBase.NotImplemented`.
"""
function get_exa_solution_builder(prob::AbstractOptimizationProblem)
    throw(
        CTBase.NotImplemented(
            "get_exa_solution_builder not implemented for $(typeof(prob))",
        ),
    )
end