# ------------------------------------------------------------------------------ #
# Initial guess types for continuous-time OCPs
# ------------------------------------------------------------------------------ #
"""
$(TYPEDEF)

Abstract base type for initial guesses used in optimal control problem solvers.

Subtypes provide initial trajectories for state, control, and optimisation variables
to warm-start numerical solvers.

See also: [`OptimalControlInitialGuess`](@ref).
"""
abstract type AbstractOptimalControlInitialGuess end

"""
$(TYPEDEF)

Concrete initial guess for an optimal control problem, storing callable
trajectories for state and control, and a value for the optimisation variable.

# Fields

- `state::X`: A function `t -> x(t)` returning the state guess at time `t`.
- `control::U`: A function `t -> u(t)` returning the control guess at time `t`.
- `variable::V`: The initial guess for the optimisation variable (scalar or vector).

# Example

```julia-repl
julia> using CTModels

julia> x_guess = t -> [cos(t), sin(t)]
julia> u_guess = t -> [0.5]
julia> v_guess = [1.0, 2.0]
julia> ig = CTModels.OptimalControlInitialGuess(x_guess, u_guess, v_guess)
```
"""
struct OptimalControlInitialGuess{X<:Function,U<:Function,V} <:
       AbstractOptimalControlInitialGuess
    state::X
    control::U
    variable::V
end

"""
$(TYPEDEF)

Abstract base type for pre-initialisation data used before constructing a full
initial guess.

Subtypes store raw or partial information that will be processed into an
[`OptimalControlInitialGuess`](@ref).

See also: [`OptimalControlPreInit`](@ref).
"""
abstract type AbstractOptimalControlPreInit end

"""
$(TYPEDEF)

Pre-initialisation container for initial guess data before validation and
interpolation.

# Fields

- `state::SX`: Raw state data (e.g., matrix, vector of vectors, or function).
- `control::SU`: Raw control data (e.g., matrix, vector of vectors, or function).
- `variable::SV`: Raw optimisation variable data (scalar, vector, or `nothing`).

# Example

```julia-repl
julia> using CTModels

julia> pre = CTModels.OptimalControlPreInit([1.0 2.0; 3.0 4.0], [0.5, 0.6], [1.0])
```
"""
struct OptimalControlPreInit{SX,SU,SV} <: AbstractOptimalControlPreInit
    state::SX
    control::SU
    variable::SV
end
