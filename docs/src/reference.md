# Reference

## Input widgets

```@docs
button
checkbox
togglebutton
slider
textbox
textarea
dropdown
player
```

## Output widgets

```@docs
label
```

## Graphics

```@docs
canvas
GtkObservables.Canvas
GtkObservables.MouseHandler
DeviceUnit
UserUnit
GtkObservables.XY
GtkObservables.MouseButton
GtkObservables.MouseScroll
```

## Pan/zoom

```@docs
ZoomRegion
```

Note that if you create a `zrsig::Observable{ZoomRegion}`, then
```julia
push!(zrsig, XY(1..3, 1..5))
push!(zrsig, (1..5, 1..3))
push!(zrsig, (1:5, 1:3))
```
would all update the value of the `currentview` field to the same
value (`x = 1..3` and `y = 1..5`).


```@docs
pan_x
pan_y
zoom
init_zoom_rubberband
init_zoom_scroll
init_pan_drag
init_pan_scroll
```

## API
```@docs
observable
frame
GtkObservables.gc_preserve
```
