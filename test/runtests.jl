# Workaround for libz loading confusion.
@static if Sys.islinux()
    using ImageMagick
end

using GtkObservables, Gtk.ShortNames, IntervalSets, Graphics, Colors,
      TestImages, FileIO, FixedPointNumbers, RoundingIntegers, Dates, Cairo,
      IdentityRanges
using Test

include("tools.jl")

@testset "Widgets" begin
    ## label
    l = label("Hello")
    @test observable(l) == l.observable
    @test observable(observable(l)) == l.observable
    @test get_gtk_property(l, :label, String) == "Hello"
    l[] = "world"
    @test get_gtk_property(l, :label, String) == "world"
    @test string(l) == string("Gtk.GtkLabelLeaf with ", string(observable(l)))
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

    ## checkbox
    w = Window("Checkbox")
    check = checkbox(label="click me")
    push!(w, check)
    Gtk.showall(w)
    @test check[] == false
    @test Gtk.G_.active(check.widget) == false
    check[] = true
    @test check[]
    @test Gtk.G_.active(check.widget)
    destroy(w)

    ## togglebutton
    w = Window("Togglebutton")
    tgl = togglebutton(label="click me")
    push!(w, tgl)
    Gtk.showall(w)
    @test tgl[] == false
    @test Gtk.G_.active(tgl.widget) == false
    tgl[] = true
    @test tgl[]
    @test Gtk.G_.active(tgl.widget)
    destroy(w)

    ## textbox (aka Entry)
    txt = textbox("Type something")
    num = textbox(5, range=1:10)
    win = Window("Textboxes") |> (bx = Box(:h))
    push!(bx, txt)
    push!(bx, num)
    Gtk.showall(win)
    @test get_gtk_property(txt, :text, String) == "Type something"
    txt[] = "ok"
    @test get_gtk_property(txt, :text, String) == "ok"
    set_gtk_property!(txt, :text, "other direction")
    signal_emit(widget(txt), :activate, Nothing)
    @test txt[] == "other direction"
    @test get_gtk_property(num, :text, String) == "5"
    @test_throws ArgumentError num[] = 11
    num[] = 8
    @test get_gtk_property(num, :text, String) == "8"
    meld = map(txt, num) do t, n
        join((t, n), 'X')
    end
    @test meld[] == "other directionX8"
    num[] = 4
    @test meld[] == "other directionX4"
    txt[] = "4"
    @test meld[] == "4X4"
    destroy(win)

    ## textarea (aka TextView)
    v = textarea("Type something longer")
    win = Window(v)
    Gtk.showall(win)
    @test v[] == "Type something longer"
    v[] = "ok"
    @test get_gtk_property(Gtk.G_.buffer(v.widget), :text, String) == "ok"
    destroy(win)

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

    # Use a single observable for two widgets
    s2 = slider(1:15, observable=observable(s), orientation='v')
    @test s2[] == 3
    s2[] = 11
    @test s[] == 11
    destroy(s2)
    destroy(s)

    # Updating the limits of the slider
    s = slider(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test s[] == 8
    s[] = 1:7, 5
    sleep(0.01)
    @test s[] == 5

    ## dropdown
    dd = dropdown(("Strawberry", "Vanilla", "Chocolate"))
    @test dd[] == "Strawberry"
    dd[] = "Chocolate"
    @test get_gtk_property(dd, :active, Int) == 2
    destroy(dd.widget)

    r = Ref(0)
    dd = dropdown(["Five"=>x->x[]=5,
                   "Seven"=>x->x[]=7])
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
    destroy(dd.widget)

    ## spinbutton
    s = spinbutton(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test s[] == 1
    s[] = 3
    @test s[] == 3
    destroy(s)

    s = spinbutton(0:59, orientation="vertical")
    @test G_.orientation(Orientable(widget(s))) == Gtk.GConstants.GtkOrientation.VERTICAL
    destroy(s)

    # Updating the limits of the spinbutton
    s = spinbutton(1:15)
    sleep(0.01)    # For the Gtk eventloop
    @test s[] == 1
    s[] = 1:7, 5
    @test s[] == 5


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
    destroy(a)

    s = cyclicspinbutton(0:59, carry_up, orientation="vertical")
    @test G_.orientation(Orientable(widget(s))) == Gtk.GConstants.GtkOrientation.VERTICAL
    destroy(s)

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

    # progressbar
    pb = progressbar(1..10)
    @test pb[] == 1
    pb[] = 5
    @test pb[] == 5
    pb = progressbar(2:8)
    @test pb[] == 2

end

const counter = Ref(0)

@testset "Button" begin
    ## button
    w = Window("Widgets")
    b = button("Click me")
    push!(w, b)
    action = map(b) do val
        counter[] += 1
    end
    Gtk.showall(w)
    cc = counter[]  # map seems to fire it once, so record the "new" initial value
    click(b::GtkObservables.Button) = ccall((:gtk_button_clicked,Gtk.libgtk),Cvoid,(Ptr{Gtk.GObject},),b.widget)
    GC.gc(true)
    click(b)
    if VERSION >= v"1.2.0"
        @test counter[] == cc+1
    else
        @test_broken counter[] == cc+1
    end
    destroy(w)

    # Make sure we can also put a ToolButton in a Button
    button(; widget=ToolButton("Save as..."))
end

if Gtk.libgtk_version >= v"3.10"
    # To support GtkBuilder, we need this as the minimum libgtk version
    @testset "Compound widgets" begin
        ## player widget
        s = Observable(1)
        p = player(s, 1:8)
        win = Window("Compound", 400, 100) |> (g = Grid())
        g[1,1] = p
        Gtk.showall(win)
        btn_fwd = p.widget.step_forward
        @test s[] == 1
        btn_fwd[] = nothing
        @test s[] == 2
        p.widget.play_forward[] = nothing
        for i = 1:7
                    sleep(0.1)
        end
        @test s[] == 8
        destroy(win)

        p = player(1:1000)
        win = Window("Compound 2", 400, 100)
        push!(win, frame(p))
        Gtk.showall(win)
        widget(p).direction[] = 1
        destroy(win)  # this should not generate a lot of output
    end
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
    win = Window(c)
    Gtk.showall(win)
    reveal(c, true)
    sleep(0.3)
    can_test_width = !(VERSION.minor < 3 && Sys.iswindows())
    can_test_width && @test Graphics.width(c) == 208
    @test Graphics.height(c) == 207
    @test isa(c, GtkObservables.Canvas{DeviceUnit})
    destroy(win)
    c = canvas(UserUnit, 208, 207)
    win = Window(c)
    Gtk.showall(win)
    reveal(c, true)
    sleep(1.0)
    @test isa(c, GtkObservables.Canvas{UserUnit})
    corner_dev = (DeviceUnit(208), DeviceUnit(207))
    can_test_coords = (VERSION < v"1.3" || get(ENV, "CI", nothing) != "true" || !Sys.islinux()) &&
                      can_test_width
    for (coords, corner_usr) in ((BoundingBox(0, 1, 0, 1), (UserUnit(1), UserUnit(1))),
                                 (ZoomRegion((5:10, 3:5)), (UserUnit(5), UserUnit(10))),
                                 ((-1:1, 101:110), (UserUnit(110), UserUnit(1))))
        set_coordinates(c, coords)
        if can_test_coords
            # FIXME: the new JLL-based version fails on Travis.
            # Unfortunately this is difficult to debug because it doesn't replicate
            # locally or on a local headless server. See #91.
            @test GtkObservables.convertunits(DeviceUnit, c, corner_dev...) == corner_dev
            @test GtkObservables.convertunits(DeviceUnit, c, corner_usr...) == corner_dev
            @test GtkObservables.convertunits(UserUnit, c, corner_dev...) == corner_usr
            @test GtkObservables.convertunits(UserUnit, c, corner_usr...) == corner_usr
        end
    end

    destroy(win)


    c = canvas()
    f = Frame(c)
    @test isa(f, Gtk.GtkFrameLeaf)
    destroy(f)
    c = canvas()
    f = AspectFrame(c, "Some title", 0.5, 0.5, 3.0)
    @test isa(f, Gtk.GtkAspectFrameLeaf)
    @test get_gtk_property(f, :ratio, Float64) == 3.0
    destroy(f)
end

@testset "Canvas events" begin
    win = Window() |> (c = canvas(UserUnit))
    Gtk.showall(win)
    sleep(0.2)
    lastevent = Ref("nothing")
    press   = map(btn->lastevent[] = "press",   c.mouse.buttonpress)
    release = map(btn->lastevent[] = "release", c.mouse.buttonrelease)
    motion  = map(btn->lastevent[] = string("motion to ", btn.position.x, ", ", btn.position.y),
                  c.mouse.motion)
    scroll  = map(btn->lastevent[] = "scroll", c.mouse.scroll)
    lastevent[] = "nothing"
    @test lastevent[] == "nothing"
    signal_emit(widget(c), "button-press-event", Bool, eventbutton(c, BUTTON_PRESS, 1))
    sleep(0.1)
    # FIXME: would prefer that this works on all Julia versions
    VERSION >= v"1.2.0" && @test lastevent[] == "press"
    signal_emit(widget(c), "button-release-event", Bool, eventbutton(c, GtkObservables.BUTTON_RELEASE, 1))
    sleep(0.1)
    sleep(0.1)
    VERSION >= v"1.2.0" && @test lastevent[] == "release"
    signal_emit(widget(c), "scroll-event", Bool, eventscroll(c, UP))
    sleep(0.1)
    sleep(0.1)
    VERSION >= v"1.2.0" && @test lastevent[] == "scroll"
    signal_emit(widget(c), "motion-notify-event", Bool, eventmotion(c, 0, UserUnit(20), UserUnit(15)))
    sleep(0.1)
    sleep(0.1)
    VERSION >= v"1.2.0" && @test lastevent[] == "motion to UserUnit(20.0), UserUnit(15.0)"
    destroy(win)
end

@testset "Popup" begin
    popupmenu = Menu()
    popupitem = MenuItem("Popup menu...")
    push!(popupmenu, popupitem)
    Gtk.showall(popupmenu)
    win = Window() |> (c = canvas())
    popuptriggered = Ref(false)
    push!(c.preserved, map(c.mouse.buttonpress) do btn
        if btn.button == 3 && btn.clicktype == BUTTON_PRESS
            popup(popupmenu, btn.gtkevent)  # use the raw Gtk event
            popuptriggered[] = true
            nothing
        end
    end)
    yield()
    @test !popuptriggered[]
    evt = eventbutton(c, BUTTON_PRESS, 1)
    signal_emit(widget(c), "button-press-event", Bool, evt)
    yield()
    @test !popuptriggered[]
    evt = eventbutton(c, BUTTON_PRESS, 3)
    signal_emit(widget(c), "button-press-event", Bool, evt)
    @test popuptriggered[]
    destroy(win)
    destroy(popupmenu)
end

@testset "Drawing" begin
    img = testimage("lighthouse")
    c = canvas(UserUnit, size(img, 2), size(img, 1))
    win = Window(c)
    xsig, ysig = Observable(20), Observable(20)
    draw(c, xsig, ysig) do cnvs, x, y
        copy!(c, img)
        ctx = getgc(cnvs)
        set_source(ctx, colorant"red")
        set_line_width(ctx, 2)
        circle(ctx, x, y, 5)
        stroke(ctx)
    end
    Gtk.showall(win)
    xsig[] = 100
    sleep(1)
    # Check that the displayed image is as expected
    if get(ENV, "CI", nothing) != "true" || !Sys.islinux() || VERSION < v"1.3" # broken on Travis
        fn = joinpath(tempdir(), "circled.png")
        Cairo.write_to_png(getgc(c).surface, fn)
        imgout = load(fn)
        rm(fn)
        @test imgout[25,100] == imgout[16,100] == imgout[20,105] == colorant"red"
        @test imgout[20,100] == img[20,100]
    end
    destroy(win)
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
    win = Window() |> (c = canvas(UserUnit))
    zr = Observable(ZoomRegion((1:11, 1:20)))
    zoomrb = init_zoom_rubberband(c, zr)
    zooms = init_zoom_scroll(c, zr)
    pans = init_pan_scroll(c, zr)
    pand = init_pan_drag(c, zr)
    draw(c) do cnvs
        set_coordinates(c, zr[])
        fill!(c, colorant"blue")
    end
    Gtk.showall(win)
    sleep(0.1)

    # Zoom by rubber band
    signal_emit(widget(c), "button-press-event", Bool,
                eventbutton(c, BUTTON_PRESS, 1, UserUnit(5), UserUnit(3), CONTROL))
    signal_emit(widget(c), "motion-notify-event", Bool,
                eventmotion(c, mask(1), UserUnit(10), UserUnit(4)))
    signal_emit(widget(c), "button-release-event", Bool,
                eventbutton(c, GtkObservables.BUTTON_RELEASE, 1, UserUnit(10), UserUnit(4)))
    @test zr[].currentview.x == 5..10
    @test zr[].currentview.y == 3..4
    # Ensure that the rubber band damage has been repaired
    if get(ENV, "CI", nothing) != "true" || !Sys.islinux() || VERSION < v"1.3" # broken on Travis
        fn = tempname()
        Cairo.write_to_png(getgc(c).surface, fn)
        imgout = load(fn)
        rm(fn)
        @test all(x->x==colorant"blue", imgout)
    end

    # Pan-drag
    signal_emit(widget(c), "button-press-event", Bool,
                eventbutton(c, BUTTON_PRESS, 1, UserUnit(6), UserUnit(3), 0))
    signal_emit(widget(c), "motion-notify-event", Bool,
                eventmotion(c, mask(1), UserUnit(7), UserUnit(2)))
    @test zr[].currentview.x == 4..9
    @test zr[].currentview.y == 4..5

    # Reset
    signal_emit(widget(c), "button-press-event", Bool,
                eventbutton(c, DOUBLE_BUTTON_PRESS, 1, UserUnit(5), UserUnit(4.5), CONTROL))
    @test zr[].currentview.x == 1..20
    @test zr[].currentview.y == 1..11

    # Zoom-scroll
    signal_emit(widget(c), "scroll-event", Bool,
                eventscroll(c, UP, UserUnit(8), UserUnit(4), CONTROL))
    @test zr[].currentview.x == 4..14
    @test zr[].currentview.y == 2..8

    # Pan-scroll
    signal_emit(widget(c), "scroll-event", Bool,
                eventscroll(c, RIGHT, UserUnit(8), UserUnit(4), 0))
    @test zr[].currentview.x == 5..15
    @test zr[].currentview.y == 2..8

    signal_emit(widget(c), "scroll-event", Bool,
                eventscroll(c, DOWN, UserUnit(8), UserUnit(4), 0))
    @test zr[].currentview.x == 5..15
    @test zr[].currentview.y == 3..9

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
        destroy(surf)
    end
end

@testset "Layout" begin
    g = Grid()
    g[1,1] = textbox("hello")
end

# Ensure that the examples run (but the Observables queue is stopped, so
# they won't work unless one calls `@async Observables.run()` manually)
examplepath = joinpath(dirname(dirname(@__FILE__)), "examples")
include(joinpath(examplepath, "imageviewer.jl"))
include(joinpath(examplepath, "widgets.jl"))
include(joinpath(examplepath, "drawing.jl"))
