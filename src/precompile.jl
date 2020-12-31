function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    @assert precompile(Tuple{Core.kwftype(typeof(timewidget)),NamedTuple{(:observable,), Tuple{Observable{Time}}},typeof(timewidget),Time})   # time: 0.115743145
    @assert precompile(Tuple{typeof(init_zoom_rubberband),Canvas{UserUnit},Observable{ZoomRegion{RInt64}}})   # time: 0.110777095
    @assert precompile(Tuple{typeof(init_zoom_rubberband),Canvas{UserUnit},Observable{ZoomRegion{RInt64}},typeof(GtkObservables.zrb_init_default), typeof(GtkObservables.zrb_reset_default), Int})   # time: 0.110777095
    @assert precompile(Tuple{Core.kwftype(typeof(datetimewidget)),NamedTuple{(:observable,), Tuple{Observable{DateTime}}},typeof(datetimewidget),DateTime})   # time: 0.110061295
    @assert precompile(Tuple{typeof(label),String})   # time: 0.101116486
    @assert precompile(Tuple{typeof(copy!),Canvas{UserUnit},Matrix{RGB{N0f8}}})   # time: 0.09909209
    @assert precompile(Tuple{typeof(player),Observable{Int64},UnitRange{Int64}})   # time: 0.082910724
    @assert precompile(Tuple{typeof(canvas),Int64,Int64})   # time: 0.08071636
    @assert precompile(Tuple{typeof(show),IOBuffer,Label})   # time: 0.07879969
    @assert precompile(Tuple{typeof(textarea),String})   # time: 0.054318994
    @assert precompile(Tuple{typeof(image_surface),Matrix{RGBA{Float64}}})   # time: 0.046262104
    @assert precompile(Tuple{typeof(textbox),String})   # time: 0.043787602
    @assert precompile(Tuple{typeof(dropdown),Tuple{Vararg{String, 100}}})   # time: 0.042523906
    @assert precompile(Tuple{Core.kwftype(typeof(togglebutton)),NamedTuple{(:label,), Tuple{String}},typeof(togglebutton)})   # time: 0.040888157
    @assert precompile(Tuple{Core.kwftype(typeof(checkbox)),NamedTuple{(:label,), Tuple{String}},typeof(checkbox)})   # time: 0.034800116
    @assert precompile(Tuple{typeof(progressbar),ClosedInterval{Int64}})   # time: 0.033394996
    @assert precompile(Tuple{typeof(slider),UnitRange{Int64}})   # time: 0.03210807
    @assert precompile(Tuple{typeof(spinbutton),UnitRange{Int64}})   # time: 0.0317442
    @assert precompile(Tuple{typeof(image_surface),Matrix{Float64}})   # time: 0.025033748
    @assert precompile(Tuple{Core.kwftype(typeof(dropdown)),NamedTuple{(:label,), Tuple{String}},typeof(dropdown),Vector{Pair{String, Function}}})   # time: 0.02340839
    @assert precompile(Tuple{Core.kwftype(typeof(textbox)),NamedTuple{(:range,), Tuple{UnitRange{Int64}}},typeof(textbox),Int64})   # time: 0.022958083
    @assert precompile(Tuple{Type{GtkAspectFrame},Canvas{DeviceUnit},String,Float64,Float64,Float64})   # time: 0.021899309
    @assert precompile(Tuple{typeof(canvas),Type{UserUnit}})   # time: 0.020233927
    @assert precompile(Tuple{typeof(canvas),Type{UserUnit},Int64,Int64})   # time: 0.020233927
    @assert precompile(Tuple{typeof(mousescroll_cb),Ptr{GObject},Ptr{Gtk.GdkEventScroll},MouseHandler{UserUnit}})   # time: 0.018706173
    @assert precompile(Tuple{typeof(setindex!),Slider{Int64},Tuple{UnitRange{Int64}, Int64}})   # time: 0.018451277
    @assert precompile(Tuple{typeof(zoom),ZoomRegion{RInt64},Float64})   # time: 0.018138554
    @assert precompile(Tuple{typeof(map),Function,Textbox{String},Textbox{Int64}})   # time: 0.016691625
    @assert precompile(Tuple{typeof(mousemove_cb),Ptr{GObject},Ptr{Gtk.GdkEventMotion},MouseHandler{UserUnit}})   # time: 0.016197048
    @assert precompile(Tuple{typeof(cyclicspinbutton),UnitRange{Int64},Observable{Bool}})   # time: 0.015953336
    @assert precompile(Tuple{typeof(button),String})   # time: 0.015578984
    @assert precompile(Tuple{typeof(axes),ZoomRegion{RInt64}})   # time: 0.012924676
    @assert precompile(Tuple{typeof(image_surface),Matrix{Gray{N0f8}}})   # time: 0.011829626
    @assert precompile(Tuple{typeof(dropdown),Vector{Pair{String, Function}}})   # time: 0.01169991
    @assert precompile(Tuple{typeof(+),XY{Float64},XY{Float64}})   # time: 0.011136752
    @assert precompile(Tuple{Core.kwftype(typeof(textbox)),NamedTuple{(:observable,), Tuple{Observable{Int64}}},typeof(textbox),Type{Int64}})   # time: 0.010784853
    @assert precompile(Tuple{typeof(init_zoom_scroll),Canvas{UserUnit},Observable{ZoomRegion{RInt64}}})   # time: 0.01061211
    @assert precompile(Tuple{typeof(map),Function,Label})   # time: 0.009765576
    @assert precompile(Tuple{Type{ZoomRegion},Tuple{UnitRange{Int64}, UnitRange{Int64}}})   # time: 0.009671802
    @assert precompile(Tuple{Core.kwftype(typeof(textbox)),NamedTuple{(:widget, :observable, :range), Tuple{GtkEntryLeaf, Observable{Int64}, UnitRange{Int64}}},typeof(textbox),Int64})   # time: 0.008382424
    @assert precompile(Tuple{typeof(draw),Function,Canvas{UserUnit},Observable{Int64},Vararg{Observable{Int64}, 100}})   # time: 0.008291145
    @assert precompile(Tuple{typeof(draw),Function,Canvas{UserUnit},Observable{Vector{Any}},Vararg{Observable{Vector{Any}}, 100}})   # time: 0.007357308
    @assert precompile(Tuple{Core.kwftype(typeof(button)),NamedTuple{(:widget,), Tuple{GtkToolButtonLeaf}},typeof(button)})   # time: 0.006894188
    @assert precompile(Tuple{Type{ZoomRegion},Tuple{Base.OneTo{Int64}, Base.OneTo{Int64}}})   # time: 0.006405025
    @assert precompile(Tuple{typeof(map),Function,Button})   # time: 0.006336905
    @assert precompile(Tuple{typeof(draw),Function,Canvas{UserUnit},Observable{Any}})   # time: 0.006168176
    @assert precompile(Tuple{typeof(canvas),Type{UserUnit}})   # time: 0.005956597
    @assert precompile(Tuple{typeof(map),Function,Checkbox})   # time: 0.005810558
    @assert precompile(Tuple{Core.kwftype(typeof(slider)),NamedTuple{(:observable, :orientation), Tuple{Observable{Int64}, Char}},typeof(slider),UnitRange{Int64}})   # time: 0.005702973
    @assert precompile(Tuple{Core.kwftype(typeof(spinbutton)),NamedTuple{(:value,), Tuple{Int64}},typeof(spinbutton),UnitRange{Int64}})   # time: 0.005454661
    @assert precompile(Tuple{Core.kwftype(typeof(slider)),NamedTuple{(:widget, :observable), Tuple{GtkScaleLeaf, Observable{Int64}}},typeof(slider),UnitRange{Int64}})   # time: 0.004878002
    @assert precompile(Tuple{typeof(init_pan_drag),Canvas{UserUnit},Observable{ZoomRegion{RInt64}}})   # time: 0.004753301
    @assert precompile(Tuple{typeof(mousedown_cb),Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{UserUnit}})   # time: 0.00433181
    @assert precompile(Tuple{Core.kwftype(typeof(spinbutton)),NamedTuple{(:widget, :observable), Tuple{GtkSpinButtonLeaf, Observable{Int64}}},typeof(spinbutton),UnitRange{Int64}})   # time: 0.004098546
    @assert precompile(Tuple{Type{GtkWindow},Textarea})   # time: 0.00398958
    @assert precompile(Tuple{typeof(set_coordinates),Canvas{UserUnit},BoundingBox})   # time: 0.003914427
    @assert precompile(Tuple{typeof(mousedown_cb),Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{DeviceUnit}})   # time: 0.003356859
    @assert precompile(Tuple{typeof(mousescroll_cb),Ptr{GObject},Ptr{Gtk.GdkEventScroll},MouseHandler{DeviceUnit}})   # time: 0.00330406
    @assert precompile(Tuple{typeof(setindex!),Observable{ZoomRegion{RInt64}},Tuple{UnitRange{Int64}, UnitRange{Int64}}})   # time: 0.003122286
    @assert precompile(Tuple{typeof(draw),Function,Canvas{UserUnit}})   # time: 0.00281273
    @assert precompile(Tuple{typeof(fill!),Canvas{UserUnit},RGB{N0f8}})   # time: 0.002759036
    @assert precompile(Tuple{typeof(init_pan_scroll),Canvas{UserUnit},Observable{ZoomRegion{RInt64}}})   # time: 0.00264137
    @assert precompile(Tuple{typeof(convertunits),Type{DeviceUnit},Canvas{UserUnit},UserUnit,UserUnit})   # time: 0.002624784
    @assert precompile(Tuple{typeof(canvas)})   # time: 0.00260139
    @assert precompile(Tuple{Type{Label},Observable{String},GtkLabelLeaf,Vector{Any}})   # time: 0.002581081
    @assert precompile(Tuple{typeof(set_coordinates),Canvas{UserUnit},ZoomRegion{RInt64}})   # time: 0.002466032
    @assert precompile(Tuple{Type{Dropdown},Observable{String},Observable{Any},GtkComboBoxTextLeaf,UInt64,Vector{Any}})   # time: 0.002410124
    @assert precompile(Tuple{typeof(gc_preserve),GtkFrameLeaf,Player{PlayerWithTextbox}})   # time: 0.002317133
    @assert precompile(Tuple{typeof(ondestroy),GtkProgressBarLeaf,Vector{Any}})   # time: 0.002292251
    @assert precompile(Tuple{typeof(player),UnitRange{Int64}})   # time: 0.002277744
    @assert precompile(Tuple{typeof(ondestroy),GtkLabelLeaf,Vector{Any}})   # time: 0.002236544
    @assert precompile(Tuple{typeof(ondestroy),GtkComboBoxTextLeaf,Vector{Any}})   # time: 0.002222859
    @assert precompile(Tuple{typeof(zoom),ZoomRegion{RInt64},Float64,XY{DeviceUnit}})   # time: 0.002209134
    @assert precompile(Tuple{Core.kwftype(typeof(button)),NamedTuple{(:widget,), Tuple{GtkButtonLeaf}},typeof(button)})   # time: 0.002120643
    @assert precompile(Tuple{typeof(setindex!),Textbox{Int64},Int64})   # time: 0.001964045
    @assert precompile(Tuple{Type{MouseButton{UserUnit}}})   # time: 0.001963396
    @assert precompile(Tuple{typeof(destroy),SpinButton{Int64}})   # time: 0.001867615
    @assert precompile(Tuple{typeof(zoom),ZoomRegion{RInt64},Int64})   # time: 0.001822723
    @assert precompile(Tuple{typeof(setindex!),SpinButton{Int64},Tuple{UnitRange{Int64}, Int64}})   # time: 0.001812057
    @assert precompile(Tuple{typeof(destroy),Slider{Int64}})   # time: 0.001750338
    @assert precompile(Tuple{typeof(draw),Function,Canvas{DeviceUnit}})   # time: 0.001727843
    @assert precompile(Tuple{typeof(setindex!),Checkbox,Bool})   # time: 0.001716981
    @assert precompile(Tuple{typeof(setindex!),TimeWidget{DateTime},DateTime})   # time: 0.001705442
    @assert precompile(Tuple{typeof(setindex!),Label,String})   # time: 0.001647036
    @assert precompile(Tuple{typeof(setindex!),TimeWidget{Time},Time})   # time: 0.001623848
    @assert precompile(Tuple{typeof(show),IOBuffer,XY{Float64}})   # time: 0.001530783
    @assert precompile(Tuple{typeof(show),IOBuffer,XY{Int64}})   # time: 0.001503061
    @assert precompile(Tuple{Type{BoundingBox},XY{ClosedInterval{Int64}}})   # time: 0.001497522
    @assert precompile(Tuple{typeof(get_gtk_property),Label,Symbol,Type{String}})   # time: 0.001479955
    @assert precompile(Tuple{typeof(show),IOBuffer,UserUnit})   # time: 0.001462472
    @assert precompile(Tuple{Core.kwftype(typeof(spinbutton)),NamedTuple{(:orientation,), Tuple{String}},typeof(spinbutton),UnitRange{Int64}})   # time: 0.001407626
    @assert precompile(Tuple{Type{MouseButton{DeviceUnit}}})   # time: 0.001365265
    @assert precompile(Tuple{typeof(pan_x),ZoomRegion{RInt64},Float64})   # time: 0.001364175
    @assert precompile(Tuple{typeof(rubberband_move),Canvas{UserUnit},RubberBand{UserUnit},MouseButton{UserUnit},Cairo.CairoContext})   # time: 0.001334047
    @assert precompile(Tuple{Type{ZoomRegion},Matrix{RGB{N0f8}}})   # time: 0.001308999
    @assert precompile(Tuple{typeof(setindex!),Observable{ZoomRegion{RInt64}},XY{ClosedInterval{Int64}}})   # time: 0.001308547
    @assert precompile(Tuple{Core.kwftype(typeof(checkbox)),NamedTuple{(:label,), Tuple{String}},typeof(checkbox),Bool})   # time: 0.001228299
    @assert precompile(Tuple{Type{GtkFrame},Canvas{DeviceUnit}})   # time: 0.001184776
    @assert precompile(Tuple{Type{ZoomRegion},Tuple{UnitRange{Int64}, UnitRange{Int64}},Tuple{UnitRange{Int64}, UnitRange{Int64}}})   # time: 0.001152972
    @assert precompile(Tuple{typeof(convertunits),Type{UserUnit},Canvas{UserUnit},DeviceUnit,DeviceUnit})   # time: 0.001084311
    @assert precompile(Tuple{Type{ZoomRegion},XY{ClosedInterval{RInt64}},BoundingBox})   # time: 0.001061675
    @assert precompile(Tuple{typeof(convert),Type{XY{RInt64}},XY{Float64}})   # time: 0.001046295
    @assert precompile(Tuple{Type{DeviceUnit},Int64})   # time: 0.001015558

    # Special handling of the interactives to precompile the callback functions
    for U in (UserUnit, DeviceUnit)
        guidict = init_pan_scroll(canvas(U), Observable(ZoomRegion(rand(3,3))))
        @assert precompile(guidict["pan"].f, (MouseScroll{U},))
        for f in (init_pan_drag, init_zoom_rubberband)
            guidict = f(canvas(U), Observable(ZoomRegion(rand(3,3))))
            @assert precompile(guidict["init"].f, (MouseButton{U},))
            @assert precompile(guidict["drag"].f, (MouseButton{U},))
            @assert precompile(guidict["finish"].f, (MouseButton{U},))
        end
        guidict = init_zoom_scroll(canvas(U), Observable(ZoomRegion(rand(3,3))))
        @assert precompile(guidict["zoom"].f, (MouseScroll{U},))
    end
end
