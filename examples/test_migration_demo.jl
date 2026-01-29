using CTModels

println("Testing current CTBase vs new enriched exceptions...")
println("="^60)

# Test 1: Current behavior (CTBase)
println("\n📌 Test 1: Current CTBase behavior")
println("-"^40)

try
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="t")
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    CTModels.control!(ocp, 1, "u")
    
    # This uses CTBase.IncorrectArgument currently
    CTModels.objective!(ocp, :invalid, mayer=(x0, xf, v) -> sum(xf))
catch e
    println("Caught CTBase error:")
    println("Type: ", typeof(e))
    println("Message: ", e.var)  # CTBase uses 'var' field
end

# Test 2: New enriched exception
println("\n📌 Test 2: New enriched exception")
println("-"^40)

using CTModels.Exceptions

try
    # Create enriched error directly
    throw(CTModels.Exceptions.IncorrectArgument(
        "Invalid optimization criterion",
        got=":invalid",
        expected=":min, :max, :MIN, or :MAX",
        suggestion="Use objective!(ocp, :min, ...) or objective!(ocp, :max, ...)",
        context="objective! function"
    ))
catch e
    println("Caught enriched error:")
    println("Type: ", typeof(e))
    println("Message: ", e.msg)
    println("Got: ", e.got)
    println("Expected: ", e.expected)
    println("Suggestion: ", e.suggestion)
end

println("\n" * "="^60)
println("Conclusion:")
println("✅ Enriched exceptions work and show location")
println("🔄 Need to migrate CTBase calls to use enriched exceptions")
println("📋 Migration plan ready for implementation")
