## GFSpatialQueryIdentity: 空间查询实体身份值对象。
##
## 将 Object、StringName、String 与 int 统一成稳定 key。Object 使用 weakref
## 保存，避免空间索引因为查询身份持有场景对象生命周期；值类型会复制保存。
## Array、Dictionary 等可变复合值不会被接受为稳定空间查询身份。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
class_name GFSpatialQueryIdentity
extends RefCounted


# --- 常量 ---

## Object 身份类型。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_OBJECT: StringName = &"object"

## StringName 身份类型。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_STRING_NAME: StringName = &"string_name"

## String 身份类型。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_STRING: StringName = &"string"

## int 身份类型。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_INT: StringName = &"int"


# --- 公共变量 ---

## 稳定查询 key，格式为 `kind:value`。
## [br]
## @api public
## [br]
## @since 8.0.0
var key: String = ""

## 身份类型。
## [br]
## @api public
## [br]
## @since 8.0.0
var kind: StringName = &""

## int 身份值；非 int 身份时为 0。
## [br]
## @api public
## [br]
## @since 8.0.0
var entity_id: int = 0

## Object 实例 ID；非 Object 身份时为 0。
## [br]
## @api public
## [br]
## @since 8.0.0
var object_instance_id: int = 0

## String 或 StringName 身份文本；其他身份时为空字符串。
## [br]
## @api public
## [br]
## @since 8.0.0
var string_value: String = ""


# --- 私有变量 ---

var _value: Variant = null
var _object_ref: WeakRef = null


# --- 公共方法 ---

## 从实体值创建空间查询身份。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param entity: Object、StringName、String 或 int 实体身份。
## [br]
## @return 空间查询身份；不支持的实体值会返回空 key 身份。
## [br]
## @schema entity: Object, StringName, String, or int identity.
static func from_value(entity: Variant) -> GFSpatialQueryIdentity:
	var identity: GFSpatialQueryIdentity = GFSpatialQueryIdentity.new()
	identity._assign(entity)
	return identity


## 直接获取实体值对应的稳定 key。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param entity: Object、StringName、String 或 int 实体身份。
## [br]
## @return 支持的实体值返回稳定 key；不支持时返回空字符串。
## [br]
## @schema entity: Object, StringName, String, or int identity.
static func make_key(entity: Variant) -> String:
	return from_value(entity).key


## 判断实体值是否可作为稳定空间查询身份。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param entity: 待检测实体身份。
## [br]
## @return 支持时返回 true。
## [br]
## @schema entity: Object, StringName, String, or int identity candidate.
static func supports_value(entity: Variant) -> bool:
	return not make_key(entity).is_empty()


## 按空间身份 key 稳定排序。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param left_key: 左侧 key。
## [br]
## @param right_key: 右侧 key。
## [br]
## @return left_key 应排在 right_key 前方时返回 true。
static func sort_keys(left_key: String, right_key: String) -> bool:
	var left_kind: String = get_key_kind(left_key)
	var right_kind: String = get_key_kind(right_key)
	if left_kind == right_kind and left_kind == "int":
		return get_int_key_value(left_key) < get_int_key_value(right_key)
	return left_key < right_key


## 从稳定 key 中取出类型前缀。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param identity_key: 稳定空间身份 key。
## [br]
## @return key 类型；格式无效时返回空字符串。
static func get_key_kind(identity_key: String) -> String:
	var separator_index: int = identity_key.find(":")
	if separator_index < 0:
		return ""
	return identity_key.substr(0, separator_index)


## 从 int 类型稳定 key 中取出数值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param identity_key: 稳定空间身份 key。
## [br]
## @return int key 的数值；非 int key 返回 0。
static func get_int_key_value(identity_key: String) -> int:
	var prefix: String = "int:"
	if not identity_key.begins_with(prefix):
		return 0
	return int(identity_key.substr(prefix.length()))


## 当前身份是否有效。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return key 非空且 Object 身份未释放时返回 true。
func is_valid() -> bool:
	if key.is_empty():
		return false
	if kind == KIND_OBJECT:
		return get_object() != null
	return true


## 取回原始实体值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return Object 身份返回 live Object；值身份返回保存的值；无效身份返回 null。
## [br]
## @schema return: Object, StringName, String, int, or null entity value.
func get_value() -> Variant:
	if kind == KIND_OBJECT:
		return get_object()
	return GFVariantData.duplicate_variant(_value, true)


## 取回 Object 身份引用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return Object 身份未释放时返回 Object；否则返回 null。
func get_object() -> Object:
	if _object_ref == null:
		return null
	return _object_ref.get_ref()


## 转换为可序列化快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param include_value: 为 true 时为非 Object 身份附带原始值。
## [br]
## @return 身份快照。
## [br]
## @schema return: Dictionary with key, kind, entity_id, object_instance_id, string_value, valid, and optional value.
func to_dictionary(include_value: bool = false) -> Dictionary:
	var snapshot: Dictionary = {
		"key": key,
		"kind": kind,
		"entity_id": entity_id,
		"object_instance_id": object_instance_id,
		"string_value": string_value,
		"valid": is_valid(),
	}
	if include_value and kind != KIND_OBJECT:
		snapshot["value"] = get_value()
	return snapshot


# --- 私有/辅助方法 ---

func _assign(entity: Variant) -> void:
	if entity == null:
		return
	if entity is Object:
		var object: Object = _variant_to_object(entity)
		if object == null:
			return
		kind = KIND_OBJECT
		object_instance_id = object.get_instance_id()
		key = "object:%d" % object_instance_id
		_object_ref = weakref(object)
		return
	if entity is StringName:
		var string_name_value: StringName = entity
		if string_name_value == &"":
			return
		kind = KIND_STRING_NAME
		string_value = String(string_name_value)
		key = "string_name:%s" % string_value
		_value = string_name_value
		return
	if entity is String:
		var string_value_data: String = entity
		if string_value_data.is_empty():
			return
		kind = KIND_STRING
		string_value = string_value_data
		key = "string:%s" % string_value
		_value = string_value_data
		return
	if entity is int:
		var int_value: int = entity
		kind = KIND_INT
		entity_id = int_value
		key = "int:%d" % int_value
		_value = int_value


func _variant_to_object(value: Variant) -> Object:
	if value is Object:
		var object: Object = value
		return object
	return null
