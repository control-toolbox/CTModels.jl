"""
$(TYPEDSIGNATURES)

Used to set the default value for the constraints.
"""
__constraints() = nothing

"""
$(TYPEDSIGNATURES)

Used to set the default value of the format of the file to be used for export and import.
"""
__format() = :JLD

"""
$(TYPEDSIGNATURES)

Used to set the default value of the label of a constraint.
A unique value is given to each constraint using the `gensym` function and prefixing by `:unamed`.
"""
__constraint_label() = gensym(:unamed)

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the control.
The default value is `"u"`.
"""
__control_name()::String = "u"

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the controls.
The default value is `["u"]` for a one dimensional control, and `["u₁", "u₂", ...]` for a multi dimensional control.
"""
__control_components(m::Dimension, name::String)::Vector{String} =
    m > 1 ? [name * CTBase.ctindices(i) for i in range(1, m)] : [name]

"""
$(TYPEDSIGNATURES)

Used to set the default value of the type of criterion. Either :min or :max.
The default value is `:min`.
The other possible criterion type is `:max`.
"""
__criterion_type() = :min

"""
$(TYPEDSIGNATURES)

Used to set the default value of the name of the state.
The default value is `"x"`.
"""
__state_name()::String = "x"

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the states.
The default value is `["x"]` for a one dimensional state, and `["x₁", "x₂", ...]` for a multi dimensional state.
"""
__state_components(n::Dimension, name::String)::Vector{String} =
    n > 1 ? [name * CTBase.ctindices(i) for i in range(1, n)] : [name]

"""
$(TYPEDSIGNATURES)

Used to set the default value of the name of the time.
The default value is `t`.
"""
__time_name()::String = "t"

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the variables.
The default value is `"v"`.
"""
function __variable_name(q::Dimension)::String
    return q > 0 ? "v" : ""
end

"""
$(TYPEDSIGNATURES)

Used to set the default value of the names of the variables.
The default value is `["v"]` for a one dimensional variable, and `["v₁", "v₂", ...]` for a multi dimensional variable.
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

Used to set the default value of the storage of elements in a matrix.
The default value is `1`.
"""
__matrix_dimension_storage() = 1
