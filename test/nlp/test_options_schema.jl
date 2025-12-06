# Unit tests for generic options schema utilities (OptionSpec and helpers).

# Dummy tool types for exercising the generic API
struct CM_DummyToolNoSpecs <: CTModels.AbstractOCPTool end

struct CM_DummyToolWithSpecs <: CTModels.AbstractOCPTool
    options_values
    options_sources
end

CTModels._option_specs(::Type{CM_DummyToolNoSpecs}) = missing

function CTModels._option_specs(::Type{CM_DummyToolWithSpecs})
    (
        max_iter=CTModels.OptionSpec(;
            type=Int, default=100, description="Max iterations"
        ),
        tol=CTModels.OptionSpec(; type=Float64, default=1e-6, description="Tolerance"),
        verbose=CTModels.OptionSpec(; type=Bool, default=missing, description=missing),
    )
end

function test_options_schema()

    # ========================================================================
    # METADATA ACCESSORS (options_keys, is_an_option_key, option_* helpers)
    # ========================================================================

    Test.@testset "metadata accessors" verbose=VERBOSE showtiming=SHOWTIMING begin
        # No specs: options_keys / is_an_option_key / option_* should return missing
        Test.@test CTModels.options_keys(CM_DummyToolNoSpecs) === missing
        Test.@test CTModels.is_an_option_key(:foo, CM_DummyToolNoSpecs) === missing
        Test.@test CTModels.option_type(:foo, CM_DummyToolNoSpecs) === missing
        Test.@test CTModels.option_description(:foo, CM_DummyToolNoSpecs) === missing
        Test.@test CTModels.option_default(:foo, CM_DummyToolNoSpecs) === missing
        Test.@test CTModels.default_options(CM_DummyToolNoSpecs) == NamedTuple()

        # With specs
        keys = CTModels.options_keys(CM_DummyToolWithSpecs)
        Test.@test Set(keys) == Set((:max_iter, :tol, :verbose))

        Test.@test CTModels.is_an_option_key(:max_iter, CM_DummyToolWithSpecs)
        Test.@test !CTModels.is_an_option_key(:foo, CM_DummyToolWithSpecs)

        Test.@test CTModels.option_type(:max_iter, CM_DummyToolWithSpecs) == Int
        Test.@test CTModels.option_type(:tol, CM_DummyToolWithSpecs) == Float64
        Test.@test CTModels.option_type(:foo, CM_DummyToolWithSpecs) === missing

        Test.@test CTModels.option_description(:max_iter, CM_DummyToolWithSpecs) isa
            AbstractString
        Test.@test CTModels.option_description(:verbose, CM_DummyToolWithSpecs) === missing

        Test.@test CTModels.option_default(:max_iter, CM_DummyToolWithSpecs) == 100
        Test.@test CTModels.option_default(:tol, CM_DummyToolWithSpecs) == 1e-6
        Test.@test CTModels.option_default(:verbose, CM_DummyToolWithSpecs) === missing

        # default_options should include only non-missing defaults
        defs = CTModels.default_options(CM_DummyToolWithSpecs)
        Test.@test Set(propertynames(defs)) == Set((:max_iter, :tol))
        Test.@test defs.max_iter == 100
        Test.@test defs.tol == 1e-6

        # Instance-based accessors should behave like the type-based ones
        vals_inst, srcs_inst = CTModels._build_ocp_tool_options(CM_DummyToolWithSpecs)
        tool_inst = CM_DummyToolWithSpecs(vals_inst, srcs_inst)

        keys_from_type = CTModels.options_keys(CM_DummyToolWithSpecs)
        keys_from_inst = CTModels.options_keys(tool_inst)
        Test.@test Set(keys_from_inst) == Set(keys_from_type)

        defs_from_type = CTModels.default_options(CM_DummyToolWithSpecs)
        defs_from_inst = CTModels.default_options(tool_inst)
        Test.@test defs_from_inst == defs_from_type

        Test.@test CTModels.option_default(:max_iter, tool_inst) == 100
        Test.@test CTModels.option_default(:tol, tool_inst) == 1e-6
        Test.@test CTModels.option_default(:verbose, tool_inst) === missing
    end

    # ========================================================================
    # _filter_options
    # ========================================================================

    Test.@testset "_filter_options" verbose=VERBOSE showtiming=SHOWTIMING begin
        nt = (a=1, b=2, c=3)
        filtered = CTModels._filter_options(nt, (:b,))
        Test.@test Set(propertynames(filtered)) == Set((:a, :c))
        Test.@test filtered.a == 1
        Test.@test filtered.c == 3
    end

    # ========================================================================
    # _string_distance and _suggest_option_keys
    # ========================================================================

    Test.@testset "suggestions" verbose=VERBOSE showtiming=SHOWTIMING begin
        # A simple sanity check on the distance function
        d_exact = CTModels._string_distance("max_iter", "max_iter")
        d_close = CTModels._string_distance("max_iter", "mx_iter")
        d_far = CTModels._string_distance("max_iter", "tol")
        Test.@test d_exact == 0
        Test.@test d_close < d_far

        # Suggestions should prioritize the closest known key
        sugg = CTModels._suggest_option_keys(:mx_iter, CM_DummyToolWithSpecs)
        Test.@test length(sugg) >= 1
        Test.@test sugg[1] == :max_iter
    end

    # ========================================================================
    # get_option_value / get_option_source / get_option_default
    # ========================================================================

    Test.@testset "get_option_*" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Build values/sources using the generic constructor
        vals, srcs = CTModels._build_ocp_tool_options(CM_DummyToolWithSpecs; tol=1e-4)
        tool = CM_DummyToolWithSpecs(vals, srcs)

        # Known options with and without user override
        Test.@test CTModels.get_option_value(tool, :max_iter) == 100
        Test.@test CTModels.get_option_source(tool, :max_iter) == :ct_default
        Test.@test CTModels.get_option_default(tool, :max_iter) == 100

        Test.@test CTModels.get_option_value(tool, :tol) == 1e-4
        Test.@test CTModels.get_option_source(tool, :tol) == :user
        Test.@test CTModels.get_option_default(tool, :tol) == 1e-6

        # Known option declared but with no default and not set by the user
        err_no_val = nothing
        try
            CTModels.get_option_value(tool, :verbose)
        catch e
            err_no_val = e
        end
        Test.@test err_no_val isa CTBase.IncorrectArgument
        buf_no_val = sprint(showerror, err_no_val)
        # Basic sanity: error message should be non-empty
        Test.@test !isempty(buf_no_val)

        # Unknown option key should trigger an IncorrectArgument with suggestions
        err_unknown = nothing
        try
            CTModels.get_option_value(tool, :mx_iter)
        catch e
            err_unknown = e
        end
        Test.@test err_unknown isa CTBase.IncorrectArgument
        buf_unknown = sprint(showerror, err_unknown)
        Test.@test occursin("Unknown option mx_iter", buf_unknown)
        Test.@test occursin("max_iter", buf_unknown)
        Test.@test occursin("show_options(CM_DummyToolWithSpecs)", buf_unknown)
    end

    # ========================================================================
    # _show_options
    # ========================================================================

    Test.@testset "_show_options" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Just ensure that calling _show_options on both dummy tools does not throw,
        # while silencing the printed output.
        redirect_stdout(devnull) do
            CTModels.show_options(CM_DummyToolNoSpecs)
            CTModels.show_options(CM_DummyToolWithSpecs)
        end
        Test.@test true
    end

    # ========================================================================
    # _validate_option_kwargs
    # ========================================================================

    Test.@testset "_validate_option_kwargs" verbose=VERBOSE showtiming=SHOWTIMING begin
        # No specs: nothing should be validated or rejected
        CTModels._validate_option_kwargs((foo=1,), CM_DummyToolNoSpecs; strict_keys=false)

        # Known keys with correct types
        CTModels._validate_option_kwargs(
            (max_iter=200, tol=1e-5), CM_DummyToolWithSpecs; strict_keys=false
        )

        # Unknown key with strict_keys = false should be accepted
        CTModels._validate_option_kwargs(
            (foo=1,), CM_DummyToolWithSpecs; strict_keys=false
        )

        # Unknown key with strict_keys = true should error with suggestions
        err_unknown = nothing
        try
            CTModels._validate_option_kwargs(
                (mx_iter=10,), CM_DummyToolWithSpecs; strict_keys=true
            )
        catch e
            err_unknown = e
        end
        Test.@test err_unknown isa CTBase.IncorrectArgument
        buf = sprint(showerror, err_unknown)
        Test.@test occursin("Unknown option mx_iter", buf)
        Test.@test occursin("max_iter", buf)
        Test.@test occursin("show_options(CM_DummyToolWithSpecs)", buf)

        # Wrong type for a known option should error
        err_type = nothing
        try
            CTModels._validate_option_kwargs(
                (tol="1e-6",), CM_DummyToolWithSpecs; strict_keys=false
            )
        catch e
            err_type = e
        end
        Test.@test err_type isa CTBase.IncorrectArgument
        buf_type = sprint(showerror, err_type)
        Test.@test occursin("Invalid type for option tol", buf_type)
    end

    # ========================================================================
    # _build_ocp_tool_options
    # ========================================================================

    Test.@testset "_build_ocp_tool_options" verbose=VERBOSE showtiming=SHOWTIMING begin
        # With specs: defaults merged with user overrides and provenance tracked
        vals, srcs = CTModels._build_ocp_tool_options(CM_DummyToolWithSpecs; tol=1e-4)
        Test.@test vals.max_iter == 100
        Test.@test vals.tol == 1e-4
        Test.@test srcs.max_iter == :ct_default
        Test.@test srcs.tol == :user

        # Without specs: user kwargs should pass through unchanged and be marked as :user
        vals2, srcs2 = CTModels._build_ocp_tool_options(CM_DummyToolNoSpecs; foo=1, bar=2)
        Test.@test vals2 == (foo=1, bar=2)
        Test.@test srcs2 == (foo=:user, bar=:user)
    end
end