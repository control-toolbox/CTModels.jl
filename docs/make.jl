using Documenter
using CTModels
using Plots
using JSON3
using JLD2

const CTModelsPlots = Base.get_extension(CTModels, :CTModelsPlots)
const CTModelsJSON = Base.get_extension(CTModels, :CTModelsJSON)
const CTModelsJLD = Base.get_extension(CTModels, :CTModelsJLD)

# to add docstrings from external packages
Modules = [Plots, CTModelsPlots, CTModelsJSON, CTModelsJLD]
for Module in Modules
    isnothing(DocMeta.getdocmeta(Module, :DocTestSetup)) &&
        DocMeta.setdocmeta!(Module, :DocTestSetup, :(using $Module); recursive=true)
end

repo_url = "github.com/control-toolbox/CTModels.jl"

makedocs(;
    remotes=nothing,
    warnonly=[:cross_references, :autodocs_block],
    sitename="CTModels.jl",
    format=Documenter.HTML(;
        repolink="https://" * repo_url,
        prettyurls=false,
        size_threshold_ignore=["api.md", "dev.md"],
        assets=[
            asset("https://control-toolbox.org/assets/css/documentation.css"),
            asset("https://control-toolbox.org/assets/js/documentation.js"),
        ],
    ),
    pages=[
        "Introduction" => "index.md", 
        "API" => [
            "constraints.md",
            "control.md",
            "ctmodels.md",
            "default.md",
            "definition.md",
            "dual_model.md",
            "dynamics.md",
            "init.md",
            "jld.md",
            "json.md",
            "model.md",
            "objective.md",
            "plot.md",
            "print.md",
            "solution.md",
            "state.md",
            "time_dependence.md",
            "times.md",
            "types.md",
            "utils.md",
            "variable.md",
            ]
        ],
    checkdocs=:none,
)

deploydocs(; repo=repo_url * ".git", devbranch="main")
