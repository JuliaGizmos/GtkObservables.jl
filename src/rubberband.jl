"""
    signals = init_zoom_rubberband(canvas::GtkObservables.Canvas,
                                   zr::Observable{ZoomRegion},
                                   initiate = btn->(btn.button == 1 && btn.clicktype == BUTTON_PRESS && btn.modifiers == CONTROL),
                                   reset = btn->(btn.button == 1 && btn.clicktype == DOUBLE_BUTTON_PRESS && btn.modifiers == CONTROL),
                                   minpixels = 2)

Initialize rubber-band selection that updates `zr`. `signals` is a
dictionary holding the Observables.jl signals needed for rubber-banding;
you can push `true/false` to `signals["enabled"]` to turn rubber
banding on and off, respectively. Your application is responsible for
making sure that `signals` does not get garbage-collected (which would
turn off rubberbanding).

`initiate(btn)` returns `true` when the condition for starting a
rubber-band selection has been met (by default, clicking mouse button
1). The argument `btn` is a [`MouseButton`](@ref) event. `reset(btn)`
returns true when restoring the full view (by default, double-clicking
mouse button 1). `minpixels` can be used for aborting rubber-band
selections smaller than some threshold.
"""
function init_zoom_rubberband(canvas::Canvas{U},
                              zr::Observable{ZoomRegion{T}},
                              @nospecialize(initiate::Function) = zrb_init_default,
                              @nospecialize(reset::Function) = zrb_reset_default,
                              minpixels::Integer = 2) where {U,T}
    enabled = Observable(true)
    active = Observable(false)
    function update_zr(widget, bb)
        active[] = false
        fv = zr[].fullview
        zr[] = ZoomRegion(fv, XY(interior(bb.xmin..bb.xmax, fv.x),
                                 interior(bb.ymin..bb.ymax, fv.y))
                          )
        nothing
    end
    rb = RubberBand(XY{U}(-1,-1), XY{U}(-1,-1), false, minpixels)
    ctxcopy = Ref{Cairo.CairoContext}()
    init = on(canvas.mouse.buttonpress; weak=true) do btn::MouseButton{U}
        if enabled[]
            if initiate(btn)
                active[] = true
                ctxcopy[] = copy(getgc(canvas))
                rb.pos1 = rb.pos2 = btn.position
            elseif reset(btn)
                active[] = false  # double-clicks need to cancel the previous single-click
                zr[] = GtkObservables.reset(zr[])
            end
        end
        nothing
    end
    drag = on(canvas.mouse.motion; weak=true) do btn::MouseButton{U}
        if active[]
            btn.button == 0 && return nothing
            rubberband_move(canvas, rb, btn, ctxcopy[])
        end
    end
    finish = on(canvas.mouse.buttonrelease; weak=true) do btn::MouseButton{U}
        if active[]
            btn.button == 0 && return nothing
            active[] = false
            rubberband_stop(canvas, rb, btn, ctxcopy[], update_zr)
        end
    end
    Dict{String,Any}("enabled"=>enabled, "active"=>active, "init"=>init, "drag"=>drag, "finish"=>finish)
end

zrb_init_default(btn) = btn.button == 1 && btn.clicktype == BUTTON_PRESS && btn.n_press == 1 && (btn.modifiers & 0x0f) == UInt32(CONTROL)
zrb_reset_default(btn) = btn.button == 1 && btn.clicktype == BUTTON_PRESS && btn.n_press == 2 && (btn.modifiers & 0x0f) == UInt32(CONTROL)

# For rubberband, we draw the selection region on the front canvas, and repair
# by copying from the back.
mutable struct RubberBand{U}
    pos1::XY{U}
    pos2::XY{U}
    moved::Bool
    minpixels::Int
end

const dash   = Float64[3.0,3.0]
const nodash = Float64[]

function rb_erase(r::GraphicsContext, rb::RubberBand, ctxcopy)
    # Erase the previous rubberband by copying from back surface to front
    rb_set(r, rb)
    # Because line widths are expressed in pixels, let's go to device units
    save(r)
    reset_transform(r)
    save(ctxcopy)
    reset_transform(ctxcopy)
    set_source(r, ctxcopy)
    set_line_width(r, 3)
    set_dash(r, nodash)
    stroke(r)
    restore(r)
    restore(ctxcopy)
end

function rb_draw(r::GraphicsContext, rb::RubberBand)
    rb_set(r, rb)
    save(r)
    reset_transform(r)
    set_line_width(r, 1)
    set_dash(r, dash, 3.0)
    set_source_rgb(r, 1, 1, 1)
    stroke_preserve(r)
    set_dash(r, dash, 0.0)
    set_source_rgb(r, 0, 0, 0)
    stroke(r)
    restore(r)
end

function rb_set(r::GraphicsContext, rb::RubberBand)
    x1, y1 = rb.pos1.x, rb.pos1.y
    x2, y2 = rb.pos2.x, rb.pos2.y
    rectangle(r, x1, y1, x2 - x1, y2 - y1)
end

function rubberband_move(c::Canvas, rb::RubberBand, btn, ctxcopy)
    if btn.button == 0
        return nothing
    end
    r = getgc(c)
    if rb.moved
        rb_erase(r, rb, ctxcopy)
    end
    rb.moved = true
    # Draw the new rubberband
    rb.pos2 = btn.position
    rb_draw(r, rb)
    reveal(c)
    nothing
end

function rubberband_stop(c::GtkObservables.Canvas, rb::RubberBand, btn, ctxcopy, callback_done)
    if !rb.moved
        return nothing
    end
    r = getgc(c)
    rb_set(r, rb)
    rb_erase(r, rb, ctxcopy)
    reveal(c)
    pos = btn.position
    x, y = pos.x, pos.y
    x1, y1 = rb.pos1.x, rb.pos1.y
    xd, yd = convertunits(DeviceUnit, r, x, y)
    x1d, y1d = convertunits(DeviceUnit, r, x1, y1)
    if abs(x1d-xd) > rb.minpixels || abs(y1d-yd) > rb.minpixels
        # It moved sufficiently, let's execute the callback
        bb = BoundingBox(min(x1,x), max(x1,x), min(y1,y), max(y1,y))
        callback_done(c, bb)
    end
    nothing
end
