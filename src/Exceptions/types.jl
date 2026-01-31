# Exception type definitions for CTModels
# Based on CTBase.jl but with enriched error handling

"""
    CTModelsException

Abstract supertype for all CTModels exceptions.
Compatible with CTBase.CTException for future migration.

All exceptions inherit from this type to allow uniform error handling.
"""
abstract type CTModelsException <: Exception end

"""
    IncorrectArgument <: CTModelsException

Exception thrown when an individual argument is invalid or violates a precondition.

This is an enhanced version of `CTBase.IncorrectArgument` with additional fields
for better error reporting and user guidance.

# Fields
- `msg::String`: Main error message describing the problem
- `got::Union{String, Nothing}`: What value was received (optional)
- `expected::Union{String, Nothing}`: What value was expected (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)
- `context::Union{String, Nothing}`: Where the error occurred (optional)

# Examples
```julia
# Simple message
throw(IncorrectArgument("Invalid criterion"))

# With details
throw(IncorrectArgument(
    "Invalid criterion",
    got=":invalid",
    expected=":min or :max",
    suggestion="Use objective!(ocp, :min, ...) or objective!(ocp, :max, ...)"
))

# With full context
throw(IncorrectArgument(
    "Dimension mismatch",
    got="vector of length 3",
    expected="vector of length 2",
    suggestion="Provide a vector matching the state dimension",
    context="initial_guess for state"
))
```

# See Also
- [`UnauthorizedCall`](@ref): For state-related or context-related errors
- [`set_show_full_stacktrace!`](@ref): Control stacktrace display
"""
struct IncorrectArgument <: CTModelsException
    msg::String
    got::Union{String,Nothing}
    expected::Union{String,Nothing}
    suggestion::Union{String,Nothing}
    context::Union{String,Nothing}

    # Constructor for enriched exceptions
    IncorrectArgument(
        msg::String;
        got::Union{String,Nothing}=nothing,
        expected::Union{String,Nothing}=nothing,
        suggestion::Union{String,Nothing}=nothing,
        context::Union{String,Nothing}=nothing,
    ) = new(msg, got, expected, suggestion, context)
end

"""
    UnauthorizedCall <: CTModelsException

Exception thrown when a function call is not allowed in the current state.

Enhanced version with additional context for better error reporting.

# Fields
- `msg::String`: Main error message
- `reason::Union{String, Nothing}`: Why the call is unauthorized (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)
- `context::Union{String, Nothing}`: Where the error occurred (optional)

# Examples
```julia
# Simple message
throw(UnauthorizedCall("State already set"))

# With details
throw(UnauthorizedCall(
    "Cannot call state! twice",
    reason="state has already been defined for this OCP",
    suggestion="Create a new OCP instance or use a different component name"
))
```

# See Also
- [`IncorrectArgument`](@ref): For input validation errors
"""
struct UnauthorizedCall <: CTModelsException
    msg::String
    reason::Union{String,Nothing}
    suggestion::Union{String,Nothing}
    context::Union{String,Nothing}

    UnauthorizedCall(
        msg::String;
        reason::Union{String,Nothing}=nothing,
        suggestion::Union{String,Nothing}=nothing,
        context::Union{String,Nothing}=nothing,
    ) = new(msg, reason, suggestion, context)
end

"""
    NotImplemented <: CTModelsException

Exception for unimplemented interface methods.

Enhanced version with additional context for better error reporting.

# Fields
- `msg::String`: Description of what is not implemented
- `type_info::Union{String, Nothing}`: Type information (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)
- `context::Union{String, Nothing}`: Where the error occurred (optional)

# Examples
```julia
# Simple message
throw(NotImplemented("run! not implemented for MyAlgorithm"))

# With full context
throw(NotImplemented(
    "Method solve! not implemented",
    type_info="MyStrategy",
    context="solve call",
    suggestion="Import the relevant package (e.g. CTDirect) or implement solve!(::MyStrategy, ...)"
))
```

# See Also
- [`IncorrectArgument`](@ref): For input validation errors
- [`UnauthorizedCall`](@ref): For state-related or context-related errors
"""
struct NotImplemented <: CTModelsException
    msg::String
    type_info::Union{String,Nothing}
    suggestion::Union{String,Nothing}
    context::Union{String,Nothing}

    NotImplemented(
        msg::String;
        type_info::Union{String,Nothing}=nothing,
        suggestion::Union{String,Nothing}=nothing,
        context::Union{String,Nothing}=nothing,
    ) = new(msg, type_info, suggestion, context)
end

"""
    ParsingError <: CTModelsException

Exception for parsing errors in DSLs or structured input.

Enhanced version with additional context for better error reporting.

# Fields
- `msg::String`: Description of the parsing error
- `location::Union{String, Nothing}`: Where in the input the error occurred (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)

# Examples
```julia
# Simple message
throw(ParsingError("Unexpected token 'end'", location="line 42"))

# with suggestion
throw(ParsingError(
    "Unexpected token 'end'",
    location="line 42, column 15",
    suggestion="Check syntax balance or remove extra 'end'"
))
```

# See Also
- [`IncorrectArgument`](@ref): For input validation errors
"""
struct ParsingError <: CTModelsException
    msg::String
    location::Union{String,Nothing}
    suggestion::Union{String,Nothing}

    ParsingError(
        msg::String;
        location::Union{String,Nothing}=nothing,
        suggestion::Union{String,Nothing}=nothing,
    ) = new(msg, location, suggestion)
end
