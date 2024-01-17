# This example creates a modal dialog with two checkboxes.

using Gtk.ShortNames, GtkObservables

# define the default values
OPTION_A = false
OPTION_B = false
finished = false 

cb1 = checkbox(OPTION_A, label="Option A")
cb2 = checkbox(OPTION_B, label="Option B")
btnOK = button(label="OK")

win = Window("Dialog", 200, 72) |> (bx = Box(:v))
push!(bx, cb1)
push!(bx, cb2)
push!(bx, btnOK)

function on_button_clicked(win)
    global OPTION_A, OPTION_B, finished, win
    OPTION_A = observable(cb1)[]
    OPTION_B = observable(cb2)[]
    destroy(win)
    finished = true
end
signal_connect(on_button_clicked, widget(btnOK), "clicked")

Gtk.showall(win)
while ! finished
    sleep(0.1)
end

println("Option A: $OPTION_A")
println("Option B: $OPTION_B")
nothing