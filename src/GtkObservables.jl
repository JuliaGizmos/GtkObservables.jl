module GtkObservables

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@compiler_options"))
    @eval Base.Experimental.@compiler_options optimize=1
end

using LinearAlgebra   # for `inv`
using Gtk4, Colors, FixedPointNumbers, Reexport
@reexport using Observables
using Graphics
using Graphics: set_coordinates, BoundingBox
using IntervalSets, RoundingIntegers
# There's a conflict for width, so we have to scope those calls
import Cairo

using Gtk4: GtkScaleLeaf, GtkCheckButtonLeaf, GtkToggleButtonLeaf,
    GtkButtonLeaf, GtkSpinButtonLeaf, GtkColorButtonLeaf,
    GtkEntryLeaf, GtkTextViewLeaf, GtkComboBoxTextLeaf,
    GtkLabelLeaf, GtkProgressBarLeaf
# Constants for event analysis
const SHIFT = Gtk4.ModifierType_SHIFT_MASK
const CONTROL = Gtk4.ModifierType_CONTROL_MASK
const MOD1 = Gtk4.ModifierType_ALT_MASK
const BUTTON_PRESS = Gtk4.EventType_BUTTON_PRESS
const BUTTON_RELEASE = Gtk4.EventType_BUTTON_RELEASE
const MOTION_NOTIFY = Gtk4.EventType_MOTION_NOTIFY
const UP = Gtk4.ScrollDirection_UP
const DOWN = Gtk4.ScrollDirection_DOWN
const LEFT = Gtk4.ScrollDirection_LEFT
const RIGHT = Gtk4.ScrollDirection_RIGHT

# Re-exports
export set_coordinates, BoundingBox, SHIFT, CONTROL, MOD1, UP, DOWN, LEFT, RIGHT,
       BUTTON_PRESS, destroy

## Exports
export slider, button, checkbox, togglebutton, colorbutton, dropdown, textbox, textarea, spinbutton, cyclicspinbutton, progressbar
export label
export canvas, DeviceUnit, UserUnit, XY, MouseButton, MouseScroll, MouseHandler
export player, timewidget, datetimewidget
export observable, widget, frame
# Zoom/pan
export ZoomRegion, zoom, pan_x, pan_y, init_zoom_rubberband, init_zoom_scroll,
       init_pan_scroll, init_pan_drag

# The generic Widget interface
abstract type Widget end

# A widget that gives out a observable of type T
abstract type InputWidget{T}  <: Widget end

"""
    observable(w) -> obs

Return the Observable `obs` associated with widget `w`.
"""
observable(w::Widget) = w.observable
observable(x::Observable) = x

"""
    widget(w) -> gtkw::GtkWidget

Return the GtkWidget `gtkw` associated with widget `w`.
"""
Gtk4.widget(w::Widget) = w.widget

Base.show(io::IO, w::Widget) = print(io, typeof(widget(w)), " with ", observable(w))
Base.getindex(w::Widget) = getindex(observable(w))
Base.setindex!(w::Widget, val) = setindex!(observable(w), val)
Observables.on(f, w::Widget; kwargs...) = on(f, observable(w); kwargs...)
Observables.onany(f, w::Widget, ws::Union{Widget,Observable}...; kwargs...) = onany(f, observable(w)::Observable, map(observable, ws)...; kwargs...)
Base.map(f::F, w::Widget, ws::Union{Widget,Observable}...; kwargs...) where F = map(f, observable(w)::Observable, map(observable, ws)...; kwargs...)

function Base.precompile(w::Widget)
    tf = true
    if hasfield(typeof(w), :preserved)
        for f in w.preserved
            if isa(f, Observables.ObserverFunction)
                tf &= precompile(f)
            end
        end
    end
    return tf
end

# Define specific widgets
include("widgets.jl")
include("extrawidgets.jl")
include("graphics_interaction.jl")
include("rubberband.jl")

## More convenience functions
# Containers
Gtk4.GtkWindow(w::Union{Widget,Canvas}) = GtkWindow(widget(w))
Gtk4.GtkFrame(w::Union{Widget,Canvas}) = GtkFrame(widget(w))
Gtk4.GtkAspectFrame(w::Union{Widget,Canvas}, args...) =
    GtkAspectFrame(widget(w), args...)

Base.push!(container::Union{GtkWindow,GtkBox}, child::Widget) =
    push!(container, widget(child))
Base.push!(container::Union{GtkWindow,GtkBox}, child::Canvas) =
    push!(container, widget(child))

Base.:|>(parent::Gtk4.GtkBox, child::Union{Widget,Canvas}) = push!(parent, child)

Gtk4.widget(c::Canvas) = c.widget

Gtk4.set_gtk_property!(w::Union{Widget,Canvas}, key, val) = set_gtk_property!(widget(w), key, val)
Gtk4.get_gtk_property(w::Union{Widget,Canvas}, key) = get_gtk_property(widget(w), key)
Gtk4.get_gtk_property(w::Union{Widget,Canvas}, key, ::Type{T}) where {T} = get_gtk_property(widget(w), key, T)

Base.unsafe_convert(::Type{Ptr{Gtk4.GLib.GObject}}, w::Union{Widget,Canvas}) =
    Base.unsafe_convert(Ptr{Gtk4.GLib.GObject}, widget(w))

Graphics.getgc(c::Canvas) = getgc(c.widget)
Graphics.width(c::Canvas) = Graphics.width(c.widget)
Graphics.height(c::Canvas) = height(c.widget)

Graphics.set_coordinates(c::Union{GtkCanvas,Canvas}, device::BoundingBox, user::BoundingBox) =
    set_coordinates(getgc(c)::Cairo.CairoContext, device, user)
Graphics.set_coordinates(c::Union{GtkCanvas,Canvas}, user::BoundingBox) =
    set_coordinates(c, BoundingBox(0, Graphics.width(c), 0, Graphics.height(c)), user)
function Graphics.set_coordinates(c::Union{GraphicsContext,Canvas,GtkCanvas}, zr::ZoomRegion)
    xy = zr.currentview
    bb = BoundingBox(xy)
    set_coordinates(c, bb)
end
function Graphics.set_coordinates(c::Union{Canvas,GtkCanvas}, inds::Tuple{AbstractUnitRange,AbstractUnitRange})
    y, x = inds
    bb = BoundingBox(first(x), last(x), first(y), last(y))
    set_coordinates(c, bb)
end
function Graphics.BoundingBox(xy::XY)
    BoundingBox(minimum(xy.x), maximum(xy.x), minimum(xy.y), maximum(xy.y))
end

function Base.setindex!(zr::Observable{ZoomRegion{T}}, cv::XY{ClosedInterval{S}}) where {T,S}
    fv = zr[].fullview
    setindex!(zr, ZoomRegion{T}(fv, cv))
end

function Base.setindex!(zr::Observable{ZoomRegion{T}}, inds::Tuple{ClosedInterval,ClosedInterval}) where T
    setindex!(zr, XY{ClosedInterval{T}}(inds[2], inds[1]))
end

function Base.setindex!(zr::Observable{ZoomRegion{T}}, inds::Tuple{AbstractUnitRange,AbstractUnitRange}) where T
    setindex!(zr, ClosedInterval{T}.(inds))
end

Gtk4.reveal(c::Canvas, args...) = reveal(c.widget, args...)

const _ref_dict = IdDict{Any, Any}()

"""
    gc_preserve(widget::GtkWidget, obj)

Preserve `obj` until `widget` has been [`destroy`](@ref)ed.
"""
function gc_preserve(widget::Union{GtkWidget,GtkCanvas}, obj)
    _ref_dict[obj] = obj
    signal_connect(widget, "destroy") do w
        delete!(_ref_dict, obj)
    end
end

#include("precompile.jl")

end # module
