# Test des différents patterns de modules et exports
# Chaque section est indépendante avec ses propres modules

# ============================================================================ #
# CAS 1: using ModuleA (accès aux exports seulement)
# ============================================================================ #

module Case1_ModuleA
    function case1_public_func()
        return "public from ModuleA"
    end
    
    function case1_private_func()
        return "private from ModuleA"
    end
    
    export case1_public_func
end

module Case1_MainModule
    using ..Case1_ModuleA
    export case1_public_func
end

println("=== CAS 1: using ModuleA (exports seulement) ===")
using .Case1_MainModule
println("case1_public_func(): ", case1_public_func())
try
    case1_private_func()
catch e
    println("case1_private_func(): ERREUR - ", typeof(e))
end
try
    Case1_MainModule.case1_private_func()
catch e
    println("Case1_MainModule.case1_private_func(): ERREUR - ", typeof(e))
end
try
    Case1_MainModule.Case1_ModuleA.case1_private_func()
catch e
    println("Case1_MainModule.Case1_ModuleA.case1_private_func(): ERREUR - ", typeof(e))
end

# ============================================================================ #
# CAS 2: import ModuleA: private_func (accès fonction privée)
# ============================================================================ #

module Case2_ModuleA
    function case2_public_func()
        return "public from ModuleA"
    end
    
    function case2_private_func()
        return "private from ModuleA"
    end
    
    export case2_public_func
end

module Case2_MainModule
    import ..Case2_ModuleA: case2_private_func
    export case2_private_func
end

println("\n=== CAS 2: import ModuleA: private_func ===")
using .Case2_MainModule
println("case2_private_func(): ", case2_private_func())
try
    case2_public_func()
catch e
    println("case2_public_func(): ERREUR - ", typeof(e))
end

# ============================================================================ #
# CAS 3: using ModuleA: func (accès qualifié interne)
# ============================================================================ #

module Case3_ModuleA
    function case3_public_func()
        return "public from ModuleA"
    end
    
    function case3_private_func()
        return "private from ModuleA"
    end
    
    export case3_public_func
end

module Case3_MainModule
    using ..Case3_ModuleA: case3_public_func
    
    function test_internal()
        println("case3_public_func(): ", case3_public_func())
        try
            case3_private_func()
        catch e
            println("case3_private_func(): ERREUR - ", typeof(e))
        end
    end
end

println("\n=== CAS 3: using ModuleA: func (accès qualifié) ===")
using .Case3_MainModule
Case3_MainModule.test_internal()
try
    Case3_MainModule.case3_private_func()
catch e
    println("Case3_MainModule.case3_private_func(): ERREUR - ", typeof(e))
end
try
    Case3_MainModule.Case3_ModuleA.case3_private_func()
catch e
    println("Case3_MainModule.Case3_ModuleA.case3_private_func(): ERREUR - ", typeof(e))
end

# ============================================================================ #
# CAS 4: using MainModule puis accès direct aux fonctions privées
# ============================================================================ #

module Case4_ModuleA
    function case4_public_func()
        return "public from ModuleA"
    end
    
    function case4_private_func()
        return "private from ModuleA"
    end
    
    export case4_public_func
end

module Case4_MainModule
    import ..Case4_ModuleA: case4_private_func
    export case4_public_func
end

println("\n=== CAS 4: using MainModule puis accès direct ===")
using .Case4_MainModule
println("Test: Case4_MainModule.case4_private_func()")
try
    Case4_MainModule.case4_private_func()
    println("✓ SUCCÈS: Fonction privée accessible!")
catch e
    println("✗ ERREUR: ", typeof(e))
end

# ============================================================================ #
# CAS 5: Accès qualifié direct aux fonctions privées
# ============================================================================ #

module Case5_ModuleA
    function case5_public_func()
        return "public from ModuleA"
    end
    
    function case5_private_func()
        return "private from ModuleA"
    end
    
    export case5_public_func
end

module Case5_MainModule
    using ..Case5_ModuleA
end

println("\n=== CAS 5: Accès qualifié direct ===")
using .Case5_MainModule
println("Test: Case5_MainModule.Case5_ModuleA.case5_private_func()")
try
    Case5_MainModule.Case5_ModuleA.case5_private_func()
    println("✓ SUCCÈS: Accès qualifié direct!")
catch e
    println("✗ ERREUR: ", typeof(e))
end

# ============================================================================ #
# CAS 6: Module avec réexportation
# ============================================================================ #

module Case6_ModuleA
    function case6_public_func()
        return "public from Case6_ModuleA"
    end
    
    function case6_private_func()
        return "private from Case6_ModuleA"
    end
    
    export case6_public_func
end

module Case6_ModuleB
    using ..Case6_ModuleA
    export case6_public_func  # Réexporter
    
    function case6_local_func()
        return "local from Case6_ModuleB"
    end
    
    export case6_local_func
end

module Case6_MainModule
    using ..Case6_ModuleB
    export case6_public_func, case6_local_func
end

println("\n=== CAS 6: Réexportation ===")
using .Case6_MainModule
println("case6_public_func(): ", case6_public_func())
println("case6_local_func(): ", case6_local_func())

# ============================================================================ #
# CAS 7: Import sélectif depuis l'extérieur
# ============================================================================ #

module Case7_ModuleA
    function case7_public_func()
        return "public from Case7_ModuleA"
    end
    
    function case7_private_func()
        return "private from Case7_ModuleA"
    end
    
    export case7_public_func
end

module Case7_MainModule
    import ..Case7_ModuleA: case7_private_func
end

println("\n=== CAS 7: Import sélectif depuis l'extérieur ===")
println("Test: import .Case7_MainModule: case7_private_func")
try
    import .Case7_MainModule: case7_private_func
    println("✓ SUCCÈS: Import réussi!")
    println("case7_private_func(): ", case7_private_func())
catch e
    println("✗ ERREUR: ", typeof(e))
end

println("\nTest: import .Case7_MainModule.Case7_ModuleA: case7_private_func")
try
    import .Case7_MainModule.Case7_ModuleA: case7_private_func
    println("✓ SUCCÈS: Import direct réussi!")
    println("case7_private_func(): ", case7_private_func())
catch e
    println("✗ ERREUR: ", typeof(e))
end

# ============================================================================ #
# RÉSUMÉ DES RÈGLES
# ============================================================================ #

println("\n" * "="^60)
println("RÉSUMÉ DES RÈGLES JULIA")
println("="^60)
println("🟢 using Module           → Accès aux exports seulement")
println("🟡 import Module: func     → Accès à n'importe quelle fonction")
println("🔴 Module.func             → Accès à n'importe quelle fonction")
println("📦 export func             → Rend func disponible avec using")
println("🔄 import + export         → Réexporte une fonction importée")
println("")
println("CAS 1: using ModuleA → exports seulement (case1_public_func)")
println("CAS 2: import ModuleA: case2_private_func → accès fonction privée")
println("CAS 3: using ModuleA: case3_public_func → accès qualifié interne")
println("CAS 4: using MainModule → accès direct si import dans MainModule")
println("CAS 5: Accès qualifié direct → toujours possible")
println("CAS 6: Réexportation → propage les exports")
println("CAS 7: Import sélectif extérieur → possible pour n'importe quelle fonction")
