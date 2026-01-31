module TestOCPVariable

using Test
using CTBase
using CTModels
using Main.TestOptions: VERBOSE, SHOWTIMING

function test_variable()
    Test.@testset "OCP Variable" verbose = VERBOSE showtiming = SHOWTIMING begin
        # VariableModel

        # some checks
        ocp = CTModels.PreModel()
        @test ocp.variable isa CTModels.EmptyVariableModel
        @test !CTModels.OCP.__is_variable_set(ocp)
        CTModels.variable!(ocp, 1)
        @test CTModels.OCP.__is_variable_set(ocp)

        # variable!
        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 0)
        @test CTModels.dimension(ocp.variable) == 0
        @test CTModels.name(ocp.variable) == ""
        @test CTModels.components(ocp.variable) == String[]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 1)
        @test CTModels.dimension(ocp.variable) == 1
        @test CTModels.name(ocp.variable) == "v"
        @test CTModels.components(ocp.variable) == ["v"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 1, "w")
        @test CTModels.dimension(ocp.variable) == 1
        @test CTModels.name(ocp.variable) == "w"
        @test CTModels.components(ocp.variable) == ["w"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2)
        @test CTModels.dimension(ocp.variable) == 2
        @test CTModels.name(ocp.variable) == "v"
        @test CTModels.components(ocp.variable) == ["v₁", "v₂"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2, :w)
        @test CTModels.dimension(ocp.variable) == 2
        @test CTModels.name(ocp.variable) == "w"
        @test CTModels.components(ocp.variable) == ["w₁", "w₂"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2, "w", ["a", "b"])
        @test CTModels.dimension(ocp.variable) == 2
        @test CTModels.name(ocp.variable) == "w"
        @test CTModels.components(ocp.variable) == ["a", "b"]

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2, "w", [:a, :b])
        @test CTModels.dimension(ocp.variable) == 2
        @test CTModels.name(ocp.variable) == "w"
        @test CTModels.components(ocp.variable) == ["a", "b"]

        # set twice
        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 1)
        @test_throws CTModels.Exceptions.UnauthorizedCall CTModels.variable!(ocp, 1)

        # wrong number of components
        ocp = CTModels.PreModel()
        @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 2, "w", ["a"])

        # NEW: Internal name validation tests (only for q > 0)
        @testset "variable! - Internal name validation" begin
            # Empty name (q > 0)
            ocp = CTModels.PreModel()
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "")
            
            # Empty component name (q > 0)
            ocp = CTModels.PreModel()
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 2, "v", ["", "w"])
            
            # Name in components (multiple) - should fail
            ocp = CTModels.PreModel()
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 2, "v", ["v", "w"])
            
            # Name == component (single) - should PASS (default behavior)
            ocp = CTModels.PreModel()
            @test_nowarn CTModels.variable!(ocp, 1, "v", ["v"])
            
            # Duplicate components (q > 0)
            ocp = CTModels.PreModel()
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 2, "v", ["w", "w"])
            
            # Empty variable (q = 0) should not trigger name validation
            ocp = CTModels.PreModel()
            @test_nowarn CTModels.variable!(ocp, 0)  # Should work fine
        end

        # NEW: Inter-component conflicts tests (only for q > 0)
        @testset "variable! - Inter-component conflicts" begin
            # variable.name vs state.name
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "x")  # Conflict!
            
            # variable.name vs state.component
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["v", "w"])
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "v")
            
            # variable.component vs state.name
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 2, "v", ["x", "w"])
            
            # variable.name vs control.name
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "u")
            
            # variable.component vs control.name
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 2, "v", ["u", "w"])
            
            # variable.name vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 1, "t")
            
            # variable.component vs time_name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            @test_throws CTModels.Exceptions.IncorrectArgument CTModels.variable!(ocp, 2, "v", ["t", "w"])
            
            # Empty variable (q = 0) should not trigger inter-component conflicts
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            @test_nowarn CTModels.variable!(ocp, 0)  # Should work fine even with "x" existing
        end

        # NEW: Type stability tests
        @testset "variable! - Type stability" begin
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 2, "v", ["v₁", "v₂"])
            @inferred CTModels.name(ocp.variable)
            @inferred CTModels.components(ocp.variable)
            @inferred CTModels.dimension(ocp.variable)
        end
    end
end

end # module

test_variable() = TestOCPVariable.test_variable()
