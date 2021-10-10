function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing

    # slider
    sl = slider(1:3)
    sl[] = (1:5, 3)
    precompile(sl)
    destroy(sl)

    # checkbox
    cb = checkbox(true)
    cb[] = false
    precompile(cb)
    destroy(cb)

    # togglebutton
    tb = togglebutton(true)
    tb[] = false
    precompile(tb)
    destroy(tb)

    # button
    btn = button("Push me")
    btn[] = nothing
    precompile(btn)
    destroy(btn)

    # textbox
    tb1, tb2 = textbox("Edit me"), textbox(3; range=1:5)
    tb1[] = "done"
    tb2[] = 4
    precompile(tb1)
    precompile(tb2)
    destroy(tb1); destroy(tb2)

    # textarea
    ta = textarea("Lorem ipsum...")
    ta[] = "...muspi meroL"
    precompile(ta)
    destroy(ta)

    # dropdown
    dd = dropdown(["one", "two", "three"])
    precompile(dd)
    destroy(dd)
    precompile(Tuple{typeof(dropdown),Tuple{Vararg{String, 100}}})   # time: 0.042523906
    precompile(Tuple{typeof(dropdown),Vector{Pair{String, Function}}})   # time: 0.01169991

    # label
    lbl = label("Info")
    lbl[] = "other info"
    precompile(lbl)
    destroy(lbl)
    precompile(Tuple{typeof(show),IOBuffer,Label})   # time: 0.07879969

    # spinbutton
    sb = spinbutton(1:3)
    sb[] = (1:4, 4)
    precompile(sb)
    destroy(sb)

    # cyclicspinbutton
    csb = cyclicspinbutton(1:3, Observable(true))
    csb[] = 4
    precompile(csb)
    destroy(csb)

    # progressbar
    pb = progressbar(1:3)
    pb[] = 2
    precompile(pb)
    destroy(pb)
    pb = progressbar(1.0 .. 3.0)
    pb[] = 2.2
    precompile(pb)
    destroy(pb)

    # player
    p = player(1:3)
    precompile(p)
    p[] = 2
    destroy(p)

    # # timewidget
    # tw = timewidget(Dates.Time(1,1,1))
    # tw[] = Dates.Time(2,2,2)
    # precompile(tw)
    # destroy(tw)

    # # datetimewidget
    # dtw = datetimewidget(DateTime(1,1,1,1,1,1))
    # dtw[] = DateTime(2,2,2,2,2,2)
    # destroy(dtw)

    # canvas
    precompile(Tuple{typeof(canvas),Int,Int})   # time: 0.08071636
    precompile(Tuple{typeof(canvas)})   # time: 0.00260139
    for U in (UserUnit, DeviceUnit)
        precompile(Tuple{typeof(canvas),Type{U}})   # time: 0.020233927
        precompile(Tuple{typeof(canvas),Type{U},Int,Int})   # time: 0.020233927
        precompile(Tuple{Type{GtkAspectFrame},Canvas{U},String,Float64,Float64,Float64})   # time: 0.021899309
        precompile(Tuple{typeof(gc_preserve),GtkWindowLeaf,Canvas{U}})

        # precompile(Tuple{typeof(draw),Function,Canvas{U}})   # time: 0.00281273
        # precompile(Tuple{typeof(draw),Function,Canvas{U},Observable{Any}})   # time: 0.006168176
        # precompile(Tuple{typeof(draw),Function,Canvas{U},Observable{Any},Vararg{Observable{Any}, 100}})   # time: 0.007357308

        precompile(Tuple{typeof(fill!),Canvas{U},RGB{N0f8}})   # time: 0.002759036
        precompile(Tuple{typeof(fill!),Canvas{U},RGBA{N0f8}})

        precompile(Tuple{Type{MouseButton{U}}})   # time: 0.001963396
        precompile(Tuple{Type{MouseHandler{U}},GtkCanvas})   # time: 0.017885247
        precompile(Tuple{typeof(mousedown_cb),Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{U}})
        precompile(Tuple{typeof(mouseup_cb),Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{U}})
        precompile(Tuple{typeof(mousescroll_cb),Ptr{GObject},Ptr{Gtk.GdkEventScroll},MouseHandler{U}})   # time: 0.018706173
        precompile(Tuple{typeof(mousemove_cb),Ptr{GObject},Ptr{Gtk.GdkEventMotion},MouseHandler{U}})   # time: 0.016197048
        precompile(Tuple{typeof(rubberband_move),Canvas{U},RubberBand{U},MouseButton{U},Cairo.CairoContext})   # time: 0.001334047

        precompile(Tuple{typeof(set_coordinates),Canvas{U},BoundingBox})   # time: 0.003914427
        precompile(Tuple{typeof(set_coordinates),Canvas{U},ZoomRegion{RInt}})   # time: 0.002466032
    end
    precompile(Tuple{typeof(convertunits),Type{DeviceUnit},Canvas{UserUnit},UserUnit,UserUnit})   # time: 0.002624784
    precompile(Tuple{typeof(convertunits),Type{UserUnit},Canvas{UserUnit},DeviceUnit,DeviceUnit})   # time: 0.001084311

    # image_surface & copy!
    for T in (Gray{N0f8}, GrayA{N0f8}, Gray{Float32}, Gray{Float64},
              RGB{N0f8}, RGBA{N0f8}, RGB{Float32}, RGBA{Float32}, RGB{Float64}, RGBA{Float64})
        precompile(Tuple{typeof(image_surface),Matrix{T}})   # time: 0.046262104 etc.
        for U in (UserUnit, DeviceUnit)
            precompile(Tuple{typeof(copy!),Canvas{U},Matrix{T}})   # time: 0.09909209
        end
    end

    # zoom & friends
    precompile(Tuple{typeof(zoom),ZoomRegion{RInt},Float64})   # time: 0.018138554
    for U in (UserUnit, DeviceUnit)
        precompile(Tuple{Type{XY{U}},Float64,Float64})   # time: 0.010058553
        precompile(Tuple{typeof(zoom),ZoomRegion{RInt},Float64,XY{U}})   # time: 0.002209134
    end
    precompile(Tuple{typeof(zoom),ZoomRegion{RInt},Int})   # time: 0.001822723
    precompile(Tuple{Type{ZoomRegion},Tuple{UnitRange{Int}, UnitRange{Int}}})   # time: 0.009671802
    precompile(Tuple{Type{ZoomRegion},Tuple{Base.OneTo{Int}, Base.OneTo{Int}}})   # time: 0.006405025
    precompile(Tuple{Type{ZoomRegion},Matrix{RGB{N0f8}}})   # time: 0.001308999
    precompile(Tuple{Type{ZoomRegion},Tuple{UnitRange{Int}, UnitRange{Int}},Tuple{UnitRange{Int}, UnitRange{Int}}})   # time: 0.001152972
    precompile(Tuple{Type{ZoomRegion},XY{ClosedInterval{RInt}},BoundingBox})   # time: 0.001061675

    precompile(Tuple{typeof(setindex!),Observable{ZoomRegion{RInt}},Tuple{UnitRange{Int}, UnitRange{Int}}})   # time: 0.003122286
    precompile(Tuple{typeof(setindex!),Observable{ZoomRegion{RInt}},XY{ClosedInterval{Int}}})   # time: 0.001308547
    precompile(Tuple{Type{BoundingBox},XY{ClosedInterval{Int}}})   # time: 0.001497522

    # pan & friends
    precompile(Tuple{typeof(pan),ClosedInterval{Int},Float64,ClosedInterval{Int}})
    precompile(Tuple{typeof(pan_x),ZoomRegion{RInt},Float64})   # time: 0.001364175
    precompile(Tuple{typeof(pan_y),ZoomRegion{RInt},Float64})   # time: 0.001364175

    # advanced interaction
    for U in (UserUnit, DeviceUnit), T in (RInt, Float64)
        precompile(Tuple{typeof(init_zoom_rubberband),Canvas{UserUnit},Observable{ZoomRegion{RInt}}})   # time: 0.110777095
        precompile(Tuple{typeof(init_zoom_rubberband),Canvas{UserUnit},Observable{ZoomRegion{RInt}},typeof(GtkObservables.zrb_init_default), typeof(GtkObservables.zrb_reset_default), Int})   # time: 0.110777095
        precompile(Tuple{typeof(init_zoom_scroll),Canvas{UserUnit},Observable{ZoomRegion{RInt}}})   # time: 0.01061211
        precompile(Tuple{typeof(init_pan_drag),Canvas{UserUnit},Observable{ZoomRegion{RInt}}})   # time: 0.004753301
        precompile(Tuple{typeof(init_pan_scroll),Canvas{UserUnit},Observable{ZoomRegion{RInt}}})   # time: 0.00264137
        # Special handling of the interactives to precompile the callback functions
        zr = T == RInt ? ZoomRegion(rand(3,3)) : (xy = XY(T(1) .. T(3), T(1) .. T(3)); ZoomRegion(xy, xy))
        guidict = init_pan_scroll(canvas(U), Observable(zr))
        precompile(guidict["pan"])
        for f in (init_pan_drag, init_zoom_rubberband)
            guidict = f(canvas(U), Observable(zr))
            precompile(guidict["init"])
            precompile(guidict["drag"])
            precompile(guidict["finish"])
        end
        guidict = init_zoom_scroll(canvas(U), Observable(zr))
        precompile(guidict["zoom"])
    end

    # misc
    precompile(Tuple{typeof(axes),ZoomRegion{RInt}})   # time: 0.012924676
    precompile(Tuple{typeof(+),XY{Float64},XY{Float64}})   # time: 0.011136752
    precompile(Tuple{typeof(show),IOBuffer,XY{Float64}})   # time: 0.001530783
    precompile(Tuple{typeof(show),IOBuffer,XY{Int}})   # time: 0.001503061
    precompile(Tuple{typeof(convert),Type{XY{RInt}},XY{Float64}})   # time: 0.001046295
end
