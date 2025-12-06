# ------------------------------------------------------------------------------ #
# Initial guess types for continuous-time OCPs
# ------------------------------------------------------------------------------ #
abstract type AbstractOptimalControlInitialGuess end

struct OptimalControlInitialGuess{X<:Function,U<:Function,V} <:
       AbstractOptimalControlInitialGuess
    state::X
    control::U
    variable::V
end

abstract type AbstractOptimalControlPreInit end

struct OptimalControlPreInit{SX,SU,SV} <: AbstractOptimalControlPreInit
    state::SX
    control::SU
    variable::SV
end
