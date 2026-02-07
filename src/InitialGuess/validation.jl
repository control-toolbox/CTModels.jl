# ------------------------------------------------------------------------------
# Initial Guess Validation
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Internal validation of an [`OptimalControlInitialGuess`](@ref).

Samples the state and control functions at a test time and verifies dimensions.
"""
function _validate_initial_guess(
    ocp::AbstractOptimalControlProblem, init::OptimalControlInitialGuess
)
    # Dimensions from the OCP
    xdim = state_dimension(ocp)
    udim = control_dimension(ocp)
    vdim = variable_dimension(ocp)

    # Sample evaluation time; for autonomous/non-autonomous problems
    # the shape of x(t), u(t) is independent of t.
    v0 = variable(init)
    tsample = if has_fixed_initial_time(ocp)
        initial_time(ocp)
    else
        initial_time(ocp, v0)
    end

    # State
    x0 = state(init)(tsample)
    if xdim == 1
        if !(x0 isa Real) && !(x0 isa AbstractVector && length(x0) == 1)
            throw(Exceptions.IncorrectArgument(
                "Initial state function returns invalid type for 1D state",
                got="$(typeof(x0))",
                expected="Real or length-1 Vector",
                suggestion="Ensure the state function returns a scalar or single-element vector",
                context="state function validation"
            ))
        end
    else
        if !(x0 isa AbstractVector) || length(x0) != xdim
            throw(Exceptions.IncorrectArgument(
                "Initial state function returns incompatible dimension",
                got="$(x0 isa AbstractVector ? "vector of length $(length(x0))" : "scalar")",
                expected="vector of length $xdim",
                suggestion="Ensure the state function returns a vector with $xdim elements",
                context="state function validation"
            ))
        end
    end

    # Control
    u0 = control(init)(tsample)
    if udim == 1
        if !(u0 isa Real) && !(u0 isa AbstractVector && length(u0) == 1)
            throw(Exceptions.IncorrectArgument(
                "Initial control function returns invalid type for 1D control",
                got="$(typeof(u0))",
                expected="Real or length-1 Vector",
                suggestion="Ensure the control function returns a scalar or single-element vector",
                context="control function validation"
            ))
        end
    else
        if !(u0 isa AbstractVector) || length(u0) != udim
            throw(Exceptions.IncorrectArgument(
                "Initial control function returns incompatible dimension",
                got="$(u0 isa AbstractVector ? "vector of length $(length(u0))" : "scalar")",
                expected="vector of length $udim",
                suggestion="Ensure the control function returns a vector with $udim elements",
                context="control function validation"
            ))
        end
    end

    # Variable
    if vdim == 0
        if v0 isa AbstractVector
            if length(v0) != 0
                throw(Exceptions.IncorrectArgument(
                    "Initial variable has non-zero length for problem with no variable",
                    got="vector of length $(length(v0))",
                    expected="no variable (dimension 0)",
                    suggestion="Remove the variable argument or set variable=nothing",
                    context="variable validation for zero-dimensional problem"
                ))
            end
        elseif v0 isa Real
            throw(Exceptions.IncorrectArgument(
                "Initial variable is scalar for problem with no variable",
                got="scalar value",
                expected="no variable (dimension 0)",
                suggestion="Remove the variable argument or set variable=nothing",
                context="variable validation for zero-dimensional problem"
            ))
        end
    elseif vdim == 1
        if !(v0 isa Real) && !(v0 isa AbstractVector && length(v0) == 1)
            throw(Exceptions.IncorrectArgument(
                "Initial variable has invalid type for 1D variable",
                got="$(typeof(v0))",
                expected="Real or length-1 Vector",
                suggestion="Provide a scalar or single-element vector for the variable",
                context="variable validation"
            ))
        end
    else
        if !(v0 isa AbstractVector) || length(v0) != vdim
            throw(Exceptions.IncorrectArgument(
                "Initial variable has incompatible dimension",
                got="$(v0 isa AbstractVector ? "vector of length $(length(v0))" : "scalar")",
                expected="vector of length $vdim",
                suggestion="Provide a variable vector with $vdim elements",
                context="variable validation"
            ))
        end
    end

    return init
end

"""
$(TYPEDSIGNATURES)

Build an initial guess from a previous solution (warm start).

Extracts state, control, and variable trajectories from the solution and validates
dimensions against the current problem.
"""
function _initial_guess_from_solution(
    ocp::AbstractOptimalControlProblem, sol::AbstractSolution
)
    # Basic dimensional consistency checks
    if state_dimension(ocp) != state_dimension(sol.model)
        throw(Exceptions.IncorrectArgument(
            "Warm start state dimension mismatch",
            got="solution with state dimension $(state_dimension(sol.model))",
            expected="state dimension $(state_dimension(ocp))",
            suggestion="Ensure the solution comes from a problem with matching state dimension",
            context="warm start from solution"
        ))
    end
    if control_dimension(ocp) != control_dimension(sol.model)
        throw(Exceptions.IncorrectArgument(
            "Warm start control dimension mismatch",
            got="solution with control dimension $(control_dimension(sol.model))",
            expected="control dimension $(control_dimension(ocp))",
            suggestion="Ensure the solution comes from a problem with matching control dimension",
            context="warm start from solution"
        ))
    end
    if variable_dimension(ocp) != variable_dimension(sol.model)
        throw(Exceptions.IncorrectArgument(
            "Warm start variable dimension mismatch",
            got="solution with variable dimension $(variable_dimension(sol.model))",
            expected="variable dimension $(variable_dimension(ocp))",
            suggestion="Ensure the solution comes from a problem with matching variable dimension",
            context="warm start from solution"
        ))
    end

    state_fun = state(sol)
    control_fun = control(sol)
    variable_val = variable(sol)

    init = OptimalControlInitialGuess(state_fun, control_fun, variable_val)
    return _validate_initial_guess(ocp, init)
end

"""
$(TYPEDSIGNATURES)

Build an initial guess from a `NamedTuple`.

Parses keys for state, control, variable (by name or component) and constructs
the appropriate initialisation functions.
"""
function _initial_guess_from_namedtuple(
    ocp::AbstractOptimalControlProblem, init_data::NamedTuple
)
    # Names and component maps from the OCP
    s_name_sym = Symbol(state_name(ocp))
    u_name_sym = Symbol(control_name(ocp))
    v_name_sym = Symbol(variable_name(ocp))

    s_comp_syms = Symbol.(state_components(ocp))
    u_comp_syms = Symbol.(control_components(ocp))
    v_comp_syms = Symbol.(variable_components(ocp))

    s_comp_index = Dict(sym => i for (i, sym) in enumerate(s_comp_syms))
    u_comp_index = Dict(sym => i for (i, sym) in enumerate(u_comp_syms))
    v_comp_index = Dict(sym => i for (i, sym) in enumerate(v_comp_syms))

    # Block-level and component-level specs
    state_block = nothing
    control_block = nothing
    variable_block = nothing
    state_block_set = false
    control_block_set = false
    variable_block_set = false
    state_comp = Dict{Int,Any}()
    control_comp = Dict{Int,Any}()
    variable_comp = Dict{Int,Any}()

    # Parse keys and enforce uniqueness
    for (k, v) in pairs(init_data)
        if k == :time
            throw(Exceptions.IncorrectArgument(
                "Global :time key not supported in initial guess NamedTuple",
                got=":time as global key",
                expected="time grids per block or component as (time, data) tuples",
                suggestion="Use (time_grid, data) tuples for each component or block instead of a global :time",
                context="NamedTuple initial guess parsing"
            ))
        elseif k == :variable || k == v_name_sym
            if variable_block_set || !isempty(variable_comp)
                throw(Exceptions.IncorrectArgument(
                    "Variable initial guess specified multiple times",
                    got="variable at both block and component level, or multiple block entries",
                    expected="variable specified once, either at block or component level",
                    suggestion="Use either :variable (block) or component names, not both",
                    context="NamedTuple initial guess parsing"
                ))
            end
            variable_block = v
            variable_block_set = true
        elseif k == :state || k == s_name_sym
            if state_block_set || !isempty(state_comp)
                throw(Exceptions.IncorrectArgument(
                    "State initial guess specified multiple times",
                    got="state at both block and component level, or multiple block entries",
                    expected="state specified once, either at block or component level",
                    suggestion="Use either :state (block) or component names, not both",
                    context="NamedTuple initial guess parsing"
                ))
            end
            state_block = v
            state_block_set = true
        elseif k == :control || k == u_name_sym
            if control_block_set || !isempty(control_comp)
                throw(Exceptions.IncorrectArgument(
                    "Control initial guess specified multiple times",
                    got="control at both block and component level, or multiple block entries",
                    expected="control specified once, either at block or component level",
                    suggestion="Use either :control (block) or component names, not both",
                    context="NamedTuple initial guess parsing"
                ))
            end
            control_block = v
            control_block_set = true
        elseif haskey(s_comp_index, k)
            if state_block_set
                throw(Exceptions.IncorrectArgument(
                    "Cannot mix state block and component specifications",
                    got="both :state/$s_name_sym block and component :$k",
                    expected="either block-level or component-level, not both",
                    suggestion="Remove either the block-level :state or the component-level specifications",
                    context="NamedTuple initial guess parsing"
                ))
            end
            idx = s_comp_index[k]
            if haskey(state_comp, idx)
                throw(Exceptions.IncorrectArgument(
                    "State component specified multiple times",
                    got="component :$k specified more than once",
                    expected="each component specified at most once",
                    suggestion="Remove duplicate specification of component :$k",
                    context="NamedTuple initial guess parsing"
                ))
            end
            state_comp[idx] = v
        elseif haskey(u_comp_index, k)
            if control_block_set
                throw(Exceptions.IncorrectArgument(
                    "Cannot mix control block and component specifications",
                    got="both :control/$u_name_sym block and component :$k",
                    expected="either block-level or component-level, not both",
                    suggestion="Remove either the block-level :control or the component-level specifications",
                    context="NamedTuple initial guess parsing"
                ))
            end
            idx = u_comp_index[k]
            if haskey(control_comp, idx)
                throw(Exceptions.IncorrectArgument(
                    "Control component specified multiple times",
                    got="component :$k specified more than once",
                    expected="each component specified at most once",
                    suggestion="Remove duplicate specification of component :$k",
                    context="NamedTuple initial guess parsing"
                ))
            end
            control_comp[idx] = v
        elseif haskey(v_comp_index, k)
            if variable_block_set
                throw(Exceptions.IncorrectArgument(
                    "Cannot mix variable block and component specifications",
                    got="both :variable/$v_name_sym block and component :$k",
                    expected="either block-level or component-level, not both",
                    suggestion="Remove either the block-level :variable or the component-level specifications",
                    context="NamedTuple initial guess parsing"
                ))
            end
            idx = v_comp_index[k]
            if haskey(variable_comp, idx)
                throw(Exceptions.IncorrectArgument(
                    "Variable component specified multiple times",
                    got="component :$k specified more than once",
                    expected="each component specified at most once",
                    suggestion="Remove duplicate specification of component :$k",
                    context="NamedTuple initial guess parsing"
                ))
            end
            variable_comp[idx] = v
        else
            allowed_keys = [:state, :control, :variable, s_name_sym, u_name_sym, v_name_sym]
            append!(allowed_keys, s_comp_syms)
            append!(allowed_keys, u_comp_syms)
            append!(allowed_keys, v_comp_syms)
            throw(Exceptions.IncorrectArgument(
                "Unknown key in initial guess NamedTuple",
                got=":$k",
                expected="one of: $(join(allowed_keys, ", "))",
                suggestion="Use valid keys for state, control, variable (block or component level)",
                context="NamedTuple initial guess parsing"
            ))
        end
    end

    # Build state/control with possible per-component overrides
    state_fun = _build_block_with_components(ocp, :state, state_block, state_comp)
    control_fun = _build_block_with_components(ocp, :control, control_block, control_comp)

    # Build variable (block-level or per-component)
    variable_val = begin
        if isempty(variable_comp)
            initial_variable(ocp, variable_block)
        else
            vdim = variable_dimension(ocp)
            if vdim == 0
                throw(Exceptions.IncorrectArgument(
                    "Variable components specified for problem with no variable",
                    got="component-level variable specifications",
                    expected="no variable (dimension 0)",
                    suggestion="Remove variable component specifications or use block-level :variable=nothing",
                    context="NamedTuple initial guess variable parsing"
                ))
            else
                # Start from default variable initialization and override components
                base = initial_variable(ocp, nothing)
                if vdim == 1
                    # Single-component variable: override index 1 if provided
                    if haskey(variable_comp, 1)
                        data = variable_comp[1]
                        val = if data isa AbstractVector{<:Real}
                            if length(data) != 1
                                throw(Exceptions.IncorrectArgument(
                                    "Variable component has invalid length for 1D variable",
                                    got="vector of length $(length(data))",
                                    expected="scalar or length-1 vector",
                                    suggestion="Use a scalar or single-element vector for 1D variable component",
                                    context="variable component initialization"
                                ))
                            end
                            data[1]
                        elseif data isa Real
                            data
                        else
                            throw(Exceptions.IncorrectArgument(
                                "Unsupported variable component initialization type",
                                got="$(typeof(data))",
                                expected="Real or Vector{<:Real}",
                                suggestion="Use a scalar or vector for variable component initialization",
                                context="variable component initialization without time"
                            ))
                        end
                        val
                    else
                        # No specific component provided: keep default base
                        base
                    end
                else
                    # vdim > 1: base should be a vector of length vdim
                    vec = if base isa AbstractVector
                        if length(base) != vdim
                            throw(Exceptions.IncorrectArgument(
                                "Default variable initialization has incompatible dimension",
                                got="vector of length $(length(base))",
                                expected="vector of length $vdim",
                                suggestion="This is an internal error. Please report this issue.",
                                context="variable component initialization"
                            ))
                        end
                        collect(base)
                    elseif base isa Real
                        fill(base, vdim)
                    else
                        throw(Exceptions.IncorrectArgument(
                            "Unsupported default variable initialization type",
                            got="$(typeof(base))",
                            expected="Real or Vector",
                            suggestion="This is an internal error. Please report this issue.",
                            context="variable component initialization"
                        ))
                    end
                    # Override provided components; missing ones keep default
                    for (i, data) in variable_comp
                        if !(1 <= i <= vdim)
                            throw(Exceptions.IncorrectArgument(
                                "Variable component index out of bounds",
                                got="index $i",
                                expected="index between 1 and $vdim",
                                suggestion="Use a valid component index in range 1:$vdim",
                                context="variable component initialization"
                            ))
                        end
                        val_scalar = if data isa AbstractVector{<:Real}
                            if length(data) != 1
                                throw(Exceptions.IncorrectArgument(
                                    "Variable component has invalid length",
                                    got="vector of length $(length(data)) for component $i",
                                    expected="scalar or length-1 vector",
                                    suggestion="Use a scalar or single-element vector for variable component $i",
                                    context="variable component initialization"
                                ))
                            end
                            data[1]
                        elseif data isa Real
                            data
                        else
                            throw(Exceptions.IncorrectArgument(
                                "Unsupported variable component initialization type",
                                got="$(typeof(data))",
                                expected="Real or Vector{<:Real}",
                                suggestion="Use a scalar or vector for variable component initialization",
                                context="variable component $i initialization without time"
                            ))
                        end
                        vec[i] = val_scalar
                    end
                    vec
                end
            end
        end
    end

    init = OptimalControlInitialGuess(state_fun, control_fun, variable_val)
    return _validate_initial_guess(ocp, init)
end

"""
$(TYPEDSIGNATURES)

Build an initial guess from a pre-initialisation object.

Converts raw data into validated functions and trajectories.
"""
function _initial_guess_from_preinit(ocp::AbstractOptimalControlProblem, pre::OptimalControlPreInit)
    x = initial_state(ocp, pre.state)
    u = initial_control(ocp, pre.control)
    v = initial_variable(ocp, pre.variable)
    init = OptimalControlInitialGuess(x, u, v)
    return _validate_initial_guess(ocp, init)
end
