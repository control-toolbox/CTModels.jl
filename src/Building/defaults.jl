"""
$(TYPEDSIGNATURES)

Return the default value for the constraints.

# Returns
- `Nothing`
"""
__constraints() = nothing

"""
$(TYPEDSIGNATURES)

Return the default format of the file to be used for export and import.

# Returns
- `Symbol`: The format symbol (`:JLD`).
"""
__format() = :JLD

"""
$(TYPEDSIGNATURES)

Return a unique label for a constraint using `gensym` with prefix `:unnamed`.

# Returns
- `Symbol`: A unique constraint label.
"""
__constraint_label() = gensym(:unnamed)

"""
$(TYPEDSIGNATURES)

Return the default name of the control variable.

# Returns
- `String`: The default control name (`"u"`).
"""
__control_name()::String = "u"

"""
$(TYPEDSIGNATURES)

Return the default component names for a control variable of dimension `m`.

# Arguments
- `m::Dimension`: The control dimension.
- `name::String`: The base name for components.

# Returns
- `Vector{String}`: Component names (single element for m=1, subscripted for m>1).
"""
__control_components(m::Dimension, name::String)::Vector{String} =
    m > 1 ? [name * CTBase.ctindices(i) for i in range(1, m)] : [name]

"""
$(TYPEDSIGNATURES)

Return the default optimization criterion type.

# Returns
- `Symbol`: The criterion type (`:min` for minimization).
"""
__criterion_type() = :min

"""
$(TYPEDSIGNATURES)

Return the default name of the state variable.

# Returns
- `String`: The default state name (`"x"`).
"""
__state_name()::String = "x"

"""
$(TYPEDSIGNATURES)

Return the default component names for a state variable of dimension `n`.

# Arguments
- `n::Dimension`: The state dimension.
- `name::String`: The base name for components.

# Returns
- `Vector{String}`: Component names (single element for n=1, subscripted for n>1).
"""
__state_components(n::Dimension, name::String)::Vector{String} =
    n > 1 ? [name * CTBase.ctindices(i) for i in range(1, n)] : [name]

"""
$(TYPEDSIGNATURES)

Return the default name of the time variable.

# Returns
- `String`: The default time name (`"t"`).
"""
__time_name()::String = "t"

"""
$(TYPEDSIGNATURES)

Return the default name for optimization variables.

# Arguments
- `q::Dimension`: The variable dimension.

# Returns
- `String`: The variable name (`"v"` for q>0, empty string for q=0).
"""
function __variable_name(q::Dimension)::String
    return q > 0 ? "v" : ""
end

"""
$(TYPEDSIGNATURES)

Return the default component names for a variable of dimension `q`.

# Arguments
- `q::Dimension`: The variable dimension.
- `name::String`: The base name for components.

# Returns
- `Vector{String}`: Component names (empty for q=0, single element for q=1, subscripted for q>1).
"""
function __variable_components(q::Dimension, name::String)::Vector{String}
    if q == 0
        return String[]
    else
        return q > 1 ? [name * CTBase.ctindices(i) for i in range(1, q)] : [name]
    end
end

"""
$(TYPEDSIGNATURES)

Return the default filename (without extension) for exporting and importing solutions.

# Returns
- `String`: The default filename (`"solution"`).
"""
__filename_export_import() = "solution"

"""
$(TYPEDSIGNATURES)

Return the default control interpolation type.

# Returns
- `Symbol`: The interpolation type (`:constant` for piecewise constant, `:linear` for piecewise linear).
"""
__control_interpolation()::Symbol = :constant

"""
$(TYPEDSIGNATURES)

Return the default component for time grid access in multiple time grid solutions.

# Returns
- `Symbol`: The default component (`:state`).
"""
__time_grid_default_component()::Symbol = :state
