extends Node2D

signal contract_ready(value: int)

var contract_value: int = 0


func apply_contract_marker() -> void:
	contract_ready.emit(contract_value)
	pass
