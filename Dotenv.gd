extends Node

var ENV = {}

func _ready():
	var f = File.new()
	f.open("res://.env", File.READ)
	var content = f.get_as_text()
	f.close()
	for line in content.split("\n"):
		if line == "":
			continue
		var pair = line.split("=")
		ENV[pair[0]] = pair[1]

	print(ENV) 
