module TestNameConflictsIntegrationSimple

using Test
using CTBase: CTBase
const Exceptions = CTBase.Exceptions
using CTModels
const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_name_conflicts_integration()
    Test.@testset "Simple Name Conflicts Integration Tests" verbose = VERBOSE showtiming = SHOWTIMING begin
        
        @testset "Basic conflict detection" begin
            # Test state vs control conflict
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "x")
            
            # Test control vs variable conflict
            ocp2 = CTModels.PreModel()
            CTModels.control!(ocp2, 1, "u")
            @test_throws Exceptions.IncorrectArgument CTModels.variable!(ocp2, 1, "u")
            
            # Test state vs time conflict
            ocp3 = CTModels.PreModel()
            CTModels.state!(ocp3, 1, "x")
            @test_throws Exceptions.IncorrectArgument CTModels.time!(ocp3, t0=0, tf=1, time_name="x")
        end
        
        @testset "Valid complete workflow" begin
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=10, time_name="t")
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            CTModels.variable!(ocp, 1, "v")
            
            dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
            CTModels.dynamics!(ocp, dynamics!)
            
            CTModels.objective!(ocp, :min, mayer=(x0, xf, v) -> sum(x0) + sum(xf) + sum(v))
            CTModels.constraint!(ocp, :state, lb=[-1, -1], ub=[1, 1], label=:state_bounds)
            
            CTModels.definition!(ocp, quote end)
            CTModels.time_dependence!(ocp; autonomous=false)
            @test_nowarn CTModels.build(ocp)
        end
        
        @testset "Case-insensitive objective" begin
            ocp1 = CTModels.PreModel()
            CTModels.time!(ocp1, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp1, 1, "x")
            CTModels.control!(ocp1, 1, "u")
            CTModels.variable!(ocp1, 1, "v")
            
            @test_nowarn CTModels.objective!(ocp1, :MIN, mayer=(x0, xf, v) -> sum(x0))
            @test CTModels.criterion(ocp1.objective) == :min
            
            ocp2 = CTModels.PreModel()
            CTModels.time!(ocp2, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp2, 1, "x")
            CTModels.control!(ocp2, 1, "u")
            CTModels.variable!(ocp2, 1, "v")
            
            @test_nowarn CTModels.objective!(ocp2, :MAX, mayer=(x0, xf, v) -> sum(x0))
            @test CTModels.criterion(ocp2.objective) == :max
        end
        
        @testset "Bounds validation" begin
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            CTModels.variable!(ocp, 1, "v")
            
            @test_throws Exceptions.IncorrectArgument CTModels.constraint!(ocp, :state, lb=[1, 2], ub=[0, 1])
            @test_nowarn CTModels.constraint!(ocp, :state, lb=[0, 1], ub=[1, 2])
        end
        
        @testset "High-dimensional systems" begin
            # Test with larger dimensions (dim > 3)
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp, 5, "x", ["x₁", "x₂", "x₃", "x₄", "x₅"])
            CTModels.control!(ocp, 3, "u", ["u₁", "u₂", "u₃"])
            CTModels.variable!(ocp, 2, "v", ["v₁", "v₂"])
            
            # Verify no conflicts
            @test CTModels.name(ocp.state) == "x"
            @test length(CTModels.components(ocp.state)) == 5
            @test CTModels.name(ocp.control) == "u"
            @test length(CTModels.components(ocp.control)) == 3
            @test CTModels.name(ocp.variable) == "v"
            @test length(CTModels.components(ocp.variable)) == 2
            
            # Test constraints on high-dimensional system
            @test_nowarn CTModels.constraint!(ocp, :state, lb=fill(-1.0, 5), ub=fill(1.0, 5))
            @test_nowarn CTModels.constraint!(ocp, :control, lb=fill(-2.0, 3), ub=fill(2.0, 3))
            @test_nowarn CTModels.constraint!(ocp, :variable, lb=fill(-3.0, 2), ub=fill(3.0, 2))
        end
        
        @testset "Unicode and special characters in names" begin
            # Test with various Unicode characters
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="τ")  # Greek tau
            CTModels.state!(ocp, 2, "ξ", ["ξ₁", "ξ₂"])  # Greek xi
            CTModels.control!(ocp, 1, "μ")  # Greek mu
            CTModels.variable!(ocp, 1, "λ")  # Greek lambda
            
            @test CTModels.time_name(ocp.times) == "τ"
            @test CTModels.name(ocp.state) == "ξ"
            @test CTModels.name(ocp.control) == "μ"
            @test CTModels.name(ocp.variable) == "λ"
            
            # Test conflicts with Unicode names (use fresh ocp)
            ocp2 = CTModels.PreModel()
            CTModels.time!(ocp2, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp2, 1, "α")
            @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp2, 1, "α")
        end
        
        @testset "Edge cases with bounds" begin
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp, 3, "x", ["x₁", "x₂", "x₃"])
            CTModels.control!(ocp, 2, "u", ["u₁", "u₂"])
            CTModels.variable!(ocp, 1, "v")
            
            # Test with infinity bounds
            @test_nowarn CTModels.constraint!(ocp, :state, lb=[-Inf, -Inf, -Inf], ub=[Inf, Inf, Inf])
            
            # Test with mixed finite/infinite bounds
            @test_nowarn CTModels.constraint!(ocp, :control, lb=[-1.0, -Inf], ub=[1.0, Inf])
            
            # Test equality constraints (lb == ub)
            @test_nowarn CTModels.constraint!(ocp, :variable, lb=[0.5], ub=[0.5])
            
            # Test very small differences (lb ≈ ub but lb < ub)
            @test_nowarn CTModels.constraint!(ocp, :state, lb=[0.0, 0.0, 0.0], ub=[1e-10, 1e-10, 1e-10])
        end
        
        @testset "Multiple constraint types combined" begin
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=10, time_name="t")
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp, 1, "u")
            CTModels.variable!(ocp, 1, "v")
            
            dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
            CTModels.dynamics!(ocp, dynamics!)
            
            CTModels.objective!(ocp, :min, mayer=(x0, xf, v) -> sum(xf))
            
            # Add multiple constraint types
            @test_nowarn CTModels.constraint!(ocp, :state, lb=[-5, -5], ub=[5, 5], label=:state_box)
            @test_nowarn CTModels.constraint!(ocp, :control, lb=[-1], ub=[1], label=:control_box)
            @test_nowarn CTModels.constraint!(ocp, :variable, lb=[0], ub=[10], label=:variable_box)
            
            # Path constraint
            path_constraint(r, t, x, u, v) = r[1] = x[1]^2 + u[1]^2
            @test_nowarn CTModels.constraint!(ocp, :path, f=path_constraint, lb=[0], ub=[1], label=:path_c)
            
            # Boundary constraint
            boundary_constraint(r, x0, xf, v) = r .= [x0[1], xf[1]]
            @test_nowarn CTModels.constraint!(ocp, :boundary, f=boundary_constraint, lb=[0, 0], ub=[1, 1], label=:boundary_c)
            
            CTModels.definition!(ocp, quote end)
            CTModels.time_dependence!(ocp; autonomous=false)
            @test_nowarn CTModels.build(ocp)
        end
        
        @testset "Objective criterion variations" begin
            # Test all valid criterion variations in real scenarios
            for (criterion, expected) in [(:min, :min), (:max, :max), (:MIN, :min), (:MAX, :max)]
                ocp = CTModels.PreModel()
                CTModels.time!(ocp, t0=0, tf=1, time_name="t")
                CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
                CTModels.control!(ocp, 1, "u")
                CTModels.variable!(ocp, 1, "v")
                
                dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
                CTModels.dynamics!(ocp, dynamics!)
                
                @test_nowarn CTModels.objective!(ocp, criterion, mayer=(x0, xf, v) -> sum(xf))
                @test CTModels.criterion(ocp.objective) == expected
                
                CTModels.definition!(ocp, quote end)
                CTModels.time_dependence!(ocp; autonomous=false)
                @test_nowarn CTModels.build(ocp)
            end
        end
        
        @testset "Component name vs component conflicts" begin
            # Test that component names don't conflict with other component's main name
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="t")
            
            # State component named "u" should conflict with control name "u"
            CTModels.state!(ocp, 3, "x", ["x₁", "u", "x₃"])
            @test_throws Exceptions.IncorrectArgument CTModels.control!(ocp, 1, "u")
            
            # Test with fresh ocp: control component named "v" should conflict with variable name "v"
            ocp2 = CTModels.PreModel()
            CTModels.time!(ocp2, t0=0, tf=1, time_name="t")
            CTModels.state!(ocp2, 2, "x", ["x₁", "x₂"])
            CTModels.control!(ocp2, 2, "w", ["w₁", "v"])
            @test_throws Exceptions.IncorrectArgument CTModels.variable!(ocp2, 1, "v")
        end
        
        @testset "Empty variable edge cases" begin
            # Test q=0 doesn't interfere with anything
            ocp = CTModels.PreModel()
            CTModels.time!(ocp, t0=0, tf=1, time_name="v")  # Use "v" as time name
            CTModels.state!(ocp, 1, "x")
            CTModels.control!(ocp, 1, "u")
            CTModels.variable!(ocp, 0)  # Empty variable shouldn't conflict
            
            dynamics!(r, t, x, u, v) = r[1] = u[1]
            CTModels.dynamics!(ocp, dynamics!)
            
            @test_nowarn CTModels.objective!(ocp, :min, mayer=(x0, xf, v) -> sum(xf))
            
            CTModels.definition!(ocp, quote end)
            CTModels.time_dependence!(ocp; autonomous=false)
            @test_nowarn CTModels.build(ocp)
        end
        
        @testset "Time bounds validation" begin
            # Test t0 < tf validation
            ocp = CTModels.PreModel()
            @test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, t0=10, tf=5, time_name="t")
            @test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, t0=5, tf=5, time_name="t")  # Equal not allowed
            @test_nowarn CTModels.time!(ocp, t0=0, tf=10, time_name="t")  # Valid
        end
    end
end

end # module

test_name_conflicts_integration() = TestNameConflictsIntegrationSimple.test_name_conflicts_integration()
