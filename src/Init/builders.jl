# ------------------------------------------------------------------------------
# Initial Guess Builders
# ------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Build an initialisation function combining block-level and component-level data.

# Arguments
- `ocp::CTModels.Models.AbstractModel`: The optimal control problem.
- `role::Symbol`: The component role (`:state` or `:control`).
- `block_data`: Block-level initialisation data.
- `comp_data::Dict{Int,Any}`: Component-level initialisation data indexed by component.

# Returns
- `Function`: A combined initialisation function that merges block and component data.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If dimensions are incompatible or component indices are out of bounds.

See also: [`CTModels.Init.MergedTrajectory`](@ref), [`CTModels.Init.initial_state`](@ref), [`CTModels.Init.initial_control`](@ref)
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

    return MergedTrajectory(base_fun, comp_funs, dim, role)
end

"""
$(TYPEDSIGNATURES)

Build a component-level initialisation function from data.

# Arguments
- `data`: The component data (time-dependent tuple or time-independent data).

# Returns
- `Function`: A component initialisation function.

See also: [`CTModels.Init._build_component_function_without_time`](@ref), [`CTModels.Init._build_component_function_with_time`](@ref)
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
- `CTBase.Exceptions.IncorrectArgument`: If the data type is unsupported or vector length is invalid.

See also: [`CTModels.Components.ConstantInTime`](@ref)
"""
function _build_component_function_without_time(data)
    if data isa Function
        return data
    elseif data isa Real
        return Components.ConstantInTime(data)
    elseif data isa AbstractVector{<:Real}
        if length(data) == 1
            return Components.ConstantInTime(data[1])
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
- `CTBase.Exceptions.IncorrectArgument`: If the data type is unsupported or time-grid mismatch occurs.

See also: [`CTModels.Components.ConstantInTime`](@ref), [`CTBase.Interpolation.ctinterpolate`](@extref)
"""
function _build_component_function_with_time(data, time::AbstractVector)
    if data isa Function
        return data
    elseif data isa Real
        return Components.ConstantInTime(data)
    elseif data isa AbstractVector{<:Real}
        if length(data) == length(time)
            return Interpolation.ctinterpolate(time, data)
        elseif length(data) == 1
            return Components.ConstantInTime(data[1])
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
- `ocp::CTModels.Models.AbstractModel`: The optimal control problem.
- `role::Symbol`: The component role (`:state` or `:control`).
- `data`: The data to interpolate (function, vector, or vector-of-vectors).
- `time::AbstractVector`: The time grid.

# Returns
- `Function`: An interpolated initialisation function `t -> value(t)`.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If data type is unsupported or dimensions/time-grid mismatch occurs.

See also: [`CTBase.Interpolation.ctinterpolate`](@extref), [`CTModels.Init.initial_state`](@ref), [`CTModels.Init.initial_control`](@ref)
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
