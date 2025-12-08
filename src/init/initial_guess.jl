# ------------------------------------------------------------------------------
# Initial guess
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Create a pre-initialisation object for an initial guess.

This function creates an [`OptimalControlPreInit`](@ref) that can later be
processed into a full [`OptimalControlInitialGuess`](@ref).

# Arguments

- `state`: Raw state initialisation data (function, vector, matrix, or `nothing`).
- `control`: Raw control initialisation data (function, vector, matrix, or `nothing`).
- `variable`: Raw variable initialisation data (scalar, vector, or `nothing`).

# Returns

- `OptimalControlPreInit`: A pre-initialisation container.

# Example

```julia-repl
julia> using CTModels

julia> pre = CTModels.pre_initial_guess(state=t -> [0.0, 0.0], control=t -> [1.0])
```
"""
function pre_initial_guess(; state=nothing, control=nothing, variable=nothing)
    return OptimalControlPreInit(state, control, variable)
end

"""
$(TYPEDSIGNATURES)

Construct a validated initial guess for an optimal control problem.

Builds an [`OptimalControlInitialGuess`](@ref) from the provided state, control,
and variable data, validating dimensions against the problem definition.

# Arguments

- `ocp::AbstractOptimalControlProblem`: The optimal control problem.
- `state`: State initialisation (function `t -> x(t)`, constant, vector, or `nothing`).
- `control`: Control initialisation (function `t -> u(t)`, constant, vector, or `nothing`).
- `variable`: Variable initialisation (scalar, vector, or `nothing`).

# Returns

- `OptimalControlInitialGuess`: A validated initial guess.

# Example

```julia-repl
julia> using CTModels

julia> init = CTModels.initial_guess(ocp; state=t -> [0.0, 0.0], control=t -> [1.0])
```
"""
function initial_guess(
    ocp::AbstractOptimalControlProblem;
    state::Union{Nothing,Function,Real,Vector{<:Real}}=nothing,
    control::Union{Nothing,Function,Real,Vector{<:Real}}=nothing,
    variable::Union{Nothing,Real,Vector{<:Real}}=nothing,
)
    x = initial_state(ocp, state)
    u = initial_control(ocp, control)
    v = initial_variable(ocp, variable)
    init = OptimalControlInitialGuess(x, u, v)
    return _validate_initial_guess(ocp, init)
end

"""
$(TYPEDSIGNATURES)

Return the state function directly when provided as a function.
"""
initial_state(::AbstractOptimalControlProblem, state::Function) = state

"""
$(TYPEDSIGNATURES)

Convert a scalar state value to a constant function for 1D state problems.

Throws `CTBase.IncorrectArgument` if the state dimension is not 1.
"""
function initial_state(ocp::AbstractOptimalControlProblem, state::Real)
    dim = state_dimension(ocp)
    if dim == 1
        return t -> state
    else
        msg = "Initial state dimension mismatch: got scalar for state dimension $dim"
        throw(CTBase.IncorrectArgument(msg))
    end
end

"""
$(TYPEDSIGNATURES)

Build an initialisation function combining block-level and component-level data.

Merges a base initialisation with per-component overrides.
"""
function _build_block_with_components(
    ocp::AbstractOptimalControlProblem, role::Symbol, block_data, comp_data::Dict{Int,Any}
)
    dim = role === :state ? state_dimension(ocp) : control_dimension(ocp)
    base_fun = begin
        if block_data === nothing
            if role === :state
                initial_state(ocp, nothing)
            else
                initial_control(ocp, nothing)
            end
        elseif block_data isa Tuple && length(block_data) == 2
            # Per-block time grid: (time, data)
            T, data = block_data
            time = _format_time_grid(T)
            _build_time_dependent_init(ocp, role, data, time)
        else
            if role === :state
                initial_state(ocp, block_data)
            else
                initial_control(ocp, block_data)
            end
        end
    end

    if isempty(comp_data)
        return base_fun
    end

    comp_funs = Dict{Int,Function}()
    for (i, data) in comp_data
        comp_funs[i] = _build_component_function(data)
    end

    return t -> begin
        base_val = base_fun(t)
        vec = if dim == 1
            if base_val isa AbstractVector
                copy(base_val)
            else
                [base_val]
            end
        else
            if !(base_val isa AbstractVector) || length(base_val) != dim
                msg = string(
                    "Block-level ",
                    role,
                    " initial guess produced value of incompatible dimension: got ",
                    (base_val isa AbstractVector ? length(base_val) : 1),
                    " instead of ",
                    dim,
                )
                throw(CTBase.IncorrectArgument(msg))
            end
            collect(base_val)
        end

        for (i, fi) in comp_funs
            val = fi(t)
            val_scalar = if val isa AbstractVector
                if length(val) != 1
                    msg = string(
                        "Component-level ",
                        role,
                        " initial guess must be scalar or length-1 vector for index ",
                        i,
                        ".",
                    )
                    throw(CTBase.IncorrectArgument(msg))
                end
                val[1]
            else
                val
            end
            if !(1 <= i <= dim)
                msg = string(
                    "Component index ",
                    i,
                    " out of bounds for ",
                    role,
                    " dimension ",
                    dim,
                    ".",
                )
                throw(CTBase.IncorrectArgument(msg))
            end
            vec[i] = val_scalar
        end
        return dim == 1 ? vec[1] : vec
    end
end

"""
$(TYPEDSIGNATURES)

Build a component-level initialisation function from data.

Handles both time-dependent `(time, data)` tuples and time-independent data.
"""
function _build_component_function(data)
    # Support (time, data) tuples for per-component time grids
    if data isa Tuple && length(data) == 2
        T, val = data
        time = _format_time_grid(T)
        return _build_component_function_with_time(val, time)
    else
        return _build_component_function_without_time(data)
    end
end

"""
$(TYPEDSIGNATURES)

Build a component function from time-independent data (scalar, vector, or function).
"""
function _build_component_function_without_time(data)
    if data isa Function
        return data
    elseif data isa Real
        return t -> data
    elseif data isa AbstractVector{<:Real}
        if length(data) == 1
            c = data[1]
            return t -> c
        else
            msg = "Component-level initialization without time must be scalar or length-1 vector."
            throw(CTBase.IncorrectArgument(msg))
        end
    else
        msg = string(
            "Unsupported component-level initialization type without time: ", typeof(data)
        )
        throw(CTBase.IncorrectArgument(msg))
    end
end

"""
$(TYPEDSIGNATURES)

Build a component function from data with an associated time grid.

Interpolates vector data over the time grid.
"""
function _build_component_function_with_time(data, time::AbstractVector)
    if data isa Function
        return data
    elseif data isa Real
        return t -> data
    elseif data isa AbstractVector{<:Real}
        if length(data) == length(time)
            itp = ctinterpolate(time, data)
            return t -> itp(t)
        elseif length(data) == 1
            c = data[1]
            return t -> c
        else
            msg = string(
                "Component-level initialization time-grid mismatch: got ",
                length(data),
                " samples for ",
                length(time),
                "-point time grid.",
            )
            throw(CTBase.IncorrectArgument(msg))
        end
    else
        msg = string(
            "Unsupported component-level initialization type with time grid: ", typeof(data)
        )
        throw(CTBase.IncorrectArgument(msg))
    end
end

"""
$(TYPEDSIGNATURES)

Convert a state vector to a constant function.

Throws `CTBase.IncorrectArgument` if the vector length does not match the state dimension.
"""
function initial_state(ocp::AbstractOptimalControlProblem, state::Vector{<:Real})
    dim = state_dimension(ocp)
    if length(state) != dim
        msg = string(
            "Initial state dimension mismatch: got ", length(state), " instead of ", dim
        )
        throw(CTBase.IncorrectArgument(msg))
    end
    return t -> state
end

"""
$(TYPEDSIGNATURES)

Return a default state initialisation function when no state is provided.

Returns a constant function yielding `0.1` (scalar) or `fill(0.1, dim)` (vector).
"""
function initial_state(ocp::AbstractOptimalControlProblem, ::Nothing)
    dim = state_dimension(ocp)
    if dim == 1
        return t -> 0.1
    else
        return t -> fill(0.1, dim)
    end
end

"""
$(TYPEDSIGNATURES)

Return the control function directly when provided as a function.
"""
initial_control(::AbstractOptimalControlProblem, control::Function) = control

"""
$(TYPEDSIGNATURES)

Convert a scalar control value to a constant function for 1D control problems.

Throws `CTBase.IncorrectArgument` if the control dimension is not 1.
"""
function initial_control(ocp::AbstractOptimalControlProblem, control::Real)
    dim = control_dimension(ocp)
    if dim == 1
        return t -> control
    else
        msg = "Initial control dimension mismatch: got scalar for control dimension $dim"
        throw(CTBase.IncorrectArgument(msg))
    end
end

"""
$(TYPEDSIGNATURES)

Convert a control vector to a constant function.

Throws `CTBase.IncorrectArgument` if the vector length does not match the control dimension.
"""
function initial_control(ocp::AbstractOptimalControlProblem, control::Vector{<:Real})
    dim = control_dimension(ocp)
    if length(control) != dim
        msg = string(
            "Initial control dimension mismatch: got ", length(control), " instead of ", dim
        )
        throw(CTBase.IncorrectArgument(msg))
    end
    return t -> control
end

"""
$(TYPEDSIGNATURES)

Return a default control initialisation function when no control is provided.

Returns a constant function yielding `0.1` (scalar) or `fill(0.1, dim)` (vector).
"""
function initial_control(ocp::AbstractOptimalControlProblem, ::Nothing)
    dim = control_dimension(ocp)
    if dim == 1
        return t -> 0.1
    else
        return t -> fill(0.1, dim)
    end
end

"""
$(TYPEDSIGNATURES)

Return a scalar variable value for 1D variable problems.

Throws `CTBase.IncorrectArgument` if the variable dimension is not 1.
"""
function initial_variable(ocp::AbstractOptimalControlProblem, variable::Real)
    dim = variable_dimension(ocp)
    if dim == 0
        msg = "Initial variable dimension mismatch: got scalar for variable dimension 0"
        throw(CTBase.IncorrectArgument(msg))
    elseif dim == 1
        return variable
    else
        msg = "Initial variable dimension mismatch: got scalar for variable dimension $dim"
        throw(CTBase.IncorrectArgument(msg))
    end
end

"""
$(TYPEDSIGNATURES)

Return a variable vector.

Throws `CTBase.IncorrectArgument` if the vector length does not match the variable dimension.
"""
function initial_variable(ocp::AbstractOptimalControlProblem, variable::Vector{<:Real})
    dim = variable_dimension(ocp)
    if length(variable) != dim
        msg = string(
            "Initial variable dimension mismatch: got ",
            length(variable),
            " instead of ",
            dim,
        )
        throw(CTBase.IncorrectArgument(msg))
    end
    return variable
end

"""
$(TYPEDSIGNATURES)

Return a default variable initialisation when no variable is provided.

Returns an empty vector if `dim == 0`, `0.1` if `dim == 1`, or `fill(0.1, dim)` otherwise.
"""
function initial_variable(ocp::AbstractOptimalControlProblem, ::Nothing)
    dim = variable_dimension(ocp)
    if dim == 0
        return Float64[]
    else
        if dim == 1
            return 0.1
        else
            return fill(0.1, dim)
        end
    end
end

"""
$(TYPEDSIGNATURES)

Extract the state trajectory function from an initial guess.
"""
function state(init::OptimalControlInitialGuess{X,<:Function})::X where {X<:Function}
    return init.state
end

"""
$(TYPEDSIGNATURES)

Extract the control trajectory function from an initial guess.
"""
function control(init::OptimalControlInitialGuess{<:Function,U})::U where {U<:Function}
    return init.control
end

"""
$(TYPEDSIGNATURES)

Extract the variable value from an initial guess.
"""
function variable(
    init::OptimalControlInitialGuess{<: Function,<: Function,V}
)::V where {V<:Union{Real,Vector{<:Real}}}
    return init.variable
end

"""
$(TYPEDSIGNATURES)

Validate an initial guess against an optimal control problem.

Checks that the dimensions of state, control, and variable match the problem
definition. Returns the validated initial guess or throws an error.

# Arguments

- `ocp::AbstractOptimalControlProblem`: The optimal control problem.
- `init::AbstractOptimalControlInitialGuess`: The initial guess to validate.

# Returns

- The validated initial guess.

# Throws

- `CTBase.IncorrectArgument` if dimensions do not match.
"""
function validate_initial_guess(
    ocp::AbstractOptimalControlProblem, init::AbstractOptimalControlInitialGuess
)
    if init isa OptimalControlInitialGuess
        return _validate_initial_guess(ocp, init)
    else
        # For now, only OptimalControlInitialGuess is supported.
        return init
    end
end

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
            msg = "Initial state function must return a scalar or length-1 vector for state dimension 1."
            throw(CTBase.IncorrectArgument(msg))
        end
    else
        if !(x0 isa AbstractVector) || length(x0) != xdim
            msg = string(
                "Initial state function returns value of incompatible dimension: got ",
                (x0 isa AbstractVector ? length(x0) : 1),
                " instead of ",
                xdim,
            )
            throw(CTBase.IncorrectArgument(msg))
        end
    end

    # Control
    u0 = control(init)(tsample)
    if udim == 1
        if !(u0 isa Real) && !(u0 isa AbstractVector && length(u0) == 1)
            msg = "Initial control function must return a scalar or length-1 vector for control dimension 1."
            throw(CTBase.IncorrectArgument(msg))
        end
    else
        if !(u0 isa AbstractVector) || length(u0) != udim
            msg = string(
                "Initial control function returns value of incompatible dimension: got ",
                (u0 isa AbstractVector ? length(u0) : 1),
                " instead of ",
                udim,
            )
            throw(CTBase.IncorrectArgument(msg))
        end
    end

    # Variable
    if vdim == 0
        if v0 isa AbstractVector
            if length(v0) != 0
                msg = "Initial variable has non-zero length for problem with no variable."
                throw(CTBase.IncorrectArgument(msg))
            end
        elseif v0 isa Real
            msg = "Initial variable is scalar for problem with no variable."
            throw(CTBase.IncorrectArgument(msg))
        end
    elseif vdim == 1
        if !(v0 isa Real) && !(v0 isa AbstractVector && length(v0) == 1)
            msg = "Initial variable must be a scalar or length-1 vector for variable dimension 1."
            throw(CTBase.IncorrectArgument(msg))
        end
    else
        if !(v0 isa AbstractVector) || length(v0) != vdim
            msg = string(
                "Initial variable has incompatible dimension: got ",
                (v0 isa AbstractVector ? length(v0) : 1),
                " instead of ",
                vdim,
            )
            throw(CTBase.IncorrectArgument(msg))
        end
    end

    return init
end

"""
$(TYPEDSIGNATURES)

Build an initial guess from various input formats.

Accepts multiple input types and converts them to an [`OptimalControlInitialGuess`](@ref):
- `nothing` or `()`: Returns default initial guess.
- `AbstractOptimalControlInitialGuess`: Returns as-is.
- `AbstractOptimalControlPreInit`: Converts from pre-initialisation.
- `AbstractSolution`: Warm-starts from a previous solution.
- `NamedTuple`: Parses named fields for state, control, and variable.

# Arguments

- `ocp::AbstractOptimalControlProblem`: The optimal control problem.
- `init_data`: The initial guess data in one of the supported formats.

# Returns

- `OptimalControlInitialGuess`: A validated initial guess.

# Example

```julia-repl
julia> using CTModels

julia> init = CTModels.build_initial_guess(ocp, (state=t -> [0.0], control=t -> [1.0]))
```
"""
function build_initial_guess(ocp::AbstractOptimalControlProblem, init_data)
    if init_data === nothing || init_data === ()
        return initial_guess(ocp)
    elseif init_data isa AbstractOptimalControlInitialGuess
        return init_data
    elseif init_data isa AbstractOptimalControlPreInit
        return _initial_guess_from_preinit(ocp, init_data)
    elseif init_data isa AbstractSolution
        return _initial_guess_from_solution(ocp, init_data)
    elseif init_data isa NamedTuple
        return _initial_guess_from_namedtuple(ocp, init_data)
    else
        msg = "Unsupported initial guess type: $(typeof(init_data))"
        throw(CTBase.IncorrectArgument(msg))
    end
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
        msg = "Warm start: state dimension mismatch between ocp and solution."
        throw(CTBase.IncorrectArgument(msg))
    end
    if control_dimension(ocp) != control_dimension(sol.model)
        msg = "Warm start: control dimension mismatch between ocp and solution."
        throw(CTBase.IncorrectArgument(msg))
    end
    if variable_dimension(ocp) != variable_dimension(sol.model)
        msg = "Warm start: variable dimension mismatch between ocp and solution."
        throw(CTBase.IncorrectArgument(msg))
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
            msg = "Global :time in initial guess NamedTuple is not supported. Provide time grids per block or component as (time, data) tuples."
            throw(CTBase.IncorrectArgument(msg))
        elseif k == :variable || k == v_name_sym
            if variable_block_set || !isempty(variable_comp)
                msg = "Variable initial guess specified both at block level and component level, or multiple block-level entries."
                throw(CTBase.IncorrectArgument(msg))
            end
            variable_block = v
            variable_block_set = true
        elseif k == :state || k == s_name_sym
            if state_block_set || !isempty(state_comp)
                msg = "State initial guess specified both at block level and component level, or multiple block-level entries."
                throw(CTBase.IncorrectArgument(msg))
            end
            state_block = v
            state_block_set = true
        elseif k == :control || k == u_name_sym
            if control_block_set || !isempty(control_comp)
                msg = "Control initial guess specified both at block level and component level, or multiple block-level entries."
                throw(CTBase.IncorrectArgument(msg))
            end
            control_block = v
            control_block_set = true
        elseif haskey(s_comp_index, k)
            if state_block_set
                msg = string(
                    "Cannot mix state block (:state or ",
                    s_name_sym,
                    ") and state component ",
                    k,
                    " in the same initial guess.",
                )
                throw(CTBase.IncorrectArgument(msg))
            end
            idx = s_comp_index[k]
            if haskey(state_comp, idx)
                msg = string(
                    "State component ", k, " specified more than once in initial guess."
                )
                throw(CTBase.IncorrectArgument(msg))
            end
            state_comp[idx] = v
        elseif haskey(u_comp_index, k)
            if control_block_set
                msg = string(
                    "Cannot mix control block (:control or ",
                    u_name_sym,
                    ") and control component ",
                    k,
                    " in the same initial guess.",
                )
                throw(CTBase.IncorrectArgument(msg))
            end
            idx = u_comp_index[k]
            if haskey(control_comp, idx)
                msg = string(
                    "Control component ", k, " specified more than once in initial guess."
                )
                throw(CTBase.IncorrectArgument(msg))
            end
            control_comp[idx] = v
        elseif haskey(v_comp_index, k)
            if variable_block_set
                msg = string(
                    "Cannot mix variable block (:variable or ",
                    v_name_sym,
                    ") and variable component ",
                    k,
                    " in the same initial guess.",
                )
                throw(CTBase.IncorrectArgument(msg))
            end
            idx = v_comp_index[k]
            if haskey(variable_comp, idx)
                msg = string(
                    "Variable component ", k, " specified more than once in initial guess."
                )
                throw(CTBase.IncorrectArgument(msg))
            end
            variable_comp[idx] = v
        else
            msg = string(
                "Unknown key ",
                k,
                " in initial guess NamedTuple. Allowed keys are: time, state, control, variable, ",
                s_name_sym,
                ", ",
                u_name_sym,
                ", ",
                v_name_sym,
                ", and component names of state/control/variable.",
            )
            throw(CTBase.IncorrectArgument(msg))
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
                msg = "Variable components specified for problem with no variable."
                throw(CTBase.IncorrectArgument(msg))
            else
                # Start from default variable initialization and override components
                base = initial_variable(ocp, nothing)
                if vdim == 1
                    # Single-component variable: override index 1 if provided
                    if haskey(variable_comp, 1)
                        data = variable_comp[1]
                        val = if data isa AbstractVector{<:Real}
                            if length(data) != 1
                                msg = "Variable component initial guess must be scalar or length-1 vector for variable dimension 1."
                                throw(CTBase.IncorrectArgument(msg))
                            end
                            data[1]
                        elseif data isa Real
                            data
                        else
                            msg = string(
                                "Unsupported variable component initialization type without time: ",
                                typeof(data),
                            )
                            throw(CTBase.IncorrectArgument(msg))
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
                            msg = string(
                                "Default variable initialization has incompatible dimension: got ",
                                length(base),
                                " instead of ",
                                vdim,
                                ".",
                            )
                            throw(CTBase.IncorrectArgument(msg))
                        end
                        collect(base)
                    elseif base isa Real
                        fill(base, vdim)
                    else
                        msg = string(
                            "Unsupported default variable initialization type: ",
                            typeof(base),
                        )
                        throw(CTBase.IncorrectArgument(msg))
                    end
                    # Override provided components; missing ones keep default
                    for (i, data) in variable_comp
                        if !(1 <= i <= vdim)
                            msg = string(
                                "Variable component index ",
                                i,
                                " out of bounds for variable dimension ",
                                vdim,
                                ".",
                            )
                            throw(CTBase.IncorrectArgument(msg))
                        end
                        val_scalar = if data isa AbstractVector{<:Real}
                            if length(data) != 1
                                msg = string(
                                    "Variable component index ",
                                    i,
                                    " initial guess must be scalar or length-1 vector.",
                                )
                                throw(CTBase.IncorrectArgument(msg))
                            end
                            data[1]
                        elseif data isa Real
                            data
                        else
                            msg = string(
                                "Unsupported variable component initialization type without time: ",
                                typeof(data),
                            )
                            throw(CTBase.IncorrectArgument(msg))
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

Convert a [`OptimalControlPreInit`](@ref) to an initial guess.
"""
function _initial_guess_from_preinit(
    ocp::AbstractOptimalControlProblem, preinit::OptimalControlPreInit
)
    nt = (state=preinit.state, control=preinit.control, variable=preinit.variable)
    return _initial_guess_from_namedtuple(ocp, nt)
end

"""
$(TYPEDSIGNATURES)

Normalise time grid data to a vector format.
"""
function _format_time_grid(time_data)
    if time_data === nothing
        return nothing
    elseif time_data isa AbstractVector
        return time_data
    elseif time_data isa AbstractArray
        return vec(time_data)
    else
        msg = string(
            "Invalid time grid type for initial guess: ",
            typeof(time_data),
            ". Expected a vector or array.",
        )
        throw(CTBase.IncorrectArgument(msg))
    end
end

"""
$(TYPEDSIGNATURES)

Convert matrix data to vector-of-vectors format for time-grid interpolation.
"""
function _format_init_data_for_grid(data)
    if data isa AbstractMatrix
        return matrix2vec(data, 1)
    else
        return data
    end
end

"""
$(TYPEDSIGNATURES)

Build a time-dependent initialisation function from data and a time grid.

Interpolates the provided data over the time grid to create a callable function.
"""
function _build_time_dependent_init(
    ocp::AbstractOptimalControlProblem, role::Symbol, data, time::AbstractVector
)
    dim = role === :state ? state_dimension(ocp) : control_dimension(ocp)
    if data === nothing
        return role === :state ? initial_state(ocp, nothing) : initial_control(ocp, nothing)
    end
    if data isa Function
        return data
    end
    data_fmt = _format_init_data_for_grid(data)
    if data_fmt isa AbstractVector{<:Real}
        if length(data_fmt) == length(time)
            itp = ctinterpolate(time, data_fmt)
            return t -> itp(t)
        else
            return if role === :state
                initial_state(ocp, data_fmt)
            else
                initial_control(ocp, data_fmt)
            end
        end
    elseif data_fmt isa AbstractVector &&
        !isempty(data_fmt) &&
        (data_fmt[1] isa AbstractVector)
        if length(data_fmt) != length(time)
            msg = string(
                "Time-grid ",
                role,
                " initialization mismatch: got ",
                length(data_fmt),
                " samples for ",
                length(time),
                "-point time grid.",
            )
            throw(CTBase.IncorrectArgument(msg))
        end
        itp = ctinterpolate(time, data_fmt)
        sample = itp(first(time))
        if !(sample isa AbstractVector) || length(sample) != dim
            msg = string(
                "Time-grid ",
                role,
                " initialization has incompatible dimension: got ",
                (sample isa AbstractVector ? length(sample) : 1),
                " instead of ",
                dim,
            )
            throw(CTBase.IncorrectArgument(msg))
        end
        return t -> itp(t)
    else
        msg = string(
            "Unsupported ",
            role,
            " initialization type for time-grid based initial guess: ",
            typeof(data),
        )
        throw(CTBase.IncorrectArgument(msg))
    end
end