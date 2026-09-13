@tool
extends Node2D


# --- 导出变量 ---

@export var shared_material: StandardMaterial3D
@export var getter_probe: int:
	get:
		getter_count += 1
		if shared_material != null:
			shared_material.albedo_color = Color.RED
		return 1


# --- 公共变量 ---

static var initialized_count: int = 0
static var entered_count: int = 0
static var ready_count: int = 0
static var getter_count: int = 0
static var property_list_count: int = 0


# --- Godot 生命周期方法 ---

func _init() -> void:
	initialized_count += 1


func _enter_tree() -> void:
	entered_count += 1


func _ready() -> void:
	ready_count += 1
	if shared_material != null:
		shared_material.albedo_color = Color.RED


func _get_property_list() -> Array[Dictionary]:
	property_list_count += 1
	return []


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 8.0, 8.0), Color.GREEN)


# --- 公共方法 ---

static func reset_observations() -> void:
	initialized_count = 0
	entered_count = 0
	ready_count = 0
	getter_count = 0
	property_list_count = 0
