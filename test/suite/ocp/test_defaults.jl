module TestOCPDefaults

using Test
using CTBase
using CTModels
using Main.TestOptions: VERBOSE, SHOWTIMING

function test_defaults()
    # TODO: add tests for src/core/default.jl (default options, etc.).

    Test.@testset "constraints and format defaults" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test CTModels.__constraints() === nothing
        Test.@test CTModels.__format() == :JLD

        label1 = CTModels.__constraint_label()
        label2 = CTModels.__constraint_label()
        Test.@test label1 isa Symbol
        Test.@test label2 isa Symbol
        Test.@test label1 != label2
        Test.@test startswith(String(label1), "##unnamed")
        Test.@test startswith(String(label2), "##unnamed")
    end

    Test.@testset "state and control naming defaults" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test CTModels.__state_name() == "x"
        Test.@test CTModels.__control_name() == "u"

        comps_state_1 = CTModels.__state_components(1, "x")
        comps_state_3 = CTModels.__state_components(3, "x")
        Test.@test comps_state_1 == ["x"]
        Test.@test comps_state_3 == ["x" * CTBase.ctindices(i) for i in 1:3]

        comps_control_1 = CTModels.__control_components(1, "u")
        comps_control_3 = CTModels.__control_components(3, "u")
        Test.@test comps_control_1 == ["u"]
        Test.@test comps_control_3 == ["u" * CTBase.ctindices(i) for i in 1:3]
    end

    Test.@testset "time and criterion defaults" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test CTModels.__time_name() == "t"
        Test.@test CTModels.__criterion_type() == :min
    end

    Test.@testset "variable naming defaults" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test CTModels.__variable_name(0) == ""
        Test.@test CTModels.__variable_name(1) == "v"
        Test.@test CTModels.__variable_name(3) == "v"

        comps_var_0 = CTModels.__variable_components(0, "v")
        comps_var_1 = CTModels.__variable_components(1, "v")
        comps_var_3 = CTModels.__variable_components(3, "v")

        Test.@test comps_var_0 == String[]
        Test.@test comps_var_1 == ["v"]
        Test.@test comps_var_3 == ["v" * CTBase.ctindices(i) for i in 1:3]
    end

    Test.@testset "matrix and filename defaults" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test CTModels.__matrix_dimension_storage() == 1
        Test.@test CTModels.__filename_export_import() == "solution"
    end
end

end # module

test_defaults() = TestOCPDefaults.test_defaults()
