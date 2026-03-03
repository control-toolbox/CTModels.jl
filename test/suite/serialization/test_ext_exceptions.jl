module TestExtExceptions

using Test
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels
using Main.TestProblems
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Dummy tags for testing stubs - these won't be overridden by extensions
# because extensions only override for JLD2Tag and JSON3Tag specifically
struct DummyJLD2Tag <: CTModels.AbstractTag end
struct DummyJSON3Tag <: CTModels.AbstractTag end

# Dummy solution and model types for testing serialization stubs
struct DummyAbstractSolution <: CTModels.AbstractSolution end
struct DummyAbstractModel <: CTModels.AbstractModel end

function test_ext_exceptions()
    Test.@testset "Extension Exceptions" verbose = VERBOSE showtiming = SHOWTIMING begin
        ocp, sol, pre_ocp = solution_example()

        # ============================================================================
        # Test IncorrectArgument for unknown format
        # ============================================================================
        Test.@testset "IncorrectArgument for unknown format" begin
            Test.@test_throws Exceptions.IncorrectArgument CTModels.export_ocp_solution(
                sol; format=:dummy
            )
            Test.@test_throws Exceptions.IncorrectArgument CTModels.import_ocp_solution(
                ocp; format=:dummy
            )
        end

        # ============================================================================
        # Test ExtensionError for real tags (JLD2Tag and JSON3Tag) with dummy types
        # These stubs throw ExtensionError when extensions are not loaded
        # We use dummy types to ensure we're testing the stubs, not extension overrides
        # ============================================================================
        Test.@testset "ExtensionError for JLD2Tag export/import" begin
            dummy_sol = DummyAbstractSolution()
            dummy_ocp = DummyAbstractModel()

            Test.@test_throws Exceptions.ExtensionError CTModels.export_ocp_solution(
                CTModels.JLD2Tag(), dummy_sol; filename="test"
            )
            Test.@test_throws Exceptions.ExtensionError CTModels.import_ocp_solution(
                CTModels.JLD2Tag(), dummy_ocp; filename="test"
            )
        end

        Test.@testset "ExtensionError for JSON3Tag export/import" begin
            dummy_sol = DummyAbstractSolution()
            dummy_ocp = DummyAbstractModel()

            Test.@test_throws Exceptions.ExtensionError CTModels.export_ocp_solution(
                CTModels.JSON3Tag(), dummy_sol; filename="test"
            )
            Test.@test_throws Exceptions.ExtensionError CTModels.import_ocp_solution(
                CTModels.JSON3Tag(), dummy_ocp; filename="test"
            )
        end

        # ============================================================================
        # Test stub dispatch for export/import (using dummy tags)
        # The stubs for JLD2Tag and JSON3Tag are in CTModels.jl but become no-ops
        # once extensions are loaded. To test the stub mechanism, we define dummy
        # tag types that will call the stub fallback.
        # ============================================================================
        Test.@testset "Stub dispatch for export_ocp_solution" begin
            # Test that calling with our dummy tag triggers MethodError
            # Note: The actual stubs are defined for JLD2Tag/JSON3Tag, 
            # but method dispatch should fail for unknown tag types
            Test.@test_throws MethodError CTModels.export_ocp_solution(
                DummyJLD2Tag(), sol; filename="test"
            )
            Test.@test_throws MethodError CTModels.export_ocp_solution(
                DummyJSON3Tag(), sol; filename="test"
            )
        end

        Test.@testset "Stub dispatch for import_ocp_solution" begin
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
        # If Plots is not loaded, the stub throws IncorrectArgument
        # If Plots is loaded, it tries to convert the type and throws ErrorException
        # ============================================================================
        Test.@testset "Plot method signature errors" begin
            # Test that calling plot with a dummy AbstractSolution subtype uses the stub
            # The stub should throw IncorrectArgument since Plots extension is not loaded
            Test.@test_throws Exceptions.IncorrectArgument CTModels.plot(
                DummyAbstractSolution()
            )
        end

        # ============================================================================
        # Test method signature errors
        # ============================================================================
        Test.@testset "Method signature errors" begin
            Test.@test_throws MethodError CTModels.export_ocp_solution()
            Test.@test_throws MethodError CTModels.import_ocp_solution()
        end
    end
end

end # module

test_ext_exceptions() = TestExtExceptions.test_ext_exceptions()
