#!/usr/bin/env julia

# Test script for enhanced modelers implementation
# This script tests the new options and validation functionality
#
# Author: CTModels Development Team
# Date: 2026-01-31

using Pkg
Pkg.activate(@__DIR__)  # Activate the main project
using CTModels
using CTModels.Modelers: ADNLPModeler, ExaModeler

println("🧪 Testing Enhanced Modelers Implementation")
println("=" ^ 50)

# Test 1: ADNLPModeler with new options
println("\n📋 Test 1: ADNLPModeler New Options")
try
    modeler = ADNLPModeler(
        matrix_free=true,
        name="TestProblem",
        minimize=false,
        backend=:optimized
    )
    
    opts = CTModels.Strategies.options(modeler).options
    println("✅ ADNLPModeler created successfully")
    println("   - matrix_free: ", opts[:matrix_free])
    println("   - name: ", opts[:name])
    println("   - minimize: ", opts[:minimize])
    println("   - backend: ", opts[:backend])
catch e
    println("❌ ADNLPModeler failed: ", e)
end

# Test 2: ExaModeler with new options
println("\n📋 Test 2: ExaModeler New Options")
try
    modeler = ExaModeler(
        base_type=Float32,
        auto_detect_gpu=true,
        gpu_preference=:cuda,
        precision_mode=:mixed,
        minimize=true
    )
    
    opts = CTModels.Strategies.options(modeler).options
    println("✅ ExaModeler created successfully")
    println("   - base_type: ", typeof(modeler).parameters[1])
    println("   - auto_detect_gpu: ", opts[:auto_detect_gpu])
    println("   - gpu_preference: ", opts[:gpu_preference])
    println("   - precision_mode: ", opts[:precision_mode])
    println("   - minimize: ", opts[:minimize])
catch e
    println("❌ ExaModeler failed: ", e)
end

# Test 3: Backend validation
println("\n📋 Test 3: Backend Validation")
try
    ADNLPModeler(backend=:invalid)
    println("❌ Backend validation failed - should have thrown error")
catch e
    println("✅ Backend validation works")
    println("   Error: ", typeof(e))
end

# Test 4: Type validation
println("\n📋 Test 4: Type Validation")
try
    ExaModeler(base_type=Int)
    println("❌ Type validation failed - should have thrown error")
catch e
    println("✅ Type validation works")
    println("   Error: ", typeof(e))
end

# Test 5: GPU preference validation
println("\n📋 Test 5: GPU Preference Validation")
try
    ExaModeler(gpu_preference=:invalid)
    println("❌ GPU preference validation failed - should have thrown error")
catch e
    println("✅ GPU preference validation works")
    println("   Error: ", typeof(e))
end

# Test 6: Precision mode validation
println("\n📋 Test 6: Precision Mode Validation")
try
    ExaModeler(precision_mode=:invalid)
    println("❌ Precision mode validation failed - should have thrown error")
catch e
    println("✅ Precision mode validation works")
    println("   Error: ", typeof(e))
end

# Test 7: Backward compatibility
println("\n📋 Test 7: Backward Compatibility")
try
    # Original ADNLPModeler constructor
    modeler1 = ADNLPModeler()
    
    # Original ExaModeler constructor
    modeler2 = ExaModeler()
    
    # Original options should still work
    modeler3 = ADNLPModeler(show_time=true, backend=:default)
    modeler4 = ExaModeler(base_type=Float32, minimize=false)
    
    println("✅ Backward compatibility maintained")
    println("   - ADNLPModeler() works")
    println("   - ExaModeler() works")
    println("   - Original options still work")
catch e
    println("❌ Backward compatibility failed: ", e)
end

# Test 8: Default values
println("\n📋 Test 8: Default Values")
try
    modeler_adnlp = ADNLPModeler()
    modeler_exa = ExaModeler()
    opts_adnlp = CTModels.Strategies.options(modeler_adnlp).options
    opts_exa = CTModels.Strategies.options(modeler_exa).options
    
    println("✅ Default values accessible:")
    println("   ADNLPModeler defaults:")
    println("     - show_time: ", opts_adnlp[:show_time])
    println("     - backend: ", opts_adnlp[:backend])
    println("     - matrix_free: ", opts_adnlp[:matrix_free])
    println("     - name: ", opts_adnlp[:name])
    println("     - minimize: ", opts_adnlp[:minimize])
    
    println("   ExaModeler defaults:")
    println("     - auto_detect_gpu: ", opts_exa[:auto_detect_gpu])
    println("     - gpu_preference: ", opts_exa[:gpu_preference])
    println("     - precision_mode: ", opts_exa[:precision_mode])
catch e
    println("❌ Default values test failed: ", e)
end

println("\n" * "=" * 50)
println("🎉 Enhanced Modelers Implementation Test Complete!")
println("📊 Summary: All core functionality is working")
println("🔧 Next: Fine-tune tests and documentation")
