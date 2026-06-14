module TestNameConflictsIntegrationSimple

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_name_conflicts_integration()
    Test.@testset "Name Conflicts Integration Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Name Conflicts Detection
        # ====================================================================

        Test.@testset "Basic conflict detection" begin
            # Test state vs control conflict
            ocp = Building.PreModel()
            Building.state!(ocp, 1, "x")
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp, 1, "x")

            # Test control vs variable conflict
            ocp2 = Building.PreModel()
            Building.control!(ocp2, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(ocp2, 1, "u")

            # Test state vs time conflict
            ocp3 = Building.PreModel()
            Building.state!(ocp3, 1, "x")
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp3, t0=0, tf=1, time_name="x"
            )
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================

        Test.@testset "Valid complete workflow" begin
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=10, time_name="t")
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Building.control!(ocp, 1, "u")
            Building.variable!(ocp, 1, "v")

            dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
            Building.dynamics!(ocp, dynamics!)

            Building.objective!(ocp, :min, mayer=(x0, xf, v) -> sum(x0) + sum(xf) + sum(v))
            Building.constraint!(ocp, :state, lb=[-1, -1], ub=[1, 1], label=:state_bounds)

            Building.definition!(ocp, quote end)
            Building.time_dependence!(ocp; autonomous=false)
            Test.@test_nowarn Building.build(ocp)
        end

        Test.@testset "Case-insensitive objective" begin
            ocp1 = Building.PreModel()
            Building.time!(ocp1, t0=0, tf=1, time_name="t")
            Building.state!(ocp1, 1, "x")
            Building.control!(ocp1, 1, "u")
            Building.variable!(ocp1, 1, "v")

            Test.@test_nowarn Building.objective!(ocp1, :MIN, mayer=(x0, xf, v) -> sum(x0))
            Test.@test Components.criterion(ocp1.objective) == :min

            ocp2 = Building.PreModel()
            Building.time!(ocp2, t0=0, tf=1, time_name="t")
            Building.state!(ocp2, 1, "x")
            Building.control!(ocp2, 1, "u")
            Building.variable!(ocp2, 1, "v")

            Test.@test_nowarn Building.objective!(ocp2, :MAX, mayer=(x0, xf, v) -> sum(x0))
            Test.@test Components.criterion(ocp2.objective) == :max
        end

        Test.@testset "Bounds validation" begin
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Building.control!(ocp, 1, "u")
            Building.variable!(ocp, 1, "v")

            Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
                ocp, :state, lb=[1, 2], ub=[0, 1]
            )
            Test.@test_nowarn Building.constraint!(ocp, :state, lb=[0, 1], ub=[1, 2])
        end

        Test.@testset "High-dimensional systems" begin
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Building.state!(ocp, 5, "x", ["x₁", "x₂", "x₃", "x₄", "x₅"])
            Building.control!(ocp, 3, "u", ["u₁", "u₂", "u₃"])
            Building.variable!(ocp, 2, "v", ["v₁", "v₂"])

            # Verify no conflicts
            Test.@test Components.name(ocp.state) == "x"
            Test.@test length(Components.components(ocp.state)) == 5
            Test.@test Components.name(ocp.control) == "u"
            Test.@test length(Components.components(ocp.control)) == 3
            Test.@test Components.name(ocp.variable) == "v"
            Test.@test length(Components.components(ocp.variable)) == 2

            # Test constraints on high-dimensional system
            Test.@test_nowarn Building.constraint!(
                ocp, :state, lb=fill(-1.0, 5), ub=fill(1.0, 5)
            )
            Test.@test_nowarn Building.constraint!(
                ocp, :control, lb=fill(-2.0, 3), ub=fill(2.0, 3)
            )
            Test.@test_nowarn Building.constraint!(
                ocp, :variable, lb=fill(-3.0, 2), ub=fill(3.0, 2)
            )
        end

        Test.@testset "Unicode and special characters in names" begin
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="τ")
            Building.state!(ocp, 2, "ξ", ["ξ₁", "ξ₂"])
            Building.control!(ocp, 1, "μ")
            Building.variable!(ocp, 1, "λ")

            Test.@test Components.time_name(ocp.times) == "τ"
            Test.@test Components.name(ocp.state) == "ξ"
            Test.@test Components.name(ocp.control) == "μ"
            Test.@test Components.name(ocp.variable) == "λ"

            # Test conflicts with Unicode names (use fresh ocp)
            ocp2 = Building.PreModel()
            Building.time!(ocp2, t0=0, tf=1, time_name="t")
            Building.state!(ocp2, 1, "α")
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp2, 1, "α")
        end

        Test.@testset "Edge cases with bounds" begin
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Building.state!(ocp, 3, "x", ["x₁", "x₂", "x₃"])
            Building.control!(ocp, 2, "u", ["u₁", "u₂"])
            Building.variable!(ocp, 1, "v")

            # Test with infinity bounds
            Test.@test_nowarn Building.constraint!(
                ocp, :state, lb=[-Inf, -Inf, -Inf], ub=[Inf, Inf, Inf]
            )

            # Test with mixed finite/infinite bounds
            Test.@test_nowarn Building.constraint!(
                ocp, :control, lb=[-1.0, -Inf], ub=[1.0, Inf]
            )

            # Test equality constraints (lb == ub)
            Test.@test_nowarn Building.constraint!(ocp, :variable, lb=[0.5], ub=[0.5])

            # Test very small differences (lb ≈ ub but lb < ub)
            Test.@test_nowarn Building.constraint!(
                ocp, :state, lb=[0.0, 0.0, 0.0], ub=[1e-10, 1e-10, 1e-10]
            )
        end

        Test.@testset "Multiple constraint types combined" begin
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=10, time_name="t")
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Building.control!(ocp, 1, "u")
            Building.variable!(ocp, 1, "v")

            dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
            Building.dynamics!(ocp, dynamics!)

            Building.objective!(ocp, :min, mayer=(x0, xf, v) -> sum(xf))

            Test.@test_nowarn Building.constraint!(
                ocp, :state, lb=[-5, -5], ub=[5, 5], label=:state_box
            )
            Test.@test_nowarn Building.constraint!(
                ocp, :control, lb=[-1], ub=[1], label=:control_box
            )
            Test.@test_nowarn Building.constraint!(
                ocp, :variable, lb=[0], ub=[10], label=:variable_box
            )

            path_constraint(r, t, x, u, v) = r[1] = x[1]^2 + u[1]^2
            Test.@test_nowarn Building.constraint!(
                ocp, :path, f=path_constraint, lb=[0], ub=[1], label=:path_c
            )

            boundary_constraint(r, x0, xf, v) = r .= [x0[1], xf[1]]
            Test.@test_nowarn Building.constraint!(
                ocp,
                :boundary,
                f=boundary_constraint,
                lb=[0, 0],
                ub=[1, 1],
                label=:boundary_c,
            )

            Building.definition!(ocp, quote end)
            Building.time_dependence!(ocp; autonomous=false)
            Test.@test_nowarn Building.build(ocp)
        end

        Test.@testset "Objective criterion variations" begin
            for (criterion, expected) in
                [(:min, :min), (:max, :max), (:MIN, :min), (:MAX, :max)]
                ocp = Building.PreModel()
                Building.time!(ocp, t0=0, tf=1, time_name="t")
                Building.state!(ocp, 2, "x", ["x₁", "x₂"])
                Building.control!(ocp, 1, "u")
                Building.variable!(ocp, 1, "v")

                dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
                Building.dynamics!(ocp, dynamics!)

                Test.@test_nowarn Building.objective!(
                    ocp, criterion, mayer=(x0, xf, v) -> sum(xf)
                )
                Test.@test Components.criterion(ocp.objective) == expected

                Building.definition!(ocp, quote end)
                Building.time_dependence!(ocp; autonomous=false)
                Test.@test_nowarn Building.build(ocp)
            end
        end

        Test.@testset "Component name vs component conflicts" begin
            # State component named "u" should conflict with control name "u"
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="t")
            Building.state!(ocp, 3, "x", ["x₁", "u", "x₃"])
            Test.@test_throws Exceptions.IncorrectArgument Building.control!(ocp, 1, "u")

            # control component named "v" should conflict with variable name "v"
            ocp2 = Building.PreModel()
            Building.time!(ocp2, t0=0, tf=1, time_name="t")
            Building.state!(ocp2, 2, "x", ["x₁", "x₂"])
            Building.control!(ocp2, 2, "w", ["w₁", "v"])
            Test.@test_throws Exceptions.IncorrectArgument Building.variable!(ocp2, 1, "v")
        end

        Test.@testset "Empty variable edge cases" begin
            ocp = Building.PreModel()
            Building.time!(ocp, t0=0, tf=1, time_name="v")
            Building.state!(ocp, 1, "x")
            Building.control!(ocp, 1, "u")
            Building.variable!(ocp, 0)

            dynamics!(r, t, x, u, v) = r[1] = u[1]
            Building.dynamics!(ocp, dynamics!)

            Test.@test_nowarn Building.objective!(ocp, :min, mayer=(x0, xf, v) -> sum(xf))

            Building.definition!(ocp, quote end)
            Building.time_dependence!(ocp; autonomous=false)
            Test.@test_nowarn Building.build(ocp)
        end

        Test.@testset "Time bounds validation" begin
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp, t0=10, tf=5, time_name="t"
            )
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp, t0=5, tf=5, time_name="t"
            )
            Test.@test_nowarn Building.time!(ocp, t0=0, tf=10, time_name="t")
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
function test_name_conflicts_integration()
    return TestNameConflictsIntegrationSimple.test_name_conflicts_integration()
end
