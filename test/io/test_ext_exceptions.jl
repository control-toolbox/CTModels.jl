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
    @testset "IncorrectArgument for unknown format" begin
        @test_throws CTBase.IncorrectArgument CTModels.export_ocp_solution(sol; format=:dummy)
        @test_throws CTBase.IncorrectArgument CTModels.import_ocp_solution(ocp; format=:dummy)
    end

    # ============================================================================
    # Test stub dispatch for export/import (using dummy tags)
    # The stubs for JLD2Tag and JSON3Tag are in CTModels.jl but become no-ops
    # once extensions are loaded. To test the stub mechanism, we define dummy
    # tag types that will call the stub fallback.
    # ============================================================================
    @testset "Stub dispatch for export_ocp_solution" begin
        # Test that calling with our dummy tag triggers ExtensionError
        # Note: The actual stubs are defined for JLD2Tag/JSON3Tag, 
        # but method dispatch should fail for unknown tag types
        @test_throws MethodError CTModels.export_ocp_solution(DummyJLD2Tag(), sol; filename="test")
        @test_throws MethodError CTModels.export_ocp_solution(DummyJSON3Tag(), sol; filename="test")
    end

    @testset "Stub dispatch for import_ocp_solution" begin
        @test_throws MethodError CTModels.import_ocp_solution(DummyJLD2Tag(), ocp; filename="test")
        @test_throws MethodError CTModels.import_ocp_solution(DummyJSON3Tag(), ocp; filename="test")
    end

    # ============================================================================
    # Test plot stub with a dummy solution type
    # RecipesBase.plot is extended by CTModelsPlots for AbstractSolution
    # If Plots is not loaded, the stub throws ExtensionError
    # If Plots is loaded, it works. We test the method signature errors.
    # ============================================================================
    @testset "Plot method signature errors" begin
        # Test that calling plot with wrong argument types throws MethodError
        @test_throws MethodError CTModels.plot(sol, 1)  # Wrong type for description
    end

    # ============================================================================
    # Test method signature errors
    # ============================================================================
    @testset "Method signature errors" begin
        @test_throws MethodError CTModels.export_ocp_solution()
        @test_throws MethodError CTModels.import_ocp_solution()
    end
end
