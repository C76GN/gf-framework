extends Resource


static var initialization_count: int = 0


func _init() -> void:
	initialization_count += 1


static func reset_initialization_count() -> void:
	initialization_count = 0


static func get_initialization_count() -> int:
	return initialization_count
