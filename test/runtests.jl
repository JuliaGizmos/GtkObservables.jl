# Workaround for libz loading confusion.
@static if Sys.islinux()
    using ImageMagick
end

using GtkObservables, Gtk4, IntervalSets, Graphics, Colors,
      TestImages, FileIO, FixedPointNumbers, RoundingIntegers, Dates, Cairo,
      IdentityRanges
using Test

Gtk4.GLib.start_main_loop()

@testset "Widgets" begin
    ## label
    l = label("Hello")
    @test observable(l) == l.observable
    @test observable(observable(l)) == l.observable
    @test get_gtk_property(l, "label", String) == "Hello"
    l[] = "world"
    @test get_gtk_property(l, "label", String) == "world"
    @test string(l) == string("GtkLabelLeaf with ", string(observable(l)))
    # Test other elements of the Observables API
    counter = Ref(0)
    ofunc = on(l) do _
        counter[] += 1
    end
    @test counter[] == 0
    l[] = "changeme"
    @test counter[] == 1
    off(ofunc)
    l[] = "and again"
    @test counter[] == 1
    ldouble = map(l) do str
        str*str
    end
    @test ldouble[] == "and againand again"
    # printing
    @test string(l) == "GtkLabelLeaf with Observable(\"and again\")"

    ## checkbox
    w = GtkWindow("Checkbox")
    check = checkbox(label="click me")
    push!(w, check)
    @test check[] == false
    @test Gtk4.active(check.widget) == false
    check[] = true
    @test check[]
    @test Gtk4.active(check.widget)
    Gtk4.destroy(w)
    sleep(0.1)  # work around https://github.com/JuliaGraphics/Gtk.jl/issues/391#issuecomment-1107840526

    ## togglebutton
    w = GtkWindow("Togglebutton")
    tgl = togglebutton(label="click me")
    push!(w, tgl)
    @test tgl[] == false
    @test Gtk4.active(tgl.widget) == false
    tgl[] = true
    @test tgl[]
    @test Gtk4.active(tgl.widget)
    Gtk4.destroy(w)
    sleep(0.1)

    ## colorbutton
    w = GtkWindow("Colorbutton")
    cb = colorbutton(color=RGB(1, 0, 1))
    push!(w, cb)
    @test cb[] == RGB(1, 0, 1)
    cb[] = RGB(0, 1, 0)
    @test cb[] == RGB(0, 1, 0)
    Gtk4.destroy(w)
    sleep(0.1)

    ## textbox (aka Entry)
    txt = textbox("Type something")
    num = textbox(5, range=1:10)
    lost_focus = textbox("Type something"; gtksignal = "focus-leave")
    win = GtkWindow("Textboxes")
    bx = GtkBox(:h)
    win[] = bx
    push!(bx, txt)
    push!(bx, num)
    push!(bx, lost_focus)
    @test get_gtk_property(txt, "text", String) == "Type something"
    txt[] = "ok"
    @test get_gtk_property(txt, "text", String) == "ok"
    set_gtk_property!(txt, "text", "other direction")
    signal_emit(widget(txt), "activate", Nothing)
    @test txt[] == "other direction"
    @test get_gtk_property(num, "text", String) == "5"
    @test_throws ArgumentError num[] = 11
    num[] = 8
    @test get_gtk_property(num, "text", String) == "8"
    meld = map(txt, num) do t, n
        join((t, n), 'X')
    end
    @test meld[] == "other directionX8"
    num[] = 4
    @test meld[] == "other directionX4"
    txt[] = "4"
    @test meld[] == "4X4"
    @test get_gtk_property(lost_focus, "text", String) == "Type something"
    grab_focus(widget(lost_focus))
    set_gtk_property!(lost_focus, "text", "Something!")
    @test lost_focus[] == "Type something"
    grab_focus(widget(txt))
    @test get_gtk_property(lost_focus, "text", String) == "Something!"
    @test lost_focus[] == "Something!"
    Gtk4.destroy(win)
    sleep(0.1)

    ## textarea (aka TextView)
    v = textarea("Type something longer")
    win = GtkWindow(v)
    @test v[] == "Type something longer"
    v[] = "ok"
    @test get_gtk_property(Gtk4.buffer(v.widget), "text", String) == "ok"
    Gtk4.destroy(win)
    sleep(0.1)

    ## slider
    s = slider(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test s[] == 8
    s[] = 3
    @test s[] == 3
    s3 = slider(IdentityRange(-3:3))
    sleep(0.01)
    @test s3[] == 0
    s3[] = -3
    @test s3[] == -3
    sleep(0.1)

    # Use a single observable for two widgets
    s2 = slider(1:15, observable=observable(s), orientation='v')
    @test s2[] == 3
    s2[] = 11
    @test s[] == 11
    sleep(0.1)

    # Updating the limits of the slider
    s = slider(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test s[] == 8
    s[] = 1:7, 5
    sleep(0.05)
    @test s[] == 5
    sleep(0.1)

    ## dropdown
    dd = dropdown(("Strawberry", "Vanilla", "Chocolate"))
    @test dd[] === "Strawberry"

    dd = dropdown(())
    @test dd[] === nothing

    dd = dropdown(("Strawberry", "Vanilla", "Chocolate"), value = "Vanilla")
    @test dd[] === "Vanilla"
    dd[] = "Chocolate"
    @test get_gtk_property(dd, "active", Int) == 2
    empty!(dd)
    @test dd[] === nothing
    @test get_gtk_property(dd, "active", Int) == -1
    @test_throws KeyError dd[] = "Strawberry"
    @test dd[] === nothing
    append!(dd, ("Coffee", "Caramel"))
    @test dd[] === nothing
    dd[] = "Caramel"
    @test dd[] == "Caramel"
    @test get_gtk_property(dd, "active", Int) == 1

    r = Ref(0)
    dd = dropdown(["Five"=>x->x[]=5,
                   "Seven"=>x->x[]=7], value = "Five")
    on(dd.mappedsignal) do f
        f(r)
    end
    dd[] = dd[]  # fire the callback for the initial value
    @test dd[] == "Five"
    @test r[] == 5
    dd[] = "Seven"
    @test dd[] == "Seven"
    @test r[] == 7
    dd[] = "Five"
    @test r[] == 5

    # if the Observable is just of type String, don't support unselected state (compatibility with 1.0.0)
    dd = dropdown(("Strawberry", "Vanilla", "Chocolate"), observable = Observable(""))
    @test dd[] === "Strawberry"
    @test_throws ArgumentError empty!(dd)
    sleep(0.1)

    ## spinbutton
    s = spinbutton(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test s[] == 1
    s[] = 3
    @test s[] == 3

    s = spinbutton(0.0:2.0:59.0, orientation="vertical")
    @test Gtk4.orientation(GtkOrientable(widget(s))) == Gtk4.Orientation_VERTICAL

    # Updating the limits of the spinbutton
    s = spinbutton(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test s[] == 1
    s[] = 1:7, 5
    @test s[] == 5
    sleep(0.1)


    ## cyclicspinbutton
    a = spinbutton(1:10, value = 5)
    carry_up = Observable(false)
    on(carry_up) do up
        a[] = a[] - (-1)^up
    end
    b = cyclicspinbutton(1:3, carry_up)
    @test a[] == 5
    @test b[] == 1
    b[] = 2
    @test a[] == 5
    @test b[] == 2
    b[] = 0
    @test a[] == 4
    @test b[] == 3
    b[] = 4
    @test a[] == 5
    @test b[] == 1

    s = cyclicspinbutton(0:59, carry_up, orientation="vertical")
    @test Gtk4.orientation(GtkOrientable(widget(s))) == Gtk4.Orientation_VERTICAL
    sleep(0.1)

    # timewidget
    t = Dates.Time(1,1,1)
    s = Observable(t)
    tw = timewidget(t, observable=s)
    @test tw[] == s[] == t
    t = Dates.Time(2,2,2)
    tw[] = t
    @test tw[] == s[] == t
    t = Dates.Time(3,3,3)
    s[] = t
    @test tw[] == s[] == t
    sleep(0.1)

    # datetimewidget
    t = DateTime(1,1,1,1,1,1)
    s = Observable(t)
    tw = datetimewidget(t, observable=s)
    @test tw[] == s[] == t
    t = DateTime(2,2,2,2,2,2)
    tw[] = t
    @test tw[] == s[] == t
    t = DateTime(3,3,3,3,3,3)
    s[] = t
    @test tw[] == s[] == t
    sleep(0.1)

    # progressbar
    pb = progressbar(1..10)
    @test pb[] == 1
    pb[] = 5
    @test pb[] == 5
    pb = progressbar(2:8)
    @test pb[] == 2
    sleep(0.1)

end

const counter = Ref(0)

@testset "Button" begin
    ## button
    w = GtkWindow("Widgets")
    b = button("Click me")
    push!(w, b)
    action = map(b) do val
        counter[] += 1
    end
    cc = counter[]  # map seems to fire it once, so record the "new" initial value
    click(b::GtkObservables.Button) = signal_emit(widget(b),"clicked",Nothing)
    GC.gc(true)
    click(b)
    @test counter[] == cc+1
    Gtk4.destroy(w)
end

@testset "Compound widgets" begin
    ## player widget
    s = Observable(1)
    p = player(s, 1:8)
    win = GtkWindow("Compound", 400, 100)
    g = GtkGrid()
    win[]=g
    g[1,1] = frame(p)
    btn_fwd = p.widget.step_forward
    @test s[] == 1
    btn_fwd[] = nothing
    @test s[] == 2
    p.widget.play_forward[] = nothing
    for i = 1:7
        sleep(0.1)
    end
    @test s[] == 8
    @test string(p) == "GtkObservables.PlayerWithTextbox with Observable(8)"
    Gtk4.destroy(win)

    p = player(1:1000)
    win = GtkWindow("Compound 2", 400, 100)
    push!(win, frame(p))
    widget(p).direction[] = 1
    Gtk4.destroy(win)  # this should not generate a lot of output
end

@testset "CairoUnits" begin
    x = UserUnit(0.2)
    @test UserUnit(x) === x
    @test convert(UserUnit, x) === x
    @test x+x === UserUnit(0.2+0.2)
    @test x-x === UserUnit(0.0)
    @test Float64(x) === 0.2
    @test convert(Float64, x) === 0.2
    y = UserUnit(-0.3)
    @test x > y
    @test y < x
    @test abs(x) === x
    @test abs(y) === UserUnit(0.3)
    @test min(x, y) === y
    @test max(x, y) === x
    z = DeviceUnit(2.0)
    @test_throws ErrorException x+z
    @test Bool(DeviceUnit(1.0)) === true
    @test Integer(DeviceUnit(3.0)) === 3
end

@testset "Canvas" begin
    @test XY(5, 5) === XY{Int}(5, 5)
    @test XY(5, 5.0) === XY{Float64}(5.0, 5.0)
    @test XY{UserUnit}(5, 5.0) === XY{UserUnit}(5.0, 5.0) === XY{UserUnit}(UserUnit(5), UserUnit(5))
    @test XY(5.0, 5)+XY(4, 4.1) === XY(9, 9.1)
    @test XY(5, 5)-XY(4, 4) === XY(1, 1)

    @test isa(MouseButton{UserUnit}(), MouseButton{UserUnit})
    @test isa(MouseButton{DeviceUnit}(), MouseButton{DeviceUnit})
    @test isa(MouseScroll{UserUnit}(), MouseScroll{UserUnit})
    @test isa(MouseScroll{DeviceUnit}(), MouseScroll{DeviceUnit})

    @test BoundingBox(XY(2..4, -15..15)) === BoundingBox(2, 4, -15, 15)

    c = canvas(208, 207)
    win = GtkWindow(c)
    reveal(c)
    sleep(1.0)
    can_test_width = !Sys.iswindows()
    can_test_width && @test Graphics.width(c) == 208
    can_test_width && @test Graphics.height(c) == 207
    @test isa(c, GtkObservables.Canvas{DeviceUnit})
    Gtk4.destroy(win)
    c = canvas(UserUnit, 208, 207)
    win = GtkWindow(c)
    reveal(c)
    sleep(1.0)
    @test isa(c, GtkObservables.Canvas{UserUnit})
    @test string(c) == "GtkObservables.Canvas{UserUnit}()"
    corner_dev = (DeviceUnit(208), DeviceUnit(207))
    can_test_coords = (get(ENV, "CI", nothing) != "true" || !Sys.islinux()) && can_test_width
    for (coords, corner_usr) in ((BoundingBox(0, 1, 0, 1), (UserUnit(1), UserUnit(1))),
                                 (ZoomRegion((5:10, 3:5)), (UserUnit(5), UserUnit(10))),
                                 ((-1:1, 101:110), (UserUnit(110), UserUnit(1))))
        set_coordinates(c, coords)
        if can_test_coords
            @test GtkObservables.convertunits(DeviceUnit, c, corner_dev...) == corner_dev
            @test GtkObservables.convertunits(DeviceUnit, c, corner_usr...) == corner_dev
            @test GtkObservables.convertunits(UserUnit, c, corner_dev...) == corner_usr
            @test GtkObservables.convertunits(UserUnit, c, corner_usr...) == corner_usr
        end
    end

    Gtk4.destroy(win)


    c = canvas()
    f = GtkFrame()
    f[] = c.widget
    @test isa(f, Gtk4.GtkFrameLeaf)
    c = canvas()
    f = GtkAspectFrame(0.5, 0.5, 3.0, true)
    f[] = c.widget
    @test isa(f, Gtk4.GtkAspectFrameLeaf)
    @test get_gtk_property(f, "ratio", Float64) == 3.0
end

function gesture_click(g)
    isa(g,GtkGestureClick) && g.button == 0
end

function find_gesture_click(w::GtkWidget)
    list = Gtk4.observe_controllers(w)
    i=findfirst(gesture_click, list)
    i!==nothing ? list[i] : nothing
end

@testset "Canvas events" begin
    win = GtkWindow()
    c = canvas(UserUnit)
    win[] = c.widget
    show(win)
    sleep(0.2)
    lastevent = Ref("nothing")
    press   = map(btn->lastevent[] = "press",   c.mouse.buttonpress)
    release = map(btn->lastevent[] = "release", c.mouse.buttonrelease)
    motion  = map(btn->lastevent[] = string("motion to ", btn.position.x, ", ", btn.position.y),
                  c.mouse.motion)
    scroll  = map(btn->lastevent[] = "scroll", c.mouse.scroll)
    lastevent[] = "nothing"
    @test lastevent[] == "nothing"
    ec = find_gesture_click(widget(c))
    signal_emit(ec, "pressed", Nothing, Int32(1), 0.0, 0.0)
    sleep(0.1)
    @test lastevent[] == "press"
    signal_emit(ec, "released", Nothing, Int32(1), 0.0, 0.0)
    sleep(0.1)
    sleep(0.1)
    @test lastevent[] == "release"
    ec = Gtk4.find_controller(widget(c), GtkEventControllerScroll)
    signal_emit(ec, "scroll", Bool, 1.0, 0.0)
    sleep(0.1)
    @test lastevent[] == "scroll"
    ec = Gtk4.find_controller(widget(c), GtkEventControllerMotion)
    signal_emit(ec, "motion", Nothing, UserUnit(20).val, UserUnit(15).val)
    sleep(0.1)
    sleep(0.1)
    @test lastevent[] == "motion to UserUnit(20.0), UserUnit(15.0)"
    Gtk4.destroy(win)
end

@testset "Popup" begin
    popupmenu = Gtk4.GLib.GMenu()
    popupitem = Gtk4.GLib.GMenuItem("Popup menu...")
    push!(popupmenu, popupitem)
    popover = GtkPopoverMenu(popupmenu)
    win = GtkWindow()
    modifier = Ref{Gtk4.ModifierType}(Gtk4.ModifierType_NONE)  # needed to simulate modifier state
    c = canvas(;modifier_ref = modifier)
    Gtk4.parent(popover, widget(c))
    win[] = widget(c)
    popuptriggered = Ref(false)
    push!(c.preserved, map(c.mouse.buttonpress) do btn
        if btn.button == 3 && btn.clicktype == BUTTON_PRESS
            pos = Gtk4._GdkRectangle(round(Int32,btn.position.x.val),round(Int32,btn.position.y.val),1,1)
            Gtk4.G_.set_pointing_to(popover, Ref(pos))
            Gtk4.popup(popover)
            popuptriggered[] = true
            nothing
        end
    end)
    yield()
    @test !popuptriggered[]
    ec = find_gesture_click(widget(c))
    signal_emit(ec, "pressed", Nothing, Int32(1), 0.0, 0.0)
    yield()
    @test !popuptriggered[]
    modifier[] = Gtk4.ModifierType_BUTTON3_MASK
    signal_emit(ec, "pressed", Nothing, Int32(1), 0.0, 0.0)
    @test popuptriggered[]   # this requires simulating a right click, which might require constructing a GdkEvent structure
    Gtk4.destroy(win)
end

@testset "Drawing" begin
    img = testimage("lighthouse")
    c = canvas(UserUnit, size(img, 2), size(img, 1))
    win = GtkWindow(c)
    xsig, ysig = Observable(20), Observable(20)
    draw(c, xsig, ysig) do cnvs, x, y
        copy!(c, img)
        ctx = getgc(cnvs)
        set_source(ctx, colorant"red")
        set_line_width(ctx, 2)
        circle(ctx, x, y, 5)
        stroke(ctx)
    end
    xsig[] = 100
    sleep(1)
    # Check that the displayed image is as expected
    if get(ENV, "CI", nothing) != "true" || !Sys.islinux()
        fn = joinpath(tempdir(), "circled.png")
        Cairo.write_to_png(getgc(c).surface, fn)
        imgout = load(fn)
        rm(fn)
        @test imgout[25,100] == imgout[16,100] == imgout[20,105] == colorant"red"
        @test imgout[20,100] == img[20,100]
    end
    Gtk4.destroy(win)
end

# For testing ZoomRegion support for non-AbstractArray objects
struct Foo end
Base.axes(::Foo) = (Base.OneTo(7), Base.OneTo(9))

@testset "Zoom/pan" begin
    @test string(UserUnit(3)) == "UserUnit(3.0)"
    @test string(DeviceUnit(3)) == "DeviceUnit(3.0)"

    xy = @inferred(XY(1, 3))
    @test isa(xy, XY{Int})
    @test xy.x == 1
    @test xy.y == 3
    @test string(xy) == "XY(1, 3)"
    xy = @inferred(XY{Float64}(1, 3))
    @test isa(xy, XY{Float64})
    @test xy.x == 1
    @test xy.y == 3
    @test string(xy) == "XY(1.0, 3.0)"
    @test isa(convert(XY{Int}, xy), XY{Int})
    xy = XY{Float64}(3.2, 4.8)
    xyr = convert(XY{RInt}, xy)
    @test isa(xyr, XY{RInt}) && xyr.x == 3 && xyr.y == 5
    xy = XY(UserUnit(3), UserUnit(5))
    @test string(xy) == "XY{UserUnit}(3.0, 5.0)"
    @test @inferred(XY{UserUnit}(3, 5)) == xy

    zr = ZoomRegion((1:80, 1:100))  # y, x order
    zrz = GtkObservables.zoom(zr, 0.5)
    @test zrz.currentview.x == 26..75
    @test zrz.currentview.y == 21..60
    zrp = GtkObservables.pan_x(zrz, 0.2)
    @test zrp.currentview.x == 36..85
    @test zrp.currentview.y == 21..60
    zrp = GtkObservables.pan_x(zrz, -0.2)
    @test zrp.currentview.x == 16..65
    @test zrp.currentview.y == 21..60
    zrp = GtkObservables.pan_y(zrz, -0.2)
    @test zrp.currentview.x == 26..75
    @test zrp.currentview.y == 13..52
    zrp = GtkObservables.pan_y(zrz, 0.2)
    @test zrp.currentview.x == 26..75
    @test zrp.currentview.y == 29..68
    zrp = GtkObservables.pan_x(zrz, 1.0)
    @test zrp.currentview.x == 51..100
    @test zrp.currentview.y == 21..60
    zrp = GtkObservables.pan_y(zrz, -1.0)
    @test zrp.currentview.x == 26..75
    @test zrp.currentview.y == 1..40
    zrz2 = GtkObservables.zoom(zrz, 2.0001)
    @test zrz2 == zr
    zrz2 = GtkObservables.zoom(zrz, 3)
    @test zrz2 == zr
    zrz2 = GtkObservables.zoom(zrz, 1.9)
    @test zrz2.currentview.x == 4..97
    @test zrz2.currentview.y == 3..78
    zrz = GtkObservables.zoom(zr, 0.5, GtkObservables.XY{DeviceUnit}(50.5, 40.5))
    @test zrz.currentview.x == 26..75
    @test zrz.currentview.y == 21..60
    zrz = GtkObservables.zoom(zr, 0.5, GtkObservables.XY{DeviceUnit}(60.5, 30.5))
    @test zrz.currentview.x == 31..80
    @test zrz.currentview.y == 16..55
    zrr = GtkObservables.reset(zrz)
    @test zrr == zr

    zrbb = ZoomRegion(zr.fullview, BoundingBox(5, 15, 35, 75))
    @test zrbb.fullview === zr.fullview
    @test zrbb.currentview.x == 5..15
    @test zrbb.currentview.y == 35..75
    @test typeof(zrbb.currentview) == typeof(zr.currentview)

    zrsig = Observable(zr)
    zrsig[] = (3:5, 4:7)
    zr = zrsig[]
    @test zr.fullview.y == 1..80
    @test zr.fullview.x == 1..100
    @test zr.currentview.y == 3..5
    @test zr.currentview.x == 4..7
    zrsig[] = XY(1..2, 3..4)
    zr = zrsig[]
    @test zr.fullview.y == 1..80
    @test zr.fullview.x == 1..100
    @test zr.currentview.y == 3..4
    @test zr.currentview.x == 1..2

    zr = ZoomRegion(Foo())
    @test zr.fullview.y == 1..7
    @test zr.fullview.x == 1..9

    zr = ZoomRegion((1:100, 1:80), (11:20, 8:12))
    @test zr.fullview.x == 1..80
    @test zr.fullview.y == 1..100
    @test zr.currentview.x == 8..12
    @test zr.currentview.y == 11..20
    @test axes(zr) == (11:20, 8:12)
end

@testset "More zoom/pan" begin
    ### Simulate the mouse clicks, etc. to trigger zoom/pan
    modifier = Ref{Gtk4.ModifierType}(Gtk4.ModifierType_NONE)  # needed to simulate modifier state
    c = canvas(UserUnit;modifier_ref=modifier)
    win = GtkWindow(c)
    zr = Observable(ZoomRegion((1:11, 1:20)))
    zoomrb = init_zoom_rubberband(c, zr)
    zooms = init_zoom_scroll(c, zr)
    pans = init_pan_scroll(c, zr)
    pand = init_pan_drag(c, zr)
    draw(c) do cnvs
        set_coordinates(c, zr[])
        fill!(c, colorant"blue")
    end
    sleep(0.1)

    # Zoom by rubber band
    # need to simulate control modifier + button 1
    modifier[]=CONTROL | Gtk4.ModifierType_BUTTON1_MASK
    ec = Gtk4.find_controller(widget(c), GtkGestureClick)
    xd, yd = GtkObservables.convertunits(DeviceUnit, c, UserUnit(5), UserUnit(3))
    signal_emit(ec, "pressed", Nothing, Int32(1), xd.val, yd.val)
    modifier[]=CONTROL | Gtk4.ModifierType_BUTTON1_MASK
    ecm = Gtk4.find_controller(widget(c), GtkEventControllerMotion)
    xd, yd = GtkObservables.convertunits(DeviceUnit, c, UserUnit(10), UserUnit(4))
    signal_emit(ecm, "motion", Nothing, xd.val, yd.val)
    signal_emit(ec, "released", Nothing, Int32(1), xd.val, yd.val)
    modifier[]=Gtk4.ModifierType_NONE
    @test zr[].currentview.x == 5..10
    @test zr[].currentview.y == 3..4
    # Ensure that the rubber band damage has been repaired
    if get(ENV, "CI", nothing) != "true" || !Sys.islinux()
        fn = tempname()
        Cairo.write_to_png(getgc(c).surface, fn)
        imgout = load(fn)
        rm(fn)
        @test all(x->x==colorant"blue", imgout)
    end
    
    # Pan-drag
    modifier[]=Gtk4.ModifierType_BUTTON1_MASK
    xd, yd = GtkObservables.convertunits(DeviceUnit, c, UserUnit(6), UserUnit(3))
    signal_emit(ec, "pressed", Nothing, Int32(1), xd.val, yd.val)
    xd, yd = GtkObservables.convertunits(DeviceUnit, c, UserUnit(7), UserUnit(2))
    signal_emit(ecm, "motion", Nothing, xd.val, yd.val)
    signal_emit(ec, "released", Nothing, Int32(1), xd.val, yd.val)
    modifier[]=Gtk4.ModifierType_NONE
    @test zr[].currentview.x == 4..9
    @test zr[].currentview.y == 4..5
    
    # Reset
    modifier[]=CONTROL | Gtk4.ModifierType_BUTTON1_MASK
    signal_emit(ec, "pressed", Nothing, Int32(2), xd.val, yd.val)
    @test zr[].currentview.x == 1..20
    @test zr[].currentview.y == 1..11
    
    # Zoom-scroll
    modifier[] = Gtk4.ModifierType_NONE
    xd, yd = GtkObservables.convertunits(DeviceUnit, c, UserUnit(8), UserUnit(4))
    signal_emit(ecm, "motion", Nothing, xd.val, yd.val)
    modifier[]=CONTROL
    ecs = Gtk4.find_controller(widget(c), GtkEventControllerScroll)
    signal_emit(ecs, "scroll", Bool, 0.0, 1.0)
    @test zr[].currentview.x == 4..14
    @test zr[].currentview.y == 1..7
    
    # Pan-scroll
    modifier[] = Gtk4.ModifierType_NONE
    signal_emit(ecs, "scroll", Bool, 1.0, 0.0)
    @test zr[].currentview.x == 5..15
    @test zr[].currentview.y == 1..7
    
    signal_emit(ecs, "scroll", Bool, 0.0, -1.0)
    @test zr[].currentview.x == 5..15
    @test zr[].currentview.y == 2..8
    
    destroy(win)
end

@testset "Surfaces" begin
    for (val, cmp) in ((0.2, Gray24(0.2)),
                       (Gray(N0f8(0.5)), Gray24(0.5)),
                       (RGB(0, 1, 0), RGB24(0, 1, 0)),
                       (RGBA(1, 0, 0.5, 0.8), ARGB32(1, 0, 0.5, 0.8)))
        surf = GtkObservables.image_surface(fill(val, 3, 5))
        @test surf.height == 3 && surf.width == 5
        @test all(x->x == reinterpret(UInt32, cmp), surf.data)
        Cairo.destroy(surf)
    end
end

@testset "Layout" begin
    g = GtkGrid()
    g[1,1] = textbox("hello").widget  # probably violates the spirit of this test
end

examplepath = joinpath(dirname(dirname(@__FILE__)), "examples")
include(joinpath(examplepath, "imageviewer.jl"))
include(joinpath(examplepath, "widgets.jl"))
include(joinpath(examplepath, "drawing.jl"))
