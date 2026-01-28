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
        throw(CTModels.Exceptions.IncorrectArgument(
            "Initial state dimension mismatch",
            got="scalar value",
            expected="vector of length $dim or function returning such vector",
            suggestion="Use a vector: state=[x1, x2, ..., x$dim] or a function: state=t->[...]",
            context="initial_state with scalar input"
        ))
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
            if (base_val isa AbstractVector && length(base_val) != dim) ||
               (!(base_val isa AbstractVector) && dim != 1)
                throw(CTModels.Exceptions.IncorrectArgument(
                    "Block-level $role initialization has incompatible dimension",
                    got="$(base_val isa AbstractVector ? "vector of length $(length(base_val))" : "scalar")",
                    expected="$(dim == 1 ? "scalar or length-1 vector" : "vector of length $dim")",
                    suggestion="Ensure the $role function returns the correct dimension",
                    context="block-level $role initialization"
                ))
            end
            collect(base_val)
        end

        for (i, fi) in comp_funs
            val = fi(t)
            val_scalar = if val isa AbstractVector
                if length(val) != 1
                    throw(CTModels.Exceptions.IncorrectArgument(
                        "Component-level initialization must return scalar or length-1 vector",
                        got="vector of length $(length(val)) for $role component $i",
                        expected="scalar or length-1 vector",
                        suggestion="Ensure the function for component $i returns a single value",
                        context="component-level $role initialization"
                    ))
                end
                val[1]
            else
                val
            end
            if !(1 <= i <= dim)
                throw(CTModels.Exceptions.IncorrectArgument(
                    "Component index out of bounds",
                    got="index $i for $role",
                    expected="index between 1 and $dim",
                    suggestion="Use a valid component index in range 1:$dim",
                    context="component-level $role initialization"
                ))
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
            throw(CTModels.Exceptions.IncorrectArgument(
                "Component-level initialization vector has invalid length",
                got="vector of length $(length(data))",
                expected="scalar or length-1 vector",
                suggestion="Use a scalar value or a single-element vector for component initialization",
                context="component-level initialization without time grid"
            ))
        end
    else
        throw(CTModels.Exceptions.IncorrectArgument(
            "Unsupported component-level initialization type",
            got="$(typeof(data))",
            expected="Function, Real, or Vector{<:Real}",
            suggestion="Use a function, scalar, or vector for component initialization",
            context="component-level initialization without time grid"
        ))
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
            throw(CTModels.Exceptions.IncorrectArgument(
                "Component-level initialization time-grid mismatch",
                got="$(length(data)) data points",
                expected="$(length(time)) points matching time grid, or 1 for constant",
                suggestion="Provide data with $(length(time)) samples or use a single value for constant initialization",
                context="component-level initialization with time grid"
            ))
        end
    else
        throw(CTModels.Exceptions.IncorrectArgument(
            "Unsupported component-level initialization type with time grid",
            got="$(typeof(data))",
            expected="Function, Real, or Vector{<:Real}",
            suggestion="Use a function, scalar, or vector for component initialization with time grid",
            context="component-level initialization with time grid"
        ))
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
        throw(CTModels.Exceptions.IncorrectArgument(
            "Initial state dimension mismatch",
            got="vector of length $(length(state))",
            expected="vector of length $dim",
            suggestion="Provide a state vector with $dim elements: state=[x1, x2, ..., x$dim]",
            context="initial_state with vector input"
        ))
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
        throw(CTModels.Exceptions.IncorrectArgument(
            "Initial control dimension mismatch",
            got="scalar value",
            expected="vector of length $dim or function returning such vector",
            suggestion="Use a vector: control=[u1, u2, ..., u$dim] or a function: control=t->[...]",
            context="initial_control with scalar input"
        ))
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
        throw(CTModels.Exceptions.IncorrectArgument(
            "Initial control dimension mismatch",
            got="vector of length $(length(control))",
            expected="vector of length $dim",
            suggestion="Provide a control vector with $dim elements: control=[u1, u2, ..., u$dim]",
            context="initial_control with vector input"
        ))
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
        throw(CTModels.Exceptions.IncorrectArgument(
            "Initial variable dimension mismatch",
            got="scalar value",
            expected="no variable (dimension 0)",
            suggestion="Remove the variable argument or set variable=nothing",
            context="initial_variable with scalar input for zero-dimensional variable"
        ))
    elseif dim == 1
        return variable
    else
        throw(CTModels.Exceptions.IncorrectArgument(
            "Initial variable dimension mismatch",
            got="scalar value",
            expected="vector of length $dim",
            suggestion="Use a vector: variable=[v1, v2, ..., v$dim]",
            context="initial_variable with scalar input"
        ))
    end
end

"""
$(TYPEDSIGNATURES)

Return a variable vector.

Throws `CTBase.IncorrectArgument` if the vector length does not match the variable dimension.
"""
function initial_variable(ocp::AbstractOptimalControlProblem, variable::Vector{<:Real})
    dim = variable_dimension(ocp)
    base_val = variable
    if length(base_val) != dim
        throw(CTModels.Exceptions.IncorrectArgument(
            "Initial variable dimension mismatch",
            got="vector of length $(length(base_val))",
            expected="vector of length $dim",
            suggestion="Provide a variable vector with $dim elements matching the variable dimension",
            context="initial_variable component-level initialization"
        ))
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
            throw(CTModels.Exceptions.IncorrectArgument(
                "Initial state function returns invalid type for 1D state",
                got="$(typeof(x0))",
                expected="Real or length-1 Vector",
                suggestion="Ensure the state function returns a scalar or single-element vector",
                context="state function validation"
            ))
        end
    else
        if !(x0 isa AbstractVector) || length(x0) != xdim
            throw(CTModels.Exceptions.IncorrectArgument(
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
            throw(CTModels.Exceptions.IncorrectArgument(
                "Initial control function returns invalid type for 1D control",
                got="$(typeof(u0))",
                expected="Real or length-1 Vector",
                suggestion="Ensure the control function returns a scalar or single-element vector",
                context="control function validation"
            ))
        end
    else
        if !(u0 isa AbstractVector) || length(u0) != udim
            throw(CTModels.Exceptions.IncorrectArgument(
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
                throw(CTModels.Exceptions.IncorrectArgument(
                    "Initial variable has non-zero length for problem with no variable",
                    got="vector of length $(length(v0))",
                    expected="no variable (dimension 0)",
                    suggestion="Remove the variable argument or set variable=nothing",
                    context="variable validation for zero-dimensional problem"
                ))
            end
        elseif v0 isa Real
            throw(CTModels.Exceptions.IncorrectArgument(
                "Initial variable is scalar for problem with no variable",
                got="scalar value",
                expected="no variable (dimension 0)",
                suggestion="Remove the variable argument or set variable=nothing",
                context="variable validation for zero-dimensional problem"
            ))
        end
    elseif vdim == 1
        if !(v0 isa Real) && !(v0 isa AbstractVector && length(v0) == 1)
            throw(CTModels.Exceptions.IncorrectArgument(
                "Initial variable has invalid type for 1D variable",
                got="$(typeof(v0))",
                expected="Real or length-1 Vector",
                suggestion="Provide a scalar or single-element vector for the variable",
                context="variable validation"
            ))
        end
    else
        if !(v0 isa AbstractVector) || length(v0) != vdim
            throw(CTModels.Exceptions.IncorrectArgument(
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
        throw(CTModels.Exceptions.IncorrectArgument(
            "Unsupported initial guess type",
            got="$(typeof(init_data))",
            expected="nothing, OptimalControlInitialGuess, OptimalControlPreInit, Solution, or NamedTuple",
            suggestion="Use one of the supported types for initial guess specification",
            context="build_initial_guess"
        ))
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
        throw(CTModels.Exceptions.IncorrectArgument(
            "Warm start state dimension mismatch",
            got="solution with state dimension $(state_dimension(sol.model))",
            expected="state dimension $(state_dimension(ocp))",
            suggestion="Ensure the solution comes from a problem with matching state dimension",
            context="warm start from solution"
        ))
    end
    if control_dimension(ocp) != control_dimension(sol.model)
        throw(CTModels.Exceptions.IncorrectArgument(
            "Warm start control dimension mismatch",
            got="solution with control dimension $(control_dimension(sol.model))",
            expected="control dimension $(control_dimension(ocp))",
            suggestion="Ensure the solution comes from a problem with matching control dimension",
            context="warm start from solution"
        ))
    end
    if variable_dimension(ocp) != variable_dimension(sol.model)
        throw(CTModels.Exceptions.IncorrectArgument(
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
            throw(CTModels.Exceptions.IncorrectArgument(
                "Global :time key not supported in initial guess NamedTuple",
                got=":time as global key",
                expected="time grids per block or component as (time, data) tuples",
                suggestion="Use (time_grid, data) tuples for each component or block instead of a global :time",
                context="NamedTuple initial guess parsing"
            ))
        elseif k == :variable || k == v_name_sym
            if variable_block_set || !isempty(variable_comp)
                throw(CTModels.Exceptions.IncorrectArgument(
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
                throw(CTModels.Exceptions.IncorrectArgument(
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
                throw(CTModels.Exceptions.IncorrectArgument(
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
                throw(CTModels.Exceptions.IncorrectArgument(
                    "Cannot mix state block and component specifications",
                    got="both :state/$s_name_sym block and component :$k",
                    expected="either block-level or component-level, not both",
                    suggestion="Remove either the block-level :state or the component-level specifications",
                    context="NamedTuple initial guess parsing"
                ))
            end
            idx = s_comp_index[k]
            if haskey(state_comp, idx)
                throw(CTModels.Exceptions.IncorrectArgument(
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
                throw(CTModels.Exceptions.IncorrectArgument(
                    "Cannot mix control block and component specifications",
                    got="both :control/$u_name_sym block and component :$k",
                    expected="either block-level or component-level, not both",
                    suggestion="Remove either the block-level :control or the component-level specifications",
                    context="NamedTuple initial guess parsing"
                ))
            end
            idx = u_comp_index[k]
            if haskey(control_comp, idx)
                throw(CTModels.Exceptions.IncorrectArgument(
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
                throw(CTModels.Exceptions.IncorrectArgument(
                    "Cannot mix variable block and component specifications",
                    got="both :variable/$v_name_sym block and component :$k",
                    expected="either block-level or component-level, not both",
                    suggestion="Remove either the block-level :variable or the component-level specifications",
                    context="NamedTuple initial guess parsing"
                ))
            end
            idx = v_comp_index[k]
            if haskey(variable_comp, idx)
                throw(CTModels.Exceptions.IncorrectArgument(
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
            throw(CTModels.Exceptions.IncorrectArgument(
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
                throw(CTModels.Exceptions.IncorrectArgument(
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
                                throw(CTModels.Exceptions.IncorrectArgument(
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
                            throw(CTModels.Exceptions.IncorrectArgument(
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
                            throw(CTModels.Exceptions.IncorrectArgument(
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
                        throw(CTModels.Exceptions.IncorrectArgument(
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
                            throw(CTModels.Exceptions.IncorrectArgument(
                                "Variable component index out of bounds",
                                got="index $i",
                                expected="index between 1 and $vdim",
                                suggestion="Use a valid component index in range 1:$vdim",
                                context="variable component initialization"
                            ))
                        end
                        val_scalar = if data isa AbstractVector{<:Real}
                            if length(data) != 1
                                throw(CTModels.Exceptions.IncorrectArgument(
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
                            throw(CTModels.Exceptions.IncorrectArgument(
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
        throw(CTModels.Exceptions.IncorrectArgument(
            "Invalid time grid type for initial guess",
            got="$(typeof(time_data))",
            expected="Vector or Array",
            suggestion="Provide a vector or array for the time grid",
            context="time grid formatting"
        ))
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
            throw(CTModels.Exceptions.IncorrectArgument(
                "Time-grid $role initialization mismatch",
                got="$(length(data_fmt)) samples",
                expected="$(length(time)) samples matching time grid",
                suggestion="Provide data with $(length(time)) samples for the $role initialization",
                context="time-grid based $role initialization"
            ))
        end
        itp = ctinterpolate(time, data_fmt)
        sample = itp(first(time))
        if !(sample isa AbstractVector) || length(sample) != dim
            throw(CTModels.Exceptions.IncorrectArgument(
                "Time-grid $role initialization has incompatible dimension",
                got="$(sample isa AbstractVector ? "vector of length $(length(sample))" : "scalar")",
                expected="vector of length $dim",
                suggestion="Ensure each sample in the $role data has dimension $dim",
                context="time-grid based $role initialization"
            ))
        end
        return t -> itp(t)
    else
        throw(CTModels.Exceptions.IncorrectArgument(
            "Unsupported $role initialization type for time-grid based initial guess",
            got="$(typeof(data))",
            expected="Function, Vector{<:Real}, or Vector{<:Vector}",
            suggestion="Use a function, scalar vector, or vector-of-vectors for time-grid based initialization",
            context="time-grid based $role initialization"
        ))
    end
end
