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
            "User Guide" => [
                "Defining Problems" => "interfaces/optimization_problems.md",
                "Building Solutions" => "interfaces/ocp_solution_builders.md",
            ],
            "Developer Guide" => [
                "Tutorials" => [
                    "Creating a Strategy" => "tutorials/creating_a_strategy.md",
                    "Creating a Strategy Family" => "tutorials/creating_a_strategy_family.md",
                ],
                "Interfaces" => [
                    "Strategies" => "interfaces/strategies.md",
                    "Strategy Families" => "interfaces/strategy_families.md",
                    "Orchestration & Routing" => "interfaces/orchestration.md",
                    "Optimization Modelers" => "interfaces/optimization_modelers.md",
                ],
                "Examples" => [
                    "Simple Strategy" => "examples/simple_strategy.md",
                    "Strategy with Options" => "examples/strategy_with_options.md",
                    "Strategy Family" => "examples/strategy_family.md",
                    "Option Routing" => "examples/routing_example.md",
                    "Integration Example" => "examples/integration_example.md",
                    "Migration Example" => "examples/migration_example.md",
                ],
            ],
            "API Reference" => [
                "Public API" => [
                    "Options" => "options/options_public.md",
                    "Strategies (Contract)" => "strategies/strategies_contract_public.md",
                    "Strategies (API)" => "strategies/strategies_api_public.md",
                    "Orchestration" => "orchestration/orchestration_public.md",
                ],
                "Internal API" => [
                    "Options (Internal)" => "options/options_internal.md",
                    "Strategies Contract (Internal)" => "strategies/strategies_contract_internal.md",
                    "Strategies API (Internal)" => "strategies/strategies_api_internal.md",
                    "Orchestration (Internal)" => "orchestration/orchestration_internal.md",
                ],
                "Core & OCP" => api_pages,
            ],
        ],
    )
end

# ═══════════════════════════════════════════════════════════════════════════════
deploydocs(; repo=repo_url * ".git", devbranch="main")
