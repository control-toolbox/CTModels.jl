# Enhanced Error Handling System - Demo
# This example demonstrates the new user-friendly error messages in CTModels

using CTModels

println("="^70)
println("CTModels Enhanced Error Handling Demo")
println("="^70)

# ============================================================================
# Example 1: User-Friendly Error Display with Location (Default)
# ============================================================================

println("\n📌 Example 1: User-Friendly Error Display with Location")
println("-"^70)

try
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="t")
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    CTModels.control!(ocp, 1, "u")
    
    # This will throw an enriched error with clear message and location
    CTModels.objective!(ocp, :invalid, mayer=(x0, xf, v) -> sum(xf))
catch e
    # Error is displayed in user-friendly format automatically
    println("Caught error (displayed above)")
end

# ============================================================================
# Example 2: Full Stacktrace Mode (For Debugging)
# ============================================================================

println("\n📌 Example 2: Full Stacktrace Mode")
println("-"^70)

# Enable full stacktraces for debugging
CTModels.set_show_full_stacktrace!(true)
println("Full stacktrace mode: ENABLED")

try
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="t")
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    
    # This will show full Julia stacktrace
    CTModels.objective!(ocp, :wrong, mayer=(x0, xf, v) -> sum(xf))
catch e
    println("Caught error with full stacktrace (displayed above)")
end

# Reset to user-friendly mode
CTModels.set_show_full_stacktrace!(false)
println("\nFull stacktrace mode: DISABLED (back to user-friendly)")

# ============================================================================
# Example 3: Name Conflict Detection
# ============================================================================

println("\n📌 Example 3: Name Conflict Detection")
println("-"^70)

try
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="t")
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    
    # This will throw an error because "x" is already used
    CTModels.control!(ocp, 1, "x")
catch e
    println("Caught name conflict error (displayed above)")
end

# ============================================================================
# Example 4: Bounds Validation
# ============================================================================

println("\n📌 Example 4: Bounds Validation")
println("-"^70)

try
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="t")
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    CTModels.control!(ocp, 1, "u")
    CTModels.variable!(ocp, 1, "v")
    
    # This will throw an error because lb > ub
    CTModels.constraint!(ocp, :state, lb=[1, 2], ub=[0, 1])
catch e
    println("Caught bounds validation error (displayed above)")
end

# ============================================================================
# Example 5: Unauthorized Call Detection
# ============================================================================

println("\n📌 Example 5: Unauthorized Call Detection")
println("-"^70)

try
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="t")
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    
    # Try to set state twice
    CTModels.state!(ocp, 1, "y")
catch e
    println("Caught unauthorized call error (displayed above)")
end

# ============================================================================
# Example 6: Enriched Error with Location Display
# ============================================================================

println("\n📌 Example 6: Enriched Error with Location Display")
println("-"^70)

using CTModels.Exceptions

# Force user-friendly mode to show location
CTModels.set_show_full_stacktrace!(false)

try
    # Create and throw enriched error directly to see location
    throw(IncorrectArgument(
        "Invalid optimization criterion",
        got=":minimize",
        expected=":min or :max",
        suggestion="Use :min for minimization or :max for maximization",
        context="objective! function call"
    ))
catch e
    println("Error caught - location should be shown above")
end

# ============================================================================
# Example 7: Programmatic Error Creation
# ============================================================================

println("\n📌 Example 7: Creating Enriched Errors Programmatically")
println("-"^70)

# Create an enriched error with all fields
error_example = IncorrectArgument(
    "Invalid optimization criterion",
    got=":minimize",
    expected=":min or :max",
    suggestion="Use :min for minimization or :max for maximization",
    context="objective! function call"
)

println("Created error object:")
println("  Message: ", error_example.msg)
println("  Got: ", error_example.got)
println("  Expected: ", error_example.expected)
println("  Suggestion: ", error_example.suggestion)
println("  Context: ", error_example.context)

# ============================================================================
# Summary
# ============================================================================

println("\n" * "="^70)
println("Summary")
println("="^70)
println("""
The enhanced error handling system provides:

✅ User-Friendly Display (Default)
   - Clear problem description
   - What was received vs expected
   - Actionable suggestions
   - No overwhelming stacktraces
   - **Code location with file and line numbers**

✅ Full Stacktrace Mode (For Debugging)
   - Enable with: CTModels.set_show_full_stacktrace!(true)
   - Shows complete Julia stacktrace
   - Useful for debugging internal issues

✅ Enriched Exceptions
   - IncorrectArgument: Invalid input values
   - UnauthorizedCall: Wrong calling context
   - NotImplemented: Unimplemented interfaces
   - ParsingError: Parsing errors

✅ CTBase Compatible
   - Can convert to CTBase exceptions
   - Ready for future migration

✅ Smart Location Detection
   - Filters out Julia internal frames
   - Shows only user code locations
   - Displays call stack hierarchy

For more information, see the documentation.
""")

println("="^70)
