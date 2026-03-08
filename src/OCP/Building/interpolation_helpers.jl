# Internal helpers for build_solution interpolation patterns
# Unified API following design principles:
# 1. Validation with IncorrectArgument for nothing when not allowed
# 2. Dimension checking with @ensure for robustness
# 3. Special case handling (constant costate) via parameters
# 4. Always apply deepcopy+scalar wrapping (single responsibility)

"""
    _interpolate_from_data(data, T, dim, type_param; allow_nothing=false, 
                           constant_if_two_points=false, expected_dim=nothing)

Internal helper to create an interpolated function from discrete data.

# Arguments
- `data`: Matrix{Float64}, Function, or Nothing (if allow_nothing=true)
- `T`: Time grid vector
- `dim`: Dimension to extract from matrix (nothing = take full matrix)
- `type_param`: Type parameter for dispatch (Matrix, Function, or Nothing)
- `allow_nothing`: If false, throws IncorrectArgument when data is nothing
- `constant_if_two_points`: If true and length(T)==2, return constant function
- `expected_dim`: If provided, validates matrix dimension matches (via @ensure)

# Returns
- Interpolated function (or nothing if data=nothing and allow_nothing=true)

# Throws
- `IncorrectArgument`: If data is nothing and allow_nothing=false
- `AssertionError`: If expected_dim provided and doesn't match (via @ensure)

# Notes
This is a low-level helper. Use `build_interpolated_function` for the complete workflow.
"""
function _interpolate_from_data(
    data,
    T::Vector{Float64},
    dim::Union{Int,Nothing},
    type_param::Type;
    allow_nothing::Bool=false,
    constant_if_two_points::Bool=false,
    expected_dim::Union{Int,Nothing}=nothing,
)
    # Validation: nothing handling
    if isnothing(data)
        if !allow_nothing
            throw(
                Exceptions.IncorrectArgument(
                    "Data cannot be nothing";
                    got="nothing",
                    expected="Matrix{Float64} or Function",
                    suggestion="Provide valid data or set allow_nothing=true",
                    context="_interpolate_from_data",
                ),
            )
        end
        return nothing
    end

    # Case 1: Already a function, pass through
    if type_param <: Function
        return data
    end

    # Case 2: Matrix data - validate and interpolate
    # Dimension validation if expected_dim provided
    if !isnothing(expected_dim) && !isnothing(dim)
        actual_dim = size(data, 2)
        @ensure actual_dim >= dim Exceptions.IncorrectArgument(
            "Matrix dimension mismatch",
            got="$actual_dim columns",
            expected="at least $dim columns",
            suggestion="Provide a matrix with at least $dim columns or adjust expected_dim parameter",
            context="_interpolate_from_data - validating matrix dimensions",
        )
    end

    # Special case: constant function for 2-point grids
    if constant_if_two_points && length(T) == 2
        cols = isnothing(dim) ? (:) : (1:dim)
        return t -> data[1, cols]
    end

    # Standard interpolation
    N = size(data, 1)
    cols = isnothing(dim) ? (:) : (1:dim)
    V = matrix2vec(data[:, cols], 1)
    return ctinterpolate(T[1:N], V)
end

"""
    _wrap_scalar_and_deepcopy(func, dim)

Internal helper to wrap a function with scalar extraction and deepcopy.

# Arguments
- `func`: Function or callable to wrap (or nothing)
- `dim`: Dimension of output (1 = scalar extraction, otherwise vector)

# Returns
- Wrapped function with deepcopy and scalar extraction if dim==1
- nothing if func is nothing

# Notes
Deepcopy is ESSENTIAL because Julia closures capture variable REFERENCES, not values.
Without deepcopy, modifications to external variables after solution creation would
affect the solution.

Example:
```julia
param_x = 1.0
X_func = t -> [param_x * t]
sol = build_solution(...)
param_x = 999.0
# Without deepcopy: sol.state(0.5) would return [499.5] (uses new param_x)
# With deepcopy: sol.state(0.5) returns [0.5] (uses original param_x value)
```
"""
function _wrap_scalar_and_deepcopy(func, dim::Union{Int,Nothing})
    if isnothing(func)
        return nothing
    elseif !isnothing(dim) && dim == 1
        return deepcopy(t -> func(t)[1])
    else
        return deepcopy(t -> func(t))
    end
end

"""
    build_interpolated_function(data, T, dim, type_param; allow_nothing=false,
                                constant_if_two_points=false, expected_dim=nothing)

Unified function to build an interpolated function with deepcopy and scalar wrapping.

This is the main entry point that combines interpolation and wrapping in one call.

# Arguments
- `data`: Matrix{Float64}, Function, or Nothing (if allow_nothing=true)
- `T`: Time grid vector  
- `dim`: Dimension to extract (nothing = take full matrix)
- `type_param`: Type parameter for dispatch
- `allow_nothing`: Allow data=nothing (for optional duals)
- `constant_if_two_points`: Return constant function if length(T)==2 (for costate)
- `expected_dim`: Validate matrix has this dimension (for robustness)

# Returns
- Wrapped interpolated function ready for use in Solution
- nothing if data=nothing and allow_nothing=true

# Throws  
- `IncorrectArgument`: If data is nothing and allow_nothing=false
- `AssertionError`: If expected_dim doesn't match actual dimension

# Examples
```julia
# State interpolation (required, with validation)
fx = build_interpolated_function(X, T, dim_x, TX; expected_dim=dim_x)

# Costate with special 2-point handling
fp = build_interpolated_function(P, T, dim_x, TP; 
                                 constant_if_two_points=true, expected_dim=dim_x)

# Optional dual (can be nothing)
fscbd = build_interpolated_function(state_constraints_lb_dual, T, dim_x, 
                                    Union{Matrix{Float64},Nothing};
                                    allow_nothing=true)
```
"""
function build_interpolated_function(
    data,
    T::Union{Vector{Float64},Nothing},
    dim::Union{Int,Nothing},
    type_param::Type;
    allow_nothing::Bool=false,
    constant_if_two_points::Bool=false,
    expected_dim::Union{Int,Nothing}=nothing,
)
    # Handle T=nothing case
    if isnothing(T)
        if isnothing(data)
            return nothing  # Consistent: both grid and data are nothing
        else
            # ⚠️ Applying Exception Rule: Invalid combination of grid and data
            throw(CTBase.Exceptions.IncorrectArgument(
                "Time grid cannot be nothing when data is provided";
                got="time grid=nothing, data≠nothing",
                expected="both time grid and data to be nothing, or both to be provided",
                suggestion="Provide a valid time grid or set data=nothing",
                context="build_interpolated_function"
            ))
        end
    end

    # Step 1: Interpolate
    func = _interpolate_from_data(
        data,
        T,
        dim,
        type_param;
        allow_nothing=allow_nothing,
        constant_if_two_points=constant_if_two_points,
        expected_dim=expected_dim,
    )

    # Step 2: Wrap with deepcopy and scalar extraction
    return _wrap_scalar_and_deepcopy(func, dim)
end
