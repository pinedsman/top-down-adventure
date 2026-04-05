extends Node

#use this to manage dev console commands

func _ready() -> void:
	Console.add_command("test", test)
	pass

func test():
	Console.print_line("test")
