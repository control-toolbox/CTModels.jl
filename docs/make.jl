using Documenter
using CTModels
using Plots

# to add docstrings from external packages
Modules = [Plots]
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
    pages=["Introduction" => "index.md", "Developers" => "dev.md"],
    checkdocs=:none,
)

deploydocs(; repo=repo_url * ".git", devbranch="main")
