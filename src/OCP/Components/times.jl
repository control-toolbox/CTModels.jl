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
julia> time!(ocp, t0=0, tf=1, time_name="s") # time_name is a String
# or
julia> time!(ocp, t0=0, tf=1, time_name=:s ) # time_name is a Symbol  
```

# Throws

- `CTBase.UnauthorizedCall`: If time has already been set
- `CTBase.UnauthorizedCall`: If variable must be set before (when t0 or tf is free)
- `Exceptions.IncorrectArgument`: If ind0 or indf is out of bounds
- `Exceptions.IncorrectArgument`: If both t0 and ind0 are provided
- `Exceptions.IncorrectArgument`: If neither t0 nor ind0 is provided
- `Exceptions.IncorrectArgument`: If both tf and indf are provided
- `Exceptions.IncorrectArgument`: If neither tf nor indf is provided
- `Exceptions.IncorrectArgument`: If time_name is empty
- `Exceptions.IncorrectArgument`: If time_name conflicts with existing names
- `Exceptions.IncorrectArgument`: If t0 ≥ tf (when both are fixed)
"""
function time!(
    ocp::PreModel;
    t0::Union{Time,Nothing}=nothing,
    tf::Union{Time,Nothing}=nothing,
    ind0::Union{Int,Nothing}=nothing,
    indf::Union{Int,Nothing}=nothing,
    time_name::Union{String,Symbol}=__time_name(),
)::Nothing
    @ensure !__is_times_set(ocp) CTBase.UnauthorizedCall("the time has already been set.")

    @ensure __is_variable_set(ocp) || (isnothing(ind0) && isnothing(indf)) CTBase.UnauthorizedCall(
        "the variable must be set before calling time! if t0 or tf is free."
    )

    if __is_variable_set(ocp)
        q = dimension(ocp.variable)

        @ensure isnothing(ind0) || (1 ≤ ind0 ≤ q) Exceptions.IncorrectArgument(
            "Initial time index out of bounds",
            got="ind0=$ind0",
            expected="index in range 1:$q",
            suggestion="Provide an index between 1 and $q for the initial time variable",
            context="time! with free initial time"
        )

        @ensure isnothing(indf) || (1 ≤ indf ≤ q) Exceptions.IncorrectArgument(
            "Final time index out of bounds",
            got="indf=$indf",
            expected="index in range 1:$q",
            suggestion="Provide an index between 1 and $q for the final time variable",
            context="time! with free final time"
        )
    end

    @ensure isnothing(t0) || isnothing(ind0) Exceptions.IncorrectArgument(
        "Conflicting initial time specification",
        got="both t0 and ind0 provided",
        expected="either t0 (fixed) or ind0 (free), not both",
        suggestion="Use time!(ocp, t0=value, ...) for fixed initial time OR time!(ocp, ind0=index, ...) for free initial time",
        context="time! argument validation"
    )

    @ensure !(isnothing(t0) && isnothing(ind0)) Exceptions.IncorrectArgument(
        "Missing initial time specification",
        got="neither t0 nor ind0 provided",
        expected="either t0 (fixed) or ind0 (free)",
        suggestion="Use time!(ocp, t0=value, ...) for fixed initial time OR time!(ocp, ind0=index, ...) for free initial time",
        context="time! argument validation"
    )

    @ensure isnothing(tf) || isnothing(indf) Exceptions.IncorrectArgument(
        "Conflicting final time specification",
        got="both tf and indf provided",
        expected="either tf (fixed) or indf (free), not both",
        suggestion="Use time!(ocp, ..., tf=value) for fixed final time OR time!(ocp, ..., indf=index) for free final time",
        context="time! argument validation"
    )

    @ensure !(isnothing(tf) && isnothing(indf)) Exceptions.IncorrectArgument(
        "Missing final time specification",
        got="neither tf nor indf provided",
        expected="either tf (fixed) or indf (free)",
        suggestion="Use time!(ocp, ..., tf=value) for fixed final time OR time!(ocp, ..., indf=index) for free final time",
        context="time! argument validation"
    )

    time_name = time_name isa String ? time_name : string(time_name)

    # NEW: Validate time_name is not empty
    @ensure !isempty(time_name) Exceptions.IncorrectArgument(
        "Empty time name",
        got="empty string",
        expected="non-empty string or symbol",
        suggestion="Provide a valid time name like time_name=\"t\" or time_name=:s",
        context="time! time_name validation"
    )

    # NEW: Validate time_name doesn't conflict with existing names
    @ensure !__has_name_conflict(ocp, time_name, :time) Exceptions.IncorrectArgument(
        "Time name conflict",
        got="time_name='$time_name'",
        expected="unique name not conflicting with: $(__collect_used_names(ocp))",
        suggestion="Choose a different time name that doesn't conflict with existing component names",
        context="time! name validation"
    )

    (initial_time, final_time) = MLStyle.@match (t0, ind0, tf, indf) begin
        (::Time, ::Nothing, ::Time, ::Nothing) => (
            FixedTimeModel(t0, t0 isa Int ? string(t0) : string(round(t0; digits=2))),
            FixedTimeModel(tf, tf isa Int ? string(tf) : string(round(tf; digits=2))),
        )
        (::Nothing, ::Int, ::Time, ::Nothing) => (
            FreeTimeModel(ind0, components(ocp.variable)[ind0]),
            FixedTimeModel(tf, tf isa Int ? string(tf) : string(round(tf; digits=2))),
        )
        (::Time, ::Nothing, ::Nothing, ::Int) => (
            FixedTimeModel(t0, t0 isa Int ? string(t0) : string(round(t0; digits=2))),
            FreeTimeModel(indf, components(ocp.variable)[indf]),
        )
        (::Nothing, ::Int, ::Nothing, ::Int) => (
            FreeTimeModel(ind0, components(ocp.variable)[ind0]),
            FreeTimeModel(indf, components(ocp.variable)[indf]),
        )
        _ => throw(Exceptions.IncorrectArgument(
            "Inconsistent time arguments",
            got="invalid combination of t0, ind0, tf, indf",
            expected="valid pattern: (t0, tf), (t0, indf), (ind0, tf), or (ind0, indf)",
            suggestion="Check time! documentation for valid argument combinations",
            context="time!(ocp, t0/ind0=..., tf/indf=...) - validating argument combinations"
        ))
    end

    # NEW: Validate t0 < tf when both are fixed
    if initial_time isa FixedTimeModel && final_time isa FixedTimeModel
        t0_val = time(initial_time)
        tf_val = time(final_time)
        @ensure t0_val < tf_val Exceptions.IncorrectArgument(
            "Invalid time interval",
            got="t0=$t0_val, tf=$tf_val (t0 ≥ tf)",
            expected="t0 < tf",
            suggestion="Ensure initial time is strictly less than final time",
            context="time! with fixed times validation"
        )
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
    @ensure 1 ≤ model.index ≤ length(variable) Exceptions.IncorrectArgument(
        "Time variable index out of bounds",
        got="index=$(model.index)",
        expected="index in range 1:$(length(variable))",
        suggestion="Ensure the variable vector has at least $(model.index) elements",
        context="time() accessor for free time"
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

# ------------------------------------------------------------------------------ #
# ALIASES (for naming consistency)
# ------------------------------------------------------------------------------ #

"""
$(TYPEDSIGNATURES)

Alias for [`has_fixed_initial_time`](@ref). Check if the initial time is fixed.

# Example
```julia-repl
julia> is_initial_time_fixed(times)  # equivalent to has_fixed_initial_time(times)
```

See also: [`has_fixed_initial_time`](@ref), [`is_initial_time_free`](@ref).
"""
const is_initial_time_fixed = has_fixed_initial_time

"""
$(TYPEDSIGNATURES)

Alias for [`has_free_initial_time`](@ref). Check if the initial time is free.

# Example
```julia-repl
julia> is_initial_time_free(times)  # equivalent to has_free_initial_time(times)
```

See also: [`has_free_initial_time`](@ref), [`is_initial_time_fixed`](@ref).
"""
const is_initial_time_free = has_free_initial_time

"""
$(TYPEDSIGNATURES)

Alias for [`has_fixed_final_time`](@ref). Check if the final time is fixed.

# Example
```julia-repl
julia> is_final_time_fixed(times)  # equivalent to has_fixed_final_time(times)
```

See also: [`has_fixed_final_time`](@ref), [`is_final_time_free`](@ref).
"""
const is_final_time_fixed = has_fixed_final_time

"""
$(TYPEDSIGNATURES)

Alias for [`has_free_final_time`](@ref). Check if the final time is free.

# Example
```julia-repl
julia> is_final_time_free(times)  # equivalent to has_free_final_time(times)
```

See also: [`has_free_final_time`](@ref), [`is_final_time_fixed`](@ref).
"""
const is_final_time_free = has_free_final_time
