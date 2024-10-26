struct GtkGraphicsContext <: GraphicsContext
end

abstract type Layer end

redraw(l::Layer, val) = Gtk4.reveal(l)

struct FillLayer <: Layer
    color::Observable
end

function draw(layer::FillLayer, snapshot::GtkSnapshot, w::Integer, h::Integer)
    c = convert(GdkRGBA,layer.color[])
    Gtk4.G_.append_color(snapshot, c, Ref(_GrapheneRect(0,0,w,h)))
end

struct ImageLayer <: Layer
    imgo::Observable  # ?
end

#function draw(layer::ImageLayer, w, h)
#    println("draw")
#end

mutable struct CairoLayer <: Layer
    draw::Union{Function, Nothing}
    preserved::Vector{Any}
end

CairoLayer() = CairoLayer(nothing,[])

function draw(layer::CairoLayer, snapshot::GtkSnapshot, w::Integer, h::Integer)
    if layer.draw !== nothing
        cr = Gtk4.G_.append_cairo(snapshot, Ref(_GrapheneRect(0,0,w,h)))
        cc = Cairo.CairoContext(Ptr{Nothing}(cr.handle))
        layer.draw(cc)
    end
end

function setfunc(f::F, layer::CairoLayer) where F
    layer.draw = f
end

# drawfun should look like `f(cc, sigs...)`
function Gtk4.draw(drawfun::F, c::CairoLayer, widget::GtkWidget, signals::Observable...) where F
    setfunc(c) do cc
        drawfun(cc, map(getindex, signals)...)
    end
    drawfunc = onany(signals...) do values...
        reveal(widget)
    end
    push!(c.preserved, drawfunc)
    drawfunc
end


function layered_canvas_measure(widget::Ptr{GObject}, orientation::Cint, for_size::Cint, minimum::Ptr{Cint}, natural::Ptr{Cint}, minimum_baseline::Ptr{Cint}, natural_baseline::Ptr{Cint})
    unsafe_store!(minimum, Cint(100))
    unsafe_store!(natural, Cint(100))
    nothing
end

function layered_canvas_snapshot(widget_ptr::Ptr{GObject}, snapshot_ptr::Ptr{GObject})
    widget = convert(LayeredCanvas, widget_ptr)
    snapshot = convert(GtkSnapshot, snapshot_ptr)
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
    #widget_klass.measure = @cfunction(layered_canvas_measure, Cvoid, (Ptr{GObject}, Cint, Cint, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}))
    unsafe_store!(widget_klass_ptr, widget_klass)
    nothing
end

mutable struct LayeredCanvas{U} <: GtkWidget
    handle::Ptr{GObject}
    layers::Vector{Layer}
    mouse::MouseHandler{U}
    #action_group::Gtk4.GLib.GSimpleActionGroupLeaf
    #preserved::Vector{Any} # need?
    function LayeredCanvas{U}(handle::Ptr{GObject}, owns = false) where U
        if handle == C_NULL
            error("Cannot construct LayeredCanvas with a NULL pointer")
        end
        GLib.gobject_maybe_sink(handle, owns)
        canvas = gobject_ref(new(handle, Layer[], MouseHandler{U}()))
        _init_mouse_handler(canvas.mouse, canvas)
        canvas
    end
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
    # listen to observables
end

function LayeredCanvas{U}() where U
    gtype = GLib.g_type(LayeredCanvas)
    h = ccall(("g_object_new", GLib.libgobject), Ptr{GObject}, (UInt64, Ptr{Cvoid}), gtype, C_NULL)
    LayeredCanvas{U}(h)
end

function XY{U}(w::GtkWidget, x::Float64, y::Float64) where U<:CairoUnit
    XY{U}(convertunits(U, w, DeviceUnit(x), DeviceUnit(y))...)
end

Graphics.getgc(lc::LayeredCanvas) = GtkGraphicsContext()
Graphics.set_coordinates(c::LayeredCanvas, device::BoundingBox, user::BoundingBox) =
    set_coordinates(getgc(c), device, user)
Graphics.set_coordinates(c::LayeredCanvas, user::BoundingBox) =
    set_coordinates(c, BoundingBox(0, Graphics.width(c), 0, Graphics.height(c)), user)
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

