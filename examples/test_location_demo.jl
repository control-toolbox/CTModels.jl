using CTModels

println("Testing error location display...")

try
    ocp = CTModels.PreModel()
    CTModels.time!(ocp, t0=0, tf=1, time_name="t")
    CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
    CTModels.control!(ocp, 1, "u")
    
    # This should show the location in this file
    CTModels.objective!(ocp, :invalid, mayer=(x0, xf, v) -> sum(xf))
catch e
    println("Error caught - location should be shown above")
end
