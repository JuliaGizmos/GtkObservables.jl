mutable struct GtkGraphicsContext <: GraphicsContext
    transform::GskTransform
end

abstract type Layer end

layerchanged(layer) = nothing

mutable struct LayeredCanvas{U} <: GtkWidget
    handle::Ptr{GObject}
    layers::Vector{Layer}
    context::GtkGraphicsContext
    mouse::MouseHandler{U}
    user_bbox::Union{Nothing,BoundingBox}
    #action_group::Gtk4.GLib.GSimpleActionGroupLeaf
    #preserved::Vector{Any} # need?
    function LayeredCanvas{U}(handle::Ptr{GObject}, owns = false) where U
        if handle == C_NULL
            error("Cannot construct LayeredCanvas with a NULL pointer")
        end
        GLib.gobject_maybe_sink(handle, owns)
        canvas = gobject_ref(new(handle, Layer[], GtkGraphicsContext(GskTransform()), MouseHandler{U}(), nothing))
        _init_mouse_handler(canvas.mouse, canvas)
        canvas
    end
end

## FillLayer: fills the widget with a color

mutable struct FillLayer <: Layer
    canvas::Union{Nothing,LayeredCanvas}
    color::Observable
end

FillLayer(c::Color) = FillLayer(nothing, Observable(c))

function draw(layer::FillLayer, snapshot::GtkSnapshot, w::Integer, h::Integer)
    c = convert(GdkRGBA,layer.color[])
    Gtk4.G_.append_color(snapshot, c, GrapheneRect(0,0,w,h))
end

layerchanged(layer::FillLayer) = layer.color

## ImageLayer: draws an image

mutable struct ImageLayer <: Layer
    canvas::Union{Nothing,LayeredCanvas}
    imgo::Observable
end

ImageLayer() = ImageLayer(nothing, Observable(nothing))

function set_image!(layer::ImageLayer, imgo::Observable)
    layer.imgo = imgo
end

function draw(layer::ImageLayer, snapshot::GtkSnapshot, w::Integer, h::Integer)
    if isnothing(layer.imgo[])
        return
    end
    imgsize = size(layer.imgo[])
    texture = GdkMemoryTexture(layer.imgo[])
    # to preserve the "nearest" scaling in the method below, we transform back to device units
    Gtk4.G_.save(snapshot)
    Gtk4.G_.transform(snapshot, Gtk4.G_.invert(layer.canvas.context.transform))
    Gtk4.G_.append_scaled_texture(snapshot, texture, Gtk4.ScalingFilter_NEAREST, GrapheneRect(0,0,w,h))
    Gtk4.G_.restore(snapshot)
end

layerchanged(layer::ImageLayer) = layer.imgo

## CairoLayer: draws using Cairo

mutable struct CairoLayer <: Layer
    canvas::Union{Nothing,LayeredCanvas}
    draw::Union{Function, Nothing}
    preserved::Vector{Any}
    changed::Observable{Nothing}
end

CairoLayer() = CairoLayer(nothing,nothing,[],Observable(nothing))

layerchanged(layer::CairoLayer) = layer.changed

function draw(layer::CairoLayer, snapshot::GtkSnapshot, w::Integer, h::Integer)
    if layer.draw !== nothing
        # in order to allow cairo access to the true device units, we undo our global transform here
        Gtk4.G_.save(snapshot)
        Gtk4.G_.transform(snapshot, Gtk4.G_.invert(layer.canvas.context.transform))
        cr = Gtk4.G_.append_cairo(snapshot, GrapheneRect(0,0,w,h))
        cc = Cairo.CairoContext(Ptr{Nothing}(cr.handle))
        # apply global transform to cairo context
        set_coordinates(cc, BoundingBox(0, w, 0, h), layer.canvas.user_bbox)
        layer.draw(cc)
        Gtk4.G_.restore(snapshot)
    end
end

function setfunc(f::F, layer::CairoLayer) where F
    layer.draw = f
end

# drawfun should look like `f(cc, sigs...)`
function Gtk4.draw(drawfun::F, c::CairoLayer, signals::Observable...) where F
    setfunc(c) do cc
        drawfun(cc, map(getindex, signals)...)
    end
    drawfunc = onany(signals...) do values...
        notify(c.changed)
    end
    push!(c.preserved, drawfunc)
    drawfunc
end

## layered canvas widget implementation

function layered_canvas_measure(widget::Ptr{GObject}, orientation::Cint, for_size::Cint, minimum::Ptr{Cint}, natural::Ptr{Cint}, minimum_baseline::Ptr{Cint}, natural_baseline::Ptr{Cint})
    # could preserve aspect here
    unsafe_store!(minimum, Cint(100))
    unsafe_store!(natural, Cint(100))
    nothing
end

function layered_canvas_size_allocate(widget_ptr::Ptr{GObject}, w::Cint, h::Cint, baseline::Cint)
    widget = convert(LayeredCanvas, widget_ptr)
    if widget.user_bbox !== nothing
        set_coordinates(widget, BoundingBox(0, w, 0, h), widget.user_bbox)
    end
    nothing
end

function layered_canvas_snapshot(widget_ptr::Ptr{GObject}, snapshot_ptr::Ptr{GObject})
    widget = convert(LayeredCanvas, widget_ptr)
    snapshot = convert(GtkSnapshot, snapshot_ptr)
    Gtk4.G_.transform(snapshot, widget.context.transform)
    w,h = size(widget)
    for l in widget.layers
        draw(l, snapshot, w, h)
    end
    nothing
end

function layered_canvas_class_init(class::Ptr{_GObjectClass}, user_data)
    widget_klass_ptr = Ptr{_GtkWidgetClass}(class)
    widget_klass = unsafe_load(widget_klass_ptr)
    widget_klass.snapshot = @cfunction(layered_canvas_snapshot, Cvoid, (Ptr{GObject}, Ptr{GObject}))
    widget_klass.size_allocate = @cfunction(layered_canvas_size_allocate, Cvoid, (Ptr{GObject}, Cint, Cint, Cint))
    #widget_klass.measure = @cfunction(layered_canvas_measure, Cvoid, (Ptr{GObject}, Cint, Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}))
    unsafe_store!(widget_klass_ptr, widget_klass)
    nothing
end

function GLib.g_type(::Type{T}) where T <: LayeredCanvas
    gt = GLib.g_type_from_name(:LayeredCanvas)
    if gt > 0
        return gt
    else
        base_gtype = GLib.g_type(GtkWidget)
        tq=GLib.G_.type_query(base_gtype)
        typeinfo = _GTypeInfo(tq.class_size,
                        C_NULL,   # base_init
                        C_NULL,   # base_finalize
                        @cfunction(layered_canvas_class_init, Cvoid, (Ptr{_GObjectClass}, Ptr{Cvoid})),
                        C_NULL,   # class_finalize
                        C_NULL,   # class_data
                        tq.instance_size,
                        0,        # n_preallocs
                        C_NULL,   # instance_init
                        C_NULL)   # value_table
        ngt = GLib.G_.type_register_static(base_gtype,:LayeredCanvas,Ref(typeinfo),GLib.TypeFlags_FINAL)
        GLib.gtype_wrappers[:LayeredCanvas] = LayeredCanvas
        return ngt
    end
end

#function LayeredCanvas(handle::Ptr{GObject})
#    LayeredCanvas(handle, Layer[])
#    #mouse = MouseHandler{U}(modifier_ref)
#    #ag = Gtk4.GLib.GSimpleActionGroup()
#end

function add_layer!(c::LayeredCanvas, l::Layer)
    push!(c.layers, l)
    l.canvas = c
    # listen to observables
    if layerchanged(l) !== nothing
        on(layerchanged(l)) do _
            Gtk4.reveal(c)
        end
    end
end

function LayeredCanvas{U}() where U
    gtype = GLib.g_type(LayeredCanvas)
    h = ccall(("g_object_new", GLib.libgobject), Ptr{GObject}, (UInt64, Ptr{Cvoid}), gtype, C_NULL)
    LayeredCanvas{U}(h)
end

function XY{U}(w::GtkWidget, x::Float64, y::Float64) where U<:CairoUnit
    XY{U}(convertunits(U, w, DeviceUnit(x), DeviceUnit(y))...)
end

## Graphics interface

function Graphics.reset_transform(c::GtkGraphicsContext)
    c.transform = GskTransform()
    nothing
end

function Graphics.scale(c::GtkGraphicsContext, x::Real, y::Real)
    c.transform = Gtk4.G_.scale(c.transform, x, y)
    nothing
end

function Graphics.translate(c::GtkGraphicsContext, x::Real, y::Real)
    point = Gtk4.Graphene.GraphenePoint(x,y)
    c.transform = Gtk4.G_.translate(c.transform, point)
    nothing
end

function Graphics.user_to_device!(c::GtkGraphicsContext, p::Vector{Float64})
    point = Gtk4.Graphene.GraphenePoint(p[1],p[2])
    point2 = Gtk4.G_.transform_point(c.transform, point)
    p[1]=point2.x
    p[2]=point2.y
    p
end

function Graphics.device_to_user!(c::GtkGraphicsContext, p::Vector{Float64})
    t=Gtk4.G_.invert(c.transform)
    point = Gtk4.Graphene.GraphenePoint(p[1],p[2])
    point2 = Gtk4.G_.transform_point(t, point)
    p[1]=point2.x
    p[2]=point2.y
    p
end

Graphics.getgc(lc::LayeredCanvas) = lc.context
function Graphics.set_coordinates(c::LayeredCanvas, device::BoundingBox, user::BoundingBox)
    set_coordinates(getgc(c), device, user)
end
function Graphics.set_coordinates(c::LayeredCanvas, user::BoundingBox)
    w = Graphics.width(c)
    h = Graphics.height(c)
    if w>0 && h>0  # widget must have a size for this transformation to make any sense
        set_coordinates(c, BoundingBox(0, w, 0, h), user)
    end
    c.user_bbox = user
end
function Graphics.set_coordinates(c::LayeredCanvas, zr::ZoomRegion)
    xy = zr.currentview
    bb = BoundingBox(xy)
    set_coordinates(c, bb)
end
function Graphics.set_coordinates(c::LayeredCanvas, inds::Tuple{AbstractUnitRange,AbstractUnitRange})
    y, x = inds
    bb = BoundingBox(first(x)-0.5, last(x)+0.5, first(y)-0.5, last(y)+0.5)
    set_coordinates(c, bb)
end

function init_zoom_rubberband(canvas::LayeredCanvas{U},
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
    cairolayer = GtkObservables.CairoLayer()
    add_layer!(canvas, cairolayer)
    draw(cairolayer, enabled, active) do ctx, enabled2, active2
        if enabled2 && active2
            rb_draw(ctx, rb)
        end
    end
    init = on(canvas.mouse.buttonpress; weak=true) do btn::MouseButton{U}
        if enabled[]
            if initiate(btn)
                active[] = true
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
            rb.moved = true
            rb.pos2 = btn.position
            reveal(canvas)
        end
    end
    finish = on(canvas.mouse.buttonrelease; weak=true) do btn::MouseButton{U}
        if active[]
            btn.button == 0 && return nothing
            active[] = false
            if rb.moved
                pos = btn.position
                x, y = pos.x, pos.y
                x1, y1 = rb.pos1.x, rb.pos1.y
                xd, yd = convertunits(DeviceUnit, canvas, x, y)
                x1d, y1d = convertunits(DeviceUnit, canvas, x1, y1)
                if abs(x1d-xd) > rb.minpixels || abs(y1d-yd) > rb.minpixels
                    # It moved sufficiently, let's execute the callback
                    bb = BoundingBox(min(x1,x), max(x1,x), min(y1,y), max(y1,y))
                    update_zr(canvas, bb)
                end
            end
        end
    end
    Dict{String,Any}("enabled"=>enabled, "active"=>active, "init"=>init, "drag"=>drag, "finish"=>finish)
end

