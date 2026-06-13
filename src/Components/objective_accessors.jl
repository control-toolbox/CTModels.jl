# ------------------------------------------------------------------------------ #
# Accessor methods on objective model types
# (MayerObjectiveModel, LagrangeObjectiveModel, BolzaObjectiveModel)
# ------------------------------------------------------------------------------ #

# From MayerObjectiveModel
"""
$(TYPEDSIGNATURES)

Return the criterion (:min or :max).
"""
function criterion(model::MayerObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Return the Mayer function.
"""
function mayer(model::MayerObjectiveModel{M})::M where {M<:Function}
    return model.mayer
end

"""
$(TYPEDSIGNATURES)

Return true.
"""
function has_mayer_cost(::MayerObjectiveModel)::Bool
    return true
end

"""
$(TYPEDSIGNATURES)

Return false.
"""
function has_lagrange_cost(::MayerObjectiveModel)::Bool
    return false
end

# From LagrangeObjectiveModel
"""
$(TYPEDSIGNATURES)

Return the criterion (:min or :max).
"""
function criterion(model::LagrangeObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange function.
"""
function lagrange(model::LagrangeObjectiveModel{L})::L where {L<:Function}
    return model.lagrange
end

"""
$(TYPEDSIGNATURES)

Return false.
"""
function has_mayer_cost(::LagrangeObjectiveModel)::Bool
    return false
end

"""
$(TYPEDSIGNATURES)

Return true.
"""
function has_lagrange_cost(::LagrangeObjectiveModel)::Bool
    return true
end

# From BolzaObjectiveModel
"""
$(TYPEDSIGNATURES)

Return the criterion (:min or :max).
"""
function criterion(model::BolzaObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Return the Mayer function.
"""
function mayer(model::BolzaObjectiveModel{M,<:Function})::M where {M<:Function}
    return model.mayer
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange function.
"""
function lagrange(model::BolzaObjectiveModel{<:Function,L})::L where {L<:Function}
    return model.lagrange
end

"""
$(TYPEDSIGNATURES)

Return true.
"""
function has_mayer_cost(::BolzaObjectiveModel)::Bool
    return true
end

"""
$(TYPEDSIGNATURES)

Return true.
"""
function has_lagrange_cost(::BolzaObjectiveModel)::Bool
    return true
end

# ------------------------------------------------------------------------------ #
# ALIASES (for naming consistency)
# ------------------------------------------------------------------------------ #

"""
Alias for `has_mayer_cost`.
"""
const is_mayer_cost_defined = has_mayer_cost

"""
Alias for `has_lagrange_cost`.
"""
const is_lagrange_cost_defined = has_lagrange_cost
