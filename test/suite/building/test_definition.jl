module TestOCPDefinition

import Test: Test
import CTModels.Components: Components
import CTModels.Models: Models
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_definition()
    Test.@testset "Definition Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Type Hierarchy
        # ====================================================================

        Test.@testset "AbstractDefinition hierarchy" begin
            Test.@testset "EmptyDefinition construction" begin
                d = Components.EmptyDefinition()
                Test.@test d isa Components.EmptyDefinition
                Test.@test d isa Components.AbstractDefinition
            end

            Test.@testset "Definition construction and field access" begin
                expr = :(x = 1)
                d = Components.Definition(expr)
                Test.@test d isa Components.Definition
                Test.@test d isa Components.AbstractDefinition
                Test.@test d.expr === expr
            end
        end

        # ====================================================================
        # UNIT TESTS - PreModel default
        # ====================================================================

        Test.@testset "PreModel default definition is EmptyDefinition" begin
            pre = Building.PreModel()
            Test.@test pre.definition isa Components.EmptyDefinition
            Test.@test Building.__is_definition_empty(pre)
        end

        # ====================================================================
        # UNIT TESTS - Setters/Getters
        # ====================================================================

        Test.@testset "definition! auto-wraps Expr into Definition" begin
            pre = Building.PreModel()
            expr = :(x = 1)
            Building.definition!(pre, expr)
            Test.@test pre.definition isa Components.Definition
            Test.@test pre.definition.expr === expr
            Test.@test !Building.__is_definition_empty(pre)
        end

        Test.@testset "definition! accepts AbstractDefinition directly" begin
            pre = Building.PreModel()
            d = Components.Definition(:(y = 2))
            Building.definition!(pre, d)
            Test.@test pre.definition === d
            Test.@test !Building.__is_definition_empty(pre)
        end

        Test.@testset "definition! with EmptyDefinition leaves predicate false" begin
            pre = Building.PreModel()
            Building.definition!(pre, Components.EmptyDefinition())
            Test.@test pre.definition isa Components.EmptyDefinition
            Test.@test Building.__is_definition_empty(pre)
        end

        # ====================================================================
        # UNIT TESTS - expression getter
        # ====================================================================

        Test.@testset "expression on EmptyDefinition returns empty block Expr" begin
            e = Components.expression(Components.EmptyDefinition())
            Test.@test e isa Expr
            Test.@test e.head == :block
        end

        Test.@testset "expression on Definition returns wrapped expr" begin
            expr = :(x = 1)
            e = Components.expression(Components.Definition(expr))
            Test.@test e === expr
        end

        Test.@testset "expression on EmptyDefinition via field returns empty block" begin
            pre = Building.PreModel()
            e = Components.expression(pre.definition)
            Test.@test e isa Expr
            Test.@test e.head == :block
        end

        Test.@testset "expression on Definition via field returns expr" begin
            pre = Building.PreModel()
            expr = :(x = 1)
            Building.definition!(pre, expr)
            Test.@test Components.expression(pre.definition) === expr
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================

        Test.@testset "build without definition → Model holds EmptyDefinition" begin
            pre = Building.PreModel()
            Building.time!(pre; t0=0.0, tf=1.0)
            Building.state!(pre, 1)
            Building.control!(pre, 1)
            Building.variable!(pre, 0)
            dyn!(r, t, x, u, v) = r .= 0
            Building.dynamics!(pre, dyn!)
            Building.objective!(
                pre, :min; mayer=(x0, xf, v) -> 0.0, lagrange=(t, x, u, v) -> 0.0
            )
            Building.time_dependence!(pre; autonomous=false)

            model = Building.build(pre)
            Test.@test Models.definition(model) isa Components.EmptyDefinition
            Test.@test Building.__is_definition_empty(model.definition)
            Test.@test Components.expression(model) isa Expr
            Test.@test Components.expression(model).head == :block
        end

        Test.@testset "build with definition → Model holds Definition with correct expr" begin
            pre = Building.PreModel()
            Building.time!(pre; t0=0.0, tf=1.0)
            Building.state!(pre, 1)
            Building.control!(pre, 1)
            Building.variable!(pre, 0)
            dyn!(r, t, x, u, v) = r .= 0
            Building.dynamics!(pre, dyn!)
            Building.objective!(
                pre, :min; mayer=(x0, xf, v) -> 0.0, lagrange=(t, x, u, v) -> 0.0
            )
            expr = quote
                t ∈ [0, 1], time
                x ∈ R, state
                u ∈ R, control
                ẋ(t) == u(t)
                ∫(0.5u(t)^2) → min
            end
            Building.definition!(pre, expr)
            Building.time_dependence!(pre; autonomous=false)

            model = Building.build(pre)
            Test.@test Models.definition(model) isa Components.Definition
            Test.@test Models.definition(model).expr === expr
            Test.@test !Building.__is_definition_empty(model.definition)
            Test.@test Components.expression(model) === expr
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_definition() = TestOCPDefinition.test_definition()
