extends CanvasLayer
var config = ConfigFile.new()
var closed
func get_closed_value():
     var err = config.load("user://user.cfg")
     if err == OK:
         closed = config.get_value("settings", "closed_whatsnew", "")
func _ready() -> void:
    get_closed_value()
    if closed == "":
        show()
    else:
        hide()
    


func _on_button_pressed() -> void:
    config.set_value("settings", "closed_whatsnew", "1")
    config.save("user://user.cfg")
    hide()
