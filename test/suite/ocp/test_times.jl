module TestOCPTimes

import Test
import CTBase.Exceptions
import CTModels

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
        # UNIT TESTS - Abstract Types
        # ====================================================================
        
        Test.@testset "Abstract Types" begin
            # Pure unit tests for times functionality
        end
        
        # ====================================================================
        # UNIT TESTS - Time Models
        # ====================================================================

        #
        Test.@test isconcretetype(CTModels.FixedTimeModel{Float64})
        Test.@test isconcretetype(CTModels.FreeTimeModel)

        # FixedTimeModel
        time = CTModels.FixedTimeModel(1.0, "s")
        Test.@test CTModels.time(time) == 1.0
        Test.@test CTModels.name(time) == "s"

        # FreeTimeModel
        time = CTModels.FreeTimeModel(1, "s")
        Test.@test CTModels.index(time) == 1
        Test.@test CTModels.name(time) == "s"
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time(time, Float64[])

        # some checks
        ocp = CTModels.PreModel()
        Test.@test isnothing(ocp.times)
        Test.@test !CTModels.OCP.__is_times_set(ocp)
        CTModels.time!(ocp; t0=0.0, tf=10.0, time_name="s")
        Test.@test CTModels.OCP.__is_times_set(ocp)
        Test.@test CTModels.time_name(ocp.times) == "s"

        # time!
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0) # t0, tf fixed
        Test.@test CTModels.initial_time(ocp.times) == 0.0
        Test.@test CTModels.final_time(ocp.times) == 10.0

        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0, time_name="s") # t0, tf fixed
        Test.@test CTModels.time_name(ocp.times) == "s"

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 1)
        CTModels.time!(ocp; ind0=1, tf=10.0) # t0 free, tf fixed, scalar variable
        Test.@test CTModels.initial_time(ocp.times, [0.0]) == 0.0

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2)
        CTModels.time!(ocp; ind0=2, tf=10.0) # t0 free, tf fixed, vector variable
        Test.@test CTModels.initial_time(ocp.times, [0.0, 1.0]) == 1.0

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 1)
        CTModels.time!(ocp; t0=0.0, indf=1) # t0 fixed, tf free, scalar variable
        Test.@test CTModels.final_time(ocp.times, [10.0]) == 10.0

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2)
        CTModels.time!(ocp; t0=0.0, indf=2) # t0 fixed, tf free, vector variable
        Test.@test CTModels.final_time(ocp.times, [0.0, 1.0]) == 1.0

        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2)
        CTModels.time!(ocp; ind0=1, indf=2) # t0 free, tf free, vector variable
        Test.@test CTModels.initial_time(ocp.times, [0.0, 1.0]) == 0.0
        Test.@test CTModels.final_time(ocp.times, [0.0, 1.0]) == 1.0

        # Exceptions

        # set twice
        ocp = CTModels.PreModel()
        CTModels.time!(ocp; t0=0.0, tf=10.0)
        Test.@test_throws Exceptions.PreconditionError CTModels.time!(ocp, t0=0.0, tf=10.0)

        # if ind0 or indf is provided, the variable must be set
        ocp = CTModels.PreModel()
        Test.@test_throws Exceptions.PreconditionError CTModels.time!(ocp, ind0=1, tf=10.0)
        Test.@test_throws Exceptions.PreconditionError CTModels.time!(ocp, t0=0.0, indf=1)
        Test.@test_throws Exceptions.PreconditionError CTModels.time!(ocp, ind0=1, indf=2)

        # index must satisfy 1 <= index <= q
        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, ind0=0, tf=10.0)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, ind0=3, tf=10.0)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, t0=0.0, indf=0)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, t0=0.0, indf=3)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, ind0=0, indf=3)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, ind0=3, indf=3)

        # consistency of function arguments
        ocp = CTModels.PreModel()
        CTModels.variable!(ocp, 2)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, t0=0.0, ind0=1)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, tf=10.0, indf=1)
        Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(
            ocp, t0=0.0, tf=10.0, indf=1
        )

        # NEW: Name validation tests
        Test.@testset "times: Name validation" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Empty time_name
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(
                ocp, t0=0, tf=1, time_name=""
            )

            # time_name conflicts with state
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 1, "x")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(
                ocp, t0=0, tf=1, time_name="x"
            )

            # time_name conflicts with control
            ocp = CTModels.PreModel()
            CTModels.control!(ocp, 1, "u")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(
                ocp, t0=0, tf=1, time_name="u"
            )

            # time_name conflicts with variable
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 1, "v")
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(
                ocp, t0=0, tf=1, time_name="v"
            )

            # time_name conflicts with state component
            ocp = CTModels.PreModel()
            CTModels.state!(ocp, 2, "x", ["x₁", "x₂"])
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(
                ocp, t0=0, tf=1, time_name="x₁"
            )
        end

        # NEW: Temporal validation tests
        Test.@testset "times: Temporal validation" verbose = VERBOSE showtiming = SHOWTIMING begin
            # t0 > tf
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, t0=1.0, tf=0.0)

            # t0 = tf
            ocp = CTModels.PreModel()
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time!(ocp, t0=1.0, tf=1.0)

            # Valid: t0 < tf
            ocp = CTModels.PreModel()
            Test.@test_nowarn CTModels.time!(ocp, t0=0.0, tf=1.0)

            # No validation when times are free (cannot check at definition time)
            ocp = CTModels.PreModel()
            CTModels.variable!(ocp, 2)
            Test.@test_nowarn CTModels.time!(ocp, ind0=1, indf=2)  # Cannot validate at this point
        end

        Test.@testset "times: FreeTimeModel with FakeTimeVector" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            ft = CTModels.FreeTimeModel(2, "s")
            v_ok = FakeTimeVector([1.0, 3.0])
            Test.@test CTModels.time(ft, v_ok) == 3.0

            v_short = FakeTimeVector([1.0])
            Test.@test_throws Exceptions.IncorrectArgument CTModels.time(ft, v_short)
        end

        Test.@testset "times: TimesModel names and flags" verbose = VERBOSE showtiming =
            SHOWTIMING begin
            t0 = CTModels.FixedTimeModel(0.0, "t0")
            tf = CTModels.FixedTimeModel(1.0, "tf")
            times = CTModels.TimesModel(t0, tf, "t")

            Test.@test CTModels.time_name(times) == "t"
            Test.@test CTModels.initial_time_name(times) == "t0"
            Test.@test CTModels.final_time_name(times) == "tf"

            Test.@test CTModels.has_fixed_initial_time(times)
            Test.@test !CTModels.has_free_initial_time(times)
            Test.@test CTModels.has_fixed_final_time(times)
            Test.@test !CTModels.has_free_final_time(times)

            tf2 = CTModels.FixedTimeModel(2.0, "tf2")
            t0_free = CTModels.FreeTimeModel(1, "v1")
            times_free = CTModels.TimesModel(t0_free, tf2, "t")
            v = [2.5]

            Test.@test CTModels.initial_time(times_free, v) == 2.5
            Test.@test !CTModels.has_fixed_initial_time(times_free)
            Test.@test CTModels.has_free_initial_time(times_free)
            Test.@test CTModels.has_fixed_final_time(times_free)
            Test.@test !CTModels.has_free_final_time(times_free)
        end

        # ============================================================================
        # Test naming consistency aliases (issue #169)
        # ============================================================================
        Test.@testset "times: is_* naming aliases" verbose = VERBOSE showtiming = SHOWTIMING begin
            # Fixed times
            t0 = CTModels.FixedTimeModel(0.0, "t0")
            tf = CTModels.FixedTimeModel(1.0, "tf")
            times_fixed = CTModels.TimesModel(t0, tf, "t")

            # Test that is_* aliases return the same values as has_* functions
            Test.@test CTModels.is_initial_time_fixed(times_fixed) ==
                CTModels.has_fixed_initial_time(times_fixed)
            Test.@test CTModels.is_initial_time_free(times_fixed) ==
                CTModels.has_free_initial_time(times_fixed)
            Test.@test CTModels.is_final_time_fixed(times_fixed) ==
                CTModels.has_fixed_final_time(times_fixed)
            Test.@test CTModels.is_final_time_free(times_fixed) ==
                CTModels.has_free_final_time(times_fixed)

            # Verify actual values for fixed times
            Test.@test CTModels.is_initial_time_fixed(times_fixed) == true
            Test.@test CTModels.is_initial_time_free(times_fixed) == false
            Test.@test CTModels.is_final_time_fixed(times_fixed) == true
            Test.@test CTModels.is_final_time_free(times_fixed) == false

            # Free initial time
            t0_free = CTModels.FreeTimeModel(1, "v1")
            times_free_t0 = CTModels.TimesModel(t0_free, tf, "t")

            Test.@test CTModels.is_initial_time_fixed(times_free_t0) == false
            Test.@test CTModels.is_initial_time_free(times_free_t0) == true
            Test.@test CTModels.is_final_time_fixed(times_free_t0) == true
            Test.@test CTModels.is_final_time_free(times_free_t0) == false

            # Free final time
            tf_free = CTModels.FreeTimeModel(2, "v2")
            times_free_tf = CTModels.TimesModel(t0, tf_free, "t")

            Test.@test CTModels.is_initial_time_fixed(times_free_tf) == true
            Test.@test CTModels.is_initial_time_free(times_free_tf) == false
            Test.@test CTModels.is_final_time_fixed(times_free_tf) == false
            Test.@test CTModels.is_final_time_free(times_free_tf) == true
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_times() = TestOCPTimes.test_times()
