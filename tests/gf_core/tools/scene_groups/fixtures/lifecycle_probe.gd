@tool
extends Node


func _init() -> void:
	Engine.set_meta(&"gf_scene_group_index_node_instantiated", true)


func _ready() -> void:
	Engine.set_meta(&"gf_scene_group_index_node_ready", true)
