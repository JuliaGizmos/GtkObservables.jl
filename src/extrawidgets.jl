using Dates

# Widgets built on top of more basic widgets

"""
    frame(w) -> f

Return the GtkFrame `f` associated with widget `w`.
"""
frame(f::GtkFrame) = f

################# A movie-player widget ##################

struct Player{P} <: Widget
    observable::Observable{Int}
    widget::P
    preserved::Vector{Any}

    function Player{P}(observable::Observable{Int}, widget, preserved) where P
        obj = new{P}(observable, widget, preserved)
        gc_preserve(frame(widget), obj)
        obj
    end
end
Player(observable::Observable{Int}, widget::P, preserved) where {P} =
    Player{P}(observable, widget, preserved)

frame(p::Player) = frame(p.widget)

struct PlayerWithTextbox
    range::UnitRange{Int}     # valid values for index
    direction::Observable{Int8}   # +1 = forward, -1 = backward, 0 = not playing
    # GUI elements
    frame::GtkFrame
    scale::Slider{Int}
    entry::Textbox
    play_back::Button
    step_back::Button
    stop::Button
    step_forward::Button
    play_forward::Button
end

frame(p::PlayerWithTextbox) = p.frame

function PlayerWithTextbox(builder, index::Observable{Int}, range::UnitRange{Int}, id::Int=1)
    1 <= id <= 2 || error("only 2 player widgets are defined in player.ui")
    direction = Observable(Int8(0))
    frame = builder["player_frame$id"]::Gtk4.GtkFrame
    scale = slider(range; widget=builder["index_scale$id"]::Gtk4.GtkScale, observable=index)
    entry = textbox(first(range); widget=builder["index_entry$id"]::Gtk4.GtkEntry, observable=index, range=range)
    play_back = button(; widget=builder["play_back$id"]::Gtk4.GtkButton)
    step_back = button(; widget=builder["step_back$id"]::Gtk4.GtkButton)
    stop = button(; widget=builder["stop$id"]::Gtk4.GtkButton)
    step_forward = button(; widget=builder["step_forward$id"]::Gtk4.GtkButton)
    play_forward = button(; widget=builder["play_forward$id"]::Gtk4.GtkButton)

    # Fix up widget properties
    set_gtk_property!(scale.widget, "round-digits", 0)  # glade/gtkbuilder bug that I have to set this here?

    # Link the buttons
    clampindex(i) = clamp(i, minimum(range), maximum(range))
    preserved = Any[on(play_back; weak=true) do _ direction[] = -1 end,
                    on(step_back; weak=true) do _
                       direction[] = 0
                       index[] = clampindex(index[] - 1)
                    end,
                    on(stop; weak=true) do _ direction[] = 0 end,
                    on(step_forward; weak=true) do _
                       direction[] = 0
                       index[] = clampindex(index[] + 1)
                    end,
                    on(play_forward; weak=true) do _ direction[] = +1 end]
    function advance()
        i = index[] + direction[]
        if !(i ∈ range)
            direction[] = 0
            i = clampindex(i)
        end
        index[] = i
        nothing
    end
    # Stop playing if the widget is destroyed
    signal_connect(frame, "destroy") do widget
        setindex!(direction, 0)
    end
    # Start the timer
    push!(preserved, Timer(0.0; interval=1/30) do _
        if direction[] != 0
            advance()
        end
    end)
    # Configure the cleanup
    ondestroy(frame, preserved)
    # Create the player object
    PlayerWithTextbox(range, direction, frame, scale, entry, play_back, step_back, stop, step_forward, play_forward), preserved
end
function PlayerWithTextbox(index::Observable{Int}, range::AbstractUnitRange{<:Integer}, id::Integer=1)
    builder = GtkBuilder(joinpath(splitdir(@__FILE__)[1], "player.ui"))
    PlayerWithTextbox(builder, index, convert(UnitRange{Int}, range), convert(Int, id))
end

player(range::AbstractRange{Int}; style="with-textbox", id::Integer=1) =
    player(Observable(first(range)), convert(UnitRange{Int}, range)::UnitRange{Int}; style=style, id=id)

"""
    player(range; style="with-textbox", id=1)
    player(slice::Observable{Int}, range; style="with-textbox", id=1)

Create a movie-player widget. This includes the standard play and stop
buttons and a slider; style "with-textbox" also includes play
backwards, step forward/backward, and a textbox for entering a
slice by keyboard.

You can create up to two player widgets for the same GUI, as long as
you pass `id=1` and `id=2`, respectively.
"""
function player(cs::Observable, range::AbstractUnitRange{<:Integer}; style="with-textbox", id::Integer=1)
    if style == "with-textbox"
        widget, preserved = PlayerWithTextbox(cs, range, id)
        return Player(cs, widget, preserved)
    end
    error("style $style not recognized")
end

Base.unsafe_convert(::Type{Ptr{Gtk4.GLib.GObject}}, p::PlayerWithTextbox) =
    Base.unsafe_convert(Ptr{Gtk4.GLib.GObject}, frame(p))

Gtk4.destroy(p::PlayerWithTextbox) = destroy(frame(p))


################# A time widget ##########################

struct TimeWidget{T <: Dates.TimeType} <: InputWidget{T}
    observable::Observable{T}
    widget::GtkFrame
end

"""
    timewidget(time)

Return a time widget that includes the `Time` and a `GtkFrame` with the hour, minute, and
second widgets in it. You can specify the specific `GtkFrame` widget (useful when using `GtkBuilder`). Time is guaranteed to be positive.
"""
function timewidget(t1::Dates.Time; widget=nothing, observable=nothing)
    zerotime = Dates.Time(0,0,0) # convenient since we'll use it frequently
    b = Gtk4.GtkBuilder(joinpath(@__DIR__, "time.glade"))
    if observable === nothing
        observable = Observable(t1) # this is the input observable, we can push! into it to update the widget
    end
    S = map(observable) do x
        (Dates.Second(x), x) # crop the seconds from the Time observable, but keep the time for the next (minutes) crop
    end
    M = map(S) do x
        x = last(x) # this is the time
        (Dates.Minute(x), x) # crop the minutes out of this tuple observable, and again, keep hold of the time for the next (hour) crop
    end
    H = map(M) do x
        x = last(x)
        (Dates.Hour(x), x) # last crop, we have the hours now, and the time is kept as well
    end
    t2 = map(last, H) # here is the final time
    connect_nofire!(observable, t2) # we connect the input and output times so that any update to the resulting time will go into the input observable and actually show on the widgets
    Sint = Observable(Dates.value(first(S[]))) # necessary for now, until range-like Gtk4Observables.widgets can accept other ranges.
    Ssb = spinbutton(-1:60, widget=b["second"], observable=Sint) # allow for values outside the actual range of seconds so that we'll be able to increase and decrease minutes.
    on(Sint; weak=true) do x
        Δ = Dates.Second(x) - first(S[]) # how much did we change by, this should always be ±1
        new_t = observable[] + Δ # new time
        new_t = new_t < zerotime ? zerotime : new_t # julia Time is allowed negative values, here we correct for that
        new_x = Dates.Second(new_t) # new seconds
        push!(S, (new_x, new_t)) # update that specific widget, here the magic begins, this update will cascade down the widget-line...
    end
    Sint2 = map(src -> Dates.value(Dates.Second(src)), t2) # Any change in the value of the seconds, namely 60 -> 0, needs to loop back into the beginning of this last chain of events.
    Sint3 = async_latest(Sint2) # important, otherwise we get an endless update loop
    connect_nofire!(Sint, Sint3) # final step of connecting the two
    # everything is the same for minutes:
    Mint = Observable(Dates.value(first(M[])))
    Msb = spinbutton(-1:60, widget=b["minute"], observable=Mint)
    on(Mint; weak=true) do x
        Δ = Dates.Minute(x) - first(M[])
        new_t = observable[] + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Minute(new_t)
        push!(M, (new_x, new_t))
    end
    Mint2 = map(src -> Dates.value(Dates.Minute(src)), t2)
    Mint3 = async_latest(Mint2)
    connect_nofire!(Mint, Mint3)
    # while I think this next part is not entirely necessary for Hours, my brain hurts and I want this to be over. It works.
    Hint = Observable(Dates.value(first(H[])))
    Hsb = spinbutton(0:23, widget=b["hour"], observable=Hint)
    on(Hint; weak=true) do x
        Δ = Dates.Hour(x) - first(H[])
        new_t = observable[] + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Hour(new_t)
        push!(H, (new_x, new_t))
    end
    Hint2 = map(src -> Dates.value(Dates.Hour(src)), t2)
    Hint3 = async_latest(Hint2)
    connect_nofire!(Hint, Hint3)

    if widget === nothing
        return TimeWidget(observable, b["frame"])
    else
        push!(widget, b["frame"])
        return TimeWidget(observable, widget)
    end
end

"""
    datetimewidget(datetime)

Return a datetime widget that includes the `DateTime` and a `GtkBox` with the
year, month, day, hour, minute, and second widgets in it. You can specify the
specific `SpinButton` widgets for the hour, minute, and second (useful when using
`GtkBuilder`). Date and time are guaranteed to be positive.
"""
function datetimewidget(t1::DateTime; widget=nothing, observable=nothing)
    zerotime = DateTime(0,1,1,0,0,0)
    b = Gtk4.GtkBuilder(joinpath(@__DIR__, "datetime.glade"))
    # the same logic is applied here as for `timewidget`
    if observable == nothing
        observable = Observable(t1)
    end
    S = map(observable) do x
        (Dates.Second(x), x)
    end
    M = map(S) do x
        x = last(x)
        (Dates.Minute(x), x)
    end
    H = map(M) do x
        x = last(x)
        (Dates.Hour(x), x)
    end
    d = map(H) do x
        x = last(x)
        (Dates.Day(x), x)
    end
    m = map(d) do x
        x = last(x)
        (Dates.Month(x), x)
    end
    y = map(m) do x
        x = last(x)
        (Dates.Year(x), x)
    end
    t2 = map(last, y)
    connect_nofire!(observable, t2)
    Sint = Observable(Dates.value(first(S[])))
    Ssb = spinbutton(-1:60, widget=b["second"], observable=Sint)
    on(Sint; weak=true) do x
        Δ = Dates.Second(x) - first(S[])
        new_t = observable[] + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Second(new_t)
        push!(S, (new_x, new_t))
    end
    Sint2 = map(src -> Dates.value(Dates.Second(src)), t2)
    Sint3 = async_latest(Sint2)
    connect_nofire!(Sint, Sint3)
    Mint = Observable(Dates.value(first(M[])))
    Msb = spinbutton(-1:60, widget=b["minute"], observable=Mint)
    on(Mint; weak=true) do x
        Δ = Dates.Minute(x) - first(M[])
        new_t = observable[] + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Minute(new_t)
        push!(M, (new_x, new_t))
    end
    Mint2 = map(src -> Dates.value(Dates.Minute(src)), t2)
    Mint3 = async_latest(Mint2)
    connect_nofire!(Mint, Mint3)
    Hint = Observable(Dates.value(first(H[])))
    Hsb = spinbutton(-1:24, widget=b["hour"], observable=Hint)
    on(Hint; weak=true) do x
        Δ = Dates.Hour(x) - first(H[])
        new_t = observable[] + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Hour(new_t)
        push!(H, (new_x, new_t))
    end
    Hint2 = map(src -> Dates.value(Dates.Hour(src)), t2)
    Hint3 = async_latest(Hint2)
    connect_nofire!(Hint, Hint3)
    dint = Observable(Dates.value(first(d[])))
    dsb = spinbutton(-1:32, widget=b["day"], observable=dint)
    on(dint; weak=true) do x
        Δ = Dates.Day(x) - first(d[])
        new_t = observable[] + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Day(new_t)
        push!(d, (new_x, new_t))
    end
    dint2 = map(src -> Dates.value(Dates.Day(src)), t2)
    dint3 = async_latest(dint2)
    connect_nofire!(dint, dint3)
    mint = Observable(Dates.value(first(m[])))
    msb = spinbutton(-1:13, widget=b["month"], observable=mint)
    on(mint; weak=true) do x
        Δ = Dates.Month(x) - first(m[])
        new_t = observable[] + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Month(new_t)
        push!(m, (new_x, new_t))
    end
    mint2 = map(src -> Dates.value(Dates.Month(src)), t2)
    mint3 = async_latest(mint2)
    connect_nofire!(mint, mint3)
    yint = Observable(Dates.value(first(y[])))
    ysb = spinbutton(-1:10000, widget=b["year"], observable=yint)
    on(yint; weak=true) do x
        Δ = Dates.Year(x) - first(y[])
        new_t = observable[] + Δ
        new_t = new_t < zerotime ? zerotime : new_t
        new_x = Dates.Year(new_t)
        push!(y, (new_x, new_t))
    end
    yint2 = map(src -> Dates.value(Dates.Year(src)), t2)
    yint3 = async_latest(yint2)
    connect_nofire!(yint, yint3)

    if widget === nothing
        return TimeWidget(observable, b["frame"])
    else
        push!(widget, b["frame"])
        return TimeWidget(observable, widget)
    end
end

function connect_nofire!(dest::Observable, src::Observables.AbstractObservable)
    on(src; weak=true) do val
        dest.val = val
    end
    return nothing
end
