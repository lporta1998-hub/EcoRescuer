@tool
extends EditorPlugin

func _enter_tree():
    add_autoload_singleton("SilentWolf", "res://silent_wolf/SilentWolf.gd")

func _exit_tree():
    remove_autoload_singleton("SilentWolf")
