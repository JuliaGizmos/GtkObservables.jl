using GtkObservables, Gtk4

r=1:10:91
#r=0.1:0.05:10 also works
n = slider(r; snap=true)

mainwin = GtkWindow("GtkObservables", 300, 200)
vbox = GtkBox(:v)
push!(vbox, GtkLabel("Demonstrates slider that snaps to $(r)"))
push!(vbox, n)
push!(mainwin, vbox)
show(mainwin)

