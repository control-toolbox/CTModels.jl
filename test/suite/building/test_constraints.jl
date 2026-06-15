module TestOCPConstraints

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Building: Building
import CTModels.Models: Models

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Module-level stubs for CompositeConstraint tests (world-age safe)
_path_stub1!(r, _, x, u, _) = (r[1] = x[1] + u[1])
_path_stub2!(r, t, x, _, _) = (r[1]=x[2]; r[2]=t)
_boundary_stub1!(r, x0, _, _) = (r[1] = x0[1])
_boundary_stub2!(r, _, xf, _) = (r[1] = xf[1])

# Top-level helper (module-level to avoid world-age issues)
"""
    _make_min_premodel(; state_dim, control_dim=1, variable_dim=0)

Build a minimal `PreModel` with the given dimensions, ready to receive constraints.
Used by storage / retrieval tests.
"""
function _make_min_premodel(; state_dim::Int, control_dim::Int=1, variable_dim::Int=0)
    ocp = Building.PreModel()
    Building.time!(ocp; t0=0.0, tf=1.0)
    Building.state!(ocp, state_dim)
    Building.control!(ocp, control_dim)
    if variable_dim > 0
        Building.variable!(ocp, variable_dim)
    end
    _dyn!(r, t, x, u, v) = (r .= zero(x))
    Building.dynamics!(ocp, _dyn!)
    Building.objective!(ocp, :min; mayer=(x0, xf, v) -> 0.0)
    Building.definition!(ocp, quote end)
    Building.time_dependence!(ocp; autonomous=false)
    return ocp
end

"""
    test_constraints()

Test constraint handling in OCP models.

# Note
Some tests in this file intentionally generate warnings to verify that the system
correctly warns users about multiple bound declarations on the same component.
If you see warnings like "Multiple bound declarations for component X", they are
expected and part of the test assertions.
"""
function test_constraints()
    Test.@testset "Constraints Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Constraint Handling
        # ====================================================================
        ∅ = Vector{Float64}()

        # From PreModel
        ocp_set = Building.PreModel()
        Building.time!(ocp_set; t0=0.0, tf=10.0)
        Building.state!(ocp_set, 2)
        Building.control!(ocp_set, 1)
        Building.variable!(ocp_set, 1)

        # state not set
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.control!(ocp, 1)
        Building.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError Building.constraint!(ocp, :dummy)

        # control not set
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.state!(ocp, 1)
        Building.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError Building.constraint!(ocp, :dummy)

        # times not set
        ocp = Building.PreModel()
        Building.state!(ocp, 1)
        Building.control!(ocp, 1)
        Building.variable!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError Building.constraint!(ocp, :dummy)

        # variable not set and try to add a :variable constraint
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Building.state!(ocp, 1)
        Building.control!(ocp, 1)
        Test.@test_throws Exceptions.PreconditionError Building.constraint!(ocp, :variable)

        # lb and ub cannot be both nothing
        Test.@test_throws Exceptions.PreconditionError Building.constraint!(ocp_set, :state)

        # twice the same label for two constraints
        Building.constraint!(ocp_set, :state; lb=[0, 1], label=:cons)
        Test.@test_throws Exceptions.PreconditionError Building.constraint!(
            ocp_set, :control, lb=[0, 1], label=:cons
        )

        # lb and ub must have the same length
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :state, lb=[0, 1], ub=[0, 1, 2]
        )

        # x(1) == [0, 0, 1] must raise an error if x is of dimension 2
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :boundary, lb=[0, 0, 1], ub=[0, 1, 2], codim_f=2
        )

        # if no range nor function is provided, lb and ub must have the right length:
        # depending on state, control, or variable
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :state, lb=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :control, lb=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :variable, lb=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :state, ub=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :control, ub=[0, 1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :variable, ub=[0, 1, 2]
        )

        # if no range nor function is provided, the only possible constraints are
        # :state, :control, and :variable
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :dummy, lb=[0], ub=[1]
        )

        # if a range is provided, lb and ub must have the same length as the range
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :state, rg=1:2, lb=[0], ub=[1]
        )

        # if a range is provided, it must be consistent with the dimensions of the model
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :state, rg=3:4, lb=[0, 1], ub=[1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :control, rg=2:3, lb=[0, 1], ub=[1, 2]
        )
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :variable, rg=2:3, lb=[0, 1], ub=[1, 2]
        )

        # if a range is provided, the only possible constraints are :state, :control, and :variable
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :dummy, rg=1:2, lb=[0, 1], ub=[1, 2]
        )

        # if a function is provided, the only possible constraints are :path, :boundary and :variable
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :dummy, f=(x, y) -> x + y, lb=[0, 1], ub=[1, 2]
        )

        # we cannot provide a function and a range
        Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
            ocp_set, :variable, f=(x, y) -> x + y, rg=1:2, lb=[0, 1], ub=[1, 2]
        )

        # test with :path constraint
        f_path(r, t, x, u, v) = r .= x .+ u .+ v .+ t
        Building.constraint!(ocp_set, :path; f=f_path, lb=[0, 1], ub=[1, 2], label=:path)
        Test.@test ocp_set.constraints[:path] == (:path, f_path, [0, 1], [1, 2])

        # test with :boundary constraint
        f_boundary(r, x0, xf, v) = r .= x0 .+ v .* (xf .- x0)
        Building.constraint!(
            ocp_set, :boundary; f=f_boundary, lb=[0, 1], ub=[1, 2], label=:boundary
        )
        Test.@test ocp_set.constraints[:boundary] == (:boundary, f_boundary, [0, 1], [1, 2])

        # test with :state constraint and range
        Building.constraint!(ocp_set, :state; rg=1:2, lb=[0, 1], ub=[1, 2], label=:state_rg)
        Test.@test ocp_set.constraints[:state_rg] == (:state, 1:2, [0, 1], [1, 2])

        # test with :control constraint and range
        Building.constraint!(ocp_set, :control; rg=1:1, lb=[1], ub=[1], label=:control_rg)
        Test.@test ocp_set.constraints[:control_rg] == (:control, 1:1, [1], [1])

        # test with :variable constraint and range
        Building.constraint!(ocp_set, :variable; rg=1:1, lb=[1], ub=[1], label=:variable_rg)
        Test.@test ocp_set.constraints[:variable_rg] == (:variable, 1:1, [1], [1])

        # -----------------------------------------------------------------------
        # Test duplicate constraint warning (Issue #105)
        # When multiple constraints are declared on the same component index,
        # a warning should be emitted during model build. All declarations are
        # kept; the effective bound at solver level is the intersection.
        # Applies to: state, control, and variable constraints.
        #
        # NOTE: The warnings displayed during these tests are INTENTIONAL and EXPECTED.
        # They verify that the system correctly warns users about multiple bound
        # declarations. These warnings are part of the test assertions using
        # Test.@test_warn.
        # -----------------------------------------------------------------------
        Test.@testset "duplicate constraint warning" begin
            # --- State constraints ---
            Test.@testset "state" begin
                ocp_dup = Building.PreModel()
                Building.time!(ocp_dup; t0=0.0, tf=1.0)
                Building.state!(ocp_dup, 2)
                Building.control!(ocp_dup, 1)
                dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
                Building.dynamics!(ocp_dup, dynamics!)
                Building.objective!(ocp_dup, :min; mayer=(x0, xf, v) -> xf[1])
                Building.definition!(ocp_dup, quote end)
                Building.time_dependence!(ocp_dup; autonomous=false)

                # Add constraints on state component 1
                Building.constraint!(ocp_dup, :state; rg=1:1, lb=[0.0], ub=[1.0], label=:s1)
                Building.constraint!(ocp_dup, :state; rg=1:1, lb=[0.5], ub=[1.5], label=:s2)

                Test.@test_warn "Multiple bound declarations for state component 1" Building.build(
                    ocp_dup
                )
            end

            # --- Control constraints ---
            Test.@testset "control" begin
                ocp_dup = Building.PreModel()
                Building.time!(ocp_dup; t0=0.0, tf=1.0)
                Building.state!(ocp_dup, 2)
                Building.control!(ocp_dup, 2)  # 2 controls to allow duplicate on component 1
                dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
                Building.dynamics!(ocp_dup, dynamics!)
                Building.objective!(ocp_dup, :min; mayer=(x0, xf, v) -> xf[1])
                Building.definition!(ocp_dup, quote end)
                Building.time_dependence!(ocp_dup; autonomous=false)

                # Add constraints on control component 1
                Building.constraint!(
                    ocp_dup, :control; rg=1:1, lb=[0.0], ub=[1.0], label=:c1
                )
                Building.constraint!(
                    ocp_dup, :control; rg=1:1, lb=[0.5], ub=[1.5], label=:c2
                )

                Test.@test_warn "Multiple bound declarations for control component 1" Building.build(
                    ocp_dup
                )
            end

            # --- Variable constraints ---
            Test.@testset "variable" begin
                ocp_dup = Building.PreModel()
                Building.time!(ocp_dup; t0=0.0, tf=1.0)
                Building.state!(ocp_dup, 2)
                Building.control!(ocp_dup, 1)
                Building.variable!(ocp_dup, 2)  # 2 variables to allow duplicate on component 1
                dynamics!(r, t, x, u, v) = r .= [x[1], u[1]]
                Building.dynamics!(ocp_dup, dynamics!)
                Building.objective!(ocp_dup, :min; mayer=(x0, xf, v) -> xf[1])
                Building.definition!(ocp_dup, quote end)
                Building.time_dependence!(ocp_dup; autonomous=false)

                # Add constraints on variable component 1
                Building.constraint!(
                    ocp_dup, :variable; rg=1:1, lb=[0.0], ub=[1.0], label=:v1
                )
                Building.constraint!(
                    ocp_dup, :variable; rg=1:1, lb=[0.5], ub=[1.5], label=:v2
                )

                Test.@test_warn "Multiple bound declarations for variable component 1" Building.build(
                    ocp_dup
                )
            end
        end

        # ====================================================================
        # UNIT TESTS - Bound declarations storage in ConstraintsModel
        # Verifies the contract of `build(constraints)`: how declared bounds
        # are stored in the `state_constraints_box` / `control_constraints_box`
        # / `variable_constraints_box` tuples of the resulting Model.
        # ====================================================================

        Test.@testset "bound declarations storage" begin
            Test.@testset "single full-range declaration preserves order" begin
                ocp = _make_min_premodel(; state_dim=3)
                Building.constraint!(
                    ocp, :state; rg=1:3, lb=[0.0, 1.0, 2.0], ub=[1.0, 2.0, 3.0], label=:s
                )
                m = Building.build(ocp)
                cs = Components.state_constraints_box(m)
                Test.@test cs[1] == [0.0, 1.0, 2.0]
                Test.@test cs[2] == [1, 2, 3]
                Test.@test cs[3] == [1.0, 2.0, 3.0]
                Test.@test cs[4] == [:s, :s, :s]
                Test.@test cs[5] == [[:s], [:s], [:s]]
                Test.@test Components.dim_state_constraints_box(m) == 3
            end

            Test.@testset "partial range not starting at 1" begin
                ocp = _make_min_premodel(; state_dim=3)
                Building.constraint!(
                    ocp, :state; rg=2:3, lb=[0.0, 1.0], ub=[1.0, 2.0], label=:s
                )
                m = Building.build(ocp)
                cs = Components.state_constraints_box(m)
                Test.@test cs[1] == [0.0, 1.0]
                Test.@test cs[2] == [2, 3]
                Test.@test cs[3] == [1.0, 2.0]
                Test.@test cs[5] == [[:s], [:s]]
                Test.@test Components.dim_state_constraints_box(m) == 2
            end

            Test.@testset "duplicate: intersection applied, per-component uniqueness" begin
                ocp = _make_min_premodel(; state_dim=2)
                Building.constraint!(ocp, :state; rg=1:1, lb=[0.0], ub=[2.0], label=:s1)
                Building.constraint!(ocp, :state; rg=1:1, lb=[0.5], ub=[1.5], label=:s2)
                # warning emitted once at build; storage holds one entry per component
                m = (Test.@test_logs (:warn, r"Multiple bound declarations") Building.build(
                    ocp
                ))
                cs = Components.state_constraints_box(m)
                # effective (intersected) bounds
                Test.@test cs[1] == [0.5]
                Test.@test cs[2] == [1]
                Test.@test cs[3] == [1.5]
                # first-declared label kept in cs[4]; all labels kept in cs[5]
                Test.@test cs[4] == [:s1]
                Test.@test cs[5] == [[:s1, :s2]]
                # dim counts unique components, not declarations
                Test.@test Components.dim_state_constraints_box(m) == 1
            end

            Test.@testset "overlapping ranges" begin
                ocp = _make_min_premodel(; state_dim=3)
                Building.constraint!(
                    ocp, :state; rg=1:2, lb=[0.0, 1.0], ub=[1.0, 2.0], label=:a
                )
                Building.constraint!(
                    ocp, :state; rg=2:3, lb=[0.5, 1.5], ub=[1.5, 2.5], label=:b
                )
                m = (Test.@test_logs (:warn, r"component 2") Building.build(ocp))
                cs = Components.state_constraints_box(m)
                # 3 unique components: 1 (from :a), 2 (intersected from :a,:b), 3 (from :b)
                Test.@test length(cs[1]) == 3
                Test.@test cs[2] == [1, 2, 3]
                Test.@test cs[1] == [0.0, 1.0, 1.5]  # max of lbs per component
                Test.@test cs[3] == [1.0, 1.5, 2.5]  # min of ubs per component
                Test.@test cs[4] == [:a, :a, :b]    # first label per component
                Test.@test cs[5] == [[:a], [:a, :b], [:b]]
                Test.@test Components.dim_state_constraints_box(m) == 3
            end
        end

        # ====================================================================
        # UNIT TESTS - constraint(model, label) retrieval
        # After duplicates are kept, `constraint(m, :label)` must still return
        # the originally declared bounds for each individual label.
        # ====================================================================

        Test.@testset "constraint(model, label) retrieval with duplicates" begin
            # After dedup+intersection, `constraint(m, :label)` returns the
            # **effective** (intersected) bounds, not the bounds as initially
            # declared for that specific label. Both :s1 and :s2 target
            # component 1, so both retrievals yield the same intersected bound.
            ocp = _make_min_premodel(; state_dim=2)
            Building.constraint!(ocp, :state; rg=1:1, lb=[0.0], ub=[2.0], label=:s1)
            Building.constraint!(ocp, :state; rg=1:1, lb=[0.5], ub=[1.5], label=:s2)
            m = (Test.@test_logs (:warn, r"Multiple bound declarations") Building.build(
                ocp
            ))

            c_s1 = Models.constraint(m, :s1)
            c_s2 = Models.constraint(m, :s2)
            Test.@test c_s1[1] === :state
            Test.@test c_s1[3] == 0.5  # effective lb = max(0.0, 0.5)
            Test.@test c_s1[4] == 1.5  # effective ub = min(2.0, 1.5)
            Test.@test c_s2[1] === :state
            Test.@test c_s2[3] == 0.5
            Test.@test c_s2[4] == 1.5
        end

        # NEW: lb ≤ ub validation tests
        Test.@testset "constraints! - Bounds validation" begin
            # lb > ub for state constraints
            Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
                ocp_set, :state, lb=[1.0, 2.0], ub=[0.5, 1.0], label=:invalid_state
            )

            # lb > ub for control constraints
            Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
                ocp_set, :control, lb=[2.0], ub=[1.0], label=:invalid_control
            )

            # lb > ub for variable constraints
            Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
                ocp_set, :variable, lb=[1.5], ub=[0.5], label=:invalid_variable
            )

            # lb > ub for boundary constraints
            f_boundary_invalid(r, x0, xf, v) = r .= x0 .+ v
            Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
                ocp_set,
                :boundary;
                f=f_boundary_invalid,
                lb=[1.0, 2.0],
                ub=[0.5, 1.0],
                label=:invalid_boundary,
            )

            # lb > ub for path constraints
            f_path_invalid(r, t, x, u, v) = r .= x .+ u .+ v
            Test.@test_throws Exceptions.IncorrectArgument Building.constraint!(
                ocp_set, :path; f=f_path_invalid, lb=[2.0], ub=[1.0], label=:invalid_path
            )

            # Valid bounds (lb ≤ ub)
            Test.@test_nowarn Building.constraint!(
                ocp_set, :state, lb=[0.0, 1.0], ub=[1.0, 2.0], label=:valid_state
            )
            Test.@test_nowarn Building.constraint!(
                ocp_set, :control, lb=[0.0], ub=[1.0], label=:valid_control
            )
            Test.@test_nowarn Building.constraint!(
                ocp_set, :variable, lb=[-1.0], ub=[1.0], label=:valid_variable
            )

            # Edge case: lb == ub (equality constraints)
            Test.@test_nowarn Building.constraint!(
                ocp_set, :state, lb=[0.5, 1.5], ub=[0.5, 1.5], label=:equality_state
            )
        end

        # ====================================================================
        # UNIT TESTS - CompositeConstraint callable struct
        # ====================================================================

        # Top-level stubs (module-level, world-age safe)
        # (defined at module top-level below)

        Test.@testset "CompositeConstraint{:path} — two functions" begin
            f = Building.CompositeConstraint{:path}(2, [1, 2], (_path_stub1!, _path_stub2!))
            val = zeros(3)
            f(val, 0.5, [3.0, 4.0], [7.0], nothing)
            Test.@test f isa Function
            Test.@test val[1] ≈ 3.0 + 7.0         # stub1: x[1] + u[1]
            Test.@test val[2:3] ≈ [4.0, 0.5]      # stub2: [x[2], t]
            Test.@test contains(repr(f), "CompositeConstraint")
            Test.@test contains(repr(f), ":path")
            Test.@test contains(repr(MIME("text/plain"), f), "CompositeConstraint")
        end

        Test.@testset "CompositeConstraint{:boundary} — two functions" begin
            f = Building.CompositeConstraint{:boundary}(
                2, [1, 1], (_boundary_stub1!, _boundary_stub2!)
            )
            val = zeros(2)
            f(val, [2.0], [5.0], nothing)
            Test.@test f isa Function
            Test.@test val[1] ≈ 2.0   # stub1: x0[1]
            Test.@test val[2] ≈ 5.0   # stub2: xf[1]
            Test.@test contains(repr(f), "CompositeConstraint")
            Test.@test contains(repr(f), ":boundary")
            Test.@test contains(repr(MIME("text/plain"), f), "CompositeConstraint")
        end

        Test.@testset "CompositeConstraint{:boundary} — concrete fields (no capture-by-ref bug)" begin
            dims_orig = [1, 1]
            f = Building.CompositeConstraint{:boundary}(
                2, dims_orig, (_boundary_stub1!, _boundary_stub2!)
            )
            dims_orig[1] = 99  # mutate the original after construction
            val = zeros(2)
            f(val, [2.0], [5.0], nothing)
            # If fields were captured by reference, dims_orig[1]=99 would corrupt the loop.
            # Correct behaviour: dims field is the value passed at construction time.
            Test.@test val[1] ≈ 2.0
            Test.@test val[2] ≈ 5.0
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_constraints() = TestOCPConstraints.test_constraints()
