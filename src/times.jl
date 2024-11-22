"""
$(TYPEDSIGNATURES)

Used to set the default value of the name of the time.
The default value is `t`.
"""
__time_name()::String = "t"

"""
$(TYPEDSIGNATURES)

"""
__is_times_set(ocp::OptimalControlModelMutable)::Bool = !ismissing(ocp.times)

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
    ocp::OptimalControlModelMutable;
    t0::Union{Time, Nothing} = nothing,
    tf::Union{Time, Nothing} = nothing,
    ind0::Union{Int, Nothing} = nothing,
    indf::Union{Int, Nothing} = nothing,
    time_name::Union{String, Symbol} = __time_name(),
)::Nothing

    # check if the function has been already called
    __is_times_set(ocp) && throw(CTBase.UnauthorizedCall("the time has already been set."))

    # If t0 or tf is free, check if the problem has a variable set
    # and in this case check consistency, meaning that ind0 and indf must belong
    # to 1 <= ind0, indf <= q, where q is the variable dimension.
    # Otherwise, throw an error.
    (!isnothing(ind0) || !isnothing(indf)) && !__is_variable_set(ocp) &&
        throw(CTBase.UnauthorizedCall("the variable must be set before calling time! if t0 or tf is free."))

    # check consistency with the variable
    if __is_variable_set(ocp)
        q = dimension(ocp.variable)

        !isnothing(ind0) && !(1 ≤ ind0 ≤ q) && # t0 is free
        throw(CTBase.IncorrectArgument("the index of the t0 variable must be contained in 1:$q"))

        !isnothing(indf) && !(1 ≤ indf ≤ q) && # tf is free
        throw(CTBase.IncorrectArgument("the index of the tf variable must be contained in 1:$q"))
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
            (FixedTimeModel(t0, t0 isa Int ? string(t0) : string(round(t0, digits = 2))),
             FixedTimeModel(tf, tf isa Int ? string(tf) : string(round(tf, digits = 2))))
        end
        (::Nothing, ::Int, ::Time, ::Nothing) => begin # (ind0, tf)
            (FreeTimeModel(ind0, components(ocp.variable)[ind0]),
             FixedTimeModel(tf, tf isa Int ? string(tf) : string(round(tf, digits = 2))))
        end
        (::Time, ::Nothing, ::Nothing, ::Int) => begin # (t0, indf)
            (FixedTimeModel(t0, t0 isa Int ? string(t0) : string(round(t0, digits = 2))),
             FreeTimeModel(indf, components(ocp.variable)[indf]))
        end
        (::Nothing, ::Int, ::Nothing, ::Int) => begin # (ind0, indf)
            (FreeTimeModel(ind0, components(ocp.variable)[ind0]),
             FreeTimeModel(indf, components(ocp.variable)[indf]))
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
time(model::FixedTimeModel)::Time = model.time
name(model::FixedTimeModel)::String = model.name

# From FreeTimeModel
index(model::FreeTimeModel)::Int = model.index
name(model::FreeTimeModel)::String = model.name
function time(model::FreeTimeModel, variable::ctNumber)::Time
    # check if model.index = 1
    !(model.index == 1) && throw(CTBase.IncorrectArgument("the index of the time variable must be 1."))
    return variable
end
function time(model::FreeTimeModel, variable::AbstractVector{<:ctNumber})::Time
    # check if model.index in [1, length(variable)]
    !(1 ≤ model.index ≤ length(variable)) && throw(CTBase.IncorrectArgument("the index of the time variable must be contained in 1:$(length(variable))"))
    return variable[model.index]
end

# From TimesModel
(initial(model::TimesModel{TI, TF})::TI) where {TI <: AbstractTimeModel, TF <: AbstractTimeModel} = model.initial
(final(model::TimesModel{TI, TF})::TF) where {TI <: AbstractTimeModel, TF <: AbstractTimeModel} = model.final
time_name(model::TimesModel)::String = model.time_name
initial_time(model::TimesModel{FixedTimeModel, <:AbstractTimeModel})::Time = time(initial(model))
final_time(model::TimesModel{<:AbstractTimeModel, FixedTimeModel})::Time = time(final(model))
initial_time(model::TimesModel{FreeTimeModel, <:AbstractTimeModel}, variable::Variable)::Time = time(initial(model), variable)
final_time(model::TimesModel{<:AbstractTimeModel, FreeTimeModel}, variable::Variable)::Time = time(final(model), variable)

# From OptimalControlModel
(times(model::OptimalControlModel{T, S, C, V})::T) where {
    T<:AbstractTimesModel,
    S<:AbstractStateModel, 
    C<:AbstractControlModel, 
    V<:AbstractVariableModel} = model.times
time_name(model::OptimalControlModel)::String = time_name(times(model))
(initial_time(model::OptimalControlModel{T, S, C, V})::Time) where {
    T<:TimesModel{FixedTimeModel, <:AbstractTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel} = initial_time(times(model))
(final_time(model::OptimalControlModel{T, S, C, V})::Time) where {
    T<:TimesModel{<:AbstractTimeModel, FixedTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel} = final_time(times(model))
(initial_time(model::OptimalControlModel{T, S, C, V}, variable::Variable)::Time) where {
    T<:TimesModel{FreeTimeModel, <:AbstractTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel} = initial_time(times(model), variable)
(final_time(model::OptimalControlModel{T, S, C, V}, variable::Variable)::Time) where {
    T<:TimesModel{<:AbstractTimeModel, FreeTimeModel},
    S<:AbstractStateModel,
    C<:AbstractControlModel,
    V<:AbstractVariableModel} = final_time(times(model), variable)
initial_time_name(model::OptimalControlModel)::String = name(initial(times(model)))
final_time_name(model::OptimalControlModel)::String = name(final(times(model)))