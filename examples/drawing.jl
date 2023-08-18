using Gtk4, GtkObservables, Colors, Observables

win = GtkWindow("Drawing")
c = canvas(UserUnit)       # create a canvas with user-specified coordinates
push!(win, c)

const lines = Observable([])   # the list of lines that we'll draw
const newline = Observable([]) # the in-progress line (will be added to list above)

# Add mouse interactions
const drawing = Observable(false)  # this will be true if we're dragging a new line
sigstart = on(c.mouse.buttonpress) do btn
    if btn.button == 1 && btn.modifiers == 0
        drawing[] = true   # start extending the line
        newline[] = [btn.position]
    end
end

const dummybutton = MouseButton{UserUnit}()
sigextend = on(c.mouse.motion) do btn
    if drawing[]
        push!(newline[], btn.position)
        Observables.notify(newline)
    end
end

sigend = on(c.mouse.buttonrelease) do btn
    if btn.button == 1
        drawing[] = false  # stop extending the line
        push!(lines[], newline[])
        newline.val = []
        Observables.notify(lines)
    end
end

# Draw on the canvas
redraw = draw(c, lines, newline) do cnvs, lns, newl
    fill!(cnvs, colorant"white")   # background is white
    set_coordinates(cnvs, BoundingBox(0, 1, 0, 1))  # set coords to 0..1 along each axis
    ctx = getgc(cnvs)
    for l in lns
        drawline(ctx, l, colorant"blue")
    end
    drawline(ctx, newl, colorant"red")
end

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
