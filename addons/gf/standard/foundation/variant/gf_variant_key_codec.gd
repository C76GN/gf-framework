## GFVariantKeyCodec: 稳定 Variant key token 编码器。
##
## 用于缓存、索引、查询签名和异步 keyed gate 等底层设施，把可稳定比较的
## Variant 明确编码为 token。默认只接受稳定、有限、不可变语义明确的值；
## Array、Dictionary、Object、Resource、Callable、RID、Signal 和非有限 float 会被拒绝。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFVariantKeyCodec
extends RefCounted


const _KEY_SCHEMA_PREFIX: String = "gfv1"


# --- 公共方法 ---

## 判断值是否可以作为稳定 key。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 待检查的 Variant。
## [br]
## @return 值可稳定编码时返回 true。
## [br]
## @schema value: Variant key candidate.
static func is_stable_key(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return true
		TYPE_FLOAT:
			var float_value: float = value
			return _is_finite_float(float_value)
		TYPE_VECTOR2:
			var vector_2: Vector2 = value
			return _are_finite_floats([vector_2.x, vector_2.y])
		TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I, TYPE_RECT2I:
			return true
		TYPE_VECTOR3:
			var vector_3: Vector3 = value
			return _are_finite_floats([vector_3.x, vector_3.y, vector_3.z])
		TYPE_VECTOR4:
			var vector_4: Vector4 = value
			return _are_finite_floats([vector_4.x, vector_4.y, vector_4.z, vector_4.w])
		TYPE_RECT2:
			var rect_2: Rect2 = value
			return _are_finite_floats([rect_2.position.x, rect_2.position.y, rect_2.size.x, rect_2.size.y])
		TYPE_COLOR:
			var color: Color = value
			return _are_finite_floats([color.r, color.g, color.b, color.a])
		_:
			return false


## 尝试把 Variant 编码为稳定 key token。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 待编码的 key 值。
## [br]
## @param options: 保留给未来扩展；当前不解释。
## [br]
## @return 编码报告。
## [br]
## @schema value: Variant key candidate.
## [br]
## @schema options: Dictionary reserved for future key encoding options.
## [br]
## @schema return: Dictionary with ok, key_token, value_type, and reason.
static func try_make_key_token(value: Variant, options: Dictionary = {}) -> Dictionary:
	var _reserved_options: Dictionary = options
	if not is_stable_key(value):
		return {
			"ok": false,
			"key_token": "",
			"value_type": type_string(typeof(value)),
			"reason": "unstable_key",
		}

	var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(value, {
		"encode_dictionary_keys": true,
		"encode_unsafe_ints": true,
	})
	var encoded_text: String = JSON.stringify(encoded, "", true)
	return {
		"ok": true,
		"key_token": "%s:%s:%s" % [_KEY_SCHEMA_PREFIX, type_string(typeof(value)), encoded_text],
		"value_type": type_string(typeof(value)),
		"reason": "",
	}


## 把 Variant 编码为稳定 key token；不可编码时返回空字符串。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 待编码的 key 值。
## [br]
## @param options: 传给 try_make_key_token() 的编码选项。
## [br]
## @return 稳定 key token，失败时为空字符串。
## [br]
## @schema value: Variant key candidate.
## [br]
## @schema options: Dictionary reserved for future key encoding options.
static func make_key_token(value: Variant, options: Dictionary = {}) -> String:
	var report: Dictionary = try_make_key_token(value, options)
	return GFVariantData.get_option_string(report, "key_token")


# --- 私有/辅助方法 ---

static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _are_finite_floats(values: Array[float]) -> bool:
	for value: float in values:
		if not _is_finite_float(value):
			return false
	return true
