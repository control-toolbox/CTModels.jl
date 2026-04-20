module TestOCPDefinition

using Test: Test
using CTModels: CTModels

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_definition()
    Test.@testset "Definition Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Type Hierarchy
        # ====================================================================

        Test.@testset "AbstractDefinition hierarchy" begin
            Test.@testset "EmptyDefinition construction" begin
                d = CTModels.EmptyDefinition()
                Test.@test d isa CTModels.EmptyDefinition
                Test.@test d isa CTModels.AbstractDefinition
            end

            Test.@testset "Definition construction and field access" begin
                expr = :(x = 1)
                d = CTModels.Definition(expr)
                Test.@test d isa CTModels.Definition
                Test.@test d isa CTModels.AbstractDefinition
                Test.@test d.expr === expr
            end
        end

        # ====================================================================
        # UNIT TESTS - PreModel default
        # ====================================================================

        Test.@testset "PreModel default definition is EmptyDefinition" begin
            pre = CTModels.PreModel()
            Test.@test pre.definition isa CTModels.EmptyDefinition
            Test.@test CTModels.OCP.__is_definition_empty(pre)
        end

        # ====================================================================
        # UNIT TESTS - Setters/Getters
        # ====================================================================

        Test.@testset "definition! auto-wraps Expr into Definition" begin
            pre = CTModels.PreModel()
            expr = :(x = 1)
            CTModels.definition!(pre, expr)
            Test.@test pre.definition isa CTModels.Definition
            Test.@test pre.definition.expr === expr
            Test.@test !CTModels.OCP.__is_definition_empty(pre)
        end

        Test.@testset "definition! accepts AbstractDefinition directly" begin
            pre = CTModels.PreModel()
            d = CTModels.Definition(:(y = 2))
            CTModels.definition!(pre, d)
            Test.@test pre.definition === d
            Test.@test !CTModels.OCP.__is_definition_empty(pre)
        end

        Test.@testset "definition! with EmptyDefinition leaves predicate false" begin
            pre = CTModels.PreModel()
            CTModels.definition!(pre, CTModels.EmptyDefinition())
            Test.@test pre.definition isa CTModels.EmptyDefinition
            Test.@test CTModels.OCP.__is_definition_empty(pre)
        end

        # ====================================================================
        # UNIT TESTS - expression getter
        # ====================================================================

        Test.@testset "expression on EmptyDefinition returns empty block Expr" begin
            e = CTModels.expression(CTModels.EmptyDefinition())
            Test.@test e isa Expr
            Test.@test e.head == :block
        end

        Test.@testset "expression on Definition returns wrapped expr" begin
            expr = :(x = 1)
            e = CTModels.expression(CTModels.Definition(expr))
            Test.@test e === expr
        end

        Test.@testset "expression on EmptyDefinition via field returns empty block" begin
            pre = CTModels.PreModel()
            e = CTModels.expression(pre.definition)
            Test.@test e isa Expr
            Test.@test e.head == :block
        end

        Test.@testset "expression on Definition via field returns expr" begin
            pre = CTModels.PreModel()
            expr = :(x = 1)
            CTModels.definition!(pre, expr)
            Test.@test CTModels.expression(pre.definition) === expr
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================

        Test.@testset "build without definition → Model holds EmptyDefinition" begin
            pre = CTModels.PreModel()
            CTModels.time!(pre; t0=0.0, tf=1.0)
            CTModels.state!(pre, 1)
            CTModels.control!(pre, 1)
            CTModels.variable!(pre, 0)
            dyn!(r, t, x, u, v) = r .= 0
            CTModels.dynamics!(pre, dyn!)
            CTModels.objective!(pre, :min; mayer=(x0, xf, v) -> 0.0, lagrange=(t, x, u, v) -> 0.0)
            CTModels.time_dependence!(pre; autonomous=false)

            model = CTModels.build(pre)
            Test.@test CTModels.definition(model) isa CTModels.EmptyDefinition
            Test.@test CTModels.OCP.__is_definition_empty(model.definition)
            Test.@test CTModels.expression(model) isa Expr
            Test.@test CTModels.expression(model).head == :block
        end

        Test.@testset "build with definition → Model holds Definition with correct expr" begin
            pre = CTModels.PreModel()
            CTModels.time!(pre; t0=0.0, tf=1.0)
            CTModels.state!(pre, 1)
            CTModels.control!(pre, 1)
            CTModels.variable!(pre, 0)
            dyn!(r, t, x, u, v) = r .= 0
            CTModels.dynamics!(pre, dyn!)
            CTModels.objective!(pre, :min; mayer=(x0, xf, v) -> 0.0, lagrange=(t, x, u, v) -> 0.0)
            expr = quote
                t ∈ [0, 1], time
                x ∈ R, state
                u ∈ R, control
                ẋ(t) == u(t)
                ∫(0.5u(t)^2) → min
            end
            CTModels.definition!(pre, expr)
            CTModels.time_dependence!(pre; autonomous=false)

            model = CTModels.build(pre)
            Test.@test CTModels.definition(model) isa CTModels.Definition
            Test.@test CTModels.definition(model).expr === expr
            Test.@test !CTModels.OCP.__is_definition_empty(model.definition)
            Test.@test CTModels.expression(model) === expr
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_definition() = TestOCPDefinition.test_definition()
