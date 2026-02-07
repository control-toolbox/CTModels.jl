# using JSON3

# Simulate JSON data structures
# Case 1: 1D path (e.g. state of dimension 1 over 3 time steps)
# JSON: [[1.0], [2.0], [3.0]]
data_1d = [[1.0], [2.0], [3.0]]

# Case 2: Multi-D path (e.g. state of dimension 2 over 3 time steps)
# JSON: [[1.0, 1.1], [2.0, 2.1], [3.0, 3.1]]
data_nd = [[1.0, 1.1], [2.0, 2.1], [3.0, 3.1]]

println("--- Case 1: 1D Data ---")
stacked_1d = stack(data_1d; dims=1)
println("Type: ", typeof(stacked_1d))
println("Size: ", size(stacked_1d))
println("Content: ", stacked_1d)

println("\n--- Case 2: Multi-D Data ---")
stacked_nd = stack(data_nd; dims=1)
println("Type: ", typeof(stacked_nd))
println("Size: ", size(stacked_nd))
println("Content: ", stacked_nd)

# Verify current logic for 1D
if stacked_1d isa Vector
    println("\n[Current Logic] 1D is Vector -> Applying transformation")
    converted_1d = Matrix{Float64}(reduce(hcat, stacked_1d)')
    println("Converted 1D Size: ", size(converted_1d))
    println("Converted 1D Content: ", converted_1d)
end

# Case 3: Flat Vector (possible when state dim is 1 and exported as simple array)
# JSON: [1.0, 2.0, 3.0]
data_flat = [1.0, 2.0, 3.0]

println("\n--- Case 3: Flat Vector ---")
stacked_flat = stack(data_flat; dims=1)
println("Type: ", typeof(stacked_flat))
println("Size: ", size(stacked_flat))
println("Content: ", stacked_flat)

if stacked_flat isa Vector
    println("\n[Current Logic Triggered] Flat is Vector -> Applying transformation")
    converted_flat = Matrix{Float64}(reduce(hcat, stacked_flat)')
    println("Converted Flat Size: ", size(converted_flat))
    println("Converted Flat Content: ", converted_flat)
end
