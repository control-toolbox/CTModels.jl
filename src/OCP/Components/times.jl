"""
$(TYPEDSIGNATURES)

Set the initial and final times. We denote by t0 the initial time and tf the final time.
The optimal control problem is denoted ocp.
When a time is free, then, one must provide the corresponding index of the ocp variable.

!!! note

    You must use time! only once to set either the initial or the final time, or both.

# Examples

`time!` may be used only once per problem; each form below applies to a fresh `ocp`:

```julia-repl
julia> using CTModels

julia> CTModels.time!(ocp; t0=0, tf=1)     # Fixed t0 and fixed tf

julia> CTModels.time!(ocp; t0=0, indf=2)   # Fixed t0 and free  tf

julia> CTModels.time!(ocp; ind0=2, tf=1)   # Free  t0 and fixed tf

julia> CTModels.time!(ocp; ind0=2, indf=3) # Free  t0 and free  tf
```

When a solution is plotted, the name of the time variable appears (`"t"` by default).
To name the time variable `"s"`:

```julia-repl
julia> CTModels.time!(ocp; t0=0, tf=1, time_name="s") # time_name as a String

julia> CTModels.time!(ocp; t0=0, tf=1, time_name=:s)  # time_name as a Symbol
```

# Throws

- `Exceptions.PreconditionError`: If time has already been set
- `Exceptions.PreconditionError`: If variable must be set before (when t0 or tf is free)
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
    Core.@ensure !__is_times_set(ocp) Exceptions.PreconditionError(
        "Time already set",
        reason="time has already been defined for this OCP",
        suggestion="Create a new OCP instance or use the existing time definition",
        context="time! function - duplicate definition check",
    )

    Core.@ensure !__is_variable_empty(ocp) || (isnothing(ind0) && isnothing(indf)) Exceptions.PreconditionError(
        "Variable must be set for free time",
        reason="variable is required when t0 or tf is free (ind0/indf provided)",
        suggestion="Call variable!(ocp, dimension) before time! with free time parameters, or use fixed times (t0, tf)",
        context="time! function - free time validation",
    )

    if !__is_variable_empty(ocp)
        q = dimension(ocp.variable)

        Core.@ensure isnothing(ind0) || (1 ≤ ind0 ≤ q) Exceptions.IncorrectArgument(
            "Initial time index out of bounds",
            got="ind0=$ind0",
            expected="index in range 1:$q",
            suggestion="Provide an index between 1 and $q for the initial time variable",
            context="time! with free initial time",
        )

        Core.@ensure isnothing(indf) || (1 ≤ indf ≤ q) Exceptions.IncorrectArgument(
            "Final time index out of bounds",
            got="indf=$indf",
            expected="index in range 1:$q",
            suggestion="Provide an index between 1 and $q for the final time variable",
            context="time! with free final time",
        )
    end

    Core.@ensure isnothing(t0) || isnothing(ind0) Exceptions.IncorrectArgument(
        "Conflicting initial time specification",
        got="both t0 and ind0 provided",
        expected="either t0 (fixed) or ind0 (free), not both",
        suggestion="Use time!(ocp, t0=value, ...) for fixed initial time OR time!(ocp, ind0=index, ...) for free initial time",
        context="time! argument validation",
    )

    Core.@ensure !(isnothing(t0) && isnothing(ind0)) Exceptions.IncorrectArgument(
        "Missing initial time specification",
        got="neither t0 nor ind0 provided",
        expected="either t0 (fixed) or ind0 (free)",
        suggestion="Use time!(ocp, t0=value, ...) for fixed initial time OR time!(ocp, ind0=index, ...) for free initial time",
        context="time! argument validation",
    )

    Core.@ensure isnothing(tf) || isnothing(indf) Exceptions.IncorrectArgument(
        "Conflicting final time specification",
        got="both tf and indf provided",
        expected="either tf (fixed) or indf (free), not both",
        suggestion="Use time!(ocp, ..., tf=value) for fixed final time OR time!(ocp, ..., indf=index) for free final time",
        context="time! argument validation",
    )

    Core.@ensure !(isnothing(tf) && isnothing(indf)) Exceptions.IncorrectArgument(
        "Missing final time specification",
        got="neither tf nor indf provided",
        expected="either tf (fixed) or indf (free)",
        suggestion="Use time!(ocp, ..., tf=value) for fixed final time OR time!(ocp, ..., indf=index) for free final time",
        context="time! argument validation",
    )

    time_name = time_name isa String ? time_name : string(time_name)

    # NEW: Validate time_name is not empty
    Core.@ensure !isempty(time_name) Exceptions.IncorrectArgument(
        "Empty time name",
        got="empty string",
        expected="non-empty string or symbol",
        suggestion="Provide a valid time name like time_name=\"t\" or time_name=:s",
        context="time! time_name validation",
    )

    # NEW: Validate time_name doesn't conflict with existing names
    Core.@ensure !__has_name_conflict(ocp, time_name, :time) Exceptions.IncorrectArgument(
        "Time name conflict",
        got="time_name='$time_name'",
        expected="unique name not conflicting with: $(__collect_used_names(ocp))",
        suggestion="Choose a different time name that doesn't conflict with existing component names",
        context="time! name validation",
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
        _ => throw(
            Exceptions.IncorrectArgument(
                "Inconsistent time arguments",
                got="invalid combination of t0, ind0, tf, indf",
                expected="valid pattern: (t0, tf), (t0, indf), (ind0, tf), or (ind0, indf)",
                suggestion="Check time! documentation for valid argument combinations",
                context="time!(ocp, t0/ind0=..., tf/indf=...) - validating argument combinations",
            ),
        )
    end

    # NEW: Validate t0 < tf when both are fixed
    if initial_time isa FixedTimeModel && final_time isa FixedTimeModel
        t0_val = time(initial_time)
        tf_val = time(final_time)
        Core.@ensure t0_val < tf_val Exceptions.IncorrectArgument(
            "Invalid time interval",
            got="t0=$t0_val, tf=$tf_val (t0 ≥ tf)",
            expected="t0 < tf",
            suggestion="Ensure initial time is strictly less than final time",
            context="time! with fixed times validation",
        )
    end

    ocp.times = TimesModel(initial_time, final_time, time_name)
    return nothing
end

# Getters for FixedTimeModel/FreeTimeModel/TimesModel are now in
# src/Components/times_accessors.jl.
