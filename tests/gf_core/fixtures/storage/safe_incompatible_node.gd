extends Node


static var last_instance: WeakRef = null


func _init() -> void:
	last_instance = weakref(self)
