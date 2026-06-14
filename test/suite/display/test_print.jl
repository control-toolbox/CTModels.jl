module TestPrint

import Test: Test
import CTModels.Components: Components
import CTModels.Building: Building
import CTModels.Display: Display

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_print()
    Test.@testset "Display Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - AbstractDefinition display
        # ====================================================================

        Test.@testset "AbstractDefinition display" begin
            Test.@testset "show(EmptyDefinition) produces no output" begin
                io = IOBuffer()
                show(io, MIME"text/plain"(), Components.EmptyDefinition())
                Test.@test isempty(String(take!(io)))
            end

            Test.@testset "show(Definition) prints header" begin
                d = Components.Definition(:(x = 1))
                io = IOBuffer()
                show(io, MIME"text/plain"(), d)
                Test.@test occursin("Abstract definition:", String(take!(io)))
            end

            Test.@testset "_print_abstract_definition returns false for EmptyDefinition" begin
                io = IOBuffer()
                result = Display._print_abstract_definition(
                    io, Components.EmptyDefinition()
                )
                Test.@test result == false
                Test.@test isempty(String(take!(io)))
            end

            Test.@testset "_print_abstract_definition returns true for Definition" begin
                io = IOBuffer()
                result = Display._print_abstract_definition(
                    io, Components.Definition(:(x = 1))
                )
                Test.@test result == true
                Test.@test occursin("Abstract definition:", String(take!(io)))
            end
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================

        Test.@testset "PreModel Display" begin
            Test.@testset "show(PreModel) prints abstract and mathematical definitions" begin
                pre = Building.PreModel()

                # Minimal consistent problem
                Building.time!(pre; t0=0.0, tf=1.0)
                Building.state!(pre, 1, "x", ["x"])
                Building.control!(pre, 1, "u", ["u"])
                Building.variable!(pre, 0)

                dyn!(r, t, x, u, v) = r .= 0
                Building.dynamics!(pre, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                Building.objective!(pre, :min; mayer=mayer, lagrange=lagrange)

                def_expr = quote
                    t ∈ [0, 1], time
                    x ∈ R, state
                    u ∈ R, control
                    ẋ(t) == u(t)
                    ∫(0.5u(t)^2) → min
                end
                Building.definition!(pre, def_expr)
                Building.time_dependence!(pre; autonomous=false)

                io = IOBuffer()
                show(io, MIME"text/plain"(), pre)
                s = String(take!(io))

                Test.@test occursin("Abstract definition:", s)
                Test.@test occursin("optimal control problem is of the form:", s)
            end
        end

        Test.@testset "Model Display" begin
            Test.@testset "show(Model) prints abstract and mathematical definitions" begin
                pre = Building.PreModel()

                Building.time!(pre; t0=0.0, tf=1.0)
                Building.state!(pre, 1, "x", ["x"])
                Building.control!(pre, 1, "u", ["u"])
                Building.variable!(pre, 0)

                dyn!(r, t, x, u, v) = r .= 0
                Building.dynamics!(pre, dyn!)

                mayer(x0, xf, v) = 0.0
                lagrange(t, x, u, v) = 0.0
                Building.objective!(pre, :min; mayer=mayer, lagrange=lagrange)

                def_expr = quote
                    t ∈ [0, 1], time
                    x ∈ R, state
                    u ∈ R, control
                    ẋ(t) == u(t)
                    ∫(0.5u(t)^2) → min
                end
                Building.definition!(pre, def_expr)
                Building.time_dependence!(pre; autonomous=false)

                model = Building.build(pre)

                io = IOBuffer()
                show(io, MIME"text/plain"(), model)
                s = String(take!(io))

                Test.@test occursin("Abstract definition:", s)
                Test.@test occursin("optimal control problem is of the form:", s)
            end

            Test.@testset "show(Model) without definition omits abstract header" begin
                pre = Building.PreModel()
                Building.time!(pre; t0=0.0, tf=1.0)
                Building.state!(pre, 1, "x", ["x"])
                Building.control!(pre, 1, "u", ["u"])
                Building.variable!(pre, 0)
                dyn!(r, t, x, u, v) = r .= 0
                Building.dynamics!(pre, dyn!)
                Building.objective!(
                    pre, :min; mayer=(x0, xf, v) -> 0.0, lagrange=(t, x, u, v) -> 0.0
                )
                Building.time_dependence!(pre; autonomous=false)

                model = Building.build(pre)

                io = IOBuffer()
                show(io, MIME"text/plain"(), model)
                s = String(take!(io))

                Test.@test !occursin("Abstract definition:", s)
                Test.@test occursin("optimal control problem is of the form:", s)
            end
        end

        Test.@testset "PreModel Display - without definition" begin
            Test.@testset "show(PreModel) without definition omits abstract header" begin
                pre = Building.PreModel()
                Building.time!(pre; t0=0.0, tf=1.0)
                Building.state!(pre, 1, "x", ["x"])
                Building.control!(pre, 1, "u", ["u"])
                Building.variable!(pre, 0)
                dyn!(r, t, x, u, v) = r .= 0
                Building.dynamics!(pre, dyn!)
                Building.objective!(
                    pre, :min; mayer=(x0, xf, v) -> 0.0, lagrange=(t, x, u, v) -> 0.0
                )
                Building.time_dependence!(pre; autonomous=false)

                io = IOBuffer()
                show(io, MIME"text/plain"(), pre)
                s = String(take!(io))

                Test.@test !occursin("Abstract definition:", s)
                Test.@test occursin("optimal control problem is of the form:", s)
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Display variants
        # ====================================================================

        Test.@testset "Model Display - autonomous variant" begin
            Test.@testset "show(Model) autonomous labels output correctly" begin
                pre = Building.PreModel()
                Building.time!(pre; t0=0.0, tf=1.0)
                Building.state!(pre, 1, "x", ["x"])
                Building.control!(pre, 1, "u", ["u"])
                Building.variable!(pre, 0)
                dyn!(r, x, u, v) = r .= 0
                Building.dynamics!(pre, dyn!)
                Building.objective!(
                    pre, :min; mayer=(x0, xf, v) -> 0.0, lagrange=(t, x, u, v) -> 0.0
                )
                Building.time_dependence!(pre; autonomous=true)

                model = Building.build(pre)

                io = IOBuffer()
                show(io, MIME"text/plain"(), model)
                s = String(take!(io))

                Test.@test occursin("autonomous", s)
                Test.@test !occursin("non autonomous", s)
                Test.@test occursin("optimal control problem is of the form:", s)
            end
        end

        Test.@testset "Model Display - with optimisation variable" begin
            Test.@testset "show(Model) with variable mentions v in output" begin
                pre = Building.PreModel()
                Building.time!(pre; t0=0.0, tf=1.0)
                Building.state!(pre, 1, "x", ["x"])
                Building.control!(pre, 1, "u", ["u"])
                Building.variable!(pre, 2, "v", ["v1", "v2"])
                dyn!(r, t, x, u, v) = r .= 0
                Building.dynamics!(pre, dyn!)
                Building.objective!(
                    pre, :min; mayer=(x0, xf, v) -> 0.0, lagrange=(t, x, u, v) -> 0.0
                )
                Building.time_dependence!(pre; autonomous=false)

                model = Building.build(pre)

                io = IOBuffer()
                show(io, MIME"text/plain"(), model)
                s = String(take!(io))

                # "v" appears in the "where" clause for variable-dependent problems
                Test.@test occursin("v", s)
                Test.@test occursin("optimal control problem is of the form:", s)
                Test.@test occursin("non autonomous", s)
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_print() = TestPrint.test_print()
