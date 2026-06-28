extends RefCounted

const SAMPLE_ID: StringName = &"sample"

signal sample_changed(value: int)

var public_value: int = 1
var _private_value: int = 2


func apply_delta(delta: int) -> int:
	var result: int = public_value + delta
	sample_changed.emit(result)
	return result


func build_label(name: String = "sample", count: int = 1) -> String:
	return "%s:%d" % [name, count]


func _hidden_method() -> void:
	_private_value += 1
