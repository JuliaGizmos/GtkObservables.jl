# Much of this is event-handling to support interactivity

abstract type CairoUnit <: Real end

Base.:+(x::U, y::U) where {U<:CairoUnit} = U(x.val + y.val)
Base.:-(x::U, y::U) where {U<:CairoUnit} = U(x.val - y.val)
Base.:<(x::U, y::U) where {U<:CairoUnit} = Bool(x.val < y.val)
Base.:>(x::U, y::U) where {U<:CairoUnit} = Bool(x.val > y.val)
Base.abs(x::U) where {U<:CairoUnit} = U(abs(x.val))
Base.min(x::U, y::U) where {U<:CairoUnit} = U(min(x.val, y.val))
Base.max(x::U, y::U) where {U<:CairoUnit} = U(max(x.val, y.val))
Base.isapprox(x::U, y::U; kwargs...) where U<:CairoUnit =
    isapprox(x.val, y.val; kwargs...)

Base.convert(::Type{T}, x::T) where {T<:CairoUnit} = x
(::Type{T})(x::CairoUnit) where T<:Real = T(x.val)

# Ambiguity resolution
Bool(x::CairoUnit) = Bool(x.val)

# The next three are for ambiguity resolution
Base.promote_rule(::Type{Bool}, ::Type{U}) where {U<:CairoUnit} = Float64
Base.promote_rule(::Type{BigFloat}, ::Type{U}) where {U<:CairoUnit} = BigFloat
Base.promote_rule(::Type{T}, ::Type{U}) where {T<:Irrational,U<:CairoUnit} = promote_type(T, Float64)
Base.promote_rule(::Type{T}, ::Type{U}) where {T<:Real,U<:CairoUnit} = promote_type(T, Float64)

"""
    DeviceUnit(x)

Represent a number `x` as having "device" units (aka, screen
pixels). See the Cairo documentation.
"""
struct DeviceUnit <: CairoUnit
    val::Float64
end
DeviceUnit(x::DeviceUnit) = x

"""
    UserUnit(x)

Represent a number `x` as having "user" units, i.e., whatever units
have been established with calls that affect the transformation
matrix, e.g., [`Graphics.set_coordinates`](@ref) or
[`Cairo.set_matrix`](@ref).
"""
struct UserUnit <: CairoUnit
    val::Float64
end
UserUnit(x::UserUnit) = x

showtype(::Type{UserUnit}) = "UserUnit"
showtype(::Type{DeviceUnit}) = "DeviceUnit"

Base.show(io::IO, x::CairoUnit) = print(io, showtype(typeof(x)), '(', x.val, ')')

Base.promote_rule(::Type{U}, ::Type{D}) where {U<:UserUnit,D<:DeviceUnit} =
    error("UserUnit and DeviceUnit are incompatible, promotion not defined")

function convertunits(::Type{UserUnit}, c, x::DeviceUnit, y::DeviceUnit)
    xu, yu = device_to_user(getgc(c), x.val, y.val)
    UserUnit(xu), UserUnit(yu)
end
function convertunits(::Type{UserUnit}, c, x::UserUnit, y::UserUnit)
    x, y
end
function convertunits(::Type{DeviceUnit}, c, x::DeviceUnit, y::DeviceUnit)
    x, y
end
function convertunits(::Type{DeviceUnit}, c, x::UserUnit, y::UserUnit)
    xd, yd = user_to_device(getgc(c), x.val, y.val)
    DeviceUnit(xd), DeviceUnit(yd)
end

"""
    XY(x, y)

A type to hold `x` (horizontal), `y` (vertical) coordinates, where the
number increases to the right and downward. If used to encode mouse
pointer positions, the units of `x` and `y` are either
[`DeviceUnit`](@ref) or [`UserUnit`](@ref).
"""
struct XY{T}
    x::T
    y::T

    XY{T}(x, y) where {T} = new{T}(x, y)
    XY{U}(x::U, y::U) where {U<:CairoUnit} = new{U}(x, y)
    XY{U}(x::Real, y::Real) where {U<:CairoUnit} = new{U}(U(x), U(y))
end
XY(x::T, y::T) where {T} = XY{T}(x, y)
XY(x, y) = XY(promote(x, y)...)

function XY{U}(w::GtkCanvas, x::Float64, y::Float64) where U<:CairoUnit
    XY{U}(convertunits(U, w, DeviceUnit(x), DeviceUnit(y))...)
end

function Base.show(io::IO, xy::XY{T}) where T<:CairoUnit
    print(io, "XY{$(showtype(T))}(", convert(Float64, xy.x), ", ", convert(Float64, xy.y), ')')
end
Base.show(io::IO, xy::XY) = print(io, "XY(", xy.x, ", ", xy.y, ')')

Base.convert(::Type{XY{T}}, xy::XY{T}) where {T} = xy
Base.convert(::Type{XY{T}}, xy::XY) where {T} = XY(T(xy.x), T(xy.y))

Base.:+(xy1::XY{T}, xy2::XY{T}) where {T} = XY{T}(xy1.x+xy2.x,xy1.y+xy2.y)
Base.:-(xy1::XY{T}, xy2::XY{T}) where {T} = XY{T}(xy1.x-xy2.x,xy1.y-xy2.y)

"""
    MouseButton(position, button, clicktype, modifiers, n_press=1)

A type to hold information about a mouse button event (e.g., a
click). `position` is the canvas position of the pointer (see
[`XY`](@ref)). `button` is an integer identifying the
button, where 1=left button, 2=middle button, 3=right
button. `clicktype` may be `BUTTON_PRESS` or
`BUTTON_RELEASE`. `modifiers` indicates whether any keys were
held down during the click; they may be any combination of `SHIFT`,
`CONTROL`, or `MOD1` stored as a bitfield (test with `btn.modifiers &
SHIFT`). Multiple clicks can be handled by setting the `n_press`
argument. For example, a double click event corresponds to `n_press=2`.

The fieldnames are the same as the argument names above.


    MouseButton{UserUnit}()
    MouseButton{DeviceUnit}()

Create a "dummy" MouseButton event. Often useful for the fallback to
Observables's `filterwhen`.
"""
struct MouseButton{U<:CairoUnit}
    position::XY{U}
    button::UInt32
    clicktype::typeof(BUTTON_PRESS)
    modifiers::typeof(SHIFT)
    n_press::Int32
end
function MouseButton(pos::XY{U}, button::Integer, clicktype, modifiers, n_press=1) where U<:CairoUnit
    MouseButton{U}(pos, UInt32(button), clicktype, modifiers, n_press)
end

function _get_button(modifiers, e::GtkEventController)
    if modifiers & Gtk4.ModifierType_BUTTON1_MASK == Gtk4.ModifierType_BUTTON1_MASK
        return 1
    elseif modifiers & Gtk4.ModifierType_BUTTON2_MASK == Gtk4.ModifierType_BUTTON2_MASK
        return 2
    elseif modifiers & Gtk4.ModifierType_BUTTON3_MASK == Gtk4.ModifierType_BUTTON3_MASK
        return 3        
    else
        return isa(e, GtkGestureSingle) ? Gtk4.current_button(e) : 0
    end
end

function MouseButton{U}(e::GtkEventController, n_press::Integer, x::Float64, y::Float64, clicktype, modifier_ref=nothing) where U<:CairoUnit
    modifiers = if modifier_ref === nothing
        Gtk4.current_event_state(e)
    else
        modifier_ref[]
    end
    button = _get_button(modifiers,e)
    w = widget(e)
    MouseButton{U}(XY{U}(w, x, y), UInt32(button), clicktype, modifiers, n_press)
end
function MouseButton{U}() where U<:CairoUnit
    MouseButton(XY(U(-1), U(-1)), UInt32(0), Gtk4.EventType(0), Gtk4.ModifierType(0))
end

"""
    MouseScroll(position, direction, modifiers)

A type to hold information about a mouse wheel scroll. `position` is the
canvas position of the pointer (see
[`XY`](@ref)). `direction` may be `UP`, `DOWN`, `LEFT`, or
`RIGHT`. `modifiers` indicates whether any keys were held down during
the click; they may be 0 (no modifiers) or any combination of `SHIFT`,
`CONTROL`, or `MOD1` stored as a bitfield.


    MouseScroll{UserUnit}()
    MouseScroll{DeviceUnit}()

Create a "dummy" MouseScroll event. Often useful for the fallback to
Observables's `filterwhen`.
"""
struct MouseScroll{U<:CairoUnit}
    position::XY{U}
    direction::typeof(UP)
    modifiers::typeof(SHIFT)
end
function MouseScroll(pos::XY{U}, direction, modifiers) where U <: CairoUnit
    MouseScroll{U}(pos, direction, modifiers)
end
function MouseScroll{U}(e::GtkEventController, direction, modifier_ref = nothing) where U <: CairoUnit
    modifiers = if modifier_ref === nothing
        Gtk4.current_event_state(e)
    else
        modifier_ref[]
    end
    evt = Gtk4.current_event(e)
    b, x, y = if evt.handle != C_NULL
        Gtk4.position(evt)
    else
        (false, 0.0, 0.0)
    end
    w = widget(e)
    MouseScroll{U}(XY{U}(w, x, y), direction, modifiers)
end
function MouseScroll{U}() where U
    MouseScroll(XY(U(-1), U(-1)), UP, Gtk4.ModifierType(0))
end

"""
    MouseHandler{U<:CairoUnit}

A type with `Observable` fields for which you can `map` callback actions. The fields are:
  - `buttonpress` for clicks (of type [`MouseButton`](@ref));
  - `buttonrelease` for release events (of type [`MouseButton`](@ref));
  - `motion` for move and drag events (of type [`MouseButton`](@ref));
  - `scroll` for wheelmouse or track-pad actions (of type [`MouseScroll`](@ref));

`U` should be either [`DeviceUnit`](@ref) or [`UserUnit`](@ref) and
determines the coordinate system used for reporting mouse positions.
"""
struct MouseHandler{U<:CairoUnit}
    buttonpress::Observable{MouseButton{U}}
    buttonrelease::Observable{MouseButton{U}}
    motion::Observable{MouseButton{U}}
    scroll::Observable{MouseScroll{U}}
    ids::Vector{Culong}   # for disabling any of these callbacks
    widget::GtkCanvas
    modifier_ref::Union{Nothing,Ref{Gtk4.ModifierType}}

    function MouseHandler{U}(canvas::GtkCanvas, modifier_ref=nothing) where U<:CairoUnit
        pos = XY(U(-1), U(-1))
        btn = MouseButton(pos, 0, BUTTON_PRESS, SHIFT)
        scroll = MouseScroll(pos, UP, SHIFT)
        ids = Vector{Culong}(undef, 0)
        handler = new{U}(Observable(btn), Observable(btn), Observable(btn), Observable(scroll), ids, canvas, modifier_ref)
        # Create the callbacks
        g = GtkGestureClick(canvas,0)
        gm = GtkEventControllerMotion(canvas)
        gs = GtkEventControllerScroll(Gtk4.EventControllerScrollFlags_HORIZONTAL |
                                      Gtk4.EventControllerScrollFlags_VERTICAL  |
                                      Gtk4.EventControllerScrollFlags_DISCRETE , canvas)
        
        push!(ids, signal_connect(mousedown_cb, g, "pressed", Nothing, (Int32, Float64, Float64), false, handler))
        push!(ids, signal_connect(mouseup_cb, g, "released", Nothing, (Int32, Float64, Float64), false, handler))
        push!(ids, signal_connect(mousemove_cb, gm, "motion", Nothing, (Float64, Float64), false, handler))
        push!(ids, signal_connect(mousescroll_cb, gs, "scroll", Cint, (Float64, Float64), false, handler))

        handler
    end
end

function mousedown_cb(ecp::Ptr, n_press::Int32, x::Float64, y::Float64, handler::MouseHandler{U}) where U
    ec = convert(GtkGestureClick, ecp)
    handler.buttonpress[] = MouseButton{U}(ec, n_press, x, y, BUTTON_PRESS, handler.modifier_ref)
    nothing
end

function mouseup_cb(ecp::Ptr, n_press::Int32, x::Float64, y::Float64, handler::MouseHandler{U}) where U
    ec = convert(GtkGestureClick, ecp)
    handler.buttonrelease[] = MouseButton{U}(ec, n_press, x, y, BUTTON_RELEASE, handler.modifier_ref)
    nothing
end

function mousemove_cb(ecp::Ptr, x::Float64, y::Float64, handler::MouseHandler{U}) where U
    ec = convert(GtkEventControllerMotion, ecp)
    handler.motion[] = MouseButton{U}(ec, 0, x, y, MOTION_NOTIFY, handler.modifier_ref)
    nothing
end

function mousescroll_cb(ecp::Ptr, dx::Float64, dy::Float64, handler::MouseHandler{U}) where U
    ec = convert(GtkEventControllerScroll, ecp)
    vert = (abs(dy)>abs(dx))
    dir = if vert
        dy > 0 ? Gtk4.ScrollDirection_DOWN : Gtk4.ScrollDirection_UP
    else
        dx > 0 ? Gtk4.ScrollDirection_RIGHT : Gtk4.ScrollDirection_LEFT
    end
    modifiers = if handler.modifier_ref === nothing
        Gtk4.current_event_state(ec)
    else
        handler.modifier_ref[]
    end
    handler.scroll[] = MouseScroll{U}(handler.motion[].position, dir, modifiers)
    Cint(1)
end

"""
    GtkObservables.Canvas{U}(w=-1, h=-1, own=true)

Create a canvas for drawing and interaction. The relevant fields are:
  - `canvas`: the "raw" Gtk widget (from Gtk4.jl)
  - `mouse`: the [`MouseHandler{U}`](@ref) for this canvas.

See also [`canvas`](@ref).
"""
struct Canvas{U}
    widget::GtkCanvas
    mouse::MouseHandler{U}
    preserved::Vector{Any}

    function Canvas{U}(w::Int=-1, h::Int=-1; own::Bool=true, init_back=false, modifier_ref=nothing) where U
        gtkcanvas = GtkCanvas(w, h, init_back)
        # Initialize handlers
        mouse = MouseHandler{U}(gtkcanvas, modifier_ref)
        grab_focus(gtkcanvas)
        preserved = []
        canvas = new{U}(gtkcanvas, mouse, preserved)
        gc_preserve(gtkcanvas, canvas)
        canvas
    end
end
Canvas{U}(w::Integer, h::Integer=-1; own::Bool=true, init_back = false, modifier_ref=nothing) where U = Canvas{U}(Int(w)::Int, Int(h)::Int; own=own, init_back=init_back, modifier_ref=modifier_ref)

Base.show(io::IO, canvas::Canvas{U}) where U = print(io, "GtkObservables.Canvas{$U}()")

"""
    canvas(U=DeviceUnit, w=-1, h=-1) - c::GtkObservables.Canvas

Create a canvas for drawing and interaction. Optionally specify the
width `w` and height `h`. `U` refers to the units for the canvas (for
both drawing and reporting mouse pointer positions), see
[`DeviceUnit`](@ref) and [`UserUnit`](@ref). See also [`GtkObservables.Canvas`](@ref).
"""
canvas(::Type{U}=DeviceUnit, w::Integer=-1, h::Integer=-1; init_back=false, modifier_ref=nothing) where {U<:CairoUnit} = Canvas{U}(w, h; init_back=init_back, modifier_ref=modifier_ref)
canvas(w::Integer, h::Integer; init_back=false, modifier_ref=nothing) = canvas(DeviceUnit, w, h; init_back=init_back, modifier_ref=modifier_ref)

"""
    draw(f, c::GtkObservables.Canvas, signals...)

Supply a draw function `f` for `c`. This will be called whenever the
canvas is resized or whenever any of the input `signals` update. `f`
should be of the form `f(cnvs, sigs...)`, where the number of
arguments is equal to 1 + `length(signals)`.

`f` can be defined as a named function, an anonymous function, or
using `do`-block notation:

    using Graphics, Colors

    draw(c, imgobs, xsig, ysig) do cnvs, img, x, y
        copy!(cnvs, img)
        ctx = getgc(cnvs)
        set_source(ctx, colorant"red")
        set_line_width(ctx, 2)
        circle(ctx, x, y, 5)
        stroke(ctx)
    end

This would paint an image-Observable `imgobs` onto the canvas and then
draw a red circle centered on `xsig`, `ysig`.
"""
function Gtk4.draw(drawfun::F, c::Canvas, signals::Observable...) where F
    @guarded draw(c.widget) do widget
        # This used to have a `yield` in it to allow the Gtk event queue to run,
        # but that caused
        # https://github.com/JuliaGraphics/Gtk.jl/issues/368
        # and the bizarre failures in
        # https://github.com/JuliaImages/ImageView.jl/pull/153
        drawfun(widget, map(getindex, signals)...)
    end
    drawfunc = onany(signals...) do values...
        draw(c.widget)
    end
    push!(c.preserved, drawfunc)
    drawfunc
end
function Gtk4.draw(drawfun::F, c::Canvas, signal::Observable) where F
    @guarded draw(c.widget) do widget
        drawfun(widget, signal[])
    end
    drawfunc = on(signal) do _
        draw(c.widget)
    end
    push!(c.preserved, drawfunc)
    drawfunc
end

# Painting an image to a canvas
function Base.copy!(ctx::GraphicsContext, img::AbstractArray{C}) where C<:Union{Colorant,Number}
    save(ctx)
    reset_transform(ctx)
    Cairo.image(ctx, image_surface(img), 0, 0, Graphics.width(ctx), Graphics.height(ctx))
    restore(ctx)
end
Base.copy!(c::Union{GtkCanvas,Canvas}, img) = copy!(getgc(c), img)
function Base.fill!(c::Union{GtkCanvas,Canvas}, color::Colorant)
    ctx = getgc(c)
    save(ctx)
    reset_transform(ctx)
    w, h = Graphics.width(c), Graphics.height(c)
    rectangle(ctx, 0, 0, w, h)
    set_source(ctx, color)
    fill(ctx)
    restore(ctx)
end

# TODO: Remove Matrix once the CairoImageSurface constructor has been
# generalized. Cairo.jl issue #252.
image_surface(img::Matrix{Gray24}) =
    Cairo.CairoImageSurface(Matrix(reinterpret(UInt32, img)), Cairo.FORMAT_RGB24)
image_surface(img::Matrix{RGB24})  =
    Cairo.CairoImageSurface(Matrix(reinterpret(UInt32, img)), Cairo.FORMAT_RGB24)
image_surface(img::Matrix{ARGB32}) =
    Cairo.CairoImageSurface(Matrix(reinterpret(UInt32, img)), Cairo.FORMAT_ARGB32)

image_surface(img::AbstractArray{T}) where {T<:Number} =
    image_surface(convert(Matrix{Gray24}, img))
image_surface(img::AbstractArray{T}) where {T<:ColorTypes.AbstractGray} =
    image_surface(convert(Matrix{Gray24}, img))
image_surface(img::AbstractArray{C}) where {C<:Color} =
    image_surface(convert(Matrix{RGB24}, img))
image_surface(img::AbstractArray{C}) where {C<:Colorant} =
    image_surface(convert(Matrix{ARGB32}, img))


# Coordinates could be AbstractFloat without an implied step, so let's
# use intervals instead of ranges
struct ZoomRegion{T}
    fullview::XY{ClosedInterval{T}}
    currentview::XY{ClosedInterval{T}}
end

"""
    ZoomRegion(fullinds) -> zr
    ZoomRegion(fullinds, currentinds) -> zr
    ZoomRegion(img::AbstractMatrix) -> zr

Create a `ZoomRegion` object `zr` for selecting a rectangular
region-of-interest for zooming and panning. `fullinds` should be a
pair `(yrange, xrange)` of indices, an [`XY`](@ref) object, or pass a
matrix `img` from which the indices will be taken.

`zr.currentview` holds the currently-active region of
interest. `zr.fullview` stores the original `fullinds` from which `zr` was
constructed; these are used to reset to the original limits and to
confine `zr.currentview`.
"""
function ZoomRegion(inds::Tuple{AbstractUnitRange{I},AbstractUnitRange{I}}) where I<:Integer
    ci = ClosedInterval{RInt}.(inds)
    fullview = XY(ci[2], ci[1])
    ZoomRegion(fullview, fullview)
end
function ZoomRegion(fullinds::Tuple{AbstractUnitRange{I},AbstractUnitRange{I}},
                    curinds::Tuple{AbstractUnitRange{I},AbstractUnitRange{I}}) where I<:Integer
    fi = ClosedInterval{RInt}.(fullinds)
    ci = ClosedInterval{RInt}.(curinds)
    ZoomRegion(XY(fi[2], fi[1]), XY(ci[2], ci[1]))
end
ZoomRegion(img) = ZoomRegion(axes(img))
function ZoomRegion(fullview::XY, bb::BoundingBox)
    xview = oftype(fullview.x, bb.xmin..bb.xmax)
    yview = oftype(fullview.y, bb.ymin..bb.ymax)
    ZoomRegion(fullview, XY(xview, yview))
end

reset(zr::ZoomRegion) = ZoomRegion(zr.fullview, zr.fullview)

Base.axes(zr::ZoomRegion) = UnitRange.((zr.currentview.y, zr.currentview.x))

function interior(iv::ClosedInterval, limits::AbstractInterval)
    imin, imax = minimum(iv), maximum(iv)
    lmin, lmax = minimum(limits), maximum(limits)
    if imin < lmin
        imin = lmin
        imax = imin + IntervalSets.width(iv)
    elseif imax > lmax
        imax = lmax
        imin = imax - IntervalSets.width(iv)
    end
    oftype(limits, (imin..imax) ∩ limits)
end

function pan(iv::ClosedInterval, frac::Real, limits)
    s = frac*IntervalSets.width(iv)
    interior(minimum(iv)+s..maximum(iv)+s, limits)
end

"""
    pan_x(zr::ZoomRegion, frac) -> zr_new

Pan the x-axis by a fraction `frac` of the current x-view. `frac>0` means
that the coordinates shift right, which corresponds to a leftward
shift of objects.
"""
pan_x(zr::ZoomRegion, s) =
    ZoomRegion(zr.fullview, XY(pan(zr.currentview.x, s, zr.fullview.x), zr.currentview.y))

"""
    pan_y(zr::ZoomRegion, frac) -> zr_new

Pan the y-axis by a fraction `frac` of the current x-view. `frac>0` means
that the coordinates shift downward, which corresponds to an upward
shift of objects.
"""
pan_y(zr::ZoomRegion, s) =
    ZoomRegion(zr.fullview, XY(zr.currentview.x, pan(zr.currentview.y, s, zr.fullview.y)))

function zoom(iv::ClosedInterval, s::Real, limits)
    dw = 0.5*(s - 1)*IntervalSets.width(iv)
    interior(minimum(iv)-dw..maximum(iv)+dw, limits)
end

"""
    zoom(zr::ZoomRegion, scaleview, pos::XY) -> zr_new

Zooms in (`scaleview` < 1) or out (`scaleview` > 1) by a scaling
factor `scaleview`, in a manner centered on `pos`.
"""
function zoom(zr::ZoomRegion, s, pos::XY)
    xview, yview = zr.currentview.x, zr.currentview.y
    xviewlimits, yviewlimits = zr.fullview.x, zr.fullview.y
    centerx, centery = pos.x.val, pos.y.val
    w, h = IntervalSets.width(xview), IntervalSets.width(yview)
    fx, fy = (centerx-minimum(xview))/w, (centery-minimum(yview))/h
    wbb, hbb = s*w, s*h
    # set a limit on how far in we can zoom (ImageView issue #297)
    if wbb <= 1.0 || hbb <= 1.0
        return zr
    end
    xview = interior(ClosedInterval(centerx-fx*wbb,centerx+(1-fx)*wbb), xviewlimits)
    yview = interior(ClosedInterval(centery-fy*hbb,centery+(1-fy)*hbb), yviewlimits)
    ZoomRegion(zr.fullview, XY(xview, yview))
end

"""
    zoom(zr::ZoomRegion, scaleview)

Zooms in (`scaleview` < 1) or out (`scaleview` > 1) by a scaling
factor `scaleview`, in a manner centered around the current view
region.
"""
function zoom(zr::ZoomRegion, s)
    xview, yview = zr.currentview.x, zr.currentview.y
    xviewlimits, yviewlimits = zr.fullview.x, zr.fullview.y
    xview = zoom(xview, s, xviewlimits)
    yview = zoom(yview, s, yviewlimits)
    ZoomRegion(zr.fullview, XY(xview, yview))
end

"""
    signals = init_pan_scroll(canvas::GtkObservables.Canvas,
                              zr::Observable{ZoomRegion},
                              filter_x::Function = evt->evt.modifiers == SHIFT || event.direction == LEFT || event.direction == RIGHT,
                              filter_y::Function = evt->evt.modifiers == 0 || event.direction == UP || event.direction == DOWN,
                              xpanflip = false,
                              ypanflip  = false)

Initialize panning-by-mouse-scroll for `canvas` and update
`zr`. `signals` is a dictionary holding the Observables.jl signals needed
for scroll-panning; you can push `true/false` to `signals["enabled"]`
to turn scroll-panning on and off, respectively. Your application is
responsible for making sure that `signals` does not get
garbage-collected (which would turn off scroll-panning).

`filter_x` and `filter_y` are functions that return `true` when the
conditions for x- and y-scrolling are met; the argument is a
[`MouseScroll`](@ref) event. The defaults are that vertical scrolling
is triggered with an unmodified scroll, whereas horizontal scrolling
is triggered by scrolling while holding down the SHIFT key.

You can flip the direction of either pan operation with `xpanflip` and
`ypanflip`, respectively.
"""
function init_pan_scroll(canvas::Canvas{U},
                         zr::Observable{ZoomRegion{T}},
                         @nospecialize(filter_x::Function) = evt->(evt.modifiers & SHIFT) == SHIFT || evt.direction == LEFT || evt.direction == RIGHT,
                         @nospecialize(filter_y::Function) = evt->(evt.modifiers & SHIFT) == 0 && (evt.direction == UP || evt.direction == DOWN),
                         xpanflip = false,
                         ypanflip  = false) where {U,T}
    enabled = Observable(true)
    pan = on(canvas.mouse.scroll; weak=true) do event::MouseScroll{U}
        if enabled[]
            if event.modifiers & CONTROL == CONTROL
            # filter out zoom events
            # TODO: figure out how to handle custom filters -- this will fail if the user
            # sets a modifier other than CONTROL to do zoom
                return nothing
            end
            s = 0.1*scrollpm(event.direction)
            if filter_x(event)
                setindex!(zr, pan_x(zr[], s))
            elseif filter_y(event)
                setindex!(zr, pan_y(zr[], s))
            end
        end
        return nothing
    end
    Dict{String,Any}("enabled"=>enabled, "pan"=>pan)
end

"""
    signals = init_pan_drag(canvas::GtkObservables.Canvas,
                            zr::Observable{ZoomRegion},
                            initiate = btn->(btn.button == 1 && btn.clicktype == BUTTON_PRESS && btn.modifiers == 0))

Initialize click-drag panning that updates `zr`. `signals` is a
dictionary holding the Observables.jl signals needed for pan-drag; you
can push `true/false` to `signals["enabled"]` to turn it on and off,
respectively. Your application is responsible for making sure that
`signals` does not get garbage-collected (which would turn off
pan-dragging).

`initiate(btn)` returns `true` when the condition for starting
click-drag panning has been met (by default, clicking mouse button
1). The argument `btn` is a [`MouseButton`](@ref) event.
"""
function init_pan_drag(canvas::Canvas{U},
                       zr::Observable{ZoomRegion{T}},
                       @nospecialize(initiate::Function) = pandrag_init_default) where {U,T}
    enabled = Observable(true)
    active = Observable(false)
    pos1ref, zr1ref, mtrxref = Ref{XY{DeviceUnit}}(), Ref{XY{ClosedInterval{T}}}(), Ref{Matrix{Float64}}()   # julia#15276
    init = on(canvas.mouse.buttonpress; weak=true) do btn::MouseButton{U}
        if initiate(btn)
            active[] = true
            # Because the user coordinates will change during panning,
            # convert to absolute position
            pos1ref[] = XY(convertunits(DeviceUnit, canvas, btn.position.x, btn.position.y)...)
            zr1ref[] = zr[].currentview
            m = Cairo.get_matrix(getgc(canvas))
            mtrxref[] = inv([m.xx m.xy 0.0; m.yx m.yy 0.0; m.x0 m.y0 1.0])
        end
        return nothing
    end
    drag = on(canvas.mouse.motion; weak=true) do btn::MouseButton{U}
        if active[]
            btn.button == 0 && return nothing
            pos1, zr1, mtrx = pos1ref[], zr1ref[], mtrxref[]
            xd, yd = convertunits(DeviceUnit, canvas, btn.position.x, btn.position.y)
            dx, dy, _ = mtrx*[xd-pos1.x, yd-pos1.y, 1.0]
            fv = zr[].fullview
            cv = XY(interior(minimum(zr1.x)-dx..maximum(zr1.x)-dx, fv.x),
                    interior(minimum(zr1.y)-dy..maximum(zr1.y)-dy, fv.y))
            if cv != zr[].currentview
                setindex!(zr, ZoomRegion(fv, cv))
            end
        end
    end
    finish = on(canvas.mouse.buttonrelease; weak=true) do btn::MouseButton{U}
        btn.button == 0 && return nothing
        active[] = false
        return nothing
    end
    Dict{String,Any}("enabled"=>enabled, "active"=>active, "init"=>init, "drag"=>drag, "finish"=>finish)
end
pandrag_button(btn) = btn.button == 1 && (btn.modifiers & CONTROL) == 0
pandrag_init_default(btn) = btn.clicktype == BUTTON_PRESS && pandrag_button(btn)

"""
    signals = init_zoom_scroll(canvas::GtkObservables.Canvas,
                               zr::Observable{ZoomRegion},
                               filter::Function = evt->evt.modifiers == CONTROL,
                               focus::Symbol = :pointer,
                               factor = 2.0,
                               flip = false)

Initialize zooming-by-mouse-scroll for `canvas` and update
`zr`. `signals` is a dictionary holding the Observables.jl signals needed
for scroll-zooming; you can push `true/false` to `signals["enabled"]`
to turn scroll-zooming on and off, respectively. Your application is
responsible for making sure that `signals` does not get
garbage-collected (which would turn off scroll-zooming).

`filter` is a function that returns `true` when the conditions for
scroll-zooming are met; the argument is a [`MouseScroll`](@ref)
event. The default is to hold down the CONTROL key while scrolling the
mouse.

The `focus` keyword controls how the zooming progresses as you scroll
the mouse wheel. `:pointer` means that whatever feature of the canvas
is under the pointer will stay there as you zoom in or out. The other
choice, `:center`, keeps the canvas centered on its current location.

You can change the amount of zooming via `factor` and the direction of
zooming with `flip`.
"""
function init_zoom_scroll(canvas::Canvas{U},
                          zr::Observable{ZoomRegion{T}},
                          @nospecialize(filter::Function) = evt->(evt.modifiers & CONTROL) == CONTROL,
                          focus::Symbol = :pointer,
                          factor = 2.0,
                          flip = false) where {U,T}
    focus == :pointer || focus == :center || error("focus must be :pointer or :center")
    enabled = Observable(true)
    zm = on(canvas.mouse.scroll; weak=true) do event::MouseScroll{U}
        if enabled[] && filter(event)
            s = factor
            if event.direction == UP
                s = 1/s
            end
            if flip
                s = 1/s
            end
            if focus === :pointer
                setindex!(zr, zoom(zr[], s, canvas.mouse.motion[].position))
            else
                setindex!(zr, zoom(zr[], s))
            end
        end
    end
    Dict{String,Any}("enabled"=>enabled, "zoom"=>zm)
end

scrollpm(direction) =
    direction == UP ? -1 :
    direction == DOWN ? 1 :
    direction == RIGHT ? 1 :
    direction == LEFT ? -1 : error("Direction ", direction, " not recognized")
