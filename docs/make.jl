using Documenter
using CTModels

repo_url = "github.com/control-toolbox/CTModels.jl"

makedocs(;
    remotes=nothing,
    warnonly=[:cross_references, :autodocs_block],
    sitename="CTModels",
    format=Documenter.HTML(;
        repolink="https://" * repo_url,
        prettyurls=false,
        size_threshold_ignore=["api.md", "dev.md"],
        assets=[
            asset("https://control-toolbox.org/assets/css/documentation.css"),
            asset("https://control-toolbox.org/assets/js/documentation.js"),
        ],
    ),
    pages=["Introduction" => "index.md", "API" => "api.md"],
    checkdocs=:none,
)

deploydocs(; repo=repo_url * ".git", devbranch="main")
