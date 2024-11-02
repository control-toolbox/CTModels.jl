using Documenter

repo_url = "github.com/control-toolbox/CTModels.jl"

makedocs(;
    remotes=nothing,
    warnonly=:cross_references,
    sitename="CTModels",
    format=Documenter.HTML(;
        repolink="https://" * repo_url,
        prettyurls=false,
        size_threshold_ignore=["index.md"],
        assets=[
            asset("https://control-toolbox.org/assets/css/documentation.css"),
            asset("https://control-toolbox.org/assets/js/documentation.js"),
        ],
    ),
    pages=["Introduction" => "index.md"],
)

deploydocs(; repo=repo_url * ".git", devbranch="main")
