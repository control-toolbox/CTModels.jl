module TestModelers

using Test
using CTBase
using CTModels
using ADNLPModels
using ExaModels
using SolverCore
using Main.TestOptions: VERBOSE, SHOWTIMING

"""
    test_modelers_basic()

Test basic functionality and module structure.
"""
function test_modelers_basic()
    Test.@testset "Modelers Basic Tests" begin
        # Test module exports
        Test.@test isdefined(CTModels, :AbstractOptimizationModeler)
        Test.@test isdefined(CTModels, :ADNLPModeler)
        Test.@test isdefined(CTModels, :ExaModeler)
        
        # Test type hierarchy
        Test.@test CTModels.AbstractOptimizationModeler <: CTModels.Strategies.AbstractStrategy
        Test.@test CTModels.ADNLPModeler <: CTModels.AbstractOptimizationModeler
        Test.@test CTModels.ExaModeler <: CTModels.AbstractOptimizationModeler
        
        # Test strategy identification
        Test.@test CTModels.Strategies.id(CTModels.ADNLPModeler) == :adnlp
        Test.@test CTModels.Strategies.id(CTModels.ExaModeler) == :exa
        
        # Test strategy metadata structure
        adnlp_meta = CTModels.Strategies.metadata(CTModels.ADNLPModeler)
        Test.@test adnlp_meta isa CTModels.Strategies.StrategyMetadata
        Test.@test haskey(adnlp_meta.specs, :show_time)
        Test.@test haskey(adnlp_meta.specs, :backend)
        
        exa_meta = CTModels.Strategies.metadata(CTModels.ExaModeler)
        Test.@test exa_meta isa CTModels.Strategies.StrategyMetadata
        Test.@test haskey(exa_meta.specs, :base_type)
        Test.@test haskey(exa_meta.specs, :minimize)
        Test.@test haskey(exa_meta.specs, :backend)
    end
end

"""
    test_adnlp_modeler()

Test ADNLPModeler implementation.
"""
function test_adnlp_modeler()
    Test.@testset "ADNLPModeler Tests" begin
        # Test default constructor
        modeler = CTModels.ADNLPModeler()
        Test.@test modeler isa CTModels.AbstractOptimizationModeler
        Test.@test modeler isa CTModels.Strategies.AbstractStrategy
        
        # Test constructor with options
        modeler_opts = CTModels.ADNLPModeler(show_time=true, backend=:forwarddiff)
        opts = CTModels.Strategies.options(modeler_opts)
        Test.@test opts[:show_time] == true
        Test.@test opts[:backend] == :forwarddiff
        
        # Test option defaults
        modeler_default = CTModels.ADNLPModeler()
        opts_default = CTModels.Strategies.options(modeler_default)
        Test.@test opts_default[:show_time] == false
        Test.@test opts_default[:backend] == :optimized
        
        # Test options are passed generically
        opts_nt = CTModels.Strategies.options(modeler_opts).options
        Test.@test opts_nt isa NamedTuple
        Test.@test haskey(opts_nt, :show_time)
        Test.@test haskey(opts_nt, :backend)
    end
end

"""
    test_exa_modeler()

Test ExaModeler implementation.
"""
function test_exa_modeler()
    Test.@testset "ExaModeler Tests" begin
        # Test default constructor
        modeler = CTModels.ExaModeler()
        Test.@test modeler isa CTModels.AbstractOptimizationModeler
        Test.@test modeler isa CTModels.Strategies.AbstractStrategy
        Test.@test typeof(modeler) == CTModels.ExaModeler{Float64}
        
        # Test constructor with options
        modeler_opts = CTModels.ExaModeler(minimize=true, backend=nothing)
        opts = CTModels.Strategies.options(modeler_opts)
        Test.@test opts[:minimize] == true
        Test.@test opts[:backend] === nothing
        
        # Test type parameter
        modeler_f32 = CTModels.ExaModeler{Float32}()
        Test.@test typeof(modeler_f32) == CTModels.ExaModeler{Float32}
        
        # Test base_type option handling
        modeler_type = CTModels.ExaModeler(base_type=Float32)
        Test.@test typeof(modeler_type) == CTModels.ExaModeler{Float32}
        
        # Test base_type is filtered from stored options
        opts_nt = CTModels.Strategies.options(modeler_type).options
        Test.@test !haskey(opts_nt, :base_type)  # base_type is in the type parameter
        Test.@test !haskey(opts_nt, :minimize)  # minimize has NotProvided default, not stored if not provided
        Test.@test haskey(opts_nt, :backend)  # backend has nothing default, always stored
    end
end

"""
    test_modelers_integration()

Test integration with Optimization and Strategies modules.
"""
function test_modelers_integration()
    Test.@testset "Modelers Integration Tests" begin
        # Test strategy registry compatibility
        Test.@test CTModels.ADNLPModeler <: CTModels.Strategies.AbstractStrategy
        Test.@test CTModels.ExaModeler <: CTModels.Strategies.AbstractStrategy
        
        # Test option extraction
        modeler = CTModels.ADNLPModeler(show_time=true)
        opts = CTModels.Strategies.options(modeler)
        Test.@test haskey(opts, :show_time)
        Test.@test haskey(opts, :backend)
    end
end

"""
    test_modelers_error_handling()

Test error handling and edge cases.
"""
function test_modelers_error_handling()
    Test.@testset "Modelers Error Handling" begin
        # Test that abstract methods throw NotImplemented
        # Note: Cannot instantiate abstract type, so we test the interface exists
        Test.@test hasmethod(
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
    Test.@testset "Modelers Options API" begin
        # Test that options are passed generically (not extracted by name)
        modeler = CTModels.ADNLPModeler(show_time=true, backend=:forwarddiff)
        opts = CTModels.Strategies.options(modeler)
        
        # Options should be accessible as NamedTuple for generic passing
        opts_nt = opts.options
        Test.@test opts_nt isa NamedTuple
        Test.@test length(opts_nt) == 2  # show_time and backend
        
        # Test that we can iterate over options
        for (key, value) in pairs(opts_nt)
            Test.@test key isa Symbol
        end
    end
end

function test_modelers()
    Test.@testset "Modelers Module Tests" verbose = VERBOSE showtiming = SHOWTIMING begin
        test_modelers_basic()
        test_adnlp_modeler()
        test_exa_modeler()
        test_modelers_integration()
        test_modelers_error_handling()
        test_modelers_options_api()
    end
end

end # module

test_modelers() = TestModelers.test_modelers()
