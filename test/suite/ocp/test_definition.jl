module TestOCPDefinition

using Test: Test
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_definition()
    Test.@testset "Definition Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for definition functionality
        end

        # ====================================================================
        # UNIT TESTS - Setters/Getters on PreModel and Model
        # ====================================================================

        Test.@testset "definition! and definition on PreModel" begin
            pre = CTModels.PreModel()
            expr = :(x = 1)

            CTModels.definition!(pre, expr)

            Test.@test CTModels.definition(pre) === expr
        end

        # ====================================================================
        # INTEGRATION TESTS - Definition Propagated Through Build
        # ====================================================================

        Test.@testset "definition carried to Model after build" begin
            pre = CTModels.PreModel()

            # Minimal consistent problem using the high-level API
            CTModels.time!(pre; t0=0.0, tf=1.0)
            CTModels.state!(pre, 1)
            CTModels.control!(pre, 1)
            CTModels.variable!(pre, 0)

            dyn!(r, t, x, u, v) = r .= 0
            CTModels.dynamics!(pre, dyn!)

            mayer(x0, xf, v) = 0.0
            lagrange(t, x, u, v) = 0.0
            CTModels.objective!(pre, :min; mayer=mayer, lagrange=lagrange)

            expr = quote
                t ∈ [0, 1], time
                x ∈ R, state
                u ∈ R, control
                ẋ(t) == u(t)
                ∫(0.5u(t)^2) → min
            end

            CTModels.definition!(pre, expr)
            CTModels.time_dependence!(pre; autonomous=false)

            model = CTModels.build(pre)

            Test.@test CTModels.definition(model) === expr
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_definition() = TestOCPDefinition.test_definition()
