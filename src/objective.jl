# Calls to Mayer function
function (F::Mayer{<:Function, <:Val, <:Val})(r::ctVector, x0::State, xf::State, v::Variable)::Nothing
    F.f(r, x0, xf, v)
    return nothing
end

function (F::Mayer{<:Function, Val{1}, <:Val})(r::ctVector, x0::State, xf::State, v::Variable)::Nothing
    F.f(r, x0[1], xf[1], v)
    return nothing
end

function (F::Mayer{<:Function, <:Val, Val{1}})(r::ctVector, x0::State, xf::State, v::Variable)::Nothing 
    F.f(r, x0, xf, v[1])
    return nothing
end

function (F::Mayer{<:Function, Val{1}, Val{1}})(r::ctVector, x0::State, xf::State, v::Variable)::Nothing
    F.f(r, x0[1], xf[1], v[1])
    return nothing
end

function (F::Mayer{<:Function, <:Val, Val{0}})(r::ctVector, x0::State, xf::State, v::Variable)::Nothing
    F.f(r, x0, xf)
    return nothing
end

function (F::Mayer{<:Function, Val{1}, Val{0}})(r::ctVector, x0::State, xf::State, v::Variable)::Nothing
    F.f(r, x0[1], xf[1])
    return nothing
end

# Calls to Lagrange function
function (F::Lagrange{<:Function, <:Val, <:Val, <:Val})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing 
    F.f(r, t, x, u, v)
    return nothing
end

function (F::Lagrange{<:Function, Val{1}, <:Val, <:Val})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x[1], u, v)
    return nothing
end

function (F::Lagrange{<:Function, <:Val, Val{1}, <:Val})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x, u[1], v)
    return nothing
end

function (F::Lagrange{<:Function, Val{1}, Val{1}, <:Val})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x[1], u[1], v)
    return nothing
end

function (F::Lagrange{<:Function, <:Val, <:Val, Val{1}})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x, u, v[1])
    return nothing
end

function (F::Lagrange{<:Function, Val{1}, <:Val, Val{1}})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x[1], u, v[1])
    return nothing
end

function (F::Lagrange{<:Function, <:Val, Val{1}, Val{1}})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x, u[1], v[1])
    return nothing
end

function (F::Lagrange{<:Function, Val{1}, Val{1}, Val{1}})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x[1], u[1], v[1])
    return nothing
end

function (F::Lagrange{<:Function, <:Val, <:Val, Val{0}})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x, u)
    return nothing
end

function (F::Lagrange{<:Function, Val{1}, <:Val, Val{0}})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x[1], u)
    return nothing
end

function (F::Lagrange{<:Function, <:Val, Val{1}, Val{0}})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x, u[1])
    return nothing
end

function (F::Lagrange{<:Function, Val{1}, Val{1}, Val{0}})(r::ctVector, t::Time, x::State, u::Control, v::Variable)::Nothing
    F.f(r, t, x[1], u[1])
    return nothing
end

"""
$(TYPEDSIGNATURES)

Used to set the default value of the type of criterion. Either :min or :max.
The default value is `:min`.
The other possible criterion type is `:max`.
"""
__criterion_type() = :min

"""
$(TYPEDSIGNATURES)

Set the objective of the optimal control problem.

# Arguments

- `ocp::OptimalControlModelMutable`: the optimal control problem.
- `criterion::Symbol`: the type of criterion. Either :min or :max. Default is :min.
- `mayer::Union{Function, Nothing}`: the Mayer function (inplace). Default is nothing.
- `lagrange::Union{Function, Nothing}`: the Lagrange function (inplace). Default is nothing.

!!! note

    - The state, control and variable must be set before the objective.
    - The objective must not be set before.
    - At least one of the two functions must be given. Please provide a Mayer or a Lagrange function.

# Examples

```@example
julia> function mayer!(r, x0, xf, v)
           r[1] = x0[1] + xf[1] + v[1]
       end
juila> function lagrange!(r, t, x, u, v)
           r[1] = x[1] + u[1] + v[1]
       end
julia> objective!(ocp, :min, mayer=mayer!, lagrange=lagrange!)
"""
function objective!(
    ocp::OptimalControlModelMutable,
    criterion::Symbol = __criterion_type();
    mayer::Union{Function, Nothing} = nothing,
    lagrange::Union{Function, Nothing} = nothing,
)::Nothing

    # checkings: state, control and variable must be set before the objective
    !__is_state_set(ocp) && throw(CTBase.UnauthorizedCall("the state must be set before the objective."))
    !__is_control_set(ocp) && throw(CTBase.UnauthorizedCall("the control must be set before the objective."))
    #!__is_variable_set(ocp) && throw(CTBase.UnauthorizedCall("the variable must be set before the objective."))

    # checkings: the objective must not be set before
    __is_objective_set(ocp) && throw(CTBase.UnauthorizedCall("the objective has already been set."))

    # checkings: at least one of the two functions must be given
    isnothing(mayer) && isnothing(lagrange) && throw(CTBase.IncorrectArgument("at least one of the two functions must be given. Please provide a Mayer or a Lagrange function."))

    # get dimensions
    n = dimension(ocp.state)
    m = dimension(ocp.control)
    q = dimension(ocp.variable)

    # set the objective
    # Mayer and not Lagrange => MayerObjectiveModel
    # Lagrange and not Mayer => LagrangeObjectiveModel
    # Mayer and Lagrange => BolzaObjectiveModel
    if !isnothing(mayer) && isnothing(lagrange)
        ocp.objective = MayerObjectiveModel(Mayer(mayer, n, q), criterion)
    elseif isnothing(mayer) && !isnothing(lagrange)
        ocp.objective = LagrangeObjectiveModel(Lagrange(lagrange, n, m, q), criterion)
    else
        ocp.objective = BolzaObjectiveModel(Mayer(mayer, n, q), Lagrange(lagrange, n, m, q), criterion)
    end

    return nothing

end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# From MayerObjectiveModel
criterion(model::MayerObjectiveModel)::Symbol = model.criterion
(mayer(model::MayerObjectiveModel{M})::M) where {M <: AbstractMayerModel} = model.mayer!
lagrange(model::MayerObjectiveModel) = throw(CTBase.UnauthorizedCall("a Mayer objective model does not have a Lagrange function."))
has_mayer_cost(model::MayerObjectiveModel)::Bool = true
has_lagrange_cost(model::MayerObjectiveModel)::Bool = false

# From LagrangeObjectiveModel
criterion(model::LagrangeObjectiveModel)::Symbol = model.criterion
mayer(model::LagrangeObjectiveModel) = throw(CTBase.UnauthorizedCall("a Lagrange objective model does not have a Mayer function."))
(lagrange(model::LagrangeObjectiveModel{L})::L) where {L <: AbstractLagrangeModel} = model.lagrange!
has_mayer_cost(model::LagrangeObjectiveModel)::Bool = false
has_lagrange_cost(model::LagrangeObjectiveModel)::Bool = true

# From BolzaObjectiveModel
criterion(model::BolzaObjectiveModel)::Symbol = model.criterion
(mayer(model::BolzaObjectiveModel{M, L})::M) where {M <: AbstractMayerModel, L <: AbstractLagrangeModel} = model.mayer!
(lagrange(model::BolzaObjectiveModel{M, L})::L) where {M <: AbstractMayerModel, L <: AbstractLagrangeModel} = model.lagrange!
has_mayer_cost(model::BolzaObjectiveModel)::Bool = true
has_lagrange_cost(model::BolzaObjectiveModel)::Bool = true

# From OptimalControlModel
(objective(model::OptimalControlModel{T, S, C, V, O})::O) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel,
    O<:AbstractObjectiveModel} = model.objective

criterion(model::OptimalControlModel)::Symbol = criterion(objective(model))

(mayer(model::OptimalControlModel{T, S, C, V, MayerObjectiveModel{M}})::M) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel,
    M<:AbstractMayerModel} = mayer(objective(model))
(mayer(model::OptimalControlModel{T, S, C, V, BolzaObjectiveModel{M, L}})::M) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel,
    M<:AbstractMayerModel,
    L<:AbstractLagrangeModel} = mayer(objective(model))
mayer(model::OptimalControlModel{T, S, C, V, <:LagrangeObjectiveModel}) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel} = throw(CTBase.UnauthorizedCall("a Lagrange objective model does not have a Mayer function."))

(lagrange(model::OptimalControlModel{T, S, C, V, LagrangeObjectiveModel{L}})::L) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel,
    L<:AbstractLagrangeModel} = lagrange(objective(model))
(lagrange(model::OptimalControlModel{T, S, C, V, BolzaObjectiveModel{M, L}})::L) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel,
    M<:AbstractMayerModel,
    L<:AbstractLagrangeModel} = lagrange(objective(model))
lagrange(model::OptimalControlModel{T, S, C, V, <:MayerObjectiveModel}) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel} = throw(CTBase.UnauthorizedCall("a Mayer objective model does not have a Lagrange function."))

# has_mayer_cost and has_lagrange_cost
has_mayer_cost(model::OptimalControlModel)::Bool = has_mayer_cost(objective(model))
has_lagrange_cost(model::OptimalControlModel)::Bool = has_lagrange_cost(objective(model))