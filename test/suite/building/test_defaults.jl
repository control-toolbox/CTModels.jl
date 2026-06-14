module TestOCPDefaults

import Test: Test
import CTBase: CTBase
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_defaults()
    Test.@testset "Defaults Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Default Values
        # ====================================================================
        Test.@testset "constraints and format defaults" begin
            Test.@test Building.__constraints() === nothing
            Test.@test Building.__format() == :JLD

            label1 = Building.__constraint_label()
            label2 = Building.__constraint_label()
            Test.@test label1 isa Symbol
            Test.@test label2 isa Symbol
            Test.@test label1 != label2
            Test.@test startswith(String(label1), "##unnamed")
            Test.@test startswith(String(label2), "##unnamed")
        end

        Test.@testset "state and control naming defaults" begin
            Test.@test Building.__state_name() == "x"
            Test.@test Building.__control_name() == "u"

            comps_state_1 = Building.__state_components(1, "x")
            comps_state_3 = Building.__state_components(3, "x")
            Test.@test comps_state_1 == ["x"]
            Test.@test comps_state_3 == ["x" * CTBase.ctindices(i) for i in 1:3]

            comps_control_1 = Building.__control_components(1, "u")
            comps_control_3 = Building.__control_components(3, "u")
            Test.@test comps_control_1 == ["u"]
            Test.@test comps_control_3 == ["u" * CTBase.ctindices(i) for i in 1:3]
        end

        Test.@testset "time and criterion defaults" begin
            Test.@test Building.__time_name() == "t"
            Test.@test Building.__criterion_type() == :min
            Test.@test Building.__time_grid_default_component() == :state
        end

        Test.@testset "variable naming defaults" begin
            Test.@test Building.__variable_name(0) == ""
            Test.@test Building.__variable_name(1) == "v"
            Test.@test Building.__variable_name(3) == "v"

            comps_var_0 = Building.__variable_components(0, "v")
            comps_var_1 = Building.__variable_components(1, "v")
            comps_var_3 = Building.__variable_components(3, "v")

            Test.@test comps_var_0 == String[]
            Test.@test comps_var_1 == ["v"]
            Test.@test comps_var_3 == ["v" * CTBase.ctindices(i) for i in 1:3]
        end

        Test.@testset "matrix and filename defaults" begin
            Test.@test CTBase.Core.__matrix_dimension_storage() == 1
            Test.@test Building.__filename_export_import() == "solution"
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_defaults() = TestOCPDefaults.test_defaults()
