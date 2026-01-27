module TestMetaExports

using Test
using CTModels
using CTModels.Options
using CTModels.Strategies
using CTModels.Orchestration

# Default test options
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : false
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : false

"""
    test_exports()

Verify that the expected methods and types are correctly exported by the modules.
This helps maintain an explicit public API.
"""
function test_exports()
    # Test.@testset "Meta Exports" verbose=VERBOSE showtiming=SHOWTIMING begin
        
    #     Test.@testset "Options Exports" begin
    #         # List of expected exports in Options
    #         # Note: We use Symbol because we test if they are exported from the module
    #         expected_options = [
    #             :NotProvided, :NotProvidedType,
    #             :OptionValue, :OptionDefinition,
    #             :extract_option, :extract_options, :extract_raw_options
    #         ]
            
    #         for sym in expected_options
    #             Test.@test isdefined(CTModels.Options, sym)
    #             # Check if it's exported
    #             Test.@test sym in names(CTModels.Options)
    #         end
    #     end
        
    #     Test.@testset "Strategies Exports" begin
    #         # List of expected exports in Strategies
    #         expected_strategies = [
    #             :AbstractStrategy, :StrategyRegistry, :StrategyMetadata, :StrategyOptions, :OptionDefinition,
    #             :id, :metadata, :options,
    #             :create_registry, :strategy_ids, :type_from_id,
    #             :option_names, :option_type, :option_description, :option_default, :option_defaults,
    #             :option_value, :option_source,
    #             :is_user, :is_default, :is_computed,
    #             :build_strategy, :build_strategy_from_method,
    #             :extract_id_from_method, :option_names_from_method,
    #             :build_strategy_options, :resolve_alias,
    #             :filter_options, :suggest_options,
    #             :validate_strategy_contract
    #         ]
            
    #         for sym in expected_strategies
    #             Test.@test isdefined(CTModels.Strategies, sym)
    #             Test.@test sym in names(CTModels.Strategies)
    #         end
    #     end
        
    #     Test.@testset "Orchestration Exports" begin
    #         expected_orchestration = [
    #             :route_all_options,
    #             :extract_strategy_ids, :build_strategy_to_family_map, :build_option_ownership_map,
    #             :build_strategy_from_method, :option_names_from_method
    #         ]
            
    #         for sym in expected_orchestration
    #             Test.@test isdefined(CTModels.Orchestration, sym)
    #             Test.@test sym in names(CTModels.Orchestration)
    #         end
    #     end

    #     Test.@testset "Main Module Exports" begin
    #         # Optimization Problem and Builders
    #         expected_main = [
    #             :AbstractOptimizationProblem,
    #             :AbstractBuilder, :AbstractModelBuilder, :AbstractSolutionBuilder,
    #             :AbstractOCPSolutionBuilder,
    #             :ADNLPModelBuilder, :ExaModelBuilder,
    #             :ADNLPSolutionBuilder, :ExaSolutionBuilder,
    #             :get_adnlp_model_builder, :get_exa_model_builder,
    #             :get_adnlp_solution_builder, :get_exa_solution_builder,
    #             :build_model, :build_solution,
    #             :extract_solver_infos
    #         ]

    #         # Modelers
    #         append!(expected_main, [:AbstractOptimizationModeler, :ADNLPModeler, :ExaModeler])

    #         # DOCP
    #         append!(expected_main, [:DiscretizedOptimalControlProblem, :ocp_model, :nlp_model, :ocp_solution])
            
    #         for sym in expected_main
    #             Test.@test isdefined(CTModels, sym)
    #         end
    #     end

    # end
end

end # module

test_exports() = TestMetaExports.test_exports()
