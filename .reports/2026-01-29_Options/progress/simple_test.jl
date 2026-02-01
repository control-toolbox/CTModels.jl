# Simple test for enhanced modelers
using CTModels
using CTModels.Modelers

println("Testing ADNLPModeler...")
modeler1 = ADNLPModeler(matrix_free=true, name="Test")
println("✅ ADNLPModeler works!")

println("Testing ExaModeler...")
modeler2 = ExaModeler(auto_detect_gpu=true)
println("✅ ExaModeler works!")

println("Testing validation...")
try
    ADNLPModeler(backend=:invalid)
    println("❌ Validation failed")
catch
    println("✅ Validation works!")
end

println("🎉 All tests passed!")
