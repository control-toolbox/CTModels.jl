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

# Exported Functions

- `set_show_full_stacktrace!`: Control stacktrace display
- `get_show_full_stacktrace`: Get current stacktrace setting
- `to_ctbase`: Convert to CTBase exceptions

# Exported Types

- `CTModelsException`: Abstract base type
- `IncorrectArgument`: Invalid argument exception
- `UnauthorizedCall`: Unauthorized call exception  
- `NotImplemented`: Unimplemented interface exception
- `ParsingError`: Parsing error exception
"""
module Exceptions

using CTBase

# Include the main exception definitions
include("exceptions.jl")

end # module
