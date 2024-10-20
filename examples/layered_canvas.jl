using Gtk4, GtkObservables, TestImages, Colors

img=testimage("mandrill")
lc=GtkObservables.LayeredCanvas()
bgcolor=Observable(colorant"blue")
push!(lc.layers, GtkObservables.FillLayer(bgcolor))

on(bgcolor) do val
    reveal(lc)
end

win=GtkWindow("layered canvas")
win[]=lc

