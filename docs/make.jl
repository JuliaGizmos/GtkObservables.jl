using Documenter, GtkObservables, TestImages
testimage("lighthouse")    # ensure all artifacts get downloaded before running tests

makedocs(sitename = "GtkObservables",
         format   = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
         pages    = ["index.md", "controls.md", "drawing.md", "zoom_pan.md", "reference.md"]
         )

deploydocs(repo         = "github.com/JuliaGizmos/GtkObservables.jl.git",
           push_preview = true,
           )
