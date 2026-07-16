## GFAudioBank: 音频片段配置集合。
##
## 用 StringName 管理一组 `GFAudioClip`，便于 UI、表现动作或项目配置
## 通过稳定 ID 播放音频。单个 ID 可保存一个片段或多个候选片段。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFAudioBank
extends Resource


# --- 枚举 ---

## 音频集合加载状态。
## [br]
## @api public
enum LifecycleState {
	## 尚未加载。
	UNLOADED,
	## 正在加载。
	LOADING,
	## 已加载。
	LOADED,
	## 加载失败。
	FAILED,
}


# --- 导出变量 ---

## 音频片段表。
## [br]
## @api public
## [br]
## @schema clips: Key 为 StringName 片段 ID，Value 为 GFAudioClip 或 GFAudioClip 数组。
@export var clips: Dictionary = {}

## 分层事件 ID 的回退分隔符。例如 `ui+confirm+primary` 可回退到 `ui+confirm` 再到 `ui`。
## [br]
## @api public
@export var fallback_separator: String = "+"

## 加载状态。框架只记录状态，不假设具体加载后端。
## [br]
## @api public
@export var lifecycle_state: LifecycleState = LifecycleState.UNLOADED

## 最近一次加载或卸载结果原因。
## [br]
## @api public
@export var lifecycle_reason: StringName = &""


# --- 公共方法 ---

## 设置一个音频片段。
## [br]
## @api public
## [br]
## @param clip_id: 片段标识。
## [br]
## @param clip: 片段配置。
func set_clip(clip_id: StringName, clip: GFAudioClip) -> void:
	if clip_id == &"":
		push_error("[GFAudioBank] set_clip 失败：clip_id 为空。")
		return
	if clip == null:
		var _erased: bool = clips.erase(clip_id)
		return
	clips[clip_id] = clip


## 设置一个音频片段候选列表。
## [br]
## @api public
## [br]
## @param clip_id: 片段标识。
## [br]
## @param clip_list: 片段候选列表。
## [br]
## @schema clip_list: GFAudioClip 候选数组。
func set_clips(clip_id: StringName, clip_list: Array[GFAudioClip]) -> void:
	if clip_id == &"":
		push_error("[GFAudioBank] set_clips 失败：clip_id 为空。")
		return

	var valid_clips: Array[GFAudioClip] = []
	for clip: GFAudioClip in clip_list:
		if clip != null:
			valid_clips.append(clip)
	if valid_clips.is_empty():
		var _erased: bool = clips.erase(clip_id)
		return
	clips[clip_id] = valid_clips


## 获取音频片段。
## [br]
## @api public
## [br]
## @param clip_id: 片段标识。
## [br]
## @return: 片段配置；多个候选时返回第一个有效片段，不存在时返回 null。
func get_clip(clip_id: StringName) -> GFAudioClip:
	var clip_list: Array[GFAudioClip] = get_clips(clip_id)
	if clip_list.is_empty():
		return null
	return clip_list[0]


## 获取音频片段候选列表。
## [br]
## @api public
## [br]
## @param clip_id: 片段标识。
## [br]
## @return: 片段候选列表。
## [br]
## @schema return: GFAudioClip 候选数组。
func get_clips(clip_id: StringName) -> Array[GFAudioClip]:
	var result: Array[GFAudioClip] = []
	var raw_value: Variant = GFVariantData.get_option_value(clips, clip_id)
	if raw_value is GFAudioClip:
		result.append(_variant_to_audio_clip(raw_value))
	elif raw_value is Array:
		var clip_values: Array = GFVariantData.as_array(raw_value)
		for clip_variant: Variant in clip_values:
			if clip_variant is GFAudioClip:
				result.append(_variant_to_audio_clip(clip_variant))
	return result


## 按候选权重获取片段。
## [br]
## @api public
## [br]
## @param clip_id: 片段标识。
## [br]
## @param rng: 可选随机数生成器；为空时返回第一个有效片段。
## [br]
## @return: 片段配置；不存在时返回 null。
func get_weighted_clip(clip_id: StringName, rng: RandomNumberGenerator = null) -> GFAudioClip:
	var clip_list: Array[GFAudioClip] = get_clips(clip_id)
	if clip_list.is_empty():
		return null
	if rng == null or clip_list.size() == 1:
		return clip_list[0]

	var total_weight: float = 0.0
	for clip: GFAudioClip in clip_list:
		total_weight += maxf(clip.weight, 0.0)
	if total_weight <= 0.0:
		return clip_list[0]

	var cursor: float = rng.randf_range(0.0, total_weight)
	for clip: GFAudioClip in clip_list:
		cursor -= maxf(clip.weight, 0.0)
		if cursor <= 0.0:
			return clip
	return clip_list[clip_list.size() - 1]


## 按 ID 获取片段；找不到时按 fallback_separator 逐级回退。
## [br]
## @api public
## [br]
## @param clip_id: 片段标识。
## [br]
## @param rng: 可选随机数生成器。
## [br]
## @return: 片段配置；不存在时返回 null。
func get_clip_with_fallback(clip_id: StringName, rng: RandomNumberGenerator = null) -> GFAudioClip:
	var resolution: Dictionary = resolve_clip(clip_id, rng)
	return _variant_to_audio_clip(GFVariantData.get_option_value(resolution, "clip"))


## 解析片段并返回诊断报告。
## [br]
## @api public
## [br]
## @param clip_id: 片段标识。
## [br]
## @param rng: 可选随机数生成器。
## [br]
## @return: 解析报告。
## [br]
## @schema return: Dictionary，包含 ok、requested_id、resolved_id、fallback_used、attempted_ids 和 clip 字段。
func resolve_clip(clip_id: StringName, rng: RandomNumberGenerator = null) -> Dictionary:
	var attempted_ids: PackedStringArray = PackedStringArray()
	if clip_id == &"":
		return _make_resolution_report(false, clip_id, &"", false, attempted_ids, null)

	_append_packed_string(attempted_ids, String(clip_id))
	var clip: GFAudioClip = get_weighted_clip(clip_id, rng)
	if clip != null:
		return _make_resolution_report(true, clip_id, clip_id, false, attempted_ids, clip)

	var separator: String = fallback_separator
	if separator.is_empty():
		return _make_resolution_report(false, clip_id, &"", false, attempted_ids, null)

	var parts: PackedStringArray = String(clip_id).split(separator, false)
	while parts.size() > 1:
		parts.remove_at(parts.size() - 1)
		var fallback_id: StringName = StringName(separator.join(parts))
		_append_packed_string(attempted_ids, String(fallback_id))
		clip = get_weighted_clip(fallback_id, rng)
		if clip != null:
			return _make_resolution_report(true, clip_id, fallback_id, true, attempted_ids, clip)
	return _make_resolution_report(false, clip_id, &"", false, attempted_ids, null)


## 把 resolve_clip() 的原始报告转换为 JSON-safe 诊断报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: resolve_clip() 返回的原始报告。
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return JSON-safe 解析报告。
## [br]
## @schema report: Dictionary，包含 ok、requested_id、resolved_id、fallback_used、attempted_ids 和 clip 字段。
## [br]
## @schema options: Dictionary with GFReportValueCodec options.
## [br]
## @schema return: Dictionary，clip 会转换为脱敏 marker，不直接暴露 GFAudioClip 资源实例。
func to_json_compatible_resolution_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
	var codec_options: Dictionary = options.duplicate(true)
	return GFVariantData.as_dictionary(GFReportValueCodec.to_json_compatible(report, codec_options))


## 检查是否存在指定片段。
## [br]
## @api public
## [br]
## @param clip_id: 片段标识。
## [br]
## @return: 存在时返回 true。
func has_clip(clip_id: StringName) -> bool:
	return not get_clips(clip_id).is_empty()


## 获取全部片段 ID。
## [br]
## @api public
## [br]
## @return: 按字典序排列的片段 ID。
func get_clip_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in clips.keys():
		_append_packed_string(result, GFVariantData.to_text(key))
	result.sort()
	return result


## 设置音频集合加载状态。
## [br]
## @api public
## [br]
## @param state: 新状态。
## [br]
## @param reason: 可选原因。
func set_lifecycle_state(state: LifecycleState, reason: StringName = &"") -> void:
	lifecycle_state = state
	lifecycle_reason = reason


## 获取加载状态快照。
## [br]
## @api public
## [br]
## @return: 状态快照字典。
## [br]
## @schema return: Dictionary，包含 state、reason 和 clip_count 字段。
func get_lifecycle_snapshot() -> Dictionary:
	return {
		"state": lifecycle_state,
		"reason": lifecycle_reason,
		"clip_count": clips.size(),
	}


## 校验音频集合。
## [br]
## @api public
## [br]
## @param check_resource_exists: 是否检查 path 指向的资源存在。
## [br]
## @return: 校验报告。
func validate_bank(check_resource_exists: bool = false) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new("GFAudioBank")
	report.metadata["clip_count"] = clips.size()
	for key: Variant in clips.keys():
		var clip_id: StringName = GFVariantData.to_string_name(key)
		if clip_id == &"":
			var _add_error_result_280: Variant = report.add_error(&"empty_clip_id", "Audio clip id is empty.", key)
			continue

		var raw_value: Variant = clips[key]
		if raw_value is GFAudioClip:
			_validate_clip(report, clip_id, _variant_to_audio_clip(raw_value), check_resource_exists)
		elif raw_value is Array:
			var clip_list: Array = GFVariantData.as_array(raw_value)
			if clip_list.is_empty():
				var _add_warning_result_289: Variant = report.add_warning(&"empty_clip_list", "Audio clip candidate list is empty.", clip_id)
			for index: int in range(clip_list.size()):
				var clip: GFAudioClip = _variant_to_audio_clip(clip_list[index])
				if clip == null:
					var _add_error_result_293: Variant = report.add_error(&"invalid_clip_candidate", "Audio clip candidate is not GFAudioClip.", clip_id, "", {
						"index": index,
					})
					continue
				_validate_clip(report, clip_id, clip, check_resource_exists, index)
		else:
			var _add_error_result_299: Variant = report.add_error(&"invalid_clip_value", "Audio clip value must be GFAudioClip or Array[GFAudioClip].", clip_id)
	return report


# --- 私有/辅助方法 ---

func _make_resolution_report(
	ok: bool,
	requested_id: StringName,
	resolved_id: StringName,
	fallback_used: bool,
	attempted_ids: PackedStringArray,
	clip: GFAudioClip
) -> Dictionary:
	return {
		"ok": ok,
		"requested_id": requested_id,
		"resolved_id": resolved_id,
		"fallback_used": fallback_used,
		"attempted_ids": attempted_ids,
		"clip": clip,
	}


func _validate_clip(
	report: GFValidationReport,
	clip_id: StringName,
	clip: GFAudioClip,
	check_resource_exists: bool,
	index: int = -1
) -> void:
	var metadata: Dictionary = {}
	if index >= 0:
		metadata["index"] = index
	if not clip.has_source():
		var _add_warning_result_334: Variant = report.add_warning(&"missing_audio_source", "Audio clip has no stream or path.", clip_id, "", metadata)
		return
	if check_resource_exists and clip.stream == null and not ResourceLoader.exists(clip.path, "AudioStream"):
		var _add_warning_result_337: Variant = report.add_warning(&"missing_audio_resource", "Audio clip path does not resolve to AudioStream.", clip_id, clip.path, metadata)


func _variant_to_audio_clip(value: Variant) -> GFAudioClip:
	if value is GFAudioClip:
		var clip: GFAudioClip = value
		return clip
	return null


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
