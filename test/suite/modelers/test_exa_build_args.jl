# Test for ExaModeler build arguments verification
#
# This file tests that base_type is correctly extracted and NOT passed
# as a named argument to the ExaModel builder.

module TestExaBuildArgs

using Test
using CTModels
using CTModels.Modelers: ExaModeler
using CTModels.Strategies: options

# Create a mock problem that captures builder arguments
struct MockOptimizationProblem <: CTModels.AbstractOptimizationProblem
    captured_args::Ref{Vector{Any}}
    captured_kwargs::Ref{Vector{Pair{Symbol, Any}}}
end

# Mock builder that captures all arguments for inspection
function mock_exa_model_builder(BaseType, initial_guess; kwargs...)
    # Simply return the arguments for verification
    return (BaseType=BaseType, initial_guess=initial_guess, kwargs=kwargs)
end

# Override the get_exa_model_builder for our test
function CTModels.Modelers.get_exa_model_builder(prob::MockOptimizationProblem)
    return mock_exa_model_builder
end

function test_exa_build_args()
    @testset "ExaModeler Build Arguments Verification" verbose=true begin
        
        @testset "Base Type Not in Named Arguments" begin
            # Test with Float32
            modeler = ExaModeler(base_type=Float32, backend=nothing)
            prob = MockOptimizationProblem(Ref{Vector{Any}}(), Ref{Vector{Pair{Symbol, Any}}}())
            
            # This should call our mock builder
            result = modeler(prob, [1.0, 2.0])
            
            # Verify BaseType was extracted correctly (first positional argument)
            @test result.BaseType == Float32
            
            # Verify base_type is NOT in named arguments
            @test !haskey(result.kwargs, :base_type)
            
            # Verify other options ARE in named arguments
            @test haskey(result.kwargs, :backend)
            @test result.kwargs[:backend] === nothing
        end
        
        @testset "Base Type Not in Named Arguments with Float64" begin
            # Test with Float64 and multiple options
            modeler = ExaModeler(base_type=Float64, backend=nothing)
            prob = MockOptimizationProblem(Ref{Vector{Any}}(), Ref{Vector{Pair{Symbol, Any}}}())
            
            result = modeler(prob, [1.0, 2.0])
            
            # Verify BaseType was extracted correctly
            @test result.BaseType == Float64
            
            # Verify base_type is NOT in named arguments
            @test !haskey(result.kwargs, :base_type)
            
            # Verify backend IS in named arguments
            @test haskey(result.kwargs, :backend)
            @test result.kwargs[:backend] === nothing
        end
        
        @testset "Default Base Type Behavior" begin
            # Test with default base_type (Float64)
            modeler = ExaModeler()  # No explicit base_type
            prob = MockOptimizationProblem(Ref{Vector{Any}}(), Ref{Vector{Pair{Symbol, Any}}}())
            
            result = modeler(prob, [1.0, 2.0])
            
            # Verify default BaseType was extracted
            @test result.BaseType == Float64
            
            # Verify base_type is NOT in named arguments
            @test !haskey(result.kwargs, :base_type)
        end
        
        @testset "Multiple Options Without Base Type" begin
            # Test with multiple options but no base_type specified
            modeler = ExaModeler(backend=nothing)
            prob = MockOptimizationProblem(Ref{Vector{Any}}(), Ref{Vector{Pair{Symbol, Any}}}())
            
            result = modeler(prob, [1.0, 2.0])
            
            # Verify default BaseType was used
            @test result.BaseType == Float64
            
            # Verify base_type is NOT in named arguments
            @test !haskey(result.kwargs, :base_type)
            
            # Verify other options ARE present
            @test haskey(result.kwargs, :backend)
            @test result.kwargs[:backend] === nothing
        end
    end
end

end # module
