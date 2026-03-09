# ------------------------------------------------------------------------------
# Initial Guess API
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Create a pre-initialisation object for an initial guess.

This function creates an `PreInitialGuess` that can later be
processed into a full `InitialGuess`.

# Arguments

- `state`: Raw state initialisation data (function, vector, matrix, or `nothing`).
- `control`: Raw control initialisation data (function, vector, matrix, or `nothing`).
- `variable`: Raw variable initialisation data (scalar, vector, or `nothing`).

# Returns

- `PreInitialGuess`: A pre-initialisation container.

# Example

```julia-repl
julia> using CTModels

julia> pre = CTModels.pre_initial_guess(state=t -> [0.0, 0.0], control=t -> [1.0])
```
"""
function pre_initial_guess(; state=nothing, control=nothing, variable=nothing)
    return PreInitialGuess(state, control, variable)
end

"""
$(TYPEDSIGNATURES)

Construct an initial guess for an optimal control problem.

Builds an `InitialGuess` from the provided state, control,
and variable data. The returned initial guess is **not validated** against the
problem dimensions; use `build_initial_guess` or
`validate_initial_guess` for dimension checking.

# Arguments

- `ocp::AbstractModel`: The optimal control problem.
- `state`: State initialisation (function `t -> x(t)`, constant, vector, or `nothing`).
- `control`: Control initialisation (function `t -> u(t)`, constant, vector, or `nothing`).
- `variable`: Variable initialisation (scalar, vector, or `nothing`).

# Returns

- `InitialGuess`: An initial guess (not yet validated).

# Example

```julia-repl
julia> using CTModels

julia> init = CTModels.initial_guess(ocp; state=t -> [0.0, 0.0], control=t -> [1.0])
```
"""
function initial_guess(
    ocp::AbstractModel;
    state::Union{Nothing,Function,Real,Vector{<:Real}}=nothing,
    control::Union{Nothing,Function,Real,Vector{<:Real}}=nothing,
    variable::Union{Nothing,Real,Vector{<:Real}}=nothing,
)
    x = initial_state(ocp, state)
    u = initial_control(ocp, control)
    v = initial_variable(ocp, variable)
    return InitialGuess(x, u, v)
end

"""
$(TYPEDSIGNATURES)

Build and validate an initial guess from various input formats.

Accepts multiple input types, converts them to an `InitialGuess`,
and validates dimensions against the problem definition. This is the **single entry
point** that guarantees a validated initial guess.

Supported input types:
- `nothing` or `()`: Returns default initial guess.
- `AbstractInitialGuess`: Validates and returns.
- `AbstractPreInitialGuess`: Converts from pre-initialisation.
- `AbstractSolution`: Warm-starts from a previous solution.
- `NamedTuple`: Parses named fields for state, control, and variable.

# Arguments

- `ocp::AbstractModel`: The optimal control problem.
- `init_data`: The initial guess data in one of the supported formats.

# Returns

- `InitialGuess`: A validated initial guess.

# Throws

- `Exceptions.IncorrectArgument`: If `init_data` has an unsupported type or if
  dimensions do not match the problem definition.

# Example

```julia-repl
julia> using CTModels

julia> init = CTModels.build_initial_guess(ocp, (state=t -> [0.0], control=t -> [1.0]))
```
"""
function build_initial_guess(ocp::AbstractModel, init_data)
    # Phase 1: Construction (no validation)
    init = if init_data === nothing || init_data === ()
        initial_guess(ocp)
    elseif init_data isa AbstractInitialGuess
        init_data
    elseif init_data isa AbstractPreInitialGuess
        _initial_guess_from_preinit(ocp, init_data)
    elseif init_data isa AbstractSolution
        _initial_guess_from_solution(ocp, init_data)
    elseif init_data isa NamedTuple
        _initial_guess_from_namedtuple(ocp, init_data)
    else
        throw(
            Exceptions.IncorrectArgument(
                "Unsupported initial guess type";
                got="$(typeof(init_data))",
                expected="nothing, InitialGuess, PreInitialGuess, Solution, or NamedTuple",
                suggestion="Use one of the supported types for initial guess specification",
                context="build_initial_guess",
            ),
        )
    end

    # Phase 2: Centralised validation
    return validate_initial_guess(ocp, init)
end

"""
$(TYPEDSIGNATURES)

Validate an initial guess against an optimal control problem.

Checks that the state, control, and variable dimensions of the initial guess
are consistent with the problem definition. This function can be called
explicitly on a manually constructed `InitialGuess`.

# Arguments

- `ocp::AbstractModel`: The optimal control problem.
- `init::AbstractInitialGuess`: The initial guess to validate.

# Returns

- `AbstractInitialGuess`: The validated initial guess (same object).

# Throws

- `Exceptions.IncorrectArgument`: If dimensions do not match the problem definition.
"""
function validate_initial_guess(ocp::AbstractModel, init::AbstractInitialGuess)
    if init isa InitialGuess
        return _validate_initial_guess(ocp, init)
    else
        return init
    end
end
