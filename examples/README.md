# CTModels Examples

This directory contains examples demonstrating the enhanced error handling system in CTModels.

## Files

### `error_handling_demo.jl`
**Main demonstration** of the enhanced error handling system.

Shows:
- User-friendly error display with location information
- Full stacktrace mode for debugging
- Various error types (criteria validation, name conflicts, bounds validation, unauthorized calls)
- Programmatic error creation
- Stacktrace control

**Run with**:
```bash
julia --project=. examples/error_handling_demo.jl
```

### `test_location_demo.jl`
**Quick test** of error location display.

Shows how the enhanced exceptions display the exact location in user code where errors occur.

**Run with**:
```bash
julia --project=. examples/test_location_demo.jl
```

### `test_migration_demo.jl`
**Migration demonstration** comparing CTBase vs enriched exceptions.

Shows:
- Current CTBase behavior (basic messages)
- New enriched exception behavior (detailed messages with context)
- Comparison between the two approaches
- Migration path guidance

**Run with**:
```bash
julia --project=. examples/test_migration_demo.jl
```

## Features Demonstrated

### ✅ User-Friendly Error Display
- Clear problem descriptions
- Structured format with emojis
- Actionable suggestions
- No overwhelming stacktraces by default

### ✅ Code Location Information
- File and line number where error occurred
- Call stack hierarchy
- Filters out Julia internal frames
- Shows only user-relevant locations

### ✅ Stacktrace Control
- User-friendly mode (default): Clean display with location
- Debug mode: Full Julia stacktraces
- Easy toggle with `CTModels.set_show_full_stacktrace!(bool)`

### ✅ Enriched Exceptions
- `IncorrectArgument`: Invalid input values with got/expected/suggestion
- `UnauthorizedCall`: Wrong calling context with reason/suggestion
- `NotImplemented`: Unimplemented interfaces
- `ParsingError`: Parsing errors with location

### ✅ CTBase Compatibility
- Can convert enriched exceptions to CTBase format
- Ready for future migration to CTBase
- Backward compatibility maintained

## Key Benefits

1. **Better User Experience**: Clear, actionable error messages instead of cryptic stacktraces
2. **Faster Debugging**: Exact location of errors in user code
3. **Contextual Help**: Suggestions on how to fix common problems
4. **Flexible Display**: Toggle between user-friendly and debug modes
5. **Future-Ready**: Compatible with CTBase migration path

## Usage Tips

### Default Usage (Recommended)
```julia
using CTModels

# Errors automatically display in user-friendly format
ocp = CTModels.PreModel()
CTModels.objective!(ocp, :invalid, mayer=...)  # Clear error with location
```

### Debug Mode
```julia
# Enable full stacktraces for complex issues
CTModels.set_show_full_stacktrace!(true)
# ... your code here ...
CTModels.set_show_full_stacktrace!(false)  # Reset to user-friendly
```

### Creating Custom Errors
```julia
using CTModels.Exceptions

throw(IncorrectArgument(
    "Invalid parameter",
    got="value",
    expected="valid_value",
    suggestion="Use valid_value instead",
    context="my_function"
))
```

## Migration Path

The enhanced error system is ready for immediate use. Existing CTBase exceptions will continue to work, and you can gradually migrate to enriched exceptions for better user experience.

See the documentation in `reports/2026-01-28_Checkings/reference/02_enhanced_error_system.md` for complete details.
