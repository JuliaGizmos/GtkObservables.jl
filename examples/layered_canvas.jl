using Gtk4, GtkObservables, TestImages, Colors, Cairo

img=testimage("mandrill")
lc=GtkObservables.LayeredCanvas{UserUnit}()
bgcolor=Observable(colorant"blue")
push!(lc.layers, GtkObservables.FillLayer(bgcolor))

function drawline(ctx, l, color)
    isempty(l) && return
    p = first(l)
    move_to(ctx, p.x, p.y)
    set_source(ctx, color)
    for i = 2:length(l)
        p = l[i]
        line_to(ctx, p.x, p.y)
    end
    stroke(ctx)
end

cc=GtkObservables.CairoLayer() do ctx
    println("draw")
    drawline(ctx, [Point(1,1),Point(20,20)], colorant"yellow")
end

push!(lc.layers, cc)

on(bgcolor) do val
    reveal(lc)
end

win=GtkWindow("layered canvas")
win[]=lc

