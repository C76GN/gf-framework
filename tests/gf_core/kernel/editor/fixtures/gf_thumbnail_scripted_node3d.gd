@tool
extends Node3D


# --- 导出变量 ---

@export var shared_material: StandardMaterial3D


# --- 公共变量 ---

static var initialized_count: int = 0
static var entered_count: int = 0
static var ready_count: int = 0


# --- Godot 生命周期方法 ---

func _init() -> void:
	initialized_count += 1


func _enter_tree() -> void:
	entered_count += 1


func _ready() -> void:
	ready_count += 1
	if shared_material != null:
		shared_material.albedo_color = Color.RED


# --- 公共方法 ---

static func reset_observations() -> void:
	initialized_count = 0
	entered_count = 0
	ready_count = 0
