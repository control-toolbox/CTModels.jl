# Utility functions for discretizing functions on time grids
# Used for serialization (JSON, JLD2) and solution reconstruction

"""
    _discretize_function(f::Function, T::AbstractVector, dim::Int=-1)::Matrix{Float64}

Discrétise une fonction sur une grille temporelle.

# Arguments
- `f::Function`: Fonction à discrétiser (peut retourner scalaire ou vecteur)
- `T::AbstractVector`: Grille temporelle (ou TimeGridModel)
- `dim::Int`: Dimension attendue du résultat. Si -1, auto-détectée depuis la première évaluation.

# Returns
- `Matrix{Float64}`: Matrice n×dim où n = length(T)

# Examples
```julia
# Fonction scalaire
f_scalar = t -> 2.0 * t
result = _discretize_function(f_scalar, [0.0, 0.5, 1.0], 1)
# result = [0.0; 1.0; 2.0]

# Fonction vectorielle
f_vec = t -> [t, 2*t]
result = _discretize_function(f_vec, [0.0, 0.5, 1.0], 2)
# result = [0.0 0.0; 0.5 1.0; 1.0 2.0]

# Auto-détection de dimension
result = _discretize_function(f_vec, [0.0, 0.5, 1.0])
# result = [0.0 0.0; 0.5 1.0; 1.0 2.0]
```
"""
function _discretize_function(f::Function, T::AbstractVector, dim::Int=-1)::Matrix{Float64}
    n = length(T)
    
    # Auto-détecter dimension si nécessaire
    if dim == -1
        first_val = f(T[1])
        dim = first_val isa Number ? 1 : length(first_val)
    end
    
    result = Matrix{Float64}(undef, n, dim)
    for (i, t) in enumerate(T)
        val = f(t)
        if dim == 1
            result[i, 1] = val isa Number ? val : val[1]
        else
            result[i, :] = val
        end
    end
    return result
end

"""
    _discretize_function(f::Function, T::TimeGridModel, dim::Int=-1)::Matrix{Float64}

Surcharge pour TimeGridModel - extrait automatiquement la grille temporelle.
"""
function _discretize_function(f::Function, T::TimeGridModel, dim::Int=-1)::Matrix{Float64}
    return _discretize_function(f, T.value, dim)
end

"""
    _discretize_dual(dual_func::Union{Function,Nothing}, T, dim::Int=-1)

Helper pour discrétiser les fonctions duales qui peuvent être `nothing`.

# Arguments
- `dual_func`: Fonction duale ou `nothing`
- `T`: Grille temporelle
- `dim`: Dimension (auto-détectée si -1)

# Returns
- `Matrix{Float64}` si `dual_func` est une fonction
- `nothing` si `dual_func` est `nothing`
"""
function _discretize_dual(dual_func::Union{Function,Nothing}, T, dim::Int=-1)
    return isnothing(dual_func) ? nothing : _discretize_function(dual_func, T, dim)
end
