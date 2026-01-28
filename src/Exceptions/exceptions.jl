# CTModels Enhanced Exception System
# Based on CTBase.jl exception.jl but with enriched error handling
# Compatible with CTBase exceptions for future migration

"""
    CTModelsException

Abstract supertype for all CTModels exceptions.
Compatible with CTBase.CTException for future migration.

All exceptions inherit from this type to allow uniform error handling.
"""
abstract type CTModelsException <: Exception end

# Global configuration for error display
"""
    SHOW_FULL_STACKTRACE

Module-level configuration to control stacktrace display.
Set to `true` to show full Julia stacktraces, `false` for user-friendly display only.

Default: `false` (user-friendly display)

# Example
```julia
CTModels.set_show_full_stacktrace!(true)  # Show full stacktraces
CTModels.set_show_full_stacktrace!(false) # User-friendly display only
```
"""
const SHOW_FULL_STACKTRACE = Ref{Bool}(false)

"""
    set_show_full_stacktrace!(value::Bool)

Configure whether to display full Julia stacktraces in error messages.

# Arguments
- `value::Bool`: `true` to show full stacktraces, `false` for user-friendly display

# Example
```julia
# Enable full stacktraces for debugging
CTModels.set_show_full_stacktrace!(true)

# Disable for cleaner user experience (default)
CTModels.set_show_full_stacktrace!(false)
```
"""
function set_show_full_stacktrace!(value::Bool)
    SHOW_FULL_STACKTRACE[] = value
    return nothing
end

"""
    get_show_full_stacktrace()

Get current stacktrace display configuration.

# Returns
- `Bool`: Current setting for full stacktrace display
"""
function get_show_full_stacktrace()
    return SHOW_FULL_STACKTRACE[]
end

# ------------------------------------------------------------------------
# Enhanced Exception Types
# ------------------------------------------------------------------------

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
    got::Union{String, Nothing}
    expected::Union{String, Nothing}
    suggestion::Union{String, Nothing}
    context::Union{String, Nothing}
    
    # Constructor for enriched exceptions
    IncorrectArgument(
        msg::String;
        got::Union{String, Nothing}=nothing,
        expected::Union{String, Nothing}=nothing,
        suggestion::Union{String, Nothing}=nothing,
        context::Union{String, Nothing}=nothing
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
    reason::Union{String, Nothing}
    suggestion::Union{String, Nothing}
    context::Union{String, Nothing}
    
    UnauthorizedCall(
        msg::String;
        reason::Union{String, Nothing}=nothing,
        suggestion::Union{String, Nothing}=nothing,
        context::Union{String, Nothing}=nothing
    ) = new(msg, reason, suggestion, context)
end

"""
    NotImplemented <: CTModelsException

Exception for unimplemented interface methods.

# Fields
- `msg::String`: Description of what is not implemented
- `type_info::Union{String, Nothing}`: Type information (optional)

# Example
```julia
throw(NotImplemented("run! not implemented for MyAlgorithm"))
```
"""
struct NotImplemented <: CTModelsException
    msg::String
    type_info::Union{String, Nothing}
    
    NotImplemented(msg::String; type_info::Union{String, Nothing}=nothing) = new(msg, type_info)
end

"""
    ParsingError <: CTModelsException

Exception for parsing errors in DSLs or structured input.

# Fields
- `msg::String`: Description of the parsing error
- `location::Union{String, Nothing}`: Where in the input the error occurred (optional)

# Example
```julia
throw(ParsingError("Unexpected token 'end'", location="line 42"))
```
"""
struct ParsingError <: CTModelsException
    msg::String
    location::Union{String, Nothing}
    
    ParsingError(msg::String; location::Union{String, Nothing}=nothing) = new(msg, location)
end

# ------------------------------------------------------------------------
# Custom Display Functions
# ------------------------------------------------------------------------

"""
    extract_user_frames(st::Vector)

Extract stacktrace frames that are relevant to user code.
Filters out Julia stdlib and CTModels internal frames.

# Arguments
- `st::Vector`: Stacktrace from `stacktrace(catch_backtrace())`

# Returns
- `Vector`: Filtered stacktrace frames
"""
function extract_user_frames(st::Vector)
    user_frames = filter(st) do frame
        file_str = string(frame.file)
        # Keep frames that are NOT from Julia stdlib or CTModels internals
        !contains(file_str, ".julia/") &&
        !contains(file_str, "juliaup/") &&
        !contains(file_str, "/macros.jl") &&
        !contains(file_str, "/exception") &&
        !contains(file_str, "Base.jl") &&
        !contains(file_str, "boot.jl")
    end
    return user_frames
end

"""
    format_user_friendly_error(io::IO, e::CTModelsException)

Display an error in a user-friendly format with clear sections and user code location.

# Arguments
- `io::IO`: Output stream
- `e::CTModelsException`: The exception to display
"""
function format_user_friendly_error(io::IO, e::CTModelsException)
    println(io, "\n" * "━"^70)
    printstyled(io, "❌ ERROR in CTModels\n"; color=:red, bold=true)
    println(io, "━"^70)
    
    # Main problem
    println(io, "\n📋 Problem:")
    println(io, "   ", e.msg)
    
    # Type-specific details
    if e isa IncorrectArgument
        if !isnothing(e.got)
            println(io, "\n🔍 Details:")
            println(io, "   Got:      ", e.got)
            if !isnothing(e.expected)
                println(io, "   Expected: ", e.expected)
            end
        end
        
        if !isnothing(e.context)
            println(io, "\n📂 Context:")
            println(io, "   ", e.context)
        end
        
        if !isnothing(e.suggestion)
            println(io, "\n💡 Suggestion:")
            println(io, "   ", e.suggestion)
        end
        
    elseif e isa UnauthorizedCall
        if !isnothing(e.reason)
            println(io, "\n❓ Reason:")
            println(io, "   ", e.reason)
        end
        
        if !isnothing(e.context)
            println(io, "\n📂 Context:")
            println(io, "   ", e.context)
        end
        
        if !isnothing(e.suggestion)
            println(io, "\n💡 Suggestion:")
            println(io, "   ", e.suggestion)
        end
        
    elseif e isa NotImplemented
        if !isnothing(e.type_info)
            println(io, "\n🔧 Type:")
            println(io, "   ", e.type_info)
        end
        
    elseif e isa ParsingError
        if !isnothing(e.location)
            println(io, "\n📍 Location:")
            println(io, "   ", e.location)
        end
    end
    
    # Add user code location
    user_frames = extract_user_frames(stacktrace(catch_backtrace()))
    if !isempty(user_frames)
        println(io, "\n📍 In your code:")
        # Show up to 3 most relevant user frames
        for (i, frame) in enumerate(user_frames[1:min(3, length(user_frames))])
            file_name = basename(string(frame.file))
            line_info = frame.line
            func_name = frame.func
            
            if i == 1
                # The most recent frame (where error occurred)
                println(io, "   $func_name at $file_name:$line_info")
            else
                # Previous frames (call stack)
                println(io, "   called from $func_name at $file_name:$line_info")
            end
        end
    end
    
    # Stacktrace info
    if !SHOW_FULL_STACKTRACE[]
        println(io, "\n💬 Note:")
        println(io, "   For full Julia stacktrace, run:")
        printstyled(io, "   CTModels.set_show_full_stacktrace!(true)\n"; color=:cyan)
    end
    
    println(io, "━"^70 * "\n")
end

"""
    Base.showerror(io::IO, e::IncorrectArgument)

Custom error display for IncorrectArgument.
Shows user-friendly format if SHOW_FULL_STACKTRACE is false.
"""
function Base.showerror(io::IO, e::IncorrectArgument)
    if SHOW_FULL_STACKTRACE[]
        # Standard Julia error display
        printstyled(io, "IncorrectArgument"; color=:red, bold=true)
        print(io, ": ", e.msg)
        if !isnothing(e.got)
            print(io, " (got: ", e.got, ")")
        end
        if !isnothing(e.expected)
            print(io, " (expected: ", e.expected, ")")
        end
    else
        # User-friendly display
        format_user_friendly_error(io, e)
    end
end

"""
    Base.showerror(io::IO, e::UnauthorizedCall)

Custom error display for UnauthorizedCall.
"""
function Base.showerror(io::IO, e::UnauthorizedCall)
    if SHOW_FULL_STACKTRACE[]
        printstyled(io, "UnauthorizedCall"; color=:red, bold=true)
        print(io, ": ", e.msg)
        if !isnothing(e.reason)
            print(io, " (reason: ", e.reason, ")")
        end
    else
        format_user_friendly_error(io, e)
    end
end

"""
    Base.showerror(io::IO, e::NotImplemented)

Custom error display for NotImplemented.
"""
function Base.showerror(io::IO, e::NotImplemented)
    if SHOW_FULL_STACKTRACE[]
        printstyled(io, "NotImplemented"; color=:red, bold=true)
        print(io, ": ", e.msg)
    else
        format_user_friendly_error(io, e)
    end
end

"""
    Base.showerror(io::IO, e::ParsingError)

Custom error display for ParsingError.
"""
function Base.showerror(io::IO, e::ParsingError)
    if SHOW_FULL_STACKTRACE[]
        printstyled(io, "ParsingError"; color=:red, bold=true)
        print(io, ": ", e.msg)
    else
        format_user_friendly_error(io, e)
    end
end

# ------------------------------------------------------------------------
# Compatibility Layer with CTBase
# ------------------------------------------------------------------------

"""
    to_ctbase(e::IncorrectArgument)

Convert CTModels.IncorrectArgument to CTBase.IncorrectArgument.
Useful for migration to CTBase.

# Arguments
- `e::IncorrectArgument`: CTModels exception

# Returns
- `CTBase.IncorrectArgument`: Compatible CTBase exception
"""
function to_ctbase(e::IncorrectArgument)
    # Build a complete message with all context
    full_msg = e.msg
    if !isnothing(e.got)
        full_msg *= " (got: $(e.got))"
    end
    if !isnothing(e.expected)
        full_msg *= " (expected: $(e.expected))"
    end
    if !isnothing(e.suggestion)
        full_msg *= ". Suggestion: $(e.suggestion)"
    end
    
    return CTBase.IncorrectArgument(full_msg)
end

"""
    to_ctbase(e::UnauthorizedCall)

Convert CTModels.UnauthorizedCall to CTBase.UnauthorizedCall.
"""
function to_ctbase(e::UnauthorizedCall)
    full_msg = e.msg
    if !isnothing(e.reason)
        full_msg *= " (reason: $(e.reason))"
    end
    if !isnothing(e.suggestion)
        full_msg *= ". Suggestion: $(e.suggestion)"
    end
    
    return CTBase.UnauthorizedCall(full_msg)
end

# Export public API
export CTModelsException
export IncorrectArgument, UnauthorizedCall, NotImplemented, ParsingError
export set_show_full_stacktrace!, get_show_full_stacktrace
export to_ctbase
