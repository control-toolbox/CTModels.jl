# to run the documentation generation: julia --project=. docs/make.jl
# to serve the documentation (option 1 — handles clean URLs natively):
#   npx serve docs/build/1 --listen 5173
# to serve the documentation (option 2 — Julia only):
#   julia --project=docs -e 'using LiveServer; LiveServer.serve(dir="docs/build/1", single_page=true)'
# note: single_page=true is required so that reloading /getting-started serves the correct HTML
pushfirst!(LOAD_PATH, joinpath(@__DIR__))
pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using DocumenterVitepress
using DocumenterInterLinks
using CTModels
using CTBase
using Markdown
using MarkdownAST: MarkdownAST

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════
draft = false # Draft mode: if true, @example blocks in markdown are not executed

# ═══════════════════════════════════════════════════════════════════════════════
# Cross-package links (InterLinks)
# ═══════════════════════════════════════════════════════════════════════════════
links = InterLinks(
    "CTBase" => (
        "https://control-toolbox.org/CTBase.jl/dev/",
        "https://control-toolbox.org/CTBase.jl/dev/objects.inv",
    ),
)

# ═══════════════════════════════════════════════════════════════════════════════
# Extensions
# ═══════════════════════════════════════════════════════════════════════════════
const DocumenterReference = Base.get_extension(CTBase, :DocumenterReference)

if !isnothing(DocumenterReference)
    DocumenterReference.reset_config!()
end

# ═══════════════════════════════════════════════════════════════════════════════
# Docstrings from external packages
# ═══════════════════════════════════════════════════════════════════════════════
using JLD2, JSON3, Plots
const CTModelsJLD = Base.get_extension(CTModels, :CTModelsJLD)
const CTModelsJSON = Base.get_extension(CTModels, :CTModelsJSON)
const CTModelsPlots = Base.get_extension(CTModels, :CTModelsPlots)

# ═══════════════════════════════════════════════════════════════════════════════
# Paths
# ═══════════════════════════════════════════════════════════════════════════════
repo_url = "github.com/control-toolbox/CTModels.jl"
src_dir = abspath(joinpath(@__DIR__, "..", "src"))
ext_dir = abspath(joinpath(@__DIR__, "..", "ext"))

# Include the API reference manager
include("api_reference.jl")

# ═══════════════════════════════════════════════════════════════════════════════
# Build documentation
# ═══════════════════════════════════════════════════════════════════════════════
with_api_reference(src_dir, ext_dir) do api_pages
    return makedocs(;
        draft=draft,
        remotes=nothing,
        warnonly=[:cross_references, :external_cross_references],
        sitename="CTModels.jl",
        format=DocumenterVitepress.MarkdownVitepress(;
            repo=repo_url, devbranch="main", devurl="dev", sidebar_drawer=true
        ),
        pages=[
            # index.md is the VitePress root — not listed here
            "Getting Started" => "getting-started.md",
            "Performance" => joinpath("guide", "performance.md"),
            "OCP Model" => [
                "Overview" => joinpath("model", "overview.md"),
                "Types & Traits" => joinpath("model", "types_and_traits.md"),
                "Components" => joinpath("model", "components.md"),
                "Dynamics & Objective" => joinpath("model", "dynamics_objective.md"),
                "Constraints" => joinpath("model", "constraints.md"),
                "Building a Model" => joinpath("model", "building.md"),
                "Displaying Models" => joinpath("model", "display.md"),
            ],
            "Solutions" => [
                "Overview" => joinpath("solution", "overview.md"),
                "Time Grids" => joinpath("solution", "time_grids.md"),
                "Trajectories" => joinpath("solution", "trajectories.md"),
                "Duals & Diagnostics" => joinpath("solution", "duals.md"),
            ],
            "Initial Guesses" => [
                "Overview" => joinpath("initial_guess", "overview.md"),
                "Input Formats" => joinpath("initial_guess", "formats.md"),
                "Validation" => joinpath("initial_guess", "validation.md"),
            ],
            "Extensions" => [
                "Overview" => joinpath("serialization", "overview.md"),
                "Export & Import" => joinpath("serialization", "export_import.md"),
                "Plotting" => joinpath("serialization", "plotting.md"),
            ],
            "API Reference" => api_pages,
        ],
        plugins=[links],
    )
end

# ═══════════════════════════════════════════════════════════════════════════════
# Deploy documentation to GitHub Pages
# ═══════════════════════════════════════════════════════════════════════════════
bases_file = joinpath(@__DIR__, "build", "bases.txt")
if isfile(bases_file)
    DocumenterVitepress.deploydocs(;
        repo=repo_url * ".git", devbranch="main", push_preview=true
    )
else
    @info "Skipping deployment: no bases were built (prerelease with existing higher stable release)."
end
