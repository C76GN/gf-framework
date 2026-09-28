## GFCacheDiagnostics: 通用缓存命中、写入和失效统计。
##
## 用于给各类缓存、索引或预热池提供一致的诊断快照。它不持有缓存内容，
## 也不规定缓存淘汰策略，只记录可观测事件。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFCacheDiagnostics
extends RefCounted


# --- 常量 ---

## 生成 JSON-safe 诊断文本时使用的报告值编码器。
## [br]
## @api private
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")

## 将 Variant key 转为稳定 token 时使用的 key 编码器。
## [br]
## @api private
const _GF_VARIANT_KEY_CODEC_SCRIPT = preload("res://addons/gf/standard/foundation/variant/gf_variant_key_codec.gd")

## 统计计数器允许达到的最大值。
## [br]
## @api private
const _MAX_COUNTER_VALUE: int = 9223372036854775807


# --- 公共变量 ---

## 诊断对象标识。
## [br]
## @api public
## [br]
## @since 6.0.0
var cache_id: StringName = &""


# --- 私有变量 ---

## 缓存命中总数。
## [br]
## @api private
var _hit_count: int = 0

## 缓存未命中总数。
## [br]
## @api private
var _miss_count: int = 0

## 缓存写入总数。
## [br]
## @api private
var _write_count: int = 0

## 缓存淘汰总数。
## [br]
## @api private
var _eviction_count: int = 0

## 缓存失效总数。
## [br]
## @api private
var _invalidation_count: int = 0

## 按失效原因累计的计数。
## [br]
## @api private
var _invalidation_reasons: Dictionary = {}

## 最近一次记录的缓存事件。
## [br]
## @api private
var _last_event: Dictionary = {}

## 任一计数达到饱和值时置为 true，reset() 会清除此标志。
## [br]
## @api private
var _counter_saturated: bool = false


# --- 公共方法 ---

## 记录缓存命中。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param key: 可选缓存 key。
## [br]
## @schema key: 任意缓存键；诊断快照会以字符串形式记录。
func record_hit(key: Variant = null) -> void:
	_hit_count = _add_counter(_hit_count, 1)
	_last_event = _make_event(&"hit", key)


## 记录缓存未命中。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param key: 可选缓存 key。
## [br]
## @schema key: 任意缓存键；诊断快照会以字符串形式记录。
func record_miss(key: Variant = null) -> void:
	_miss_count = _add_counter(_miss_count, 1)
	_last_event = _make_event(&"miss", key)


## 记录缓存写入。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param key: 可选缓存 key。
## [br]
## @schema key: 任意缓存键；诊断快照会以字符串形式记录。
func record_write(key: Variant = null) -> void:
	_write_count = _add_counter(_write_count, 1)
	_last_event = _make_event(&"write", key)


## 记录缓存淘汰。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param reason: 淘汰原因。
## [br]
## @param key: 可选缓存 key。
## [br]
## @schema key: 任意缓存键；诊断快照会以字符串形式记录。
func record_eviction(reason: StringName = &"evicted", key: Variant = null) -> void:
	_eviction_count = _add_counter(_eviction_count, 1)
	_invalidation_count = _add_counter(_invalidation_count, 1)
	_record_invalidation_reason(reason)
	_last_event = _make_event(reason, key)


## 记录缓存失效。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param reason: 失效原因。
## [br]
## @param key: 可选缓存 key。
## [br]
## @schema key: 任意缓存键；诊断快照会以字符串形式记录。
## [br]
## @param amount: 失效数量。
func record_invalidation(reason: StringName = &"invalidated", key: Variant = null, amount: int = 1) -> void:
	if amount <= 0:
		return
	var count: int = amount
	_invalidation_count = _add_counter(_invalidation_count, count)
	_record_invalidation_reason(reason, count)
	_last_event = _make_event(reason, key, count)


## 清空统计。
## [br]
## @api public
## [br]
## @since 6.0.0
func reset() -> void:
	_hit_count = 0
	_miss_count = 0
	_write_count = 0
	_eviction_count = 0
	_invalidation_count = 0
	_invalidation_reasons.clear()
	_last_event.clear()
	_counter_saturated = false


## 获取命中率。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 命中率；没有读请求时返回 0.0。
func get_hit_ratio() -> float:
	if _hit_count <= 0 and _miss_count <= 0:
		return 0.0
	return float(_hit_count) / (float(_hit_count) + float(_miss_count))


## 获取诊断快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 诊断快照。
## [br]
## @schema return: Dictionary with cache_id, hit_count, miss_count, write_count, eviction_count, invalidation_count, hit_ratio, counter_saturated, invalidation_reasons, and last_event.
func get_debug_snapshot() -> Dictionary:
	return {
		"cache_id": cache_id,
		"hit_count": _hit_count,
		"miss_count": _miss_count,
		"write_count": _write_count,
		"eviction_count": _eviction_count,
		"invalidation_count": _invalidation_count,
		"hit_ratio": get_hit_ratio(),
		"counter_saturated": _counter_saturated,
		"invalidation_reasons": _invalidation_reasons.duplicate(true),
		"last_event": _last_event.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 按原因累计失效数量；空原因使用 invalidated 作为键。
## [br]
## @api private
func _record_invalidation_reason(reason: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	var reason_key: String = String(reason) if reason != &"" else "invalidated"
	_invalidation_reasons[reason_key] = _add_counter(
		GFVariantData.get_option_int(_invalidation_reasons, reason_key, 0),
		amount
	)


## 增加非负计数；达到上限时饱和并记录饱和标志。
## [br]
## @api private
func _add_counter(current: int, amount: int) -> int:
	if amount <= 0:
		return current
	if current > _MAX_COUNTER_VALUE - amount:
		_counter_saturated = true
		return _MAX_COUNTER_VALUE
	return current + amount


## 创建包含类型、key 文本、数量和毫秒 tick 的事件字典。
## [br]
## @api private
func _make_event(event_type: StringName, key: Variant, amount: int = 1) -> Dictionary:
	return {
		"type": event_type,
		"key": _make_key_text(key),
		"amount": amount,
		"timestamp_msec": Time.get_ticks_msec(),
	}


## 将 key 编码为诊断文本；null 为空，编码器无 token 时使用 JSON-safe 文本。
## [br]
## @api private
func _make_key_text(key: Variant) -> String:
	if key == null:
		return ""
	var key_token: String = _GF_VARIANT_KEY_CODEC_SCRIPT.make_key_token(key)
	if not key_token.is_empty():
		return key_token
	return _GF_REPORT_VALUE_CODEC_SCRIPT.stringify_json_compatible(key, "", true)
