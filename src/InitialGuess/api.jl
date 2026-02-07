# ------------------------------------------------------------------------------
# Initial Guess API
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Create a pre-initialisation object for an initial guess.

This function creates an [`OptimalControlPreInit`](@ref) that can later be
processed into a full [`OptimalControlInitialGuess`](@ref).

# Arguments

- `state`: Raw state initialisation data (function, vector, matrix, or `nothing`).
- `control`: Raw control initialisation data (function, vector, matrix, or `nothing`).
- `variable`: Raw variable initialisation data (scalar, vector, or `nothing`).

# Returns

- `OptimalControlPreInit`: A pre-initialisation container.

# Example

```julia-repl
julia> using CTModels

julia> pre = CTModels.pre_initial_guess(state=t -> [0.0, 0.0], control=t -> [1.0])
```
"""
function pre_initial_guess(; state=nothing, control=nothing, variable=nothing)
    return OptimalControlPreInit(state, control, variable)
end

"""
$(TYPEDSIGNATURES)

Construct a validated initial guess for an optimal control problem.

Builds an [`OptimalControlInitialGuess`](@ref) from the provided state, control,
and variable data, validating dimensions against the problem definition.

# Arguments

- `ocp::AbstractOptimalControlProblem`: The optimal control problem.
- `state`: State initialisation (function `t -> x(t)`, constant, vector, or `nothing`).
- `control`: Control initialisation (function `t -> u(t)`, constant, vector, or `nothing`).
- `variable`: Variable initialisation (scalar, vector, or `nothing`).

# Returns

- `OptimalControlInitialGuess`: A validated initial guess.

# Example

```julia-repl
julia> using CTModels

julia> init = CTModels.initial_guess(ocp; state=t -> [0.0, 0.0], control=t -> [1.0])
```
"""
function initial_guess(
    ocp::AbstractOptimalControlProblem;
    state::Union{Nothing,Function,Real,Vector{<:Real}}=nothing,
    control::Union{Nothing,Function,Real,Vector{<:Real}}=nothing,
    variable::Union{Nothing,Real,Vector{<:Real}}=nothing,
)
    x = initial_state(ocp, state)
    u = initial_control(ocp, control)
    v = initial_variable(ocp, variable)
    init = OptimalControlInitialGuess(x, u, v)
    return _validate_initial_guess(ocp, init)
end

"""
$(TYPEDSIGNATURES)

Build an initial guess from various input formats.

Accepts multiple input types and converts them to an [`OptimalControlInitialGuess`](@ref):
- `nothing` or `()`: Returns default initial guess.
- `AbstractOptimalControlInitialGuess`: Returns as-is.
- `AbstractOptimalControlPreInit`: Converts from pre-initialisation.
- `AbstractSolution`: Warm-starts from a previous solution.
- `NamedTuple`: Parses named fields for state, control, and variable.

# Arguments

- `ocp::AbstractOptimalControlProblem`: The optimal control problem.
- `init_data`: The initial guess data in one of the supported formats.

# Returns

- `OptimalControlInitialGuess`: A validated initial guess.

# Example

```julia-repl
julia> using CTModels

julia> init = CTModels.build_initial_guess(ocp, (state=t -> [0.0], control=t -> [1.0]))
```
"""
function build_initial_guess(ocp::AbstractOptimalControlProblem, init_data)
    if init_data === nothing || init_data === ()
        return initial_guess(ocp)
    elseif init_data isa AbstractOptimalControlInitialGuess
        return init_data
    elseif init_data isa AbstractOptimalControlPreInit
        return _initial_guess_from_preinit(ocp, init_data)
    elseif init_data isa AbstractSolution
        return _initial_guess_from_solution(ocp, init_data)
    elseif init_data isa NamedTuple
        return _initial_guess_from_namedtuple(ocp, init_data)
    else
        throw(Exceptions.IncorrectArgument(
            "Unsupported initial guess type",
            got="$(typeof(init_data))",
            expected="nothing, OptimalControlInitialGuess, OptimalControlPreInit, Solution, or NamedTuple",
            suggestion="Use one of the supported types for initial guess specification",
            context="build_initial_guess"
        ))
    end
end

"""
$(TYPEDSIGNATURES)

Validate an initial guess for an optimal control problem.

# Throws

- `Exceptions.IncorrectArgument` if dimensions do not match.
"""
function validate_initial_guess(
    ocp::AbstractOptimalControlProblem, init::AbstractOptimalControlInitialGuess
)
    if init isa OptimalControlInitialGuess
        return _validate_initial_guess(ocp, init)
    else
        # For now, only OptimalControlInitialGuess is supported.
        return init
    end
end
