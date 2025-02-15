using PrecompileTools

@setup_workload begin
    if !Gtk4.initialized[]
        @warn("GtkObservables precompile skipped: Gtk4 could not be initialized (are you on a headless system?)")
        return
    end
    buttoncontroller(c) = Gtk4.find_controller(widget(c), GtkGestureClick)
    motioncontroller(c) = Gtk4.find_controller(widget(c), GtkEventControllerMotion)
    scrollcontroller(c) = Gtk4.find_controller(widget(c), GtkEventControllerScroll)

    imgrand = rand(RGB{N0f8}, 100, 100)
    Gtk4.GLib.start_main_loop()
    @compile_workload begin
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
        #p = player(1:3)
        #precompile(p)
        #p[] = 2
        #p=nothing

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
                c = canvas(U, 100, 100; init_back=true)
                fill!(c, RGB(0, 0, 0))
                fill!(c, RGBA(1, 1, 1, 1))
                lastevent = Ref("nothing")
                press = map(btn->lastevent[] = "press", c.mouse.buttonpress)
                signal_emit(buttoncontroller(c), "pressed", Nothing, Cint(1), 0.0, 0.0)
                xsig, ysig = Observable(20), Observable(20)
                draw(c, xsig, ysig) do cnvs, x, y
                    copy!(cnvs, imgrand)
                    ctx = getgc(cnvs)
                    set_source(ctx, colorant"red")
                    set_line_width(ctx, 2)
                    circle(ctx, x, y, 5)
                    stroke(ctx)
                end
            end
            modifier = Ref{Gtk4.ModifierType}(Gtk4.ModifierType_NONE)  # needed to simulate modifier state
            c = canvas(UserUnit, 100, 100; init_back=true, modifier_ref=modifier)
            zr = Observable(ZoomRegion((1:11, 1:20)))
            zoomrb = init_zoom_rubberband(c, zr)
            zooms = init_zoom_scroll(c, zr)
            pans = init_pan_scroll(c, zr)
            pand = init_pan_drag(c, zr)
            draw(c) do cnvs
                set_coordinates(cnvs, zr[])
                fill!(cnvs, colorant"blue")
            end
            modifier[]=CONTROL | Gtk4.ModifierType_BUTTON1_MASK
            xd, yd = convertunits(DeviceUnit, c, UserUnit(5), UserUnit(3))
            signal_emit(buttoncontroller(c), "pressed", Nothing, Cint(1), xd.val, yd.val)
            xd, yd = convertunits(DeviceUnit, c, UserUnit(10), UserUnit(4))
            signal_emit(motioncontroller(c), "motion", Nothing, xd.val, yd.val)
            signal_emit(buttoncontroller(c), "released", Nothing, Cint(1), xd.val, yd.val)
            modifier[]=Gtk4.ModifierType_NONE
            signal_emit(buttoncontroller(c), "pressed", Nothing,
                        Cint(1), convert(Float64, UserUnit(6)), convert(Float64, UserUnit(3)))
            signal_emit(motioncontroller(c), "motion", Nothing,
                        convert(Float64, UserUnit(7)), convert(Float64, UserUnit(2)))
            modifier[]=CONTROL | Gtk4.ModifierType_BUTTON1_MASK
            xd, yd = convertunits(DeviceUnit, c, UserUnit(5), UserUnit(3))
            signal_emit(buttoncontroller(c), "pressed", Nothing, Cint(2), xd.val, yd.val)
            modifier[]=CONTROL
            signal_emit(scrollcontroller(c), "scroll", Bool,
                        convert(Float64, UserUnit(8)), convert(Float64, UserUnit(4)))
            modifier[]=Gtk4.ModifierType_NONE
            signal_emit(scrollcontroller(c), "scroll", Bool,
                        convert(Float64, UserUnit(8)), convert(Float64, UserUnit(4)))
            c=nothing
        catch
            @warn("GtkObservables canvas precompile code failure")
        end
    end
    Gtk4.GLib.stop_main_loop(true)
end

empty!(_ref_dict)  # bandaid until reffing is sorted out

GC.gc(true)  # allow canvases to finalize
sleep(1)     # ensure all timers are closed
GC.gc(true)  # allow canvases to finalize
