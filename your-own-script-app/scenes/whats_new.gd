extends CanvasLayer

func _ready():
	al.get_closed_value()
	if al.closed == "one":
		hide()
	else:
		show()
	


func _on_button_pressed() -> void:
	al.config.set_value("settings", "closed_whatsnew", "one")
	al.config.save("user://user.cfg")
	hide()
