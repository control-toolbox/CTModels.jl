function test_nlp_types()
    # ----------------------------------------------------------------------
    # Type hierarchy for builders and optimization problems
    # (moved from test/nlp/test_problem_core.jl)
    # ----------------------------------------------------------------------
    Test.@testset "type hierarchy" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test isabstracttype(CTModels.AbstractBuilder)
        Test.@test isabstracttype(CTModels.AbstractModelBuilder)
        Test.@test isabstracttype(CTModels.AbstractSolutionBuilder)
        Test.@test isabstracttype(CTModels.AbstractOptimizationProblem)

        Test.@test CTModels.ADNLPModelBuilder <: CTModels.AbstractModelBuilder
        Test.@test CTModels.ExaModelBuilder <: CTModels.AbstractModelBuilder
    end

    # ----------------------------------------------------------------------
    # Type hierarchy for OCP solution builders
    # (moved from test/nlp/test_discretized_ocp.jl)
    # ----------------------------------------------------------------------
    Test.@testset "type hierarchy" verbose=VERBOSE showtiming=SHOWTIMING begin
        # AbstractOCPSolutionBuilder should be abstract and inherit from AbstractSolutionBuilder
        Test.@test isabstracttype(CTModels.AbstractOCPSolutionBuilder)
        Test.@test CTModels.AbstractOCPSolutionBuilder <: CTModels.AbstractSolutionBuilder

        # Concrete solution builders should inherit from AbstractOCPSolutionBuilder
        Test.@test CTModels.ADNLPSolutionBuilder <: CTModels.AbstractOCPSolutionBuilder
        Test.@test CTModels.ExaSolutionBuilder <: CTModels.AbstractOCPSolutionBuilder
    end
end
