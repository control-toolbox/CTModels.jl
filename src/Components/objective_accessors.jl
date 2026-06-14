# ------------------------------------------------------------------------------ #
# Accessor methods on objective model types
# (MayerObjectiveModel, LagrangeObjectiveModel, BolzaObjectiveModel)
# ------------------------------------------------------------------------------ #

# From MayerObjectiveModel
"""
$(TYPEDSIGNATURES)

Return the criterion (:min or :max).

# Returns
- `Symbol`: The optimisation criterion (`:min` or `:max`).

See also: [`CTModels.Components.mayer`](@ref), [`CTModels.Components.has_mayer_cost`](@ref).
"""
function criterion(model::MayerObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Return the Mayer function.

# Returns
- `M`: The Mayer cost function `(x0, xf, v) -> g(x0, xf, v)`.

See also: [`CTModels.Components.criterion`](@ref), [`CTModels.Components.has_mayer_cost`](@ref).
"""
function mayer(model::MayerObjectiveModel{M})::M where {M<:Function}
    return model.mayer
end

"""
$(TYPEDSIGNATURES)

Return true.

# Returns
- `Bool`: `true` (Mayer cost is defined).

See also: [`CTModels.Components.has_lagrange_cost`](@ref), [`CTModels.Components.mayer`](@ref).
"""
function has_mayer_cost(::MayerObjectiveModel)::Bool
    return true
end

"""
$(TYPEDSIGNATURES)

Return false.

# Returns
- `Bool`: `false` (Lagrange cost is not defined).

See also: [`CTModels.Components.has_mayer_cost`](@ref), [`CTModels.Components.lagrange`](@ref).
"""
function has_lagrange_cost(::MayerObjectiveModel)::Bool
    return false
end

# From LagrangeObjectiveModel
"""
$(TYPEDSIGNATURES)

Return the criterion (:min or :max).

# Returns
- `Symbol`: The optimisation criterion (`:min` or `:max`).

See also: [`CTModels.Components.lagrange`](@ref), [`CTModels.Components.has_lagrange_cost`](@ref).
"""
function criterion(model::LagrangeObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange function.

# Returns
- `L`: The Lagrange integrand `(t, x, u, v) -> f⁰(t, x, u, v)`.

See also: [`CTModels.Components.criterion`](@ref), [`CTModels.Components.has_lagrange_cost`](@ref).
"""
function lagrange(model::LagrangeObjectiveModel{L})::L where {L<:Function}
    return model.lagrange
end

"""
$(TYPEDSIGNATURES)

Return false.

# Returns
- `Bool`: `false` (Mayer cost is not defined).

See also: [`CTModels.Components.has_lagrange_cost`](@ref), [`CTModels.Components.mayer`](@ref).
"""
function has_mayer_cost(::LagrangeObjectiveModel)::Bool
    return false
end

"""
$(TYPEDSIGNATURES)

Return true.

# Returns
- `Bool`: `true` (Lagrange cost is defined).

See also: [`CTModels.Components.has_mayer_cost`](@ref), [`CTModels.Components.lagrange`](@ref).
"""
function has_lagrange_cost(::LagrangeObjectiveModel)::Bool
    return true
end

# From BolzaObjectiveModel
"""
$(TYPEDSIGNATURES)

Return the criterion (:min or :max).

# Returns
- `Symbol`: The optimisation criterion (`:min` or `:max`).

See also: [`CTModels.Components.mayer`](@ref), [`CTModels.Components.lagrange`](@ref), [`CTModels.Components.has_mayer_cost`](@ref).
"""
function criterion(model::BolzaObjectiveModel)::Symbol
    return model.criterion
end

"""
$(TYPEDSIGNATURES)

Return the Mayer function.

# Returns
- `M`: The Mayer cost function.

See also: [`CTModels.Components.criterion`](@ref), [`CTModels.Components.lagrange`](@ref), [`CTModels.Components.has_mayer_cost`](@ref).
"""
function mayer(model::BolzaObjectiveModel{M,<:Function})::M where {M<:Function}
    return model.mayer
end

"""
$(TYPEDSIGNATURES)

Return the Lagrange function.

# Returns
- `L`: The Lagrange integrand.

See also: [`CTModels.Components.criterion`](@ref), [`CTModels.Components.mayer`](@ref), [`CTModels.Components.has_lagrange_cost`](@ref).
"""
function lagrange(model::BolzaObjectiveModel{<:Function,L})::L where {L<:Function}
    return model.lagrange
end

"""
$(TYPEDSIGNATURES)

Return true.

# Returns
- `Bool`: `true` (Mayer cost is defined).

See also: [`CTModels.Components.has_lagrange_cost`](@ref), [`CTModels.Components.mayer`](@ref).
"""
function has_mayer_cost(::BolzaObjectiveModel)::Bool
    return true
end

"""
$(TYPEDSIGNATURES)

Return true.

# Returns
- `Bool`: `true` (Lagrange cost is defined).

See also: [`CTModels.Components.has_mayer_cost`](@ref), [`CTModels.Components.lagrange`](@ref).
"""
function has_lagrange_cost(::BolzaObjectiveModel)::Bool
    return true
end

# ------------------------------------------------------------------------------ #
# ALIASES (for naming consistency)
# ------------------------------------------------------------------------------ #

"""
Alias for `has_mayer_cost`.

See also: [`CTModels.Components.has_mayer_cost`](@ref).
"""
const is_mayer_cost_defined = has_mayer_cost

"""
Alias for `has_lagrange_cost`.

See also: [`CTModels.Components.has_lagrange_cost`](@ref).
"""
const is_lagrange_cost_defined = has_lagrange_cost
