module TestOCPState

using Test
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_state()
    Test.@testset "OCP State" verbose = VERBOSE showtiming = SHOWTIMING begin
        # StateModel

        # some checks
        ocp = CTModels.PreModel()
        @test isnothing(ocp.state)
        @test !CTModels.OCP.__is_state_set(ocp)
        CTModels.state!(ocp, 1)
        @test CTModels.OCP.__is_state_set(ocp)

        # state!
        ocp = CTModels.PreModel()
        @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 0)

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 1)
        @test CTModels.dimension(ocp.state) == 1
        @test CTModels.name(ocp.state) == "x"
        @test CTModels.components(ocp.state) == ["x"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 1, "y")
        @test CTModels.dimension(ocp.state) == 1
        @test CTModels.name(ocp.state) == "y"
        @test CTModels.components(ocp.state) == ["y"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2)
        @test CTModels.dimension(ocp.state) == 2
        @test CTModels.name(ocp.state) == "x"
        @test CTModels.components(ocp.state) == ["x₁", "x₂"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2, :y)
        @test CTModels.dimension(ocp.state) == 2
        @test CTModels.name(ocp.state) == "y"
        @test CTModels.components(ocp.state) == ["y₁", "y₂"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2, "y", ["u", "v"])
        @test CTModels.dimension(ocp.state) == 2
        @test CTModels.name(ocp.state) == "y"
        @test CTModels.components(ocp.state) == ["u", "v"]

        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 2, "y", [:u, :v])
        @test CTModels.dimension(ocp.state) == 2
        @test CTModels.name(ocp.state) == "y"
        @test CTModels.components(ocp.state) == ["u", "v"]

        # set twice
        ocp = CTModels.PreModel()
        CTModels.state!(ocp, 1)
        @test_throws Exceptions.PreconditionError CTModels.state!(ocp, 1)

        # wrong number of components
        ocp = CTModels.PreModel()
        @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 2, "y", ["u"])

        # NEW: Internal name validation tests
        @testset "state! - Internal name validation" begin
            # Empty name
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 1, "")
            
            # Empty component name
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 2, "x", ["", "y"])
            
            # Name in components (multiple components) - should fail
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 2, "x", ["x", "y"])
            
            # Name == component (single) - should PASS (default behavior)
            ocp = CTModels.PreModel()
            @test_nowarn CTModels.state!(ocp, 1, "x", ["x"])
            
            # Duplicate components
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 2, "x", ["y", "y"])
        end

        # NEW: Inter-component conflicts tests
        @testset "state! - Inter-component conflicts" begin
            # state.name vs control.name
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 1, "u")  # Conflict!
            
            # state.component vs control.name
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 2, "x", ["u", "v"])
            
            # state.name vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 1, "t")
            
            # state.component vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 2, "x", ["t", "y"])
            
            # state.name vs variable.name
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 1, "v")
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 1, "v")
            
            # state.component vs variable.name
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 1, "v")
            @test_throws Exceptions.IncorrectArgument CTModels.state!(ocp, 2, "x", ["v", "y"])
        end

        # NEW: Type stability tests
        @testset "state! - Type stability" begin
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            @inferred CTModels.name(ocp.state)
            @inferred CTModels.components(ocp.state)
            @inferred CTModels.dimension(ocp.state)
        end
    end
end

end # module

test_state() = TestOCPState.test_state()
