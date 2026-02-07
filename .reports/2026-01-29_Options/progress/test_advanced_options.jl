# Test advanced options for enhanced modelers
using CTModels
using CTModels.Modelers

println("🧪 Testing Advanced Backend Overrides")
println("=" ^ 50)

# Test 1: Advanced backend options
println("\n📋 Test 1: Advanced Backend Options")
try
    modeler = ADNLPModeler(
        backend=:optimized,
        matrix_free=true,
        name="AdvancedTest",
        gradient_backend=nothing,
        hprod_backend=nothing,
        jprod_backend=nothing,
        jacobian_backend=nothing,
        hessian_backend=nothing,
        ghjvprod_backend=nothing,
        hprod_residual_backend=nothing,
        jprod_residual_backend=nothing,
        jtprod_residual_backend=nothing,
        jacobian_residual_backend=nothing,
        hessian_residual_backend=nothing
    )
    println("✅ All advanced backend options work!")
    
    # Check options are accessible
    opts = CTModels.Strategies.options(modeler).options
    println("   Available options: ", length(opts))
    println("   - gradient_backend: ", opts[:gradient_backend])
    println("   - hprod_backend: ", opts[:hprod_backend])
    println("   - ghjvprod_backend: ", opts[:ghjvprod_backend])
    
catch e
    println("❌ Advanced options failed: ", e)
end

# Test 2: Backend override validation
println("\n📋 Test 2: Backend Override Validation")
try
    ADNLPModeler(gradient_backend="invalid")
    println("❌ Backend validation failed - should have thrown error")
catch e
    println("✅ Backend validation works!")
    println("   Error type: ", typeof(e))
end

# Test 3: Combined with ExaModeler
println("\n📋 Test 3: Combined Advanced + ExaModeler")
try
    adnlp = ADNLPModeler(
        matrix_free=true,
        name="CombinedTest",
        gradient_backend=nothing,
        hessian_backend=nothing
    )
    
    exa = ExaModeler(
        auto_detect_gpu=true,
        gpu_preference=:cuda,
        precision_mode=:high
    )
    
    println("✅ Combined advanced modelers work!")
    println("   ADNLPModeler options: ", length(CTModels.Strategies.options(adnlp).options))
    println("   ExaModeler options: ", length(CTModels.Strategies.options(exa).options))
    
catch e
    println("❌ Combined modelers failed: ", e)
end

println("\n🎉 Advanced Options Testing Complete!")
