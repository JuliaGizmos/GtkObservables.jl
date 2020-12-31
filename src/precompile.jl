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
    @assert precompile(Tuple{typeof(dropdown),Tuple{Vararg{String, 100}}})   # time: 0.042523906
    @assert precompile(Tuple{typeof(dropdown),Vector{Pair{String, Function}}})   # time: 0.01169991

    # label
    lbl = label("Info")
    lbl[] = "other info"
    precompile(lbl)
    destroy(lbl)
    @assert precompile(Tuple{typeof(show),IOBuffer,Label})   # time: 0.07879969

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
    @assert precompile(Tuple{typeof(canvas),Int,Int})   # time: 0.08071636
    @assert precompile(Tuple{typeof(canvas)})   # time: 0.00260139
    for U in (UserUnit, DeviceUnit)
        @assert precompile(Tuple{typeof(canvas),Type{U}})   # time: 0.020233927
        @assert precompile(Tuple{typeof(canvas),Type{U},Int,Int})   # time: 0.020233927
        @assert precompile(Tuple{Type{GtkAspectFrame},Canvas{U},String,Float64,Float64,Float64})   # time: 0.021899309
        @assert precompile(Tuple{typeof(gc_preserve),GtkWindowLeaf,Canvas{U}})

        # @assert precompile(Tuple{typeof(draw),Function,Canvas{U}})   # time: 0.00281273
        # @assert precompile(Tuple{typeof(draw),Function,Canvas{U},Observable{Any}})   # time: 0.006168176
        # @assert precompile(Tuple{typeof(draw),Function,Canvas{U},Observable{Any},Vararg{Observable{Any}, 100}})   # time: 0.007357308

        @assert precompile(Tuple{typeof(fill!),Canvas{U},RGB{N0f8}})   # time: 0.002759036
        @assert precompile(Tuple{typeof(fill!),Canvas{U},RGBA{N0f8}})

        @assert precompile(Tuple{Type{MouseButton{U}}})   # time: 0.001963396
        @assert precompile(Tuple{Type{MouseHandler{U}},GtkCanvas})   # time: 0.017885247
        @assert precompile(Tuple{typeof(mousedown_cb),Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{U}})
        @assert precompile(Tuple{typeof(mouseup_cb),Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{U}})
        @assert precompile(Tuple{typeof(mousescroll_cb),Ptr{GObject},Ptr{Gtk.GdkEventScroll},MouseHandler{U}})   # time: 0.018706173
        @assert precompile(Tuple{typeof(mousemove_cb),Ptr{GObject},Ptr{Gtk.GdkEventMotion},MouseHandler{U}})   # time: 0.016197048
        @assert precompile(Tuple{typeof(rubberband_move),Canvas{U},RubberBand{U},MouseButton{U},Cairo.CairoContext})   # time: 0.001334047

        @assert precompile(Tuple{typeof(set_coordinates),Canvas{U},BoundingBox})   # time: 0.003914427
        @assert precompile(Tuple{typeof(set_coordinates),Canvas{U},ZoomRegion{RInt}})   # time: 0.002466032
    end
    @assert precompile(Tuple{typeof(convertunits),Type{DeviceUnit},Canvas{UserUnit},UserUnit,UserUnit})   # time: 0.002624784
    @assert precompile(Tuple{typeof(convertunits),Type{UserUnit},Canvas{UserUnit},DeviceUnit,DeviceUnit})   # time: 0.001084311

    # image_surface & copy!
    for T in (Gray{N0f8}, GrayA{N0f8}, Gray{Float32}, Gray{Float64},
              RGB{N0f8}, RGBA{N0f8}, RGB{Float32}, RGBA{Float32}, RGB{Float64}, RGBA{Float64})
        @assert precompile(Tuple{typeof(image_surface),Matrix{T}})   # time: 0.046262104 etc.
        for U in (UserUnit, DeviceUnit)
            @assert precompile(Tuple{typeof(copy!),Canvas{U},Matrix{T}})   # time: 0.09909209
        end
    end

    # zoom & friends
    @assert precompile(Tuple{typeof(zoom),ZoomRegion{RInt},Float64})   # time: 0.018138554
    for U in (UserUnit, DeviceUnit)
        @assert precompile(Tuple{Type{XY{U}},Float64,Float64})   # time: 0.010058553
        @assert precompile(Tuple{typeof(zoom),ZoomRegion{RInt},Float64,XY{U}})   # time: 0.002209134
    end
    @assert precompile(Tuple{typeof(zoom),ZoomRegion{RInt},Int})   # time: 0.001822723
    @assert precompile(Tuple{Type{ZoomRegion},Tuple{UnitRange{Int}, UnitRange{Int}}})   # time: 0.009671802
    @assert precompile(Tuple{Type{ZoomRegion},Tuple{Base.OneTo{Int}, Base.OneTo{Int}}})   # time: 0.006405025
    @assert precompile(Tuple{Type{ZoomRegion},Matrix{RGB{N0f8}}})   # time: 0.001308999
    @assert precompile(Tuple{Type{ZoomRegion},Tuple{UnitRange{Int}, UnitRange{Int}},Tuple{UnitRange{Int}, UnitRange{Int}}})   # time: 0.001152972
    @assert precompile(Tuple{Type{ZoomRegion},XY{ClosedInterval{RInt}},BoundingBox})   # time: 0.001061675

    @assert precompile(Tuple{typeof(setindex!),Observable{ZoomRegion{RInt}},Tuple{UnitRange{Int}, UnitRange{Int}}})   # time: 0.003122286
    @assert precompile(Tuple{typeof(setindex!),Observable{ZoomRegion{RInt}},XY{ClosedInterval{Int}}})   # time: 0.001308547
    @assert precompile(Tuple{Type{BoundingBox},XY{ClosedInterval{Int}}})   # time: 0.001497522

    # pan & friends
    @assert precompile(Tuple{typeof(pan),ClosedInterval{Int},Float64,ClosedInterval{Int}})
    @assert precompile(Tuple{typeof(pan_x),ZoomRegion{RInt},Float64})   # time: 0.001364175
    @assert precompile(Tuple{typeof(pan_y),ZoomRegion{RInt},Float64})   # time: 0.001364175

    # advanced interaction
    for U in (UserUnit, DeviceUnit), T in (RInt, Float64)
        @assert precompile(Tuple{typeof(init_zoom_rubberband),Canvas{UserUnit},Observable{ZoomRegion{RInt}}})   # time: 0.110777095
        @assert precompile(Tuple{typeof(init_zoom_rubberband),Canvas{UserUnit},Observable{ZoomRegion{RInt}},typeof(GtkObservables.zrb_init_default), typeof(GtkObservables.zrb_reset_default), Int})   # time: 0.110777095
        @assert precompile(Tuple{typeof(init_zoom_scroll),Canvas{UserUnit},Observable{ZoomRegion{RInt}}})   # time: 0.01061211
        @assert precompile(Tuple{typeof(init_pan_drag),Canvas{UserUnit},Observable{ZoomRegion{RInt}}})   # time: 0.004753301
        @assert precompile(Tuple{typeof(init_pan_scroll),Canvas{UserUnit},Observable{ZoomRegion{RInt}}})   # time: 0.00264137
        # Special handling of the interactives to precompile the callback functions
        zr = T == RInt ? ZoomRegion(rand(3,3)) : (xy = XY(T(1) .. T(3), T(1) .. T(3)); ZoomRegion(xy, xy))
        guidict = init_pan_scroll(canvas(U), Observable(zr))
        @assert precompile(guidict["pan"])
        for f in (init_pan_drag, init_zoom_rubberband)
            guidict = f(canvas(U), Observable(zr))
            @assert precompile(guidict["init"])
            @assert precompile(guidict["drag"])
            @assert precompile(guidict["finish"])
        end
        guidict = init_zoom_scroll(canvas(U), Observable(zr))
        @assert precompile(guidict["zoom"])
    end

    # misc
    @assert precompile(Tuple{typeof(axes),ZoomRegion{RInt}})   # time: 0.012924676
    @assert precompile(Tuple{typeof(+),XY{Float64},XY{Float64}})   # time: 0.011136752
    @assert precompile(Tuple{typeof(show),IOBuffer,XY{Float64}})   # time: 0.001530783
    @assert precompile(Tuple{typeof(show),IOBuffer,XY{Int}})   # time: 0.001503061
    @assert precompile(Tuple{typeof(convert),Type{XY{RInt}},XY{Float64}})   # time: 0.001046295
end
