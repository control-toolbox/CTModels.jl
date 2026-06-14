module TestBuildingDedup

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Building: Building

const VERBOSE    = isdefined(Main, :TestData) ? Main.TestData.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_dedup()
    Test.@testset "Building dedup / build(ConstraintsDictType)" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT - _dedup_box_constraints!  (direct tests)
        # ====================================================================

        Test.@testset "empty inds → aliases cleared" begin
            inds   = Int[]
            lbs    = Float64[]
            ubs    = Float64[]
            labels = Symbol[]
            aliases = Vector{Symbol}[[  :existing]]  # non-empty going in

            Building._dedup_box_constraints!(inds, lbs, ubs, labels, aliases, "state")

            Test.@test isempty(inds)
            Test.@test isempty(aliases)
        end

        Test.@testset "single declaration → no warning, no dedup" begin
            inds   = [2]
            lbs    = [0.0]
            ubs    = [1.0]
            labels = [:a]
            aliases = Vector{Symbol}[]

            Test.@test_nowarn Building._dedup_box_constraints!(
                inds, lbs, ubs, labels, aliases, "state"
            )

            Test.@test inds == [2]
            Test.@test lbs == [0.0]
            Test.@test ubs == [1.0]
            Test.@test labels == [:a]
            Test.@test aliases == [[:a]]
        end

        Test.@testset "duplicates → intersection bounds + @warn" begin
            # Component 1 declared by :a (lb=0,ub=2) and :b (lb=1,ub=3)
            # Effective: lb=max(0,1)=1, ub=min(2,3)=2
            inds   = [1, 1]
            lbs    = [0.0, 1.0]
            ubs    = [2.0, 3.0]
            labels = [:a, :b]
            aliases = Vector{Symbol}[]

            Test.@test_logs (:warn, r"Multiple bound declarations for state component 1") begin
                Building._dedup_box_constraints!(inds, lbs, ubs, labels, aliases, "state")
            end

            Test.@test inds == [1]
            Test.@test lbs ≈ [1.0]
            Test.@test ubs ≈ [2.0]
            Test.@test labels == [:a]
            Test.@test aliases == [[:a, :b]]
        end

        Test.@testset "empty intersection → IncorrectArgument" begin
            # Component 1: lb=5, ub=3 after intersection → infeasible
            inds   = [1, 1]
            lbs    = [5.0, 0.0]
            ubs    = [10.0, 3.0]
            labels = [:x, :y]
            aliases = Vector{Symbol}[]

            Test.@test_throws Exceptions.IncorrectArgument begin
                redirect_stderr(devnull) do
                    Building._dedup_box_constraints!(inds, lbs, ubs, labels, aliases, "state")
                end
            end
        end

        Test.@testset "sorting by component index" begin
            # Declare component 3 first, then 1 → result must be sorted [1, 3]
            inds   = [3, 1]
            lbs    = [0.0, -1.0]
            ubs    = [4.0,  2.0]
            labels = [:c3, :c1]
            aliases = Vector{Symbol}[]

            Test.@test_nowarn Building._dedup_box_constraints!(
                inds, lbs, ubs, labels, aliases, "state"
            )

            Test.@test inds == [1, 3]
            Test.@test lbs ≈ [-1.0, 0.0]
            Test.@test ubs ≈ [2.0, 4.0]
        end

        Test.@testset "multiple components, one duplicated" begin
            # Component 1: declared once by :a
            # Component 2: declared by :b (lb=0,ub=1) and :c (lb=0.5,ub=2) → intersection lb=0.5,ub=1
            inds   = [1, 2, 2]
            lbs    = [-1.0, 0.0, 0.5]
            ubs    = [ 1.0, 1.0, 2.0]
            labels = [:a, :b, :c]
            aliases = Vector{Symbol}[]

            Test.@test_logs (:warn, r"Multiple bound declarations for state component 2") begin
                Building._dedup_box_constraints!(inds, lbs, ubs, labels, aliases, "state")
            end

            Test.@test inds == [1, 2]
            Test.@test lbs ≈ [-1.0, 0.5]
            Test.@test ubs ≈ [ 1.0, 1.0]
            Test.@test aliases[1] == [:a]
            Test.@test aliases[2] == [:b, :c]
        end

        # ====================================================================
        # ERROR - build(ConstraintsDictType) with unknown constraint type
        # ====================================================================

        Test.@testset "build(ConstraintsDictType) unknown type → IncorrectArgument" begin
            f! = (r, _, _, _, _) -> (r .= zero(r))
            constraints = Components.ConstraintsDictType(
                :bad => (:unknown_type, f!, [0.0], [1.0])
            )

            Test.@test_throws Exceptions.IncorrectArgument Building.build(constraints)
        end

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_dedup() = TestBuildingDedup.test_dedup()
