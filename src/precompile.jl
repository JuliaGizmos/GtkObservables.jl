using PrecompileTools

@setup_workload begin
    function buttoncontroller(c)
        l = Gtk4.observe_controllers(widget(c))
        c=findfirst(x->isa(GtkGestureClick, x),l)
        c===nothing && error("Didn't find a GestureClick controller")
        c
    end
    # function eventbutton(c, event_type, btn, x=DeviceUnit(0), y=DeviceUnit(0), state=0)
    #     xd, yd = GtkObservables.convertunits(DeviceUnit, c, x, y)
    #     Gtk.GdkEventButton(event_type,
    #                        Gtk.gdk_window(widget(c)),
    #                        Int8(0),
    #                        UInt32(0),
    #                        convert(Float64, xd), convert(Float64, yd),
    #                        convert(Ptr{Float64},C_NULL),
    #                        UInt32(state),
    #                        UInt32(btn),
    #                        C_NULL,
    #                        0.0, 0.0)
    # end
    # function eventscroll(c, direction, x=DeviceUnit(0), y=DeviceUnit(0), state=0)
    #     xd, yd = GtkObservables.convertunits(DeviceUnit, c, x, y)
    #     Gtk.GdkEventScroll(Gtk.GdkEventType.SCROLL,
    #                        Gtk.gdk_window(widget(c)),
    #                        Int8(0),
    #                        UInt32(0),
    #                        convert(Float64, xd), convert(Float64, yd),
    #                        UInt32(state),
    #                        direction,
    #                        convert(Ptr{Float64},C_NULL),
    #                        0.0, 0.0,
    #                        0.0, 0.0)
    # end
    # function eventmotion(c, btn, x, y)
    #     xd, yd = GtkObservables.convertunits(DeviceUnit, c, x, y)
    #     Gtk.GdkEventMotion(Gtk.GdkEventType.MOTION_NOTIFY,
    #                        Gtk.gdk_window(widget(c)),
    #                        Int8(0),
    #                        UInt32(0),
    #                        convert(Float64, xd), convert(Float64, yd),
    #                        convert(Ptr{Float64},C_NULL),
    #                        UInt32(btn),
    #                        Int16(0),
    #                        C_NULL,
    #                        0.0, 0.0)
    # end
    #ModType = Gtk.GConstants.GdkModifierType
    #mask(btn) =
    #    btn == 1 ? ModType.GDK_BUTTON1_MASK :
    #    btn == 2 ? ModType.GDK_BUTTON2_MASK :
    #    btn == 3 ? ModType.GDK_BUTTON3_MASK :
    #    error(btn, " not recognized")

    imgrand = rand(RGB{N0f8}, 100, 100)
    Gtk4.GLib.start_main_loop()
    @compile_workload begin
        @async println("is loop running? ", Gtk4.GLib.is_loop_running())
        # slider
        sl = slider(1:3)
        sl[] = (1:5, 3)
        precompile(sl)
        sl=nothing

        # checkbox
        cb = checkbox(true)
        cb[] = false
        precompile(cb)
        cb=nothing

        # togglebutton
        tb = togglebutton(true)
        tb[] = false
        precompile(tb)
        tb=nothing

        # button
        btn = button("Push me")
        btn[] = nothing
        precompile(btn)
        btn=nothing

        # colorbutton
        cbtn = colorbutton(RGB(0, 0, 0))
        cbtn[] = RGB(1, 0, 0)
        precompile(cbtn)
        cbtn=nothing

        # textbox
        tb1, tb2 = textbox("Edit me"), textbox(3; range=1:5)
        tb1[] = "done"
        tb2[] = 4
        precompile(tb1)
        precompile(tb2)
        tb1=tb2=nothing

        # textarea
        ta = textarea("Lorem ipsum...")
        ta[] = "...muspi meroL"
        precompile(ta)
        ta=nothing

        # dropdown
        dd = dropdown(["one", "two", "three"])
        precompile(dd)
        dd=nothing
        precompile(Tuple{typeof(dropdown),Tuple{Vararg{String, 100}}})   # time: 0.042523906
        precompile(Tuple{typeof(dropdown),Vector{Pair{String, Function}}})   # time: 0.01169991

        # label
        lbl = label("Info")
        lbl[] = "other info"
        precompile(lbl)
        lbl=nothing
        precompile(Tuple{typeof(show),IOBuffer,Label})   # time: 0.07879969

        # spinbutton
        sb = spinbutton(1:3)
        sb[] = (1:4, 4)
        precompile(sb)
        sb=nothing

        # cyclicspinbutton
        csb = cyclicspinbutton(1:3, Observable(true))
        csb[] = 4
        precompile(csb)
        csb=nothing

        # progressbar
        pb = progressbar(1:3)
        pb[] = 2
        precompile(pb)
        pb=nothing
        pb = progressbar(1.0 .. 3.0)
        pb[] = 2.2
        precompile(pb)
        pb=nothing

        # player
        p = player(1:3)
        precompile(p)
        p[] = 2
        p=nothing

        # timewidget
        tw = timewidget(Dates.Time(1,1,1))
        tw[] = Dates.Time(2,2,2)
        precompile(tw)
        tw=nothing

        # datetimewidget
        dtw = datetimewidget(DateTime(1,1,1,1,1,1))
        dtw[] = DateTime(2,2,2,2,2,2)
        dtw=nothing

        # canvas
        try # if we don't have a display, this might fail?
            for U in (UserUnit, DeviceUnit)
                c = canvas(U, 100, 100)
                fill!(c, RGB(0, 0, 0))
                fill!(c, RGBA(1, 1, 1, 1))
                lastevent = Ref("nothing")
                press = map(btn->lastevent[] = "press", c.mouse.buttonpress)
                signal_emit(buttoncontroller(c), "pressed", Nothing, (Cint, Cdouble, Cdouble), 1, 0, 0)
                xsig, ysig = Observable(20), Observable(20)
                draw(c, xsig, ysig) do cnvs, x, y
                    copy!(cnvs, imgrand)
                    ctx = getgc(cnvs)
                    set_source(ctx, colorant"red")
                    set_line_width(ctx, 2)
                    circle(ctx, x, y, 5)
                    stroke(ctx)
                end
                c = nothing
            end
            c = canvas(UserUnit)
            zr = Observable(ZoomRegion((1:11, 1:20)))
            zoomrb = init_zoom_rubberband(c, zr)
            zooms = init_zoom_scroll(c, zr)
            pans = init_pan_scroll(c, zr)
            pand = init_pan_drag(c, zr)
            draw(c) do cnvs
                set_coordinates(cnvs, zr[])
                fill!(cnvs, colorant"blue")
            end
            #signal_emit(buttoncontroller(c), "pressed", Nothing, (Cint, Cdouble, Cdouble),
            #            1, UserUnit(5), UserUnit(3), CONTROL))
            #signal_emit(widget(c), "motion-notify-event", Bool,
            #            eventmotion(c, mask(1), UserUnit(10), UserUnit(4)))
            #signal_emit(widget(c), "button-release-event", Bool,
            #            eventbutton(c, GtkObservables.BUTTON_RELEASE, 1, UserUnit(10), UserUnit(4)))
            #signal_emit(widget(c), "button-press-event", Bool,
            #            eventbutton(c, BUTTON_PRESS, 1, UserUnit(6), UserUnit(3), 0))
            #signal_emit(widget(c), "motion-notify-event", Bool,
            #            eventmotion(c, mask(1), UserUnit(7), UserUnit(2)))
            #signal_emit(widget(c), "button-press-event", Bool,
            #            eventbutton(c, DOUBLE_BUTTON_PRESS, 1, UserUnit(5), UserUnit(4.5), CONTROL))
            #signal_emit(widget(c), "scroll-event", Bool,
            #            eventscroll(c, UP, UserUnit(8), UserUnit(4), CONTROL))
            #signal_emit(widget(c), "scroll-event", Bool,
            #            eventscroll(c, RIGHT, UserUnit(8), UserUnit(4), 0))
            c = nothing
        catch
        end
    end
end

empty!(_ref_dict)  # bandaid until reffing is sorted out
Gtk4.GLib.stop_main_loop()

GC.gc(true)  # allow canvases to finalize
sleep(1)     # ensure all timers are closed
GC.gc(true)  # allow canvases to finalize
