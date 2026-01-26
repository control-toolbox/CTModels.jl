module TestExtExceptions

using Test
using CTModels
using CTBase
using Main.TestProblems
using Main.TestOptions: VERBOSE, SHOWTIMING

# Dummy tags for testing stubs - these won't be overridden by extensions
# because extensions only override for JLD2Tag and JSON3Tag specifically
struct DummyJLD2Tag <: CTModels.AbstractTag end
struct DummyJSON3Tag <: CTModels.AbstractTag end

# Dummy solution type for testing plot stub
struct DummyAbstractSolution <: CTModels.AbstractSolution end

function test_ext_exceptions()
    ocp, sol, pre_ocp = solution_example()

    # ============================================================================
    # Test IncorrectArgument for unknown format
    # ============================================================================
    Test.@testset "IncorrectArgument for unknown format" verbose = VERBOSE showtiming = SHOWTIMING begin
        Test.@test_throws CTBase.IncorrectArgument CTModels.export_ocp_solution(
            sol; format=:dummy
        )
        Test.@test_throws CTBase.IncorrectArgument CTModels.import_ocp_solution(
            ocp; format=:dummy
        )
    end

    # ============================================================================
    # Test stub dispatch for export/import (using dummy tags)
    # The stubs for JLD2Tag and JSON3Tag are in CTModels.jl but become no-ops
    # once extensions are loaded. To test the stub mechanism, we define dummy
    # tag types that will call the stub fallback.
    # ============================================================================
    Test.@testset "Stub dispatch for export_ocp_solution" verbose = VERBOSE showtiming = SHOWTIMING begin
        # Test that calling with our dummy tag triggers ExtensionError
        # Note: The actual stubs are defined for JLD2Tag/JSON3Tag, 
        # but method dispatch should fail for unknown tag types
        Test.@test_throws MethodError CTModels.export_ocp_solution(
            DummyJLD2Tag(), sol; filename="test"
        )
        Test.@test_throws MethodError CTModels.export_ocp_solution(
            DummyJSON3Tag(), sol; filename="test"
        )
    end

    Test.@testset "Stub dispatch for import_ocp_solution" verbose = VERBOSE showtiming = SHOWTIMING begin
        Test.@test_throws MethodError CTModels.import_ocp_solution(
            DummyJLD2Tag(), ocp; filename="test"
        )
        Test.@test_throws MethodError CTModels.import_ocp_solution(
            DummyJSON3Tag(), ocp; filename="test"
        )
    end

    # ============================================================================
    # Test plot stub with a dummy solution type
    # RecipesBase.plot is extended by CTModelsPlots for AbstractSolution
    # If Plots is not loaded, the stub throws ExtensionError
    # If Plots is loaded, it works. We test the method signature errors.
    # ============================================================================
    Test.@testset "Plot method signature errors" verbose = VERBOSE showtiming = SHOWTIMING begin
        # Test that calling plot with wrong argument types throws MethodError
        Test.@test_throws MethodError CTModels.plot(sol, 1)  # Wrong type for description
    end

    # ============================================================================
    # Test method signature errors
    # ============================================================================
    Test.@testset "Method signature errors" verbose = VERBOSE showtiming = SHOWTIMING begin
        Test.@test_throws MethodError CTModels.export_ocp_solution()
        Test.@test_throws MethodError CTModels.import_ocp_solution()
    end
end

end # module

test_ext_exceptions() = TestExtExceptions.test_ext_exceptions()
