module TestPrint

using Test: Test
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_print()
    Test.@testset "Display Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Display Functions
        # ====================================================================

        Test.@testset "Abstract Types" begin
            # Pure unit tests for display functionality
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================

        Test.@testset "PreModel Display" begin
            Test.@testset "show(PreModel) prints abstract and mathematical definitions" begin
                pre = CTModels.PreModel()

                # Minimal consistent problem
                CTModels.time!(pre; t0=0.0, tf=1.0)
                CTModels.state!(pre, 1, "x", ["x"])
                CTModels.control!(pre, 1, "u", ["u"])
                CTModels.variable!(pre, 0)

                dyn!(r, t, x, u, v) = r .= 0
                CTModels.dynamics!(pre, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                CTModels.objective!(pre, :min; mayer=mayer, lagrange=lagrange)

                def_expr = quote
                    t ∈ [0, 1], time
                    x ∈ R, state
                    u ∈ R, control
                    ẋ(t) == u(t)
                    ∫(0.5u(t)^2) → min
                end
                CTModels.definition!(pre, def_expr)
                CTModels.time_dependence!(pre; autonomous=false)

                io = IOBuffer()
                show(io, MIME"text/plain"(), pre)
                s = String(take!(io))

                Test.@test occursin("Abstract definition:", s)
                Test.@test occursin("optimal control problem is of the form:", s)
            end
        end

        Test.@testset "Model Display" begin
            Test.@testset "show(Model) prints abstract and mathematical definitions" begin
                pre = CTModels.PreModel()

                CTModels.time!(pre; t0=0.0, tf=1.0)
                CTModels.state!(pre, 1, "x", ["x"])
                CTModels.control!(pre, 1, "u", ["u"])
                CTModels.variable!(pre, 0)

                dyn!(r, t, x, u, v) = r .= 0
                CTModels.dynamics!(pre, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                CTModels.objective!(pre, :min; mayer=mayer, lagrange=lagrange)

                def_expr = quote
                    t ∈ [0, 1], time
                    x ∈ R, state
                    u ∈ R, control
                    ẋ(t) == u(t)
                    ∫(0.5u(t)^2) → min
                end
                CTModels.definition!(pre, def_expr)
                CTModels.time_dependence!(pre; autonomous=false)

                model = CTModels.build(pre)

                io = IOBuffer()
                show(io, MIME"text/plain"(), model)
                s = String(take!(io))

                Test.@test occursin("Abstract definition:", s)
                Test.@test occursin("optimal control problem is of the form:", s)
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_print() = TestPrint.test_print()
