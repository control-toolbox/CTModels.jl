"""
$(TYPEDSIGNATURES)

Set the initial and final times. We denote by t0 the initial time and tf the final time.
The optimal control problem is denoted ocp.
When a time is free, then, one must provide the corresponding index of the ocp variable.

!!! note

    You must use time! only once to set either the initial or the final time, or both.

# Examples

```@example
julia> time!(ocp, t0=0,   tf=1  ) # Fixed t0 and fixed tf
julia> time!(ocp, t0=0,   indf=2) # Fixed t0 and free  tf
julia> time!(ocp, ind0=2, tf=1  ) # Free  t0 and fixed tf
julia> time!(ocp, ind0=2, indf=3) # Free  t0 and free  tf
```

When you plot a solution of an optimal control problem, the name of the time variable appears.
By default, the name is "t".
Consider you want to set the name of the time variable to "s".

```@example
julia> time!(ocp, t0=0, tf=1, name="s") # name is a String
# or
julia> time!(ocp, t0=0, tf=1, name=:s ) # name is a Symbol  
```
"""
function time!(
    ocp::PreModel;
    t0::Union{Time,Nothing}=nothing,
    tf::Union{Time,Nothing}=nothing,
    ind0::Union{Int,Nothing}=nothing,
    indf::Union{Int,Nothing}=nothing,
    time_name::Union{String,Symbol}=__time_name(),
)::Nothing

    # check if the function has been already called
    __is_times_set(ocp) && throw(CTBase.UnauthorizedCall("the time has already been set."))

    # If t0 or tf is free, check if the problem has a variable set
    # and in this case check consistency, meaning that ind0 and indf must belong
    # to 1 <= ind0, indf <= q, where q is the variable dimension.
    # Otherwise, throw an error.
    (!isnothing(ind0) || !isnothing(indf)) &&
        !__is_variable_set(ocp) &&
        throw(
            CTBase.UnauthorizedCall(
                "the variable must be set before calling time! if t0 or tf is free."
            ),
        )

    # check consistency with the variable
    if __is_variable_set(ocp)
        q = dimension(ocp.variable)

        !isnothing(ind0) &&
            !(1 ≤ ind0 ≤ q) && # t0 is free
            throw(
                CTBase.IncorrectArgument(
                    "the index of the t0 variable must be contained in 1:$q"
                ),
            )

        !isnothing(indf) &&
            !(1 ≤ indf ≤ q) && # tf is free
            throw(
                CTBase.IncorrectArgument(
                    "the index of the tf variable must be contained in 1:$q"
                ),
            )
    end

    # check consistency
    !isnothing(t0) &&
        !isnothing(ind0) &&
        throw(
            CTBase.IncorrectArgument(
                "Providing t0 and ind0 has no sense. The initial time cannot be fixed and free.",
            ),
        )
    isnothing(t0) &&
        isnothing(ind0) &&
        throw(
            CTBase.IncorrectArgument(
                "Please either provide the value of the initial time t0 (if fixed) or its index in the variable of ocp (if free).",
            ),
        )
    !isnothing(tf) &&
        !isnothing(indf) &&
        throw(
            CTBase.IncorrectArgument(
                "Providing tf and indf has no sense. The final time cannot be fixed and free.",
            ),
        )
    isnothing(tf) &&
        isnothing(indf) &&
        throw(
            CTBase.IncorrectArgument(
                "Please either provide the value of the final time tf (if fixed) or its index in the variable of ocp (if free).",
            ),
        )

    #
    time_name = time_name isa String ? time_name : string(time_name)

    # core
    (initial_time, final_time) = @match (t0, ind0, tf, indf) begin
        (::Time, ::Nothing, ::Time, ::Nothing) => begin # (t0, tf)
            (
                FixedTimeModel(t0, t0 isa Int ? string(t0) : string(round(t0; digits=2))),
                FixedTimeModel(tf, tf isa Int ? string(tf) : string(round(tf; digits=2))),
            )
        end
        (::Nothing, ::Int, ::Time, ::Nothing) => begin # (ind0, tf)
            (
                FreeTimeModel(ind0, components(ocp.variable)[ind0]),
                FixedTimeModel(tf, tf isa Int ? string(tf) : string(round(tf; digits=2))),
            )
        end
        (::Time, ::Nothing, ::Nothing, ::Int) => begin # (t0, indf)
            (
                FixedTimeModel(t0, t0 isa Int ? string(t0) : string(round(t0; digits=2))),
                FreeTimeModel(indf, components(ocp.variable)[indf]),
            )
        end
        (::Nothing, ::Int, ::Nothing, ::Int) => begin # (ind0, indf)
            (
                FreeTimeModel(ind0, components(ocp.variable)[ind0]),
                FreeTimeModel(indf, components(ocp.variable)[indf]),
            )
        end
        _ => throw(CTBase.IncorrectArgument("Provided arguments are inconsistent."))
    end

    ocp.times = TimesModel(initial_time, final_time, time_name)
    return nothing
end

# ------------------------------------------------------------------------------ #
# GETTERS
# ------------------------------------------------------------------------------ #

# From FixedTimeModel
"""
$(TYPEDSIGNATURES)

Get the time from the fixed time model.
"""
function time(model::FixedTimeModel{T})::T where {T<:Time}
    return model.time
end

"""
$(TYPEDSIGNATURES)

Get the name of the time from the fixed time model.
"""
function name(model::FixedTimeModel{<:Time})::String
    return model.name
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

Get the name of the time from the free time model.
"""
function name(model::FreeTimeModel)::String
    return model.name
end

"""
$(TYPEDSIGNATURES)

Get the time from the free time model.

# Exceptions

- If the index of the time variable is not in [1, length(variable)], throw an error.
"""
function time(model::FreeTimeModel, variable::AbstractVector{T})::T where {T<:ctNumber}
    # check if model.index in [1, length(variable)]
    !(1 ≤ model.index ≤ length(variable)) && throw(
        CTBase.IncorrectArgument(
            "the index of the time variable must be contained in 1:$(length(variable))"
        ),
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
    return time(initial(model))
end

"""
$(TYPEDSIGNATURES)

Get the final time from the times model, from a fixed final time model.
"""
function final_time(
    model::TimesModel{<:AbstractTimeModel,<:FixedTimeModel{T}}
)::T where {T<:Time}
    return time(final(model))
end

"""
$(TYPEDSIGNATURES)

Get the initial time from the times model, from a free initial time model.
"""
function initial_time(
    model::TimesModel{FreeTimeModel,<:AbstractTimeModel}, variable::AbstractVector{T}
)::T where {T<:ctNumber}
    return time(initial(model), variable)
end

"""
$(TYPEDSIGNATURES)

Get the final time from the times model, from a free final time model.
"""
function final_time(
    model::TimesModel{<:AbstractTimeModel,FreeTimeModel}, variable::AbstractVector{T}
)::T where {T<:ctNumber}
    return time(final(model), variable)
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is fixed. Return true.
"""
function has_fixed_initial_time(
    times::TimesModel{<:FixedTimeModel{T},<:AbstractTimeModel}
)::Bool where {T<:Time}
    return true
end

"""
$(TYPEDSIGNATURES)

Check if the initial time is free. Return false.
"""
function has_fixed_initial_time(times::TimesModel{FreeTimeModel,<:AbstractTimeModel})::Bool
    return false
end

"""
$(TYPEDSIGNATURES)

Check if the final time is free.
"""
function has_free_initial_time(times::TimesModel)::Bool
    return !has_fixed_initial_time(times)
end

"""
$(TYPEDSIGNATURES)

Check if the final time is fixed. Return true.
"""
function has_fixed_final_time(
    times::TimesModel{<:AbstractTimeModel,<:FixedTimeModel{T}}
)::Bool where {T<:Time}
    return true
end

"""
$(TYPEDSIGNATURES)

Check if the final time is free. Return false.
"""
function has_fixed_final_time(times::TimesModel{<:AbstractTimeModel,FreeTimeModel})::Bool
    return false
end

"""
$(TYPEDSIGNATURES)

Check if the final time is free.
"""
function has_free_final_time(times::TimesModel)::Bool
    return !has_fixed_final_time(times)
end
