"""
$(TYPEDSIGNATURES)

Set the full dynamics of the optimal control problem `ocp` using the function `f`.

# Arguments
- `ocp::PreModel`: The optimal control problem being defined.
- `f::Function`: A function that defines the complete system dynamics.

# Preconditions
- The state, control, and times must be set before calling this function.
- No dynamics must have been set previously.

# Behavior
This function assigns `f` as the complete dynamics of the system. It throws an error
if any of the required fields (`state`, `control`, `times`) are not yet set, or if
dynamics have already been set.

# Errors
Throws `CTBase.UnauthorizedCall` if called out of order or in an invalid state.
"""
function dynamics!(ocp::PreModel, f::Function)::Nothing
    @ensure __is_state_set(ocp) CTBase.UnauthorizedCall(
        "the state must be set before the dynamics."
    )
    @ensure __is_control_set(ocp) CTBase.UnauthorizedCall(
        "the control must be set before the dynamics."
    )
    @ensure __is_times_set(ocp) CTBase.UnauthorizedCall(
        "the times must be set before the dynamics."
    )
    @ensure !__is_dynamics_set(ocp) CTBase.UnauthorizedCall(
        "the dynamics has already been set."
    )

    # set the dynamics
    ocp.dynamics = f

    return nothing
end

"""
$(TYPEDSIGNATURES)

Add a partial dynamics function `f` to the optimal control problem `ocp`, applying to the
subset of state indices specified by the range `rg`.

# Arguments
- `ocp::PreModel`: The optimal control problem being defined.
- `rg::AbstractUnitRange{<:Integer}`: Range of state indices to which `f` applies.
- `f::Function`: A function describing the dynamics over the specified state indices.

# Preconditions
- The state, control, and times must be set before calling this function.
- The full dynamics must not yet be complete.
- No overlap is allowed between `rg` and existing dynamics index ranges.

# Behavior
This function appends the tuple `(rg, f)` to the list of partial dynamics. It ensures
that the specified indices are not already covered and that the system is in a valid
configuration for adding partial dynamics.

# Errors
Throws `CTBase.UnauthorizedCall` if:
- The state, control, or times are not yet set.
- The dynamics are already defined completely.
- Any index in `rg` overlaps with an existing dynamics range.

# Example
```julia-repl
julia> dynamics!(ocp, 1:2, (out, t, x, u, v) -> out .= x[1:2] .+ u[1:2])
julia> dynamics!(ocp, 3:3, (out, t, x, u, v) -> out .= x[3] * v[1])
```
"""
function dynamics!(ocp::PreModel, rg::AbstractUnitRange{<:Integer}, f::Function)::Nothing
    @ensure __is_state_set(ocp) CTBase.UnauthorizedCall(
        "the state must be set before the dynamics."
    )
    @ensure __is_control_set(ocp) CTBase.UnauthorizedCall(
        "the control must be set before the dynamics."
    )
    @ensure __is_times_set(ocp) CTBase.UnauthorizedCall(
        "the times must be set before the dynamics."
    )
    @ensure !__is_dynamics_complete(ocp) CTBase.UnauthorizedCall(
        "the dynamics has already been set."
    )

    # Check indices in rg are within valid state index bounds
    for i in rg
        if i < 1 || i > state_dimension(ocp)
            throw(
                CTBase.IncorrectArgument(
                    "index $i in the range is out of valid bounds [1, $(state_dimension(ocp))].",
                ),
            )
        end
    end

    # initialize dynamics container if needed
    if isnothing(ocp.dynamics)
        ocp.dynamics = Vector{Tuple{UnitRange{Int},Function}}()
    elseif ocp.dynamics isa Function
        throw(
            CTBase.UnauthorizedCall(
                "cannot add partial dynamics: dynamics already defined as a single function.",
            ),
        )
    end

    # check that indices in rg are not already covered
    for (existing_range, _) in ocp.dynamics
        for i in rg
            if i in existing_range
                throw(
                    CTBase.UnauthorizedCall(
                        "index $i in the range already has assigned dynamics."
                    ),
                )
            end
        end
    end

    # push the new partial dynamics
    push!(ocp.dynamics, (rg, f))

    return nothing
end

"""
$(TYPEDSIGNATURES)

Define partial dynamics for a single state variable index in an optimal control problem.

This is a convenience method for defining dynamics affecting only one element of the state vector. It wraps the scalar index `i` into a range `i:i` and delegates to the general partial dynamics method.

# Arguments
- `ocp::PreModel`: The optimal control problem being defined.
- `i::Integer`: The index of the state variable to which the function `f` applies.
- `f::Function`: A function of the form `(out, t, x, u, v) -> ...`, which updates the scalar output `out[1]` in-place.

# Behavior
This is equivalent to calling:
```julia-repl
julia> dynamics!(ocp, i:i, f)
```

# Errors
Throws the same errors as the range-based method if:
- The model is not properly initialized.
- The index `i` overlaps with existing dynamics.
- A full dynamics function is already defined.

# Example
```julia-repl
julia> dynamics!(ocp, 3, (out, t, x, u, v) -> out[1] = x[3]^2 + u[1])
```
"""
function dynamics!(ocp::PreModel, i::Integer, f::Function)::Nothing
    return dynamics!(ocp, i:i, f)
end

"""
$(TYPEDSIGNATURES)

Build a combined dynamics function from multiple parts.

This function constructs an in-place dynamics function `dyn!` by composing several sub-functions, each responsible for updating a specific segment of the output vector.

# Arguments
- `parts::Vector{<:Tuple{<:AbstractUnitRange{<:Integer}, <:Function}}`: 
  A vector of tuples, where each tuple contains:
  - A range specifying the indices in the output vector `val` that the corresponding function updates.
  - A function `f` with the signature `(output_segment, t, x, u, v)`, which updates the slice of `val` indicated by the range.

# Returns
- `dyn!`: A function with signature `(val, t, x, u, v)` that updates the full output vector `val` in-place by applying each part function to its assigned segment.

# Details
- The returned `dyn!` function calls each part function with a view of `val` restricted to the assigned range. This avoids unnecessary copying and allows efficient updates of sub-vectors.
- Each part function is expected to modify its output segment in-place.

# Example
```julia-repl
# Define two sub-dynamics functions
julia> f1(out, t, x, u, v) = out .= x[1:2] .+ u[1:2]
julia> f2(out, t, x, u, v) = out .= x[3] * v

# Combine them into one dynamics function affecting different parts of the output vector
julia> parts = [(1:2, f1), (3:3, f2)]
julia> dyn! = __build_dynamics_from_parts(parts)

val = zeros(3)
julia> dyn!(val, 0.0, [1.0, 2.0, 3.0], [0.5, 0.5], 2.0)
julia> println(val)  # prints [1.5, 2.5, 6.0]
```
"""
function __build_dynamics_from_parts(
    parts::Vector{<:Tuple{<:AbstractUnitRange{<:Integer},<:Function}}
)::Function
    function dyn!(val, t, x, u, v)
        for (rg, f!) in parts
            f!(@view(val[rg]), t, x, u, v)
        end
        return nothing
    end
    return dyn!
end
