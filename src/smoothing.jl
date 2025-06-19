using Statistics
using Dierckx
using OptimalControl

function moving_average(u::Vector{<:Real}, window::Int=10)
    return [mean(u[max(1,i-((window-1)÷2)):min(end,i+((window-1)÷2))]) for i in 1:length(u)]
end


function selective_moving_average(u::Vector{<:Real}; window::Int=3, threshold::Float64=0.5, ratio::Float64=0.6)
    n = length(u)
    result = similar(u)
    half_window = (window-1) ÷ 2
    for i in 1:n
        left = max(1, i-half_window)
        right = min(n, i+half_window)
        window_vals = u[left:right]
        ref = median(window_vals)
        n_far = count(abs.(window_vals .- ref) .> threshold)
        if n_far > ratio * length(window_vals)
            result[i] = u[i]
        else
            result[i] = mean(window_vals)
        end
    end
    return result
end

function smooth_with_splines(x, y; s=0.4)
    spline = Spline1D(x, y; s=s)
    x_smooth = range(extrema(x)..., length=100)
    y_smooth = spline(x_smooth)
    return x_smooth, y_smooth
end

"""
    smooth_control(sol; method::Symbol, window::Int=3, threshold::Float64=0.5, ratio::Float64=0.6, spline::Float64=0.4, x=nothing)

Smooths the control vector `u` using the specified method.

# Arguments
- `sol`: The solution object containing the control vector to be smoothed.
- `method::Symbol`: The smoothing method to use. Supported values are:
    - `:moving_average`: Applies a moving average filter.
    - `:selective_moving_average`: Applies a selective moving average based on a threshold.
    - `:smooth_with_splines`: Smooths the control using spline interpolation.
- `window::Int=3`: The window size for the moving average methods.
- `threshold::Float64=0.5`: The threshold parameter for selective moving average.
- `ratio::Float64=0.6`: The ratio parameter for selective moving average.
- `spline::Float64=0.4`: The smoothing parameter for spline interpolation.
- `x=nothing`: Optional argument for specifying the x-coordinates for spline smoothing.

# Returns
- The smoothed control vector.

# Examples

"""
function smooth_control(sol; method::Symbol=:smooth_with_splines, window::Int=3, threshold::Float64=0.5, ratio::Float64=0.6, spline::Float64=0.4, x=nothing)
    u = control(sol)
    t_grid = time_grid(sol)
    u_disc = [u(ti) for ti in t_grid]

    if method == :moving_average
        u_disc_smooth = moving_average(u_disc, window)
        spline_fn = Spline1D(t_grid, u_disc_smooth)
        u_smooth = t -> spline_fn(t)

    elseif method == :selective_moving_average
        u_disc_smooth = selective_moving_average(u_disc; window=window, threshold=threshold, ratio=ratio)
        spline_fn = Spline1D(t_grid, u_disc_smooth)
        u_smooth = t -> spline_fn(t)
        
    elseif method == :smooth_with_splines
        t_spline, u_disc_smooth_spline = smooth_with_splines(t_grid, u_disc; s=spline)
        spline_fn = Spline1D(t_spline, u_disc_smooth_spline)
        u_smooth = t -> spline_fn(t)
    else
        error("Méthode de lissage inconnue : $method")
    end
    return u_smooth
end
