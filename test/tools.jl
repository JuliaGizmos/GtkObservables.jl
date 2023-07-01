# Simulate user inputs
function eventscroll(c, direction, x=DeviceUnit(0), y=DeviceUnit(0), state=0)
    xd, yd = Gtk4Observables.convertunits(DeviceUnit, c, x, y)
    Gtk.GdkEventScroll(Gtk.GdkEventType.SCROLL,
                       Gtk.gdk_window(widget(c)),
                       Int8(0),
                       UInt32(0),
                       convert(Float64, xd), convert(Float64, yd),
                       UInt32(state),
                       direction,
                       convert(Ptr{Float64},C_NULL),
                       0.0, 0.0,
                       0.0, 0.0)
end

const ModType = Gtk4.ModifierType
mask(btn) =
    btn == 1 ? ModType.GDK_BUTTON1_MASK :
    btn == 2 ? ModType.GDK_BUTTON2_MASK :
    btn == 3 ? ModType.GDK_BUTTON3_MASK :
    error(btn, " not recognized")
