# Compatibility layer with CTBase exceptions

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

# Arguments
- `e::UnauthorizedCall`: CTModels exception

# Returns
- `CTBase.UnauthorizedCall`: Compatible CTBase exception
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

"""
    to_ctbase(e::NotImplemented)

Convert CTModels.NotImplemented to CTBase.NotImplemented.

# Arguments
- `e::NotImplemented`: CTModels exception

# Returns
- `CTBase.NotImplemented`: Compatible CTBase exception
"""
function to_ctbase(e::NotImplemented)
    full_msg = e.msg
    if !isnothing(e.type_info)
        full_msg *= " (type: $(e.type_info))"
    end
    if !isnothing(e.context)
        full_msg *= " (context: $(e.context))"
    end
    if !isnothing(e.suggestion)
        full_msg *= ". Suggestion: $(e.suggestion)"
    end

    return CTBase.NotImplemented(full_msg)
end

"""
    to_ctbase(e::ParsingError)

Convert CTModels.ParsingError to CTBase.NotImplemented.

# Arguments
- `e::ParsingError`: CTModels exception

# Returns
- `CTBase.NotImplemented`: Compatible CTBase exception
"""
function to_ctbase(e::ParsingError)
    full_msg = e.msg
    if !isnothing(e.location)
        full_msg *= " (at: $(e.location))"
    end
    if !isnothing(e.suggestion)
        full_msg *= ". Suggestion: $(e.suggestion)"
    end

    return CTBase.NotImplemented(full_msg)
end
