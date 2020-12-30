using GtkObservables, Gtk.ShortNames, Colors

# Create some controls
n = slider(1:10)
dd = dropdown(["one"=>()->println("you picked \"one\""),
               "two"=>()->println("two for tea"),
               "three"=>()->println("three is a magic number")],
              label="dropdown")
cb = checkbox(true, label="make window visible")

# To illustrate some of Observables's propagation, we create a textbox
# that shares the observable with the slider.
tb = textbox(Int; observable=n.observable)

# Set up the mapping for the dropdown callbacks
cbhandle = on(dd.mappedsignal) do cb  # assign to variable to prevent garbage collection
    cb()
end

# Lay out the GUI. You can alternatively use `glade` and pass the
# widgets to the constructors above (see the implementation of
# `player` in `extrawidgets.jl` for an example).
mainwin = Window("GtkObservables")
vbox = Box(:v)
hbox = Box(:h)
push!(vbox, hbox)
push!(hbox, n)
push!(hbox, tb)
push!(vbox, dd)
push!(vbox, cb)
push!(mainwin, vbox)

# Create the auxillary window and link its visibility to the checkbox
cnvs = canvas()
auxwin = Window(cnvs)
showwin = map(cb) do val
    set_gtk_property!(auxwin, :visible, val)
end
# Also make sure it gets destroyed when we destroy the main window
signal_connect(mainwin, :destroy) do w
    destroy(auxwin)
end
# Draw something in the auxillary window
draw(cnvs) do c
    fill!(c, colorant"orange")
end
Gtk.showall(auxwin)

Gtk.showall(mainwin)
