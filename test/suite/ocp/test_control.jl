module TestOCPControl

using Test
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_control()
    Test.@testset "OCP Control" verbose = VERBOSE showtiming = SHOWTIMING begin
        # ControlModel

        # some checks
        ocp = CTModels.PreModel()
        @test isnothing(ocp.control)
        @test !CTModels.OCP.__is_control_set(ocp)
        CTModels.control!(ocp, 1)
        @test CTModels.OCP.__is_control_set(ocp)

        # control!
        ocp = CTModels.PreModel()
        @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 0)

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 1)
        @test CTModels.dimension(ocp.control) == 1
        @test CTModels.name(ocp.control) == "u"
        @test CTModels.components(ocp.control) == ["u"]

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 1, "v")
        @test CTModels.dimension(ocp.control) == 1
        @test CTModels.name(ocp.control) == "v"

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 2)
        @test CTModels.dimension(ocp.control) == 2
        @test CTModels.name(ocp.control) == "u"
        @test CTModels.components(ocp.control) == ["u₁", "u₂"]

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 2, :v)
        @test CTModels.dimension(ocp.control) == 2
        @test CTModels.name(ocp.control) == "v"
        @test CTModels.components(ocp.control) == ["v₁", "v₂"]

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 2, "v", ["a", "b"])
        @test CTModels.dimension(ocp.control) == 2
        @test CTModels.name(ocp.control) == "v"
        @test CTModels.components(ocp.control) == ["a", "b"]

        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 2, "v", [:a, :b])
        @test CTModels.dimension(ocp.control) == 2
        @test CTModels.name(ocp.control) == "v"
        @test CTModels.components(ocp.control) == ["a", "b"]

        # set twice
        ocp = CTModels.PreModel()
        CTModels.control!(ocp, 1)
        @test_throws Exceptions.PreconditionError CTModels.control!(ocp, 1)

        # wrong number of components
        ocp = CTModels.PreModel()
        @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 2, "v", ["a"])

        # NEW: Internal name validation tests
        @testset "control! - Internal name validation" begin
            # Empty name
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "")

            # Empty component name
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["", "v"]
            )

            # Name in components (multiple) - should fail
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["u", "v"]
            )

            # Name == component (single) - should PASS (default behavior)
            ocp = CTModels.PreModel()
            @test_nowarn CTModels.control!(ocp, 1, "u", ["u"])

            # Duplicate components
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["v", "v"]
            )
        end

        # NEW: Inter-component conflicts tests
        @testset "control! - Inter-component conflicts" begin
            # control.name vs state.name
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "x")  # Conflict!

            # control.name vs state.component
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["u", "v"])
            @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "u")

            # control.component vs state.name
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            @test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["x", "v"]
            )

            # control.name vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "t")

            # control.component vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            @test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["t", "v"]
            )

            # control.name vs variable.name
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 1, "v")
            @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "v")

            # control.component vs variable.name
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 1, "v")
            @test_throws Exceptions.IncorrectArgument CTModels.control!(
                ocp, 2, "u", ["v", "w"]
            )
        end

        # NEW: Type stability tests
        @testset "control! - Type stability" begin
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 2, "u", ["u₁", "u₂"])
            @inferred CTModels.name(ocp.control)
            @inferred CTModels.components(ocp.control)
            @inferred CTModels.dimension(ocp.control)
        end
    end
end

end # module

test_control() = TestOCPControl.test_control()
