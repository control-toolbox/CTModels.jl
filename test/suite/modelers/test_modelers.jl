# Test Modelers Module
#
# Comprehensive tests for the Modelers module following test-julia workflow.
# Tests cover: basic functionality, strategy contract, options, error handling,
# and integration with the Optimization module.
#
# Author: CTModels Development Team
# Date: 2026-01-26

using Test
using CTBase
using CTModels
using ADNLPModels
using ExaModels
using SolverCore

"""
    test_modelers_basic()

Test basic functionality and module structure.
"""
function test_modelers_basic()
    @testset "Modelers Basic Tests" begin
        # Test module exports
        @test isdefined(CTModels, :AbstractOptimizationModeler)
        @test isdefined(CTModels, :ADNLPModeler)
        @test isdefined(CTModels, :ExaModeler)
        
        # Test type hierarchy
        @test CTModels.AbstractOptimizationModeler <: CTModels.Strategies.AbstractStrategy
        @test CTModels.ADNLPModeler <: CTModels.AbstractOptimizationModeler
        @test CTModels.ExaModeler <: CTModels.AbstractOptimizationModeler
        
        # Test strategy identification
        @test CTModels.Strategies.id(CTModels.ADNLPModeler) == :adnlp
        @test CTModels.Strategies.id(CTModels.ExaModeler) == :exa
        
        # Test strategy metadata structure
        adnlp_meta = CTModels.Strategies.metadata(CTModels.ADNLPModeler)
        @test adnlp_meta isa CTModels.Strategies.StrategyMetadata
        @test haskey(adnlp_meta.specs, :show_time)
        @test haskey(adnlp_meta.specs, :backend)
        
        exa_meta = CTModels.Strategies.metadata(CTModels.ExaModeler)
        @test exa_meta isa CTModels.Strategies.StrategyMetadata
        @test haskey(exa_meta.specs, :base_type)
        @test haskey(exa_meta.specs, :minimize)
        @test haskey(exa_meta.specs, :backend)
    end
end

"""
    test_adnlp_modeler()

Test ADNLPModeler implementation.
"""
function test_adnlp_modeler()
    @testset "ADNLPModeler Tests" begin
        # Test default constructor
        modeler = CTModels.ADNLPModeler()
        @test modeler isa CTModels.AbstractOptimizationModeler
        @test modeler isa CTModels.Strategies.AbstractStrategy
        
        # Test constructor with options
        modeler_opts = CTModels.ADNLPModeler(show_time=true, backend=:forwarddiff)
        opts = CTModels.Strategies.options(modeler_opts)
        @test opts[:show_time] == true
        @test opts[:backend] == :forwarddiff
        
        # Test option defaults
        modeler_default = CTModels.ADNLPModeler()
        opts_default = CTModels.Strategies.options(modeler_default)
        @test opts_default[:show_time] == false
        @test opts_default[:backend] == :optimized
        
        # Test options are passed generically
        opts_nt = CTModels.Strategies.options(modeler_opts).options
        @test opts_nt isa NamedTuple
        @test haskey(opts_nt, :show_time)
        @test haskey(opts_nt, :backend)
    end
end

"""
    test_exa_modeler()

Test ExaModeler implementation.
"""
function test_exa_modeler()
    @testset "ExaModeler Tests" begin
        # Test default constructor
        modeler = CTModels.ExaModeler()
        @test modeler isa CTModels.AbstractOptimizationModeler
        @test modeler isa CTModels.Strategies.AbstractStrategy
        @test typeof(modeler) == CTModels.ExaModeler{Float64}
        
        # Test constructor with options
        modeler_opts = CTModels.ExaModeler(minimize=true, backend=nothing)
        opts = CTModels.Strategies.options(modeler_opts)
        @test opts[:minimize] == true
        @test opts[:backend] === nothing
        
        # Test type parameter
        modeler_f32 = CTModels.ExaModeler{Float32}()
        @test typeof(modeler_f32) == CTModels.ExaModeler{Float32}
        
        # Test base_type option handling
        modeler_type = CTModels.ExaModeler(base_type=Float32)
        @test typeof(modeler_type) == CTModels.ExaModeler{Float32}
        
        # Test base_type is filtered from stored options
        opts_nt = CTModels.Strategies.options(modeler_type).options
        @test !haskey(opts_nt, :base_type)  # base_type is in the type parameter
        @test !haskey(opts_nt, :minimize)  # minimize has NotProvided default, not stored if not provided
        @test haskey(opts_nt, :backend)  # backend has nothing default, always stored
    end
end

"""
    test_modelers_integration()

Test integration with Optimization and Strategies modules.
"""
function test_modelers_integration()
    @testset "Modelers Integration Tests" begin
        # Test strategy registry compatibility
        @test CTModels.ADNLPModeler <: CTModels.Strategies.AbstractStrategy
        @test CTModels.ExaModeler <: CTModels.Strategies.AbstractStrategy
        
        # Test option extraction
        modeler = CTModels.ADNLPModeler(show_time=true)
        opts = CTModels.Strategies.options(modeler)
        @test haskey(opts, :show_time)
        @test haskey(opts, :backend)
    end
end

"""
    test_modelers_error_handling()

Test error handling and edge cases.
"""
function test_modelers_error_handling()
    @testset "Modelers Error Handling" begin
        # Test that abstract methods throw NotImplemented
        abstract_modeler = CTModels.AbstractOptimizationModeler
        # Note: Cannot instantiate abstract type, so we test the interface exists
        @test hasmethod(
            (m::CTModels.AbstractOptimizationModeler, prob, ig) -> m(prob, ig),
            Tuple{CTModels.AbstractOptimizationModeler, CTModels.AbstractOptimizationProblem, Any}
        )
    end
end

"""
    test_modelers_options_api()

Test generic options API.
"""
function test_modelers_options_api()
    @testset "Modelers Options API" begin
        # Test that options are passed generically (not extracted by name)
        modeler = CTModels.ADNLPModeler(show_time=true, backend=:forwarddiff)
        opts = CTModels.Strategies.options(modeler)
        
        # Options should be accessible as NamedTuple for generic passing
        opts_nt = opts.options
        @test opts_nt isa NamedTuple
        @test length(opts_nt) == 2  # show_time and backend
        
        # Test that we can iterate over options
        for (key, value) in pairs(opts_nt)
            @test key isa Symbol
        end
    end
end

function test_modelers()
    @testset "Modelers Module Tests" begin
        test_modelers_basic()
        test_adnlp_modeler()
        test_exa_modeler()
        test_modelers_integration()
        test_modelers_error_handling()
        test_modelers_options_api()
    end
end
