module TestOCPTimes

import Test: Test
import CTBase.Exceptions: Exceptions
import CTModels.Components: Components
import CTModels.Building: Building

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

struct FakeTimeVector{T} <: AbstractVector{T}
    data::Vector{T}
end

Base.length(v::FakeTimeVector) = length(v.data)
Base.getindex(v::FakeTimeVector{T}, i::Int) where {T} = v.data[i]

function test_times()
    Test.@testset "Times Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Time Models
        # ====================================================================

        #
        Test.@test isconcretetype(Components.FixedTimeModel{Float64})
        Test.@test isconcretetype(Components.FreeTimeModel)

        # FixedTimeModel
        time = Components.FixedTimeModel(1.0, "s")
        Test.@test Base.time(time) == 1.0
        Test.@test Components.name(time) == "s"

        # FreeTimeModel
        time = Components.FreeTimeModel(1, "s")
        Test.@test Components.index(time) == 1
        Test.@test Components.name(time) == "s"
        Test.@test_throws Exceptions.IncorrectArgument Base.time(time, Float64[])

        # some checks
        ocp = Building.PreModel()
        Test.@test isnothing(ocp.times)
        Test.@test !Building.__is_times_set(ocp)
        Building.time!(ocp; t0=0.0, tf=10.0, time_name="s")
        Test.@test Building.__is_times_set(ocp)
        Test.@test Components.time_name(ocp.times) == "s"

        # time!
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0) # t0, tf fixed
        Test.@test Components.initial_time(ocp.times) == 0.0
        Test.@test Components.final_time(ocp.times) == 10.0

        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0, time_name="s") # t0, tf fixed
        Test.@test Components.time_name(ocp.times) == "s"

        ocp = Building.PreModel()
        Building.variable!(ocp, 1)
        Building.time!(ocp; ind0=1, tf=10.0) # t0 free, tf fixed, scalar variable
        Test.@test Components.initial_time(ocp.times, [0.0]) == 0.0

        ocp = Building.PreModel()
        Building.variable!(ocp, 2)
        Building.time!(ocp; ind0=2, tf=10.0) # t0 free, tf fixed, vector variable
        Test.@test Components.initial_time(ocp.times, [0.0, 1.0]) == 1.0

        ocp = Building.PreModel()
        Building.variable!(ocp, 1)
        Building.time!(ocp; t0=0.0, indf=1) # t0 fixed, tf free, scalar variable
        Test.@test Components.final_time(ocp.times, [10.0]) == 10.0

        ocp = Building.PreModel()
        Building.variable!(ocp, 2)
        Building.time!(ocp; t0=0.0, indf=2) # t0 fixed, tf free, vector variable
        Test.@test Components.final_time(ocp.times, [0.0, 1.0]) == 1.0

        ocp = Building.PreModel()
        Building.variable!(ocp, 2)
        Building.time!(ocp; ind0=1, indf=2) # t0 free, tf free, vector variable
        Test.@test Components.initial_time(ocp.times, [0.0, 1.0]) == 0.0
        Test.@test Components.final_time(ocp.times, [0.0, 1.0]) == 1.0

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        # set twice
        ocp = Building.PreModel()
        Building.time!(ocp; t0=0.0, tf=10.0)
        Test.@test_throws Exceptions.PreconditionError Building.time!(ocp, t0=0.0, tf=10.0)

        # if ind0 or indf is provided, the variable must be set
        ocp = Building.PreModel()
        Test.@test_throws Exceptions.PreconditionError Building.time!(ocp, ind0=1, tf=10.0)
        Test.@test_throws Exceptions.PreconditionError Building.time!(ocp, t0=0.0, indf=1)
        Test.@test_throws Exceptions.PreconditionError Building.time!(ocp, ind0=1, indf=2)

        # index must satisfy 1 <= index <= q
        ocp = Building.PreModel()
        Building.variable!(ocp, 2)
        Test.@test_throws Exceptions.IncorrectArgument Building.time!(ocp, ind0=0, tf=10.0)
        Test.@test_throws Exceptions.IncorrectArgument Building.time!(ocp, ind0=3, tf=10.0)
        Test.@test_throws Exceptions.IncorrectArgument Building.time!(ocp, t0=0.0, indf=0)
        Test.@test_throws Exceptions.IncorrectArgument Building.time!(ocp, t0=0.0, indf=3)
        Test.@test_throws Exceptions.IncorrectArgument Building.time!(ocp, ind0=0, indf=3)
        Test.@test_throws Exceptions.IncorrectArgument Building.time!(ocp, ind0=3, indf=3)

        # consistency of function arguments
        ocp = Building.PreModel()
        Building.variable!(ocp, 2)
        Test.@test_throws Exceptions.IncorrectArgument Building.time!(ocp, t0=0.0, ind0=1)
        Test.@test_throws Exceptions.IncorrectArgument Building.time!(ocp, tf=10.0, indf=1)
        Test.@test_throws Exceptions.IncorrectArgument Building.time!(
            ocp, t0=0.0, tf=10.0, indf=1
        )

        # NEW: Name validation tests
        Test.@testset "times: Name validation" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Empty time_name
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp, t0=0, tf=1, time_name=""
            )

            # time_name conflicts with state
            ocp = Building.PreModel()
            Building.state!(ocp, 1, "x")
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp, t0=0, tf=1, time_name="x"
            )

            # time_name conflicts with control
            ocp = Building.PreModel()
            Building.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp, t0=0, tf=1, time_name="u"
            )

            # time_name conflicts with variable
            ocp = Building.PreModel()
            Building.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp, t0=0, tf=1, time_name="v"
            )

            # time_name conflicts with state component
            ocp = Building.PreModel()
            Building.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp, t0=0, tf=1, time_name="x₁"
            )
        end

        # NEW: Temporal validation tests
        Test.@testset "times: Temporal validation" verbose = VERBOSE showtiming = SHOWTIMING begin
            # t0 > tf
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp, t0=1.0, tf=0.0
            )

            # t0 = tf
            ocp = Building.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument Building.time!(
                ocp, t0=1.0, tf=1.0
            )

            # Valid: t0 < tf
            ocp = Building.PreModel()
            Test.@test_nowarn Building.time!(ocp, t0=0.0, tf=1.0)

            # No validation when times are free (cannot check at definition time)
            ocp = Building.PreModel()
            Building.variable!(ocp, 2)
            Test.@test_nowarn Building.time!(ocp, ind0=1, indf=2)  # Cannot validate at this point
        end

        Test.@testset "times: FreeTimeModel with FakeTimeVector" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            ft = Components.FreeTimeModel(2, "s")
            v_ok = FakeTimeVector([1.0, 3.0])
            Test.@test Base.time(ft, v_ok) == 3.0

            v_short = FakeTimeVector([1.0])
            Test.@test_throws Exceptions.IncorrectArgument Base.time(ft, v_short)
        end

        Test.@testset "times: TimesModel names and flags" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            t0 = Components.FixedTimeModel(0.0, "t0")
            tf = Components.FixedTimeModel(1.0, "tf")
            times = Components.TimesModel(t0, tf, "t")

            Test.@test Components.time_name(times) == "t"
            Test.@test Components.initial_time_name(times) == "t0"
            Test.@test Components.final_time_name(times) == "tf"

            Test.@test Components.has_fixed_initial_time(times)
            Test.@test !Components.has_free_initial_time(times)
            Test.@test Components.has_fixed_final_time(times)
            Test.@test !Components.has_free_final_time(times)

            tf2 = Components.FixedTimeModel(2.0, "tf2")
            t0_free = Components.FreeTimeModel(1, "v1")
            times_free = Components.TimesModel(t0_free, tf2, "t")
            v = [2.5]

            Test.@test Components.initial_time(times_free, v) == 2.5
            Test.@test !Components.has_fixed_initial_time(times_free)
            Test.@test Components.has_free_initial_time(times_free)
            Test.@test Components.has_fixed_final_time(times_free)
            Test.@test !Components.has_free_final_time(times_free)
        end

        # ============================================================================
        # Test naming consistency aliases (issue #169)
        # ============================================================================
        Test.@testset "times: is_* naming aliases" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Fixed times
            t0 = Components.FixedTimeModel(0.0, "t0")
            tf = Components.FixedTimeModel(1.0, "tf")
            times_fixed = Components.TimesModel(t0, tf, "t")

            # Test that is_* aliases return the same values as has_* functions
            Test.@test Components.is_initial_time_fixed(times_fixed) ==
                Components.has_fixed_initial_time(times_fixed)
            Test.@test Components.is_initial_time_free(times_fixed) ==
                Components.has_free_initial_time(times_fixed)
            Test.@test Components.is_final_time_fixed(times_fixed) ==
                Components.has_fixed_final_time(times_fixed)
            Test.@test Components.is_final_time_free(times_fixed) ==
                Components.has_free_final_time(times_fixed)

            # Verify actual values for fixed times
            Test.@test Components.is_initial_time_fixed(times_fixed) == true
            Test.@test Components.is_initial_time_free(times_fixed) == false
            Test.@test Components.is_final_time_fixed(times_fixed) == true
            Test.@test Components.is_final_time_free(times_fixed) == false

            # Free initial time
            t0_free = Components.FreeTimeModel(1, "v1")
            times_free_t0 = Components.TimesModel(t0_free, tf, "t")

            Test.@test Components.is_initial_time_fixed(times_free_t0) == false
            Test.@test Components.is_initial_time_free(times_free_t0) == true
            Test.@test Components.is_final_time_fixed(times_free_t0) == true
            Test.@test Components.is_final_time_free(times_free_t0) == false

            # Free final time
            tf_free = Components.FreeTimeModel(2, "v2")
            times_free_tf = Components.TimesModel(t0, tf_free, "t")

            Test.@test Components.is_initial_time_fixed(times_free_tf) == true
            Test.@test Components.is_initial_time_free(times_free_tf) == false
            Test.@test Components.is_final_time_fixed(times_free_tf) == false
            Test.@test Components.is_final_time_free(times_free_tf) == true
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_times() = TestOCPTimes.test_times()
