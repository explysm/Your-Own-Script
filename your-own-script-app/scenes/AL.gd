extends Node
var config = ConfigFile.new()

var err = config.load("user://user.cfg")
var closed = config.get_value("settings", "closed_whatsnew", "zero")



func get_closed_value():
	if err == OK:
		closed = config.get_value("settings", "closed_whatsnew", "zero")
	else:
		config.set_value("settings", "closed_whatsnew", "zero")
		config.save("user://user.cfg")
