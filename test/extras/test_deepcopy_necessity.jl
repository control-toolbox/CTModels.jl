# Test to investigate deepcopy necessity in build_solution
# Phase 3: Deepcopy Optimization

using CTModels
using Test

# Load test helpers
include("../problems/solution_example.jl")

println("\n" * "="^80)
println("Testing deepcopy necessity in build_solution")
println("="^80 * "\n")

# Create a simple OCP and solution
ocp, sol = solution_example()

# Extract the underlying interpolation function
T = CTModels.time_grid(sol)
state_fun = CTModels.state(sol)
control_fun = CTModels.control(sol)

println("Original solution:")
println("  state(0.5) = ", state_fun(0.5))
println("  control(0.5) = ", control_fun(0.5))

# Test 1: Check if closures capture values correctly WITHOUT deepcopy
println("\n" * "-"^80)
println("Test 1: Closure behavior without deepcopy")
println("-"^80)

function create_wrapper_no_deepcopy(f)
    # Simulate what build_solution does, but WITHOUT deepcopy
    wrapper = t -> f(t)
    return wrapper
end

function create_wrapper_with_deepcopy(f)
    # Simulate what build_solution does, WITH deepcopy
    wrapper = deepcopy(t -> f(t))
    return wrapper
end

# Create wrappers
state_no_copy = create_wrapper_no_deepcopy(state_fun)
state_with_copy = create_wrapper_with_deepcopy(state_fun)

println("Without deepcopy: state_no_copy(0.5) = ", state_no_copy(0.5))
println("With deepcopy:    state_with_copy(0.5) = ", state_with_copy(0.5))

@test state_no_copy(0.5) ≈ state_with_copy(0.5)
println("✓ Both produce identical results")

# Test 2: Check if modifying the original affects the wrappers
println("\n" * "-"^80)
println("Test 2: Independence from original function")
println("-"^80)

# We cannot actually "modify" an interpolation function, but we can test
# if creating multiple wrappers from the same source causes issues

state_wrapper_1 = t -> state_fun(t)
state_wrapper_2 = t -> state_fun(t)
state_wrapper_3 = deepcopy(t -> state_fun(t))

println("Wrapper 1 (no copy): ", state_wrapper_1(0.5))
println("Wrapper 2 (no copy): ", state_wrapper_2(0.5))
println("Wrapper 3 (deepcopy): ", state_wrapper_3(0.5))

@test state_wrapper_1(0.5) ≈ state_wrapper_2(0.5) ≈ state_wrapper_3(0.5)
println("✓ All wrappers produce identical results")

# Test 3: Scalar extraction (the actual use case in build_solution)
println("\n" * "-"^80)
println("Test 3: Scalar extraction for 1D case")
println("-"^80)

# Simulate dim_x == 1 case
function create_scalar_wrapper_no_copy(f)
    return t -> f(t)[1]
end

function create_scalar_wrapper_with_copy(f)
    return deepcopy(t -> f(t)[1])
end

scalar_no_copy = create_scalar_wrapper_no_copy(state_fun)
scalar_with_copy = create_scalar_wrapper_with_copy(state_fun)

println("Scalar without deepcopy: ", scalar_no_copy(0.5))
println("Scalar with deepcopy:    ", scalar_with_copy(0.5))

@test scalar_no_copy(0.5) ≈ scalar_with_copy(0.5)
println("✓ Scalar extraction works identically with/without deepcopy")

# Test 4: Basic allocation comparison
println("\n" * "-"^80)
println("Test 4: Basic allocation comparison")
println("-"^80)

println("\nCreating 1000 wrappers WITHOUT deepcopy...")
GC.gc()
mem_before_no_copy = Base.gc_live_bytes()
for i in 1:1000
    _ = create_wrapper_no_deepcopy(state_fun)
end
GC.gc()
mem_after_no_copy = Base.gc_live_bytes()

println("Creating 1000 wrappers WITH deepcopy...")
GC.gc()
mem_before_with_copy = Base.gc_live_bytes()
for i in 1:1000
    _ = create_wrapper_with_deepcopy(state_fun)
end
GC.gc()
mem_after_with_copy = Base.gc_live_bytes()

println("\nMemory impact (approximate):")
println("  Without deepcopy: $(mem_after_no_copy - mem_before_no_copy) bytes")
println("  With deepcopy:    $(mem_after_with_copy - mem_before_with_copy) bytes")
println("\n  Note: These are rough estimates, GC behavior affects measurements")

# Test 5: Full round-trip test
println("\n" * "-"^80)
println("Test 5: Full export/import round-trip with modified build_solution")
println("-"^80)

println("This test would require modifying build_solution to remove deepcopy")
println("and checking if serialization still works correctly.")
println("→ To be done manually if Tests 1-4 show deepcopy is unnecessary")

println("\n" * "="^80)
println("CONCLUSION")
println("="^80)
println("\nBased on the tests above:")
println("1. Closures capture function references correctly without deepcopy")
println("2. Multiple wrappers from the same source work identically")
println("3. Scalar extraction works without deepcopy")
println("4. Performance impact of deepcopy should be visible in benchmarks")
println("\nIf all tests pass with identical results, deepcopy is likely UNNECESSARY")
println("and can be removed for better performance.")
println("\n" * "="^80 * "\n")
