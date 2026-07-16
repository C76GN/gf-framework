## GFFlowPort: 流程节点端口描述。
##
## 端口只描述节点对外暴露的输入/输出能力，供编辑器、校验器或项目层
## 构建可视化流程使用；运行时如何解释端口数据仍由具体节点决定。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFFlowPort
extends Resource


# --- 枚举 ---

## 端口方向。
## [br]
## @api public
## [br]
## @since 3.17.0
enum Direction {
	## 输入端口。
	INPUT,
	## 输出端口。
	OUTPUT,
}

## 端口值类型提示。
## [br]
## @api public
## [br]
## @since 3.17.0
enum ValueType {
	## 任意值。
	ANY,
	## 布尔。
	BOOL,
	## 数值。
	NUMBER,
	## 字符串。
	STRING,
	## Vector2。
	VECTOR2,
	## Vector3。
	VECTOR3,
	## Dictionary。
	DICTIONARY,
	## Array。
	ARRAY,
	## Object 或 Resource。
	OBJECT,
}


# --- 导出变量 ---

## 端口稳定标识。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var port_id: StringName = &""

## 显示名称。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var display_name: String = ""

## 端口方向。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var direction: Direction = Direction.OUTPUT

## 值类型提示。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var value_type: ValueType = ValueType.ANY

## 是否允许多条连接。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var allow_multiple: bool = false

## 编辑器或可视化工具使用的端口颜色。透明色表示由工具自行决定。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var editor_color: Color = Color.TRANSPARENT

## 更细粒度的值类型提示，例如项目自定义数据结构名。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var type_hint: StringName = &""

## Object / Resource 端口的类名提示。仅在项目或校验器显式使用时参与兼容性判断。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var class_name_hint: StringName = &""

## 语义标签列表，供搜索、编辑器过滤或项目工具使用。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var semantic_tags: PackedStringArray = PackedStringArray()

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema metadata: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取端口标识。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 端口标识。
func get_port_id() -> StringName:
	if port_id != &"":
		return port_id
	return &""


## 获取显示名称。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 显示名称。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if port_id != &"":
		return String(port_id)
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename().capitalize()
	return "Flow Port"


## 检查是否包含语义标签。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param tag: 标签。
## [br]
## @return: 包含返回 true。
func has_semantic_tag(tag: StringName) -> bool:
	return semantic_tags.has(String(tag))


## 判断当前端口是否可连接到目标端口。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param target_port: 目标端口。
## [br]
## @return: 兼容返回 true。
func is_compatible_with(target_port: GFFlowPort) -> bool:
	return GFVariantData.get_option_bool(_get_compatibility_report(target_port), "ok", false)


## 获取当前端口连接到目标端口的兼容性报告。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param target_port: 目标端口。
## [br]
## @return: 兼容性报告。
## [br]
## @schema return: 包含 ok、reason、message、source_port_id、source_value_type、target_port_id 和 target_value_type 字段的 Dictionary。
func get_compatibility_report(target_port: GFFlowPort) -> Dictionary:
	return _get_compatibility_report(target_port)


## 描述端口。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 端口描述字典。
## [br]
## @schema return: 包含 port_id、display_name、direction、value_type、allow_multiple、editor_color、type_hint、class_name_hint、semantic_tags 和 metadata 字段的 Dictionary。
func describe() -> Dictionary:
	var effective_port_id: StringName = _get_effective_port_id(self)
	return {
		"port_id": effective_port_id,
		"display_name": _get_effective_display_name(self, effective_port_id),
		"direction": direction,
		"value_type": value_type,
		"allow_multiple": allow_multiple,
		"editor_color": editor_color,
		"type_hint": type_hint,
		"class_name_hint": class_name_hint,
		"semantic_tags": semantic_tags.duplicate(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _get_compatibility_report(target_port: GFFlowPort) -> Dictionary:
	if target_port == null:
		return _make_compatibility_report(self, null, false, "missing_target_port", "Target port is null.")

	var source_port: GFFlowPort = self
	var input_port: GFFlowPort = target_port
	if direction == Direction.INPUT and target_port.direction == Direction.OUTPUT:
		source_port = target_port
		input_port = self

	if source_port.direction != Direction.OUTPUT or input_port.direction != Direction.INPUT:
		return _make_compatibility_report(source_port, input_port, false, "invalid_direction", "Connections require an output port and an input port.")
	if not _value_types_are_compatible(source_port.value_type, input_port.value_type):
		return _make_compatibility_report(source_port, input_port, false, "value_type_mismatch", "Port value types are not compatible.")
	if not _class_hints_are_compatible(source_port, input_port):
		return _make_compatibility_report(source_port, input_port, false, "class_hint_mismatch", "Port class hints are not compatible.")

	return _make_compatibility_report(source_port, input_port, true, "", "")

func _value_types_are_compatible(source_type: ValueType, target_type: ValueType) -> bool:
	if source_type == ValueType.ANY or target_type == ValueType.ANY:
		return true
	return source_type == target_type


func _class_hints_are_compatible(source_port: GFFlowPort, target_port: GFFlowPort) -> bool:
	if source_port.value_type != ValueType.OBJECT or target_port.value_type != ValueType.OBJECT:
		return true
	if source_port.class_name_hint == &"" or target_port.class_name_hint == &"":
		return true
	return source_port.class_name_hint == target_port.class_name_hint


func _make_compatibility_report(
	source_port: GFFlowPort,
	target_port: GFFlowPort,
	ok: bool,
	reason: String,
	message: String
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"message": message,
		"source_port_id": _get_effective_port_id(source_port) if source_port != null else &"",
		"source_value_type": source_port.value_type if source_port != null else ValueType.ANY,
		"target_port_id": _get_effective_port_id(target_port) if target_port != null else &"",
		"target_value_type": target_port.value_type if target_port != null else ValueType.ANY,
	}


func _get_effective_port_id(port: GFFlowPort) -> StringName:
	if port == null:
		return &""
	if port.port_id != &"":
		return port.port_id
	return &""


func _get_effective_display_name(port: GFFlowPort, effective_port_id: StringName) -> String:
	if port == null:
		return "Flow Port"
	if not port.display_name.is_empty():
		return port.display_name
	if effective_port_id != &"":
		return String(effective_port_id)
	if not port.resource_path.is_empty():
		return port.resource_path.get_file().get_basename().capitalize()
	return "Flow Port"
