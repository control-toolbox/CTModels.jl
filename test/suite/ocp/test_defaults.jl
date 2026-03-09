module TestOCPDefaults

using Test: Test
using CTBase: CTBase
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_defaults()
    Test.@testset "Defaults Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for defaults functionality
        end

        # ====================================================================
        # UNIT TESTS - Default Values
        # ====================================================================
        Test.@testset "constraints and format defaults" begin
            Test.@test CTModels.OCP.__constraints() === nothing
            Test.@test CTModels.OCP.__format() == :JLD

            label1 = CTModels.OCP.__constraint_label()
            label2 = CTModels.OCP.__constraint_label()
            Test.@test label1 isa Symbol
            Test.@test label2 isa Symbol
            Test.@test label1 != label2
            Test.@test startswith(String(label1), "##unnamed")
            Test.@test startswith(String(label2), "##unnamed")
        end

        Test.@testset "state and control naming defaults" begin
            Test.@test CTModels.OCP.__state_name() == "x"
            Test.@test CTModels.OCP.__control_name() == "u"

            comps_state_1 = CTModels.OCP.__state_components(1, "x")
            comps_state_3 = CTModels.OCP.__state_components(3, "x")
            Test.@test comps_state_1 == ["x"]
            Test.@test comps_state_3 == ["x" * CTBase.ctindices(i) for i in 1:3]

            comps_control_1 = CTModels.OCP.__control_components(1, "u")
            comps_control_3 = CTModels.OCP.__control_components(3, "u")
            Test.@test comps_control_1 == ["u"]
            Test.@test comps_control_3 == ["u" * CTBase.ctindices(i) for i in 1:3]
        end

        Test.@testset "time and criterion defaults" begin
            Test.@test CTModels.OCP.__time_name() == "t"
            Test.@test CTModels.OCP.__criterion_type() == :min
        end

        Test.@testset "variable naming defaults" begin
            Test.@test CTModels.OCP.__variable_name(0) == ""
            Test.@test CTModels.OCP.__variable_name(1) == "v"
            Test.@test CTModels.OCP.__variable_name(3) == "v"

            comps_var_0 = CTModels.OCP.__variable_components(0, "v")
            comps_var_1 = CTModels.OCP.__variable_components(1, "v")
            comps_var_3 = CTModels.OCP.__variable_components(3, "v")

            Test.@test comps_var_0 == String[]
            Test.@test comps_var_1 == ["v"]
            Test.@test comps_var_3 == ["v" * CTBase.ctindices(i) for i in 1:3]
        end

        Test.@testset "matrix and filename defaults" begin
            Test.@test CTModels.Utils.__matrix_dimension_storage() == 1
            Test.@test CTModels.OCP.__filename_export_import() == "solution"
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_defaults() = TestOCPDefaults.test_defaults()
