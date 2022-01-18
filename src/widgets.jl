### Input widgets

"""
    init_wobsval([T], observable, value; default=nothing) -> observable, value

Return a suitable initial state for `observable` and `value` for a
widget. Any but one of these argument can be `nothing`. A new `observable`
will be created if the input `observable` is `nothing`. Passing in a
pre-existing `observable` will return the same observable, either setting the
observable to `value` (if specified as an input) or extracting and
returning its current value (if the `value` input is `nothing`).

Optionally specify the element type `T`; if `observable` is a
`Observables.Observable`, then `T` must agree with `eltype(observable)`.
"""
init_wobsval(::Nothing, ::Nothing; default=nothing) = _init_wobsval(nothing, default)
init_wobsval(::Nothing, value; default=nothing) = _init_wobsval(typeof(value), nothing, value)
init_wobsval(observable, value; default=nothing) = _init_wobsval(eltype(observable), observable, value)
init_wobsval(::Type{T}, ::Nothing, ::Nothing; default=nothing) where {T} =
    _init_wobsval(T, nothing, default)
init_wobsval(::Type{T}, observable, value; default=nothing) where {T} =
    _init_wobsval(T, observable, value)

_init_wobsval(::Nothing, value) = _init_wobsval(typeof(value), nothing, value)
_init_wobsval(::Type{T}, ::Nothing, value) where {T} = Observable{T}(value), value
_init_wobsval(::Type{T}, observable::Observable{T}, ::Nothing) where {T} =
    __init_wobsval(T, observable, observable[])
_init_wobsval(::Type{Union{Nothing, T}}, observable::Observable{T}, ::Nothing) where {T} =
    __init_wobsval(T, observable, observable[])
_init_wobsval(::Type{T}, observable::Observable{T}, value) where {T} = __init_wobsval(T, observable, value)
function __init_wobsval(::Type{T}, observable::Observable{T}, value) where T
    setindex!(observable, value)
    observable, value
end

"""
    init_observable2widget(widget::GtkWidget, id, observable) -> updatesignal
    init_observable2widget(getter, setter, widget::GtkWidget, id, observable) -> updatesignal

Update the "display" value of the Gtk widget `widget` whenever `observable`
changes. `id` is the observable handler id for updating `observable` from the
widget, and is required to prevent the widget from responding to the
update by firing `observable`.

If `updatesignal` is garbage-collected, the widget will no longer
update. Most likely you should either `preserve` or store
`updatesignal`.
"""
function init_observable2widget(getter::Function,
                                setter!::Function,
                                widget::GtkWidget,
                                id, observable)
    on(observable; weak=true) do val
        if signal_handler_is_connected(widget, id)
            signal_handler_block(widget, id)  # prevent "recursive firing" of the handler
            curval = getter(widget)
            try
                curval != val && setter!(widget, val)
            catch
                # if there's a problem setting the widget value, revert the observable
                observable[] = curval
                rethrow()
            end
            signal_handler_unblock(widget, id)
            nothing
        end
    end
end
init_observable2widget(widget::GtkWidget, id, observable) =
    init_observable2widget(defaultgetter, defaultsetter!, widget, id, observable)

defaultgetter(widget) = Gtk.G_.value(widget)
defaultsetter!(widget,val) = Gtk.G_.value(widget, val)

"""
    ondestroy(widget::GtkWidget, preserved)

Create a `destroy` callback for `widget` that terminates updating dependent signals.
"""
function ondestroy(widget::GtkWidget, preserved::AbstractVector)
    signal_connect(widget, "destroy") do widget
        empty!(preserved)
    end
    nothing
end

########################## Slider ############################

struct Slider{T<:Number} <: InputWidget{T}
    observable::Observable{T}
    widget::GtkScaleLeaf
    id::Culong
    preserved::Vector{Any}

    function Slider{T}(observable::Observable{T}, widget, id, preserved) where T
        obj = new{T}(observable, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end
Slider(observable::Observable{T}, widget::GtkScaleLeaf, id, preserved) where {T} =
    Slider{T}(observable, widget, id, preserved)

medianidx(r) = (ax = axes(r)[1]; return (first(ax)+last(ax))÷2)
# differs from median(r) in that it always returns an element of the range
medianelement(r::AbstractRange) = r[medianidx(r)]

slider(observable::Observable, widget::GtkScaleLeaf, id, preserved = []) =
    Slider(observable, widget, id, preserved)

"""
    slider(range; widget=nothing, value=nothing, observable=nothing, orientation="horizontal")

Create a slider widget with the specified `range`. Optionally provide:
  - the GtkScale `widget` (by default, creates a new one)
  - the starting `value` (defaults to the median of `range`)
  - the (Observables.jl) `observable` coupled to this slider (by default, creates a new observable)
  - the `orientation` of the slider.
"""
function slider(range::AbstractRange{T};
                widget=nothing,
                value=nothing,
                observable=nothing,
                orientation="horizontal",
                syncsig=true,
                own=nothing) where T
    obsin = observable
    observable, value = init_wobsval(T, observable, value; default=medianelement(range))
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkScale(lowercase(first(orientation)) == 'v',
                          first(range), last(range), step(range))
        Gtk.G_.size_request(widget, 200, -1)
    else
        adj = Gtk.Adjustment(widget)
        Gtk.G_.lower(adj, first(range))
        Gtk.G_.upper(adj, last(range))
        Gtk.G_.step_increment(adj, step(range))
    end
    Gtk.G_.value(widget, value)

    ## widget -> observable
    id = signal_connect(widget, "value_changed") do w
        observable[] = defaultgetter(w)
    end

    ## observable -> widget
    preserved = []
    if syncsig
        push!(preserved, init_observable2widget(widget, id, observable))
    end
    if own
        ondestroy(widget, preserved)
    end

    Slider(observable, widget, id, preserved)
end

# Adjust the range on a slider
# Is calling this `setindex!` too much of a pun?
function Base.setindex!(s::Slider, (range,value)::Tuple{AbstractRange, Any})
    first(range) <= value <= last(range) || error("$value is not within the span of $range")
    adj = Gtk.Adjustment(widget(s))
    Gtk.G_.lower(adj, first(range))
    Gtk.G_.upper(adj, last(range))
    Gtk.G_.step_increment(adj, step(range))
    Gtk.G_.value(widget(s), value)
end
Base.setindex!(s::Slider, range::AbstractRange) = setindex!(s, (range, s[]))

######################### Checkbox ###########################

struct Checkbox <: InputWidget{Bool}
    observable::Observable{Bool}
    widget::GtkCheckButtonLeaf
    id::Culong
    preserved::Vector{Any}

    function Checkbox(observable::Observable{Bool}, widget, id, preserved)
        obj = new(observable, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

checkbox(observable::Observable, widget::GtkCheckButtonLeaf, id, preserved=[]) =
    Checkbox(observable, widget, id, preserved)

"""
    checkbox(value=false; widget=nothing, observable=nothing, label="")

Provide a checkbox with the specified starting (boolean)
`value`. Optionally provide:
  - a GtkCheckButton `widget` (by default, creates a new one)
  - the (Observables.jl) `observable` coupled to this checkbox (by default, creates a new observable)
  - a display `label` for this widget
"""
function checkbox(value::Bool; widget=nothing, observable=nothing, label="", own=nothing)
    obsin = observable
    observable, value = init_wobsval(observable, value)
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkCheckButton(label)
    end
    Gtk.G_.active(widget, value)

    id = signal_connect(widget, "clicked") do w
        observable[] = Gtk.G_.active(w)
    end
    preserved = []
    push!(preserved, init_observable2widget(w->Gtk.G_.active(w),
                                            (w,val)->Gtk.G_.active(w, val),
                                            widget, id, observable))
    if own
        ondestroy(widget, preserved)
    end

    Checkbox(observable, widget, id, preserved)
end
checkbox(; value=false, widget=nothing, observable=nothing, label="", own=nothing) =
    checkbox(value; widget=widget, observable=observable, label=label, own=own)

###################### ToggleButton ########################

struct ToggleButton <: InputWidget{Bool}
    observable::Observable{Bool}
    widget::GtkToggleButtonLeaf
    id::Culong
    preserved::Vector{Any}

    function ToggleButton(observable::Observable{Bool}, widget, id, preserved)
        obj = new(observable, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

togglebutton(observable::Observable, widget::GtkToggleButtonLeaf, id, preserved=[]) =
    ToggleButton(observable, widget, id, preserved)

"""
    togglebutton(value=false; widget=nothing, observable=nothing, label="")

Provide a togglebutton with the specified starting (boolean)
`value`. Optionally provide:
  - a GtkCheckButton `widget` (by default, creates a new one)
  - the (Observables.jl) `observable` coupled to this button (by default, creates a new observable)
  - a display `label` for this widget
"""
function togglebutton(value::Bool; widget=nothing, observable=nothing, label="", own=nothing)
    obsin = observable
    observable, value = init_wobsval(observable, value)
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkToggleButton(label)
    end
    Gtk.G_.active(widget, value)

    id = signal_connect(widget, "clicked") do w
        setindex!(observable, Gtk.G_.active(w))
    end
    preserved = []
    push!(preserved, init_observable2widget(w->Gtk.G_.active(w),
                                        (w,val)->Gtk.G_.active(w, val),
                                        widget, id, observable))
    if own
        ondestroy(widget, preserved)
    end

    ToggleButton(observable, widget, id, preserved)
end
togglebutton(; value=false, widget=nothing, observable=nothing, label="", own=nothing) =
    togglebutton(value; widget=widget, observable=observable, label=label, own=own)

######################### Button ###########################

struct Button <: InputWidget{Nothing}
    observable::Observable{Nothing}
    widget::Union{GtkButtonLeaf,GtkToolButtonLeaf}
    id::Culong

    function Button(observable::Observable{Nothing}, widget, id)
        obj = new(observable, widget, id)
        gc_preserve(widget, obj)
        obj
    end
end

button(observable::Observable, widget::Union{GtkButtonLeaf,GtkToolButtonLeaf}, id) =
    Button(observable, widget, id)

"""
    button(label; widget=nothing, observable=nothing)
    button(; label=nothing, widget=nothing, observable=nothing)

Create a push button with text-label `label`. Optionally provide:
  - a GtkButton `widget` (by default, creates a new one)
  - the (Observables.jl) `observable` coupled to this button (by default, creates a new observable)
"""
function button(;
                label::Union{Nothing,String,Symbol}=nothing,
                widget=nothing,
                observable=nothing,
                own=nothing)
    obsin = observable
    if observable === nothing
        observable = Observable(nothing)
    end
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkButton(label)
    end

    id = signal_connect(widget, "clicked") do w
        setindex!(observable, nothing)
    end

    Button(observable, widget, id)
end
button(label::Union{String,Symbol}; widget=nothing, observable=nothing, own=nothing) =
    button(; label=label, widget=widget, observable=observable, own=own)

######################### ColorButton ###########################

struct ColorButton{C} <: InputWidget{Nothing}
    observable::Observable{C}
    widget::GtkColorButtonLeaf
    id::Culong
    preserved::Vector{Any}

    function ColorButton{C}(observable::Observable{C}, widget, id, preserved) where {T, C <: Color{T, 3}}
        obj = new(observable, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

colorbutton(observable::Observable{C}, widget::GtkColorButtonLeaf, id, preserved = []) where {T, C <: Color{T, 3}} =
    ColorButton{C}(observable, widget, id, preserved)

Base.convert(::Type{RGBA}, gcolor::Gtk.GdkRGBA) = RGBA(gcolor.r, gcolor.g, gcolor.b, gcolor.a)
Base.convert(::Type{Gtk.GdkRGBA}, color::Colorant) = Gtk.GdkRGBA(red(color), green(color), blue(color), alpha(color))

"""
    colorbutton(color; widget=nothing, observable=nothing)
    colorbutton(; color=nothing, widget=nothing, observable=nothing)

Create a push button with color `color`. Clicking opens a color picker. Optionally provide:
  - a GtkButton `widget` (by default, creates a new one)
  - the (Observables.jl) `observable` coupled to this button (by default, creates a new observable)
"""
function colorbutton(;
                color::C = RGB(0, 0, 0),
                widget=nothing,
                observable=nothing,
                own=nothing) where {T, C <: Color{T, 3}}
    obsin = observable
    observable, color = init_wobsval(observable, color)
    if own === nothing
        own = observable != obsin
    end
    getcolor(w) = get_gtk_property(w, :rgba, Gtk.GdkRGBA)
    setcolor!(w, val) = set_gtk_property!(w, :rgba, convert(Gtk.GdkRGBA, val))
    if widget === nothing
        widget = GtkColorButton(convert(Gtk.GdkRGBA, color))
    else
        setcolor!(widget, color)
    end
    id = signal_connect(widget, "color-set") do w
        setindex!(observable, convert(C, convert(RGBA, getcolor(widget))))
    end
    preserved = []
    push!(preserved, init_observable2widget(getcolor, setcolor!, widget, id, observable))

    if own
        ondestroy(widget, preserved)
    end

    ColorButton{C}(observable, widget, id, preserved)
end
colorbutton(color::Color{T, 3}; widget=nothing, observable=nothing, own=nothing) where T =
    colorbutton(; color=color, widget=widget, observable=observable, own=own)

######################## Textbox ###########################

struct Textbox{T} <: InputWidget{T}
    observable::Observable{T}
    widget::GtkEntryLeaf
    id::Culong
    preserved::Vector{Any}
    range

    function Textbox{T}(observable::Observable{T}, widget, id, preserved, range) where T
        obj = new{T}(observable, widget, id, preserved, range)
        gc_preserve(widget, obj)
        obj
    end
end
Textbox(observable::Observable{T}, widget::GtkEntryLeaf, id, preserved, range) where {T} =
    Textbox{T}(observable, widget, id, preserved, range)

textbox(observable::Observable, widget::GtkButtonLeaf, id, preserved = []) =
    Textbox(observable, widget, id, preserved)

"""
    textbox(value=""; widget=nothing, observable=nothing, range=nothing, gtksignal=:activate)
    textbox(T::Type; widget=nothing, observable=nothing, range=nothing, gtksignal=:activate)

Create a box for entering text. `value` is the starting value; if you
don't want to provide an initial value, you can constrain the type
with `T`. Optionally specify the allowed range (e.g., `-10:10`)
for numeric entries, and/or provide the (Observables.jl) `observable` coupled
to this text box. Finally, you can specify which Gtk observable (e.g.
`activate`, `changed`) you'd like the widget to update with.
"""
function textbox(::Type{T};
                 widget=nothing,
                 value=nothing,
                 range=nothing,
                 observable=nothing,
                 syncsig=true,
                 own=nothing,
                 gtksignal::String="activate") where T
    if T <: AbstractString && range !== nothing
        throw(ArgumentError("You cannot set a range on a string textbox"))
    end
    obsin = observable
    observable, value = init_wobsval(T, observable, value; default="")
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkEntry()
    end
    set_gtk_property!(widget, "text", value)

    id = signal_connect(widget, gtksignal) do w
        setindex!(observable, entrygetter(w, observable, range))
    end

    preserved = []
    function checked_entrysetter!(w, val)
        val ∈ range || throw(ArgumentError("$val is not within $range"))
        entrysetter!(w, val)
    end
    if syncsig
        push!(preserved, init_observable2widget(w->entrygetter(w, observable, range),
                                                range === nothing ? entrysetter! : checked_entrysetter!,
                                                widget, id, observable))
    end
    own && ondestroy(widget, preserved)

    Textbox(observable, widget, id, preserved, range)
end
function textbox(value::T;
                 widget=nothing,
                 range=nothing,
                 observable=nothing,
                 syncsig=true,
                 own=nothing,
                 gtksignal="activate") where T
    textbox(T; widget=widget, value=value, range=range, observable=observable, syncsig=syncsig, own=own, gtksignal=gtksignal)
end

entrygetter(w, ::Observable{<:AbstractString}, ::Nothing) =
    get_gtk_property(w, "text", String)
function entrygetter(w, observable::Observable{T}, range) where T
    val = tryparse(T, get_gtk_property(w, "text", String))
    if val === nothing
        nval = observable[]
        # Invalid entry, restore the old value
        entrysetter!(w, nval)
    else
        nval = nearest(val, range)
        if val != nval
            entrysetter!(w, nval)
        end
    end
    nval
end
nearest(val, ::Nothing) = val
function nearest(val, r::AbstractRange)
    i = round(Int, (val - first(r))/step(r)) + 1
    ax = axes(r)[1]
    r[clamp(i, first(ax), last(ax))]
end

entrysetter!(w, val) = set_gtk_property!(w, "text", string(val))


######################### Textarea ###########################

struct Textarea <: InputWidget{String}
    observable::Observable{String}
    widget::GtkTextViewLeaf
    id::Culong
    preserved::Vector{Any}

    function Textarea(observable::Observable{String}, widget, id, preserved)
        obj = new(observable, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

"""
    textarea(value=""; widget=nothing, observable=nothing)

Creates an extended text-entry area. Optionally provide a GtkTextView `widget`
and/or the (Observables.jl) `observable` associated with this widget. The
`observable` updates when you type.
"""
function textarea(value::String="";
                  widget=nothing,
                  observable=nothing,
                  syncsig=true,
                  own=nothing)
    obsin = observable
    observable, value = init_wobsval(observable, value)
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkTextView()
    end
    buf = widget[:buffer, GtkTextBuffer]
    buf[String] = value
    sleep(0.01)   # without this, we more frequently get segfaults...not sure why

    id = signal_connect(buf, "changed") do w
        setindex!(observable, w[String])
    end

    preserved = []
    if syncsig
        # GtkTextBuffer is not a GtkWidget, so we have to do this manually
        push!(preserved, on(observable; weak=true) do val
                  signal_handler_block(buf, id)
                  curval = get_gtk_property(buf, "text", String)
                  curval != val && set_gtk_property!(buf, "text", val)
                  signal_handler_unblock(buf, id)
                  nothing
              end)
    end
    own && ondestroy(widget, preserved)

    Textarea(observable, widget, id, preserved)
end

##################### SelectionWidgets ######################

struct Dropdown <: InputWidget{String}
    observable::Union{Observable{String}, Observable{Union{Nothing, String}}} # consider removing support for Observable{String} in next breaking release
    mappedsignal::Observable{Any}
    widget::GtkComboBoxTextLeaf
    str2int::Dict{String,Int}
    id::Culong
    preserved::Vector{Any}

    function Dropdown(observable::Union{Observable{String}, Observable{Union{Nothing, String}}}, mappedsignal::Observable, widget, str2int, id, preserved)
        obj = new(observable, mappedsignal, widget, str2int, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

"""
    dropdown(choices; widget=nothing, value=first(choices), observable=nothing, label="", with_entry=true, icons, tooltips)

Create a "dropdown" widget. `choices` can be a vector (or other iterable) of
options. These options might either be a list of strings, or a list of `choice::String => func` pairs
so that an action encoded by `func` can be taken when `choice` is selected.

Optionally specify
  - the GtkComboBoxText `widget` (by default, creates a new one)
  - the starting `value`
  - the (Observables.jl) `observable` coupled to this slider (by default, creates a new observable)
  - whether the widget should allow text entry

# Examples

    dd = dropdown(["one", "two", "three"])

To link a callback to the dropdown, use

    dd = dropdown(("turn red"=>colorize_red, "turn green"=>colorize_green))
    on(dd.mappedsignal) do cb
        cb(img)                     # img is external data you want to act on
    end

`cb` does not fire for the initial value of `dd`; if this is desired, manually execute
`dd[] = dd[]` after defining this action.

`dd.mappedsignal` is a function-observable only for the pairs syntax for `choices`.
"""
function dropdown(; choices=nothing,
                  widget=nothing,
                  value=nothing,
                  observable=nothing,
                  label="",
                  with_entry=true,
                  icons=nothing,
                  tooltips=nothing,
                  own=nothing)
    obsin = observable
    observable, value = init_wobsval(Union{Nothing, String}, observable, value)
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkComboBoxText()
    end
    if choices !== nothing
        empty!(widget)
    else
        error("Pre-loading the widget is not yet supported")
    end
    allstrings = all(x->isa(x, AbstractString), choices)
    allstrings || all(x->isa(x, Pair), choices) || throw(ArgumentError("all elements must either be strings or pairs, got $choices"))
    str2int = Dict{String,Int}()
    getactive(w) = (val = GAccessor.active_text(w); val == C_NULL ? nothing : Gtk.bytestring(val))
    setactive!(w, val) = (i = val !== nothing ? str2int[val] : -1; set_gtk_property!(w, :active, i))
    if length(choices) > 0
        if value === nothing || (observable isa Observable{String} && value ∉ juststring.(choices))
            # default to the first choice if value is nothing, or else if it's an empty String observable
            # and none of the choices are empty strings
            value = juststring(first(choices))
            observable[] = value
        end
    end
    k = -1
    for c in choices
        str = juststring(c)
        push!(widget, str)
        str2int[str] = (k+=1)
    end
    setactive!(widget, value)

    id = signal_connect(widget, "changed") do w
        setindex!(observable, getactive(w))
    end

    preserved = []
    push!(preserved, init_observable2widget(getactive, setactive!, widget, id, observable))
    mappedsignal = Observable{Any}(nothing)
    if !allstrings
        choicedict = Dict(choices...)
        map!(mappedsignal, observable) do val
            if val !== nothing
                choicedict[val]
            else
                _ -> nothing
            end
        end
    end
    if own
        ondestroy(widget, preserved)
    end

    Dropdown(observable, mappedsignal, widget, str2int, id, preserved)
end

function Base.precompile(w::Dropdown)
    return invoke(precompile, Tuple{Widget}, w) & precompile(w.mappedsignal)
end

function dropdown(choices; kwargs...)
    dropdown(; choices=choices, kwargs...)
end

function Base.append!(w::Dropdown, choices)
    allstrings = all(x->isa(x, AbstractString), choices)
    allstrings || all(x->isa(x, Pair), choices) || throw(ArgumentError("all elements must either be strings or pairs, got $choices"))
    allstrings && w.mappedsignal[] === nothing || throw(ArgumentError("only pairs may be added to a combobox with pairs, got $choices"))
    k = length(w.str2int) - 1
    for c in choices
        str = juststring(c)
        push!(w.widget, str)
        w.str2int[str] = (k+=1)
    end
    return w
end

function Base.empty!(w::Dropdown)
    w.observable isa Observable{String} &&
        throw(ArgumentError("empty! is only supported when the associated observable is of type $(Union{Nothing, String})"))
    empty!(w.str2int)
    empty!(w.widget)
    w.mappedsignal[] = nothing
    return w
end

juststring(str::AbstractString) = String(str)
juststring(p::Pair{String}) = p.first
pairaction(str::AbstractString) = x->nothing
pairaction(p::Pair{String,F}) where {F<:Function} = p.second


# """
# radiobuttons: see the help for `dropdown`
# """
# radiobuttons(opts; kwargs...) =
#     Options(:RadioButtons, opts; kwargs...)

# """
# selection: see the help for `dropdown`
# """
# function selection(opts; multi=false, kwargs...)
#     if multi
#         options = getoptions(opts)
#         #observable needs to be of an array of values, not just a single value
#         observable = Observable(collect(values(options))[1:1])
#         Options(:SelectMultiple, options; observable=observable, kwargs...)
#     else
#         Options(:Select, opts; kwargs...)
#     end
# end

# Base.@deprecate select(opts; kwargs...) selection(opts, kwargs...)

# """
# togglebuttons: see the help for `dropdown`
# """
# togglebuttons(opts; kwargs...) =
#     Options(:ToggleButtons, opts; kwargs...)

# """
# selection_slider: see the help for `dropdown`
# If the slider has numeric (<:Real) values, and its observable is updated, it will
# update to the nearest value from the range/choices provided. To disable this
# behaviour, so that the widget state will only update if an exact match for
# observable value is found in the range/choice, use `syncnearest=false`.
# """
# selection_slider(opts; kwargs...) = begin
#     if !haskey(Dict(kwargs), :value_label)
#         #default to middle of slider
#         mid_idx = medianidx(opts)
#         push!(kwargs, (:sel_mid_idx, mid_idx))
#     end
#     Options(:SelectionSlider, opts; kwargs...)
# end

# """
# `vselection_slider(args...; kwargs...)`

# Shorthand for `selection_slider(args...; orientation="vertical", kwargs...)`
# """
# vselection_slider(args...; kwargs...) = selection_slider(args...; orientation="vertical", kwargs...)

# function nearest_val(x, val)
#     local valbest
#     local dxbest = typemax(Float64)
#     for v in x
#         dx = abs(v-val)
#         if dx < dxbest
#             dxbest = dx
#             valbest = v
#         end
#     end
#     valbest
# end


### Output Widgets

######################## Label #############################

struct Label <: Widget
    observable::Observable{String}
    widget::GtkLabelLeaf
    preserved::Vector{Any}

    function Label(observable::Observable{String}, widget, preserved)
        obj = new(observable, widget, preserved)
        gc_preserve(widget, obj)
        obj
    end
end

"""
    label(value; widget=nothing, observable=nothing)

Create a text label displaying `value` as a string; new values may
displayed by pushing to the widget. Optionally specify
  - the GtkLabel `widget` (by default, creates a new one)
  - the (Observables.jl) `observable` coupled to this label (by default, creates a new observable)
"""
function label(value;
               widget=nothing,
               observable=nothing,
               syncsig=true,
               own=nothing)
    obsin = observable
    observable, value = init_wobsval(String, observable, value)
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkLabel(value)
    else
        set_gtk_property!(widget, "label", value)
    end
    preserved = []
    if syncsig
        let widget=widget
            push!(preserved, on(observable; weak=true) do val
                set_gtk_property!(widget, "label", val)
            end)
        end
    end
    if own
        ondestroy(widget, preserved)
    end
    Label(observable, widget, preserved)
end

# export Latex, Progress

# Base.@deprecate html(value; label="")  HTML(value)

# type Latex <: Widget
#     label::AbstractString
#     value::AbstractString
# end
# latex(label, value::AbstractString) = Latex(label, value)
# latex(value::AbstractString; label="") = Latex(label, value)
# latex(value; label="") = Latex(label, mimewritable("application/x-latex", value) ? stringmime("application/x-latex", value) : stringmime("text/latex", value))

# ## # assume we already have Latex
# ## writemime(io::IO, m::MIME{symbol("application/x-latex")}, l::Latex) =
# ##     write(io, l.value)

# type Progress <: Widget
#     label::AbstractString
#     value::Int
#     range::AbstractRange
#     orientation::String
#     readout::Bool
#     readout_format::String
#     continuous_update::Bool
# end

# progress(args...) = Progress(args...)
# progress(;label="", value=0, range=0:100, orientation="horizontal",
#             readout=true, readout_format="d", continuous_update=true) =
#     Progress(label, value, range, orientation, readout, readout_format, continuous_update)

# # Make a widget out of a domain
# widget(x::Observable, label="") = x
# widget(x::Widget, label="") = x
# widget(x::AbstractRange, label="") = selection_slider(x, label=label)
# widget(x::AbstractVector, label="") = togglebuttons(x, label=label)
# widget(x::Associative, label="") = togglebuttons(x, label=label)
# widget(x::Bool, label="") = checkbox(x, label=label)
# widget(x::AbstractString, label="") = textbox(x, label=label, typ=AbstractString)
# widget{T <: Number}(x::T, label="") = textbox(typ=T, value=x, label=label)

# ### Set!

# """
# `set!(w::Widget, fld::Symbol, val)`

# Set the value of a widget property and update all displayed instances of the
# widget. If `val` is a `Observable`, then updates to that observable will be reflected in
# widget instances/views.

# If `fld` is `:value`, `val` is also `push!`ed to `observable(w)`
# """
# function set!(w::Widget, fld::Symbol, val)
#     fld == :value && val != observable(w).value && push!(observable(w), val)
#     setfield!(w, fld, val)
#     update_view(w)
#     w
# end

# set!(w::Widget, fld::Symbol, valsig::Observable) = begin
#     map(val -> set!(w, fld, val), valsig) |> preserve
# end

# set!{T<:Options}(w::T, fld::Symbol, val::Union{Observable,Any}) = begin
#     fld == :options && (val = getoptions(val))
#     invoke(set!, (Widget, Symbol, typeof(val)), w, fld, val)
# end

########################## SpinButton ########################

struct SpinButton{T<:Number} <: InputWidget{T}
    observable::Observable{T}
    widget::GtkSpinButtonLeaf
    id::Culong
    preserved::Vector{Any}

    function SpinButton{T}(observable::Observable{T}, widget, id, preserved) where T
        obj = new{T}(observable, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end
SpinButton(observable::Observable{T}, widget::GtkSpinButtonLeaf, id, preserved) where {T} =
    SpinButton{T}(observable, widget, id, preserved)

spinbutton(observable::Observable, widget::GtkSpinButtonLeaf, id, preserved = []) =
    SpinButton(observable, widget, id, preserved)

"""
    spinbutton(range; widget=nothing, value=nothing, observable=nothing, orientation="horizontal")

Create a spinbutton widget with the specified `range`. Optionally provide:
  - the GtkSpinButton `widget` (by default, creates a new one)
  - the starting `value` (defaults to the start of `range`)
  - the (Observables.jl) `observable` coupled to this spinbutton (by default, creates a new observable)
  - the `orientation` of the spinbutton.
"""
function spinbutton(range::AbstractRange{T};
                    widget=nothing,
                    value=nothing,
                    observable=nothing,
                    orientation="horizontal",
                    syncsig=true,
                    own=nothing) where T
    obsin = observable
    observable, value = init_wobsval(T, observable, value; default=range.start)
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkSpinButton(
                          first(range), last(range), step(range))
        Gtk.G_.size_request(widget, 200, -1)
    else
        adj = Gtk.Adjustment(widget)
        Gtk.G_.lower(adj, first(range))
        Gtk.G_.upper(adj, last(range))
        Gtk.G_.step_increment(adj, step(range))
    end
    if lowercase(first(orientation)) == 'v'
        Gtk.G_.orientation(Gtk.GtkOrientable(widget),
                           Gtk.GConstants.GtkOrientation.VERTICAL)
    end
    Gtk.G_.value(widget, value)

    ## widget -> observable
    id = signal_connect(widget, "value_changed") do w
        setindex!(observable, defaultgetter(w))
    end

    ## observable -> widget
    preserved = []
    if syncsig
        push!(preserved, init_observable2widget(widget, id, observable))
    end
    if own
        ondestroy(widget, preserved)
    end

    SpinButton(observable, widget, id, preserved)
end

# Adjust the range on a spinbutton
# Is calling this `setindex!` too much of a pun?
function Base.setindex!(s::SpinButton, (range,value)::Tuple{AbstractRange,Any})
    first(range) <= value <= last(range) || error("$value is not within the span of $range")
    adj = Gtk.Adjustment(widget(s))
    Gtk.G_.lower(adj, first(range))
    Gtk.G_.upper(adj, last(range))
    Gtk.G_.step_increment(adj, step(range))
    Gtk.G_.value(widget(s), value)
end
Base.setindex!(s::SpinButton, range::AbstractRange) = setindex!(s, (range, s[]))

########################## CyclicSpinButton ########################

struct CyclicSpinButton{T<:Number} <: InputWidget{T}
    observable::Observable{T}
    widget::GtkSpinButtonLeaf
    id::Culong
    preserved::Vector{Any}

    function CyclicSpinButton{T}(observable::Observable{T}, widget, id, preserved) where T
        obj = new{T}(observable, widget, id, preserved)
        gc_preserve(widget, obj)
        obj
    end
end
CyclicSpinButton(observable::Observable{T}, widget::GtkSpinButtonLeaf, id, preserved) where {T} =
    CyclicSpinButton{T}(observable, widget, id, preserved)

cyclicspinbutton(observable::Observable, widget::GtkSpinButtonLeaf, id, preserved = []) =
    CyclicSpinButton(observable, widget, id, preserved)

"""
    cyclicspinbutton(range, carry_up; widget=nothing, value=nothing, observable=nothing, orientation="horizontal")

Create a cyclicspinbutton widget with the specified `range` that updates a `carry_up::Observable{Bool}`
only when a value outside the `range` of the cyclicspinbutton is pushed. `carry_up`
is updated with `true` when the cyclicspinbutton is updated with a value that is
higher than the maximum of the range. When cyclicspinbutton is updated with a value that is smaller
than the minimum of the range `carry_up` is updated with `false`. Optional arguments are:
  - the GtkSpinButton `widget` (by default, creates a new one)
  - the starting `value` (defaults to the start of `range`)
  - the (Observables.jl) `observable` coupled to this cyclicspinbutton (by default, creates a new observable)
  - the `orientation` of the cyclicspinbutton.
"""
function cyclicspinbutton(range::AbstractRange{T}, carry_up::Observable{Bool};
                          widget=nothing,
                          value=nothing,
                          observable=nothing,
                          orientation="horizontal",
                          syncsig=true,
                          own=nothing) where T
    obsin = observable
    observable, value = init_wobsval(T, observable, value; default=range.start)
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkSpinButton(first(range) - step(range), last(range) + step(range), step(range))
        Gtk.G_.size_request(widget, 200, -1)
    else
        adj = Gtk.Adjustment(widget)
        Gtk.G_.lower(adj, first(range) - step(range))
        Gtk.G_.upper(adj, last(range) + step(range))
        Gtk.G_.step_increment(adj, step(range))
    end
    if lowercase(first(orientation)) == 'v'
        Gtk.G_.orientation(Gtk.GtkOrientable(widget),
                           Gtk.GConstants.GtkOrientation.VERTICAL)
    end
    Gtk.G_.value(widget, value)

    ## widget -> observable
    id = signal_connect(widget, "value_changed") do w
        setindex!(observable, defaultgetter(w))
    end

    ## observable -> widget
    preserved = []
    if syncsig
        push!(preserved, init_observable2widget(widget, id, observable))
    end
    if own
        ondestroy(widget, preserved)
    end

    push!(preserved, on(observable; weak=true) do val
        if val > maximum(range)
            observable.val = minimum(range)
            setindex!(carry_up, true)
        end
    end)
    push!(preserved, on(observable; weak=true) do val
        if val < minimum(range)
            observable.val = maximum(range)
            setindex!(carry_up, false)
        end
    end)
    setindex!(observable, value)

    CyclicSpinButton(observable, widget, id, preserved)
end

######################## ProgressBar #########################

struct ProgressBar{T <: Number} <: Widget
    observable::Observable{T}
    widget::GtkProgressBarLeaf
    preserved::Vector{Any}

    function ProgressBar{T}(observable::Observable{T}, widget, preserved) where T
        obj = new{T}(observable, widget, preserved)
        gc_preserve(widget, obj)
        obj
    end
end
ProgressBar(observable::Observable{T}, widget::GtkProgressBarLeaf, preserved) where {T} =
    ProgressBar{T}(observable, widget, preserved)

# convert a member of the interval into a decimal
interval2fraction(x::AbstractInterval, i) = (i - minimum(x))/IntervalSets.width(x)

"""
    progressbar(interval::AbstractInterval; widget=nothing, observable=nothing)

Create a progressbar displaying the current state in the given interval; new iterations may be
displayed by pushing to the widget. Optionally specify
  - the GtkProgressBar `widget` (by default, creates a new one)
  - the (Observables.jl) `observable` coupled to this progressbar (by default, creates a new observable)

# Examples

```julia-repl
julia> using GtkObservables

julia> using IntervalSets

julia> n = 10

julia> pb = progressbar(1..n)
Gtk.GtkProgressBarLeaf with 1: "input" = 1 Int64

julia> for i = 1:n
           # do something
           push!(pb, i)
       end

```
"""
function progressbar(interval::AbstractInterval{T};
                     widget=nothing,
                     observable=nothing,
                     syncsig=true,
                     own=nothing) where T<:Number
    value = minimum(interval)
    obsin = observable
    observable, value = init_wobsval(T, observable, value)
    if own === nothing
        own = observable != obsin
    end
    if widget === nothing
        widget = GtkProgressBar()
    else
        set_gtk_property!(widget, "fraction", interval2fraction(interval, value))
    end
    preserved = []
    if syncsig
        push!(preserved, on(observable; weak=true) do val
            set_gtk_property!(widget, "fraction", interval2fraction(interval, val))
        end)
    end
    if own
        ondestroy(widget, preserved)
    end
    ProgressBar(observable, widget, preserved)
end

progressbar(range::AbstractRange; args...) = progressbar(ClosedInterval(range); args...)
