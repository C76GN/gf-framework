extends RefCounted


const WARNING_CODE: String = "GF lifecycle bootstrap fixture warning"


static func _static_init() -> void:
	push_warning(WARNING_CODE)
