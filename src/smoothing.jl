using Statistics
using Dierckx
using OptimalControl

function moving_average(u::AbstractVector{<:Real}, t_grid::Vector{Float64}; window::Int=10)
    u_disc = [u(ti) for ti in t_grid]
    result = [mean(u_disc[max(1,i-((window-1)÷2)):min(end,i+((window-1)÷2))]) for i in 1:length(u)]
    u_smoothed = CTModels.ctinterpolate(t_grid, result)
    return u_smoothed
end

function selective_moving_average(u::AbstractVector{<:Real}, t_grid::Vector{Float64}; window::Int=3, threshold::Float64=0.5, ratio::Float64=0.6)
    u_disc = [u(ti) for ti in t_grid]
    n = length(u_disc)
    result = u_disc
    half_window = (window-1) ÷ 2
    for i in 1:n
        left = max(1, i-half_window)
        right = min(n, i+half_window)
        window_vals = u_disc[left:right]
        ref = median(window_vals)
        n_far = count(abs.(window_vals .- ref) .> threshold)
        if n_far > ratio * length(window_vals)
            result[i] = u_disc[i]
        else
            result[i] = mean(window_vals)
        end
    end
    u_smoothed = CTModels.ctinterpolate(t_grid, result)
    return u_smoothed
end

function smooth_with_splines(t_grid::Vector{Float64}, u::Function; s::Float64=0.4)
    u_disc = [u(ti) for ti in t_grid] 
    spline = Spline1D(t_grid, u_disc; s=s)
    t_smooth = range(extrema(t_grid)..., length=100)
    u_smooth = spline(t_smooth)
    u_smoothed = CTModels.ctinterpolate(t_smooth, u_smooth)
    return u_smoothed
end


"""
    smooth_control(sol, method::Symbol; window::Int=3, threshold::Float64=0.5, ratio::Float64=0.6, spline::Float64=0.4, x=nothing)

Lisse le vecteur `u` selon la méthode choisie :
- :moving_average
- :selective_moving_average
- :smooth_with_splines (nécessite l'argument `x`)
"""
function smooth_control(sol; method::Symbol=:smooth_with_splines, window::Int=3, threshold::Float64=0.5, ratio::Float64=0.6, spline::Float64=0.4)
    u = control(sol)
    t_grid = time_grid(sol)  # suppose que vous avez une fonction pour récupérer la grille de temps

    if method == :moving_average
        u_smooth = moving_average(u, t_grid; window=window)
    elseif method == :selective_moving_average
        u_smooth = selective_moving_average(u, t_grid; window=window, threshold=threshold, ratio=ratio)
    elseif method == :smooth_with_splines
        u_smooth = smooth_with_splines(t_grid, u; s=spline)
    else
        error("Méthode de lissage inconnue : $method")
    end
    return u_smooth
end
