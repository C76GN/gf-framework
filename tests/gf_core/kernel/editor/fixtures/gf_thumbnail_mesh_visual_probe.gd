@tool
extends MeshInstance3D


# --- 导出变量 ---

@export var getter_probe: int:
	get:
		getter_count += 1
		return 1


# --- 公共变量 ---

static var getter_count: int = 0
static var property_list_count: int = 0
static var dynamic_get_count: int = 0
static var dynamic_get_properties: Array[StringName] = []


# --- Godot 回调方法 ---

func _get_property_list() -> Array[Dictionary]:
	property_list_count += 1
	return []


func _get(property: StringName) -> Variant:
	dynamic_get_count += 1
	dynamic_get_properties.append(property)
	return null


# --- 公共方法 ---

static func reset_observations() -> void:
	getter_count = 0
	property_list_count = 0
	dynamic_get_count = 0
	dynamic_get_properties.clear()
