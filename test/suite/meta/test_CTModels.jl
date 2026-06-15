module TestCTModelsTop

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels: CTModels
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Solutions: Solutions
import CTModels.Serialization: Serialization

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

struct CTMDummySol <: Solutions.AbstractSolution end
struct CTMDummyModelTop <: Models.AbstractModel end

function test_CTModels()
    Test.@testset "CTModels.jl Top-Level Module Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Basic Aliases and Tags
        # ====================================================================

        Test.@testset "type aliases and tags" begin
            Test.@test Components.Dimension == Int
            Test.@test Components.ctNumber == Real
            Test.@test Components.Time === Components.ctNumber

            # For parametric aliases, test mutual <: rather than strict identity
            Test.@test Components.ctVector <: AbstractVector{<:Components.ctNumber}
            Test.@test AbstractVector{<:Components.ctNumber} <: Components.ctVector

            Test.@test Components.Times <: AbstractVector{<:Components.Time}
            Test.@test AbstractVector{<:Components.Time} <: Components.Times

            Test.@test Serialization.JLD2Tag <: Serialization.AbstractTag
            Test.@test Serialization.JSON3Tag <: Serialization.AbstractTag

            # Aliases towards CTSolvers usage
            Test.@test Models.AbstractModel === Models.AbstractModel
            Test.@test Solutions.AbstractSolution === Solutions.AbstractSolution
        end

        # ====================================================================
        # UNIT TESTS - CTModels top-level exports nothing (tenet #1)
        # ====================================================================

        Test.@testset "CTModels exports nothing" begin
            # Base.names returns only the module itself — no user symbols exported
            exported = Base.names(CTModels; imported=false, all=false)
            Test.@test exported == [:CTModels]
        end

        # ====================================================================
        # UNIT TESTS - Components exports its announced list
        # ====================================================================

        Test.@testset "Components exports announced symbols" begin
            exported = Set(Base.names(Components))

            # Type aliases
            for sym in [
                :Dimension,
                :ctNumber,
                :Time,
                :ctVector,
                :Times,
                :TimesDisc,
                :ConstraintsDictType,
            ]
                Test.@test sym in exported
            end

            # Time dependence
            for sym in [:TimeDependence, :Autonomous, :NonAutonomous]
                Test.@test sym in exported
            end

            # State
            for sym in [:AbstractStateModel, :StateModel, :StateModelSolution]
                Test.@test sym in exported
            end

            # Control
            for sym in [
                :AbstractControlModel,
                :ControlModel,
                :ControlModelSolution,
                :EmptyControlModel,
            ]
                Test.@test sym in exported
            end

            # Variable
            for sym in [
                :AbstractVariableModel,
                :VariableModel,
                :VariableModelSolution,
                :EmptyVariableModel,
            ]
                Test.@test sym in exported
            end

            # Time models
            for sym in [
                :AbstractTimeModel,
                :FixedTimeModel,
                :FreeTimeModel,
                :AbstractTimesModel,
                :TimesModel,
            ]
                Test.@test sym in exported
            end

            # Objective
            for sym in [
                :AbstractObjectiveModel,
                :MayerObjectiveModel,
                :LagrangeObjectiveModel,
                :BolzaObjectiveModel,
            ]
                Test.@test sym in exported
            end

            # Constraints
            for sym in [:AbstractConstraintsModel, :ConstraintsModel]
                Test.@test sym in exported
            end

            # Definition
            for sym in [:AbstractDefinition, :EmptyDefinition, :Definition]
                Test.@test sym in exported
            end

            # Accessor functions
            for sym in [:name, :components, :dimension, :value, :interpolation, :expression]
                Test.@test sym in exported
            end

            # Time model accessors
            for sym in [
                :index,
                :initial,
                :final,
                :time_name,
                :initial_time_name,
                :final_time_name,
                :initial_time,
                :final_time,
                :has_fixed_initial_time,
                :has_free_initial_time,
                :has_fixed_final_time,
                :has_free_final_time,
                :is_initial_time_fixed,
                :is_initial_time_free,
                :is_final_time_fixed,
                :is_final_time_free,
            ]
                Test.@test sym in exported
            end

            # Objective accessors
            for sym in [
                :criterion,
                :mayer,
                :lagrange,
                :has_mayer_cost,
                :has_lagrange_cost,
                :is_mayer_cost_defined,
                :is_lagrange_cost_defined,
            ]
                Test.@test sym in exported
            end

            # Constraints accessors
            for sym in [
                :path_constraints_nl,
                :boundary_constraints_nl,
                :state_constraints_box,
                :control_constraints_box,
                :variable_constraints_box,
                :dim_path_constraints_nl,
                :dim_boundary_constraints_nl,
                :dim_state_constraints_box,
                :dim_control_constraints_box,
                :dim_variable_constraints_box,
            ]
                Test.@test sym in exported
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Export/Import Format Guards
        # ====================================================================

        Test.@testset "export/import format guards" begin
            sol = CTMDummySol()
            ocp = CTMDummyModelTop()

            # Unknown format should trigger an IncorrectArgument without touching extensions.
            Test.@test_throws Exceptions.IncorrectArgument Serialization.export_ocp_solution(
                sol; format=:FOO
            )
            Test.@test_throws Exceptions.IncorrectArgument Serialization.import_ocp_solution(
                ocp; format=:FOO
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_CTModels() = TestCTModelsTop.test_CTModels()
