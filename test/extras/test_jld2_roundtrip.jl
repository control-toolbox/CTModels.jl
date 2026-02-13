# Test script for JLD2 round-trip serialization
# This tests the new discretization-based JLD2 export/import

using Pkg
Pkg.activate(@__DIR__)  # Activate test/extras/Project.toml

# Load JLD2 first to trigger the extension
using JLD2
using CTModels

# Load test problem
include("../problems/solution_example.jl")
ocp, sol_original = solution_example()

println("=== Test JLD2 Round-Trip ===")
println("Original solution:")
println("  Objective: ", CTModels.objective(sol_original))
println("  State at t=0.5: ", CTModels.state(sol_original)(0.5))
println("  Control at t=0.5: ", CTModels.control(sol_original)(0.5))
println("  Costate at t=0.5: ", CTModels.costate(sol_original)(0.5))

# Export
filename = "test_jld2_roundtrip"
CTModels.export_ocp_solution(CTModels.JLD2Tag(), sol_original; filename=filename)
println("\n✓ Export successful")

# Import
sol_imported = CTModels.import_ocp_solution(CTModels.JLD2Tag(), ocp; filename=filename)
println("✓ Import successful")

# Verify that values are identical
println("\nImported solution:")
println("  Objective: ", CTModels.objective(sol_imported))
println("  State at t=0.5: ", CTModels.state(sol_imported)(0.5))
println("  Control at t=0.5: ", CTModels.control(sol_imported)(0.5))
println("  Costate at t=0.5: ", CTModels.costate(sol_imported)(0.5))

# Detailed comparison
obj_match = CTModels.objective(sol_original) ≈ CTModels.objective(sol_imported)
state_match = CTModels.state(sol_original)(0.5) ≈ CTModels.state(sol_imported)(0.5)
control_match = CTModels.control(sol_original)(0.5) ≈ CTModels.control(sol_imported)(0.5)
costate_match = CTModels.costate(sol_original)(0.5) ≈ CTModels.costate(sol_imported)(0.5)

# Test on multiple time points
t_test = [0.0, 0.25, 0.5, 0.75, 1.0]
all_states_match = all(CTModels.state(sol_original)(t) ≈ CTModels.state(sol_imported)(t) for t in t_test)
all_controls_match = all(CTModels.control(sol_original)(t) ≈ CTModels.control(sol_imported)(t) for t in t_test)

println("\n=== Validation ===")
println("  Objective match: ", obj_match ? "✓" : "✗")
println("  State match (t=0.5): ", state_match ? "✓" : "✗")
println("  Control match (t=0.5): ", control_match ? "✓" : "✗")
println("  Costate match (t=0.5): ", costate_match ? "✓" : "✗")
println("  All states match: ", all_states_match ? "✓" : "✗")
println("  All controls match: ", all_controls_match ? "✓" : "✗")

success = obj_match && state_match && control_match && costate_match && 
          all_states_match && all_controls_match

if success
    println("\n✅ JLD2 Round-trip successful!")
    # Cleanup
    rm(filename * ".jld2")
    exit(0)
else
    println("\n❌ Round-trip failed")
    exit(1)
end
