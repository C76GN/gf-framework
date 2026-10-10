@tool

# Tween 原生白名单与公开数值描述共用的纯值属性目录；不枚举场景或调用来源 getter。
extends RefCounted


# --- 层内方法 ---

## 校验闭合的直接数值描述；拒绝重复、未知字段和非有限硬边界。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param records: 数值属性描述。
## [br]
## @schema records: Array[Dictionary]，闭合 name: String、type: int、initial: int/float、minimum/maximum: int/float。
## [br]
## @return: 空串成功，否则为整组拒绝原因。
static func validate_numeric(records: Array[Dictionary]) -> String:
	if records.is_empty() or records.size() > 32:
		return "Numeric descriptors require 1 to 32 properties."
	var names: Dictionary = {}
	for record: Dictionary in records:
		if record.size() != 5:
			return "Numeric property records must contain exactly five fields."
		for key: Variant in record:
			if not (key is String) or not key in ["name", "type", "initial", "minimum", "maximum"]:
				return "Unknown numeric property field."
		if not (record.get("name") is String) or not (record.get("type") is int):
			return "Numeric property names and types are invalid."
		var property_name: String = record["name"]
		var value_type: int = record["type"]
		if property_name.is_empty() or property_name.length() > 64 or not property_name.is_valid_identifier() or names.has(property_name):
			return "Property names must be unique direct identifiers of at most 64 characters."
		names[property_name] = true
		if not value_type in [TYPE_INT, TYPE_FLOAT] or typeof(record.get("initial")) != value_type:
			return "Numeric initial values must match TYPE_INT or TYPE_FLOAT."
		var minimum: float = _number(record.get("minimum"))
		var maximum: float = _number(record.get("maximum"))
		var initial: float = _number(record.get("initial"))
		if not is_finite(minimum) or not is_finite(maximum) or not is_finite(initial) or minimum >= maximum:
			return "Numeric bounds and initial values must be finite with minimum < maximum."
		if absf(minimum) > 1000000.0 or absf(maximum) > 1000000.0 or initial < minimum or initial > maximum:
			return "Numeric bounds must contain the initial value and have magnitude at most 1000000."
	return ""


## 返回独立的原生根属性初值白名单；角度别名可选，不改变初值恢复顺序。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param kind: 0=2D、1=UI、2=3D。
## [br]
## @param include_alias: 是否加入 rotation_degrees 供路径选择和准入。
## [br]
## @return: 原生纯值目录；未知种类为空。
## [br]
## @schema return: Dictionary，String 根名到 float、Vector2、Vector3 或 Color。
static func get_native_values(kind: int, include_alias: bool = false) -> Dictionary:
	var values: Dictionary = {}
	if kind == 2:
		values = {"position": Vector3.ZERO, "rotation": Vector3.ZERO, "scale": Vector3.ONE}
	elif kind == 0 or kind == 1:
		values = {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "modulate": Color.WHITE, "self_modulate": Color.WHITE}
		if kind == 1:
			values["size"] = Vector2(64.0, 64.0)
			values["pivot_offset"] = Vector2(32.0, 32.0)
	if include_alias and not values.is_empty():
		if kind == 2:
			values["rotation_degrees"] = Vector3.ZERO
		else:
			values["rotation_degrees"] = 0.0
	return values


## 将同一原生白名单展开为根值与单层组件记录，供选择器展示。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param kind: 0=2D、1=UI、2=3D。
## [br]
## @return: 至多 64 项的独立记录。
## [br]
## @schema return: Array[Dictionary]，name: String、type: int、initial: float/Vector2/Vector3/Color、minimum/maximum: float、source: String、supported: bool、reason: String。
static func get_native_records(kind: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var values: Dictionary = get_native_values(kind, true)
	for key: Variant in values:
		var property_name: String = key
		var initial: Variant = values[property_name]
		records.append(_record(property_name, initial, "native"))
		var components: Array[String] = []
		if initial is Vector2:
			components = ["x", "y"]
		elif initial is Vector3:
			components = ["x", "y", "z"]
		elif initial is Color:
			components = ["r", "g", "b", "a"]
		for component: String in components:
			var component_initial: float = 0.0
			if initial is Vector2:
				var vector2: Vector2 = initial
				component_initial = vector2[components.find(component)]
			elif initial is Vector3:
				var vector3: Vector3 = initial
				component_initial = vector3[components.find(component)]
			elif initial is Color:
				var color: Color = initial
				component_initial = color[components.find(component)]
			records.append(_record(property_name + ":" + component, component_initial, "native"))
	return records


## 将已校验数值描述转换为同结构的选择器记录，不保留调用方数组。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param properties: validate_numeric 成功的描述。
## [br]
## @schema properties: Array[Dictionary]，同 validate_numeric。
## [br]
## @param source: 已注册的适配器 ID。
## [br]
## @return: 独立展示记录。
## [br]
## @schema return: Array[Dictionary]，字段同 get_native_records。
static func get_numeric_records(properties: Array[Dictionary], source: String) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not validate_numeric(properties).is_empty():
		return records
	for property: Dictionary in properties:
		var record: Dictionary = property.duplicate(true)
		record["source"] = source
		record["supported"] = true
		record["reason"] = ""
		records.append(record)
	return records


## 对已存在的有限记录按属性名做大小写无关搜索；不探测属性值或全场景。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @since unreleased
## [br]
## @param records: 至多 128 条闭合展示记录。
## [br]
## @schema records: Array[Dictionary]，字段同 get_native_records。
## [br]
## @param query: 最多 128 字符；超限返回空数组。
## [br]
## @return: 独立匹配记录，输入超限返回空数组。
## [br]
## @schema return: Array[Dictionary]，字段同 get_native_records。
static func search(records: Array[Dictionary], query: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	if records.size() > 128 or query.length() > 128:
		return matches
	var needle: String = query.to_lower()
	for record: Dictionary in records:
		var property_name: String = record["name"]
		if needle.is_empty() or property_name.to_lower().contains(needle):
			matches.append(record.duplicate(true))
	return matches


# --- 私有/辅助方法 ---

## 创建一条固定原生目录记录。
## [br]
## @api private
static func _record(property_name: String, initial: Variant, source: String) -> Dictionary:
	return {"name": property_name, "type": typeof(initial), "initial": initial, "minimum": -1000000.0, "maximum": 1000000.0, "source": source, "supported": true, "reason": ""}


## 数值到 float 的严格读取；其他类型返回 NAN。
## [br]
## @api private
static func _number(value: Variant) -> float:
	if value is float:
		var floating: float = value
		return floating
	if value is int:
		var integer: int = value
		return float(integer)
	return NAN
