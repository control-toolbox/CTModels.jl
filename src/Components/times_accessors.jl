# ------------------------------------------------------------------------------ #
# Accessor methods on time model types
# (FixedTimeModel, FreeTimeModel, TimesModel)
# ------------------------------------------------------------------------------ #

# From FixedTimeModel
"""
$(TYPEDSIGNATURES)

Get the time from the fixed time model.
"""
function Base.time(model::FixedTimeModel{T})::T where {T<:Time}
    return model.time
end

# From FreeTimeModel
"""
$(TYPEDSIGNATURES)

Get the index of the time variable from the free time model.
"""
function index(model::FreeTimeModel)::Int
    return model.index
end

"""
$(TYPEDSIGNATURES)

Get the time from the free time model.

# Exceptions

- If the index of the time variable is not in [1, length(variable)], throw an error.
"""
function Base.time(model::FreeTimeModel, variable::AbstractVector{T})::T where {T<:ctNumber}
    Core.@ensure 1 ≤ model.index ≤ length(variable) Exceptions.IncorrectArgument(
        "Time variable index out of bounds",
        got="index=$(model.index)",
        expected="index in range 1:$(length(variable))",
        suggestion="Ensure the variable vector has at least $(model.index) elements",
        context="time() accessor for free time",
    )
    return variable[model.index]
end

# From TimesModel
"""
$(TYPEDSIGNATURES)

Get the initial time from the times model.
"""
function initial(
    model::TimesModel{TI,<:AbstractTimeModel}
)::TI where {TI<:AbstractTimeModel}
    return model.initial
end

"""
$(TYPEDSIGNATURES)

Get the final time from the times model.
"""
function final(model::TimesModel{<:AbstractTimeModel,TF})::TF where {TF<:AbstractTimeModel}
    return model.final
end

"""
$(TYPEDSIGNATURES)

Get the name of the time variable from the times model.
"""
function time_name(model::TimesModel)::String
    return model.time_name
end

"""
$(TYPEDSIGNATURES)

Get the name of the initial time from the times model.
"""
function initial_time_name(model::TimesModel)::String
    return name(initial(model))
end

"""
$(TYPEDSIGNATURES)

Get the name of the final time from the times model.
"""
function final_time_name(model::TimesModel)::String
    return name(final(model))
end

"""
$(TYPEDSIGNATURES)

Get the initial time from the times model, from a fixed initial time model.
"""
function initial_time(
    model::TimesModel{<:FixedTimeModel{T},<:AbstractTimeModel}
)::T where {T<:Time}
    return Base.time(initial(model))
end

"""
$(TYPEDSIGNATURES)

Get the final time from the times model, from a fixed final time model.
"""
function final_time(
    model::TimesModel{<:AbstractTimeModel,<:FixedTimeModel{T}}
)::T where {T<:Time}
    return Base.time(final(model))
end

"""
$(TYPEDSIGNATURES)

Get the initial time from the times model, from a free initial time model.
"""
function initial_time(
    model::TimesModel{FreeTimeModel,<:AbstractTimeModel}, variable::AbstractVector{T}
)::T where {T<:ctNumber}
    return Base.time(initial(model), variable)
end

"""
$(TYPEDSIGNATURES)

Get the final time from the times model, from a free final time model.
"""
function final_time(
    model::TimesModel{<:AbstractTimeModel,FreeTimeModel}, variable::AbstractVector{T}
)::T where {T<:ctNumber}
    return Base.time(final(model), variable)
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is fixed. Return true.
"""
function has_fixed_initial_time(
    ::TimesModel{<:FixedTimeModel{T},<:AbstractTimeModel}
)::Bool where {T<:Time}
    return true
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is free. Return false.
"""
function has_fixed_initial_time(::TimesModel{FreeTimeModel,<:AbstractTimeModel})::Bool
    return false
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is free.
"""
function has_free_initial_time(times::TimesModel)::Bool
    return !has_fixed_initial_time(times)
end

"""
$(TYPEDSIGNATURES)

Check if the final time is fixed. Return true.
"""
function has_fixed_final_time(
    ::TimesModel{<:AbstractTimeModel,<:FixedTimeModel{T}}
)::Bool where {T<:Time}
    return true
end

"""
$(TYPEDSIGNATURES)

Check if the final time is free. Return false.
"""
function has_fixed_final_time(::TimesModel{<:AbstractTimeModel,FreeTimeModel})::Bool
    return false
end

"""
$(TYPEDSIGNATURES)

Check if the final time is free.
"""
function has_free_final_time(times::TimesModel)::Bool
    return !has_fixed_final_time(times)
end

# ------------------------------------------------------------------------------ #
# ALIASES (for naming consistency)
# ------------------------------------------------------------------------------ #

"""
Alias for `has_fixed_initial_time`.
"""
const is_initial_time_fixed = has_fixed_initial_time

"""
Alias for `has_free_initial_time`.
"""
const is_initial_time_free = has_free_initial_time

"""
Alias for `has_fixed_final_time`.
"""
const is_final_time_fixed = has_fixed_final_time

"""
Alias for `has_free_final_time`.
"""
const is_final_time_free = has_free_final_time
