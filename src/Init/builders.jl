# ------------------------------------------------------------------------------
# Initial Guess Builders
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Build an initialisation function combining block-level and component-level data.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `role::Symbol`: The component role (`:state` or `:control`).
- `block_data`: Block-level initialisation data.
- `comp_data::Dict{Int,Any}`: Component-level initialisation data indexed by component.

# Returns
- `Function`: A combined initialisation function that merges block and component data.

# Throws
- `Exceptions.IncorrectArgument`: If dimensions are incompatible or component indices are out of bounds.
"""
function _build_block_with_components(
    ocp::Models.AbstractModel, role::Symbol, block_data, comp_data::Dict{Int,Any}
)
    dim = role === :state ? Models.state_dimension(ocp) : Models.control_dimension(ocp)
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
                throw(
                    Exceptions.IncorrectArgument(
                        "Block-level $role initialization has incompatible dimension";
                        got="$(base_val isa AbstractVector ? "vector of length $(length(base_val))" : "scalar")",
                        expected="$(dim == 1 ? "scalar or length-1 vector" : "vector of length $dim")",
                        suggestion="Ensure the $role function returns the correct dimension",
                        context="block-level $role initialization",
                    ),
                )
            end
            collect(base_val)
        end

        for (i, fi) in comp_funs
            val = fi(t)
            val_scalar = if val isa AbstractVector
                if length(val) != 1
                    throw(
                        Exceptions.IncorrectArgument(
                            "Component-level initialization must return scalar or length-1 vector";
                            got="vector of length $(length(val)) for $role component $i",
                            expected="scalar or length-1 vector",
                            suggestion="Ensure the function for component $i returns a single value",
                            context="component-level $role initialization",
                        ),
                    )
                end
                val[1]
            else
                val
            end
            if !(1 <= i <= dim)
                throw(
                    Exceptions.IncorrectArgument(
                        "Component index out of bounds";
                        got="index $i for $role",
                        expected="index between 1 and $dim",
                        suggestion="Use a valid component index in range 1:$dim",
                        context="component-level $role initialization",
                    ),
                )
            end
            vec[i] = val_scalar
        end
        return dim == 1 ? vec[1] : vec
    end
end

"""
$(TYPEDSIGNATURES)

Build a component-level initialisation function from data.

# Arguments
- `data`: The component data (time-dependent tuple or time-independent data).

# Returns
- `Function`: A component initialisation function.
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

# Arguments
- `data`: The time-independent data (function, scalar, or vector).

# Returns
- `Function`: A component initialisation function.

# Throws
- `Exceptions.IncorrectArgument`: If the data type is unsupported or vector length is invalid.
"""
function _build_component_function_without_time(data)
    if data isa Function
        return data
    elseif data isa Real
        return ConstantInTime(data)
    elseif data isa AbstractVector{<:Real}
        if length(data) == 1
            return ConstantInTime(data[1])
        else
            throw(
                Exceptions.IncorrectArgument(
                    "Component-level initialization vector has invalid length";
                    got="vector of length $(length(data))",
                    expected="scalar or length-1 vector",
                    suggestion="Use a scalar value or a single-element vector for component initialization",
                    context="component-level initialization without time grid",
                ),
            )
        end
    else
        throw(
            Exceptions.IncorrectArgument(
                "Unsupported component-level initialization type";
                got="$(typeof(data))",
                expected="Function, Real, or Vector{<:Real}",
                suggestion="Use a function, scalar, or vector for component initialization",
                context="component-level initialization without time grid",
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Build a component function from data with an associated time grid.

# Arguments
- `data`: The component data (function, scalar, or vector).
- `time::AbstractVector`: The time grid for interpolation.

# Returns
- `Function`: A component initialisation function with time interpolation.

# Throws
- `Exceptions.IncorrectArgument`: If the data type is unsupported or time-grid mismatch occurs.
"""
function _build_component_function_with_time(data, time::AbstractVector)
    if data isa Function
        return data
    elseif data isa Real
        return ConstantInTime(data)
    elseif data isa AbstractVector{<:Real}
        if length(data) == length(time)
            return Interpolation.ctinterpolate(time, data)
        elseif length(data) == 1
            return ConstantInTime(data[1])
        else
            throw(
                Exceptions.IncorrectArgument(
                    "Component-level initialization time-grid mismatch";
                    got="$(length(data)) data points",
                    expected="$(length(time)) points matching time grid, or 1 for constant",
                    suggestion="Provide data with $(length(time)) samples or use a single value for constant initialization",
                    context="component-level initialization with time grid",
                ),
            )
        end
    else
        throw(
            Exceptions.IncorrectArgument(
                "Unsupported component-level initialization type with time grid";
                got="$(typeof(data))",
                expected="Function, Real, or Vector{<:Real}",
                suggestion="Use a function, scalar, or vector for component initialization with time grid",
                context="component-level initialization with time grid",
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Build a time-dependent initialisation function from data and a time grid.

# Arguments
- `ocp::Models.AbstractModel`: The optimal control problem.
- `role::Symbol`: The component role (`:state` or `:control`).
- `data`: The data to interpolate (function, vector, or vector-of-vectors).
- `time::AbstractVector`: The time grid.

# Returns
- `Function`: An interpolated initialisation function `t -> value(t)`.

# Throws
- `Exceptions.IncorrectArgument`: If data type is unsupported or dimensions/time-grid mismatch occurs.
"""
function _build_time_dependent_init(
    ocp::Models.AbstractModel, role::Symbol, data, time::AbstractVector
)
    dim = role === :state ? Models.state_dimension(ocp) : Models.control_dimension(ocp)
    if data === nothing
        return role === :state ? initial_state(ocp, nothing) : initial_control(ocp, nothing)
    end
    if data isa Function
        return data
    end
    data_fmt = _format_init_data_for_grid(data)
    if data_fmt isa AbstractVector{<:Real}
        if length(data_fmt) == length(time)
            return Interpolation.ctinterpolate(time, data_fmt)
        elseif length(data_fmt) == 1
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
            throw(
                Exceptions.IncorrectArgument(
                    "Time-grid $role initialization mismatch";
                    got="$(length(data_fmt)) samples",
                    expected="$(length(time)) samples matching time grid",
                    suggestion="Provide data with $(length(time)) samples for the $role initialization",
                    context="time-grid based $role initialization",
                ),
            )
        end
        itp = Interpolation.ctinterpolate(time, data_fmt)
        sample = itp(first(time))
        if !(sample isa AbstractVector) || length(sample) != dim
            throw(
                Exceptions.IncorrectArgument(
                    "Time-grid $role initialization has incompatible dimension";
                    got="$(sample isa AbstractVector ? "vector of length $(length(sample))" : "scalar")",
                    expected="vector of length $dim",
                    suggestion="Ensure each sample in the $role data has dimension $dim",
                    context="time-grid based $role initialization",
                ),
            )
        end
        return itp
    else
        throw(
            Exceptions.IncorrectArgument(
                "Unsupported $role initialization type for time-grid based initial guess";
                got="$(typeof(data))",
                expected="Function, Vector{<:Real}, or Vector{<:Vector}",
                suggestion="Use a function, scalar vector, or vector-of-vectors for time-grid based initialization",
                context="time-grid based $role initialization",
            ),
        )
    end
end
