# Test Modelers Module
#
# Tests for the new Modelers module using AbstractStrategy contract.
#
# Author: CTModels Development Team
# Date: 2026-01-25

using Test
using CTBase
using CTModels
using ADNLPModels
using ExaModels
using SolverCore

# Test problems
include(joinpath("..", "problems", "solution_example.jl"))

# Import types for testing
# AbstractOptimizationProblem is available as CTModels.AbstractOptimalControlProblem

"""
    test_modelers_basic()

Test basic functionality of the Modelers module.
"""
function test_modelers_basic()
    @testset "Modelers Basic Tests" begin
        # Test module loading
        @test isdefined(CTModels, :AbstractModeler)
        @test isdefined(CTModels, :ADNLPModelerStrategy)
        @test isdefined(CTModels, :ExaModelerStrategy)
        
        # Test strategy identification
        @test CTModels.Strategies.id(CTModels.ADNLPModelerStrategy) == :adnlp
        @test CTModels.Strategies.id(CTModels.ExaModelerStrategy) == :exa
        
        # Test strategy metadata
        adnlp_meta = CTModels.Strategies.metadata(CTModels.ADNLPModelerStrategy)
        @test adnlp_meta isa CTModels.Strategies.StrategyMetadata
        @test haskey(adnlp_meta.specs, :show_time)
        @test haskey(adnlp_meta.specs, :backend)
        
        exa_meta = CTModels.Strategies.metadata(CTModels.ExaModelerStrategy)
        @test exa_meta isa CTModels.Strategies.StrategyMetadata
        @test haskey(exa_meta.specs, :base_type)
        @test haskey(exa_meta.specs, :minimize)
        @test haskey(exa_meta.specs, :backend)
    end
end

"""
    test_adnlp_modeler_strategy()

Test ADNLPModelerStrategy implementation.
"""
function test_adnlp_modeler_strategy()
    @testset "ADNLPModelerStrategy Tests" begin
        # Test constructor
        modeler = CTModels.ADNLPModelerStrategy()
        @test isa(modeler, CTModels.AbstractModeler)
        @test isa(modeler, CTModels.Strategies.AbstractStrategy)
        
        # Test constructor with options
        modeler_opts = CTModels.ADNLPModelerStrategy(show_time=true, backend=:forwarddiff)
        opts = CTModels.Strategies.options(modeler_opts)
        @test opts[:show_time] == true
        @test opts[:backend] == :forwarddiff
        
        # Test option defaults
        modeler_default = CTModels.ADNLPModelerStrategy()
        opts_default = CTModels.Strategies.options(modeler_default)
        @test opts_default[:show_time] == false
        @test opts_default[:backend] == :optimized
    end
end

"""
    test_exa_modeler_strategy()

Test ExaModelerStrategy implementation.
"""
function test_exa_modeler_strategy()
    @testset "ExaModelerStrategy Tests" begin
        # Test constructor
        modeler = CTModels.ExaModelerStrategy()
        @test isa(modeler, CTModels.AbstractModeler)
        @test isa(modeler, CTModels.Strategies.AbstractStrategy)
        
        # Test constructor with options
        modeler_opts = CTModels.ExaModelerStrategy(minimize=true, backend=nothing)
        opts = CTModels.Strategies.options(modeler_opts)
        @test opts[:minimize] == true
        @test opts[:backend] === nothing
        
        # Test type parameter
        modeler_f32 = CTModels.ExaModelerStrategy{Float32}()
        @test typeof(modeler_f32) == CTModels.ExaModelerStrategy{Float32}
        
        # Test base_type option handling
        modeler_type = CTModels.ExaModelerStrategy(base_type=Float32)
        @test typeof(modeler_type) == CTModels.ExaModelerStrategy{Float32}
    end
end

"""
    test_modelers_integration()

Test integration with Options/Strategies/Orchestration modules.
"""
function test_modelers_integration()
    @testset "Modelers Integration Tests" begin
        # Test strategy registry compatibility
        @test CTModels.ADNLPModelerStrategy <: CTModels.Strategies.AbstractStrategy
        @test CTModels.ExaModelerStrategy <: CTModels.Strategies.AbstractStrategy
        
        # Test option extraction
        modeler = CTModels.ADNLPModelerStrategy(show_time=true)
        opts = CTModels.Strategies.options(modeler)
        @test haskey(opts, :show_time)
        @test haskey(opts, :backend)
        
        # Test utility functions
        @test isdefined(CTModels.Modelers, :validate_initial_guess)
        @test isdefined(CTModels.Modelers, :extract_modeler_options)
    end
end

function test_modelers()
    @testset "Modelers Module Tests" begin
        test_modelers_basic()
        test_adnlp_modeler_strategy()
        test_exa_modeler_strategy()
        test_modelers_integration()
    end
end
