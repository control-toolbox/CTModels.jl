"""
    PlotCase

Backend-free optimal-control **case layer** for the [`CTBase.Plotting`](@extref) engine.

It owns the optimal-control plotting vocabulary (`:state`, `:costate`, `:control`,
`:path`, `:dual`), turns a [`CTModels.Solutions.Solution`](@extref) plus a
`description` into [`CTBase.Plotting.Panel`](@extref)s via the semantic accessors,
adds the reference-line decorations (box bounds, initial/final time), assembles the
layout template, and produces a [`CTBase.Plotting.Figure`](@extref).

It carries **no rendering geometry and no backend dependency**: the concrete
`Plots.plot` / `Makie.plot` methods live in the `CTModelsPlots` / `CTModelsMakie`
extensions, which call [`CTModels.PlotCase.build_figure`](@extref) and hand the
figure to a [`CTBase.Plotting.render`](@extref) backend.
"""
module PlotCase

using DocStringExtensions: TYPEDSIGNATURES

using CTBase: Plotting
using CTBase: Exceptions

using ..Components
using ..Models
using ..Building
using ..Solutions

# The case-layer files were written against the flat `CTModels.<accessor>` API
# (state, control, model, initial_time, …). `PlotCase` is a submodule of `CTModels`,
# so bind that name here and keep the files verbatim — the accessors resolve at
# call time from the fully-loaded parent module.
const CTModels = parentmodule(@__MODULE__)

include(joinpath(@__DIR__, "vocabulary.jl"))
include(joinpath(@__DIR__, "panels.jl"))
include(joinpath(@__DIR__, "decorations.jl"))
include(joinpath(@__DIR__, "assemble.jl"))
include(joinpath(@__DIR__, "build.jl"))

end # module PlotCase
