using Documenter
using CTModels
using CTBase  # For automatic_reference_documentation
using Plots
using JSON3
using JLD2
using Markdown
using MarkdownAST: MarkdownAST

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════
draft = false  # Draft mode: if true, @example blocks in markdown are not executed

# ═══════════════════════════════════════════════════════════════════════════════
# Load extensions
# ═══════════════════════════════════════════════════════════════════════════════
const CTModelsPlots = Base.get_extension(CTModels, :CTModelsPlots)
const CTModelsJSON = Base.get_extension(CTModels, :CTModelsJSON)
const CTModelsJLD = Base.get_extension(CTModels, :CTModelsJLD)
const DocumenterReference = Base.get_extension(CTBase, :DocumenterReference)

# Reset DocumenterReference configuration for proper local/remote link generation
if !isnothing(DocumenterReference)
    DocumenterReference.reset_config!()
end

# to add docstrings from external packages
Modules = [Plots, CTModelsPlots, CTModelsJSON, CTModelsJLD]
for Module in Modules
    isnothing(DocMeta.getdocmeta(Module, :DocTestSetup)) &&
        DocMeta.setdocmeta!(Module, :DocTestSetup, :(using $Module); recursive=true)
end

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
    makedocs(;
        draft=draft,
        remotes=nothing,  # Disable remote links. Needed for DocumenterReference
        warnonly=true,
        sitename="CTModels.jl",
        format=Documenter.HTML(;
            repolink="https://" * repo_url,
            prettyurls=false,
            #size_threshold_ignore=["api.md", "dev.md"],
            #size_threshold=300_000,  # 300 KiB threshold
            assets=[
                asset("https://control-toolbox.org/assets/css/documentation.css"),
                asset("https://control-toolbox.org/assets/js/documentation.js"),
            ],
        ),
        checkdocs=:none,
        pages=[
            "Introduction" => "index.md",
            "Interfaces" => [
                "OCP Tools" => "interfaces/ocp_tools.md",
                "Optimization Problems" => "interfaces/optimization_problems.md",
                "Optimization Modelers" => "interfaces/optimization_modelers.md",
                "Solution Builders" => "interfaces/ocp_solution_builders.md",
            ],
            "API Reference" => api_pages,
        ],
    )
end

# ═══════════════════════════════════════════════════════════════════════════════
deploydocs(; repo=repo_url * ".git", devbranch="main")
