"""
    Exceptions

Enhanced exception system for CTModels with user-friendly error messages.

This module provides enriched exceptions compatible with CTBase but with additional
fields for better error reporting, suggestions, and context.

# Main Features

1. **Enriched Exceptions**: `IncorrectArgument`, `UnauthorizedCall`, etc. with optional fields
2. **User-Friendly Display**: Clear, formatted error messages with emojis and sections
3. **Stacktrace Control**: Toggle between full Julia stacktraces and clean user display
4. **CTBase Compatibility**: Can convert to CTBase exceptions for future migration

# Usage

```julia
using CTModels

# Throw enriched exceptions
throw(CTModels.Exceptions.IncorrectArgument(
    "Invalid criterion",
    got=":invalid",
    expected=":min or :max",
    suggestion="Use objective!(ocp, :min, ...) or objective!(ocp, :max, ...)"
))

# Control stacktrace display
CTModels.set_show_full_stacktrace!(true)   # Show full Julia stacktraces
CTModels.set_show_full_stacktrace!(false)  # User-friendly display (default)
```

# Organization

The Exceptions module is organized into thematic files:

- **config.jl**: Global configuration for stacktrace display
- **types.jl**: Exception type definitions
- **display.jl**: Custom display functions for user-friendly error messages
- **conversion.jl**: Compatibility layer with CTBase exceptions

# Public API

## Exported Types
- `CTModelsException`: Abstract base type
- `IncorrectArgument`: Invalid argument exception
- `UnauthorizedCall`: Unauthorized call exception
- `NotImplemented`: Unimplemented interface exception
- `ParsingError`: Parsing error exception

## Exported Functions
- `set_show_full_stacktrace!`: Control stacktrace display
- `get_show_full_stacktrace`: Get current stacktrace setting
- `to_ctbase`: Convert to CTBase exceptions

See also: [`CTModels`](@ref)
"""
module Exceptions

using CTBase

# Configuration
include("config.jl")

# Type definitions
include("types.jl")

# Display functions
include("display.jl")

# CTBase compatibility
include("conversion.jl")

# Export public API
export CTModelsException
export IncorrectArgument, UnauthorizedCall, NotImplemented, ParsingError
export set_show_full_stacktrace!, get_show_full_stacktrace
export to_ctbase

end # module
