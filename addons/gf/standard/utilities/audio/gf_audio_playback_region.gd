## GFAudioPlaybackRegion: 类型化音频播放区间与循环点。
##
## 使用秒数描述播放起点、自然或显式终点以及循环模式。流准备始终复制源
## `AudioStream`，只在副本上写入 Godot 原生循环属性，并对无法精确表达的组合
## 返回 UNSUPPORTED，避免静默播放错误区间。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 11.0.0
class_name GFAudioPlaybackRegion
extends Resource


# --- 枚举 ---

## 音频循环模式。
## [br]
## @api public
## [br]
## @since 11.0.0
enum LoopMode {
	## 不循环。
	DISABLED,
	## 从循环起点正向循环到区间终点。
	FORWARD,
	## 在循环起点与区间终点之间往返循环。
	PING_PONG,
	## 从区间终点反向循环到循环起点。
	BACKWARD,
}


# --- 导出变量 ---

## 播放起点，单位为秒。
## [br]
## @api public
## [br]
## @since 11.0.0
@export_range(0.0, 86_400.0, 0.001, "or_greater") var start_seconds: float = 0.0

## 播放或循环终点，单位为秒；-1 表示音频流自然结尾。
## [br]
## @api public
## [br]
## @since 11.0.0
@export_range(-1.0, 86_400.0, 0.001, "or_greater") var end_seconds: float = -1.0

## 循环模式。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var loop_mode: LoopMode = LoopMode.DISABLED

## 循环起点，单位为秒；-1 表示使用 start_seconds。
## [br]
## @api public
## [br]
## @since 11.0.0
@export_range(-1.0, 86_400.0, 0.001, "or_greater") var loop_start_seconds: float = -1.0


# --- 公共方法 ---

## 验证区间结构并解析已知的自然结尾。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param stream_length_seconds: 音频流长度；-1 表示长度未知。
## [br]
## @return 验证结果；成功时状态为 VALID，字段包含规范化后的有效区间。
func validate(stream_length_seconds: float = -1.0) -> GFAudioPlaybackRegionResult:
	var result: GFAudioPlaybackRegionResult = _make_result(
		GFAudioPlaybackRegionResult.Status.VALID,
		&"valid",
		"Audio playback region is valid."
	)
	if not is_finite(stream_length_seconds):
		return _invalid(&"non_finite_stream_length", "Stream length must be finite.")
	if stream_length_seconds < 0.0 and stream_length_seconds != -1.0:
		return _invalid(&"invalid_stream_length", "Stream length must be -1 or non-negative.")
	if not is_finite(start_seconds):
		return _invalid(&"non_finite_start", "Playback start must be finite.")
	if start_seconds < 0.0:
		return _invalid(&"negative_start", "Playback start must be non-negative.")
	if not is_finite(end_seconds):
		return _invalid(&"non_finite_end", "Playback end must be finite.")
	if end_seconds < 0.0 and end_seconds != -1.0:
		return _invalid(&"invalid_end", "Playback end must be -1 or non-negative.")
	if not is_finite(loop_start_seconds):
		return _invalid(&"non_finite_loop_start", "Loop start must be finite.")
	if loop_start_seconds < 0.0 and loop_start_seconds != -1.0:
		return _invalid(&"invalid_loop_start", "Loop start must be -1 or non-negative.")
	if not _is_valid_loop_mode(loop_mode):
		return _invalid(&"invalid_loop_mode", "Loop mode is outside the supported enum range.")
	if loop_mode == LoopMode.DISABLED and loop_start_seconds != -1.0:
		return _invalid(&"loop_start_requires_loop", "Loop start requires an enabled loop mode.")

	var has_known_length: bool = stream_length_seconds >= 0.0
	var effective_end_seconds: float = end_seconds
	if end_seconds == -1.0 and has_known_length:
		effective_end_seconds = stream_length_seconds
	if has_known_length and start_seconds >= stream_length_seconds:
		return _invalid(&"start_not_before_stream_end", "Playback start must be before the stream end.")
	if end_seconds >= 0.0:
		if end_seconds <= start_seconds:
			return _invalid(&"end_not_after_start", "Playback end must be after playback start.")
		if has_known_length and end_seconds > stream_length_seconds:
			return _invalid(&"end_exceeds_stream", "Playback end exceeds the stream length.")
	if has_known_length and effective_end_seconds <= start_seconds:
		return _invalid(&"empty_region", "Playback region must contain positive duration.")

	var effective_loop_start_seconds: float = -1.0
	if loop_mode != LoopMode.DISABLED:
		effective_loop_start_seconds = (
			start_seconds
			if loop_start_seconds == -1.0
			else loop_start_seconds
		)
		if effective_loop_start_seconds < start_seconds:
			return _invalid(&"loop_start_before_region", "Loop start must not precede playback start.")
		if effective_end_seconds >= 0.0 and effective_loop_start_seconds >= effective_end_seconds:
			return _invalid(&"loop_start_not_before_end", "Loop start must be before the effective end.")

	result.start_seconds = start_seconds
	result.end_seconds = effective_end_seconds
	result.loop_start_seconds = effective_loop_start_seconds
	result.loop_mode = loop_mode
	return result


## 为当前音频流准备 session 私有副本。
##
## WAV 支持帧级 forward / ping-pong 循环点；IMA ADPCM WAV 仅接受从
## 0 秒开始的正向循环。Godot 原生 backward 无法保持本契约的初始播放位置，
## 因此本地路径显式返回 UNSUPPORTED。
## Ogg Vorbis 与 MP3 仅接受正向循环到自然结尾；AudioStreamPlaylist 仅接受
## 全流正向循环。其他流必须由显式后端能力协议处理。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param stream: 要准备的源音频流；不会被修改。
## [br]
## @return 流准备结果；成功时状态为 APPLIED 且包含 session 私有副本。
func prepare_stream(stream: AudioStream) -> GFAudioPlaybackRegionResult:
	if stream == null:
		return _invalid(&"stream_required", "Audio stream is required.")

	var known_length_seconds: float = _get_known_stream_length(stream)
	var validation: GFAudioPlaybackRegionResult = validate(known_length_seconds)
	if not validation.is_success():
		return validation
	if loop_mode == LoopMode.DISABLED and end_seconds >= 0.0:
		return _unsupported(
			&"bounded_end_unsupported",
			"Playback without looping requires the -1 natural-end sentinel.",
			validation
		)

	var support_issue: GFAudioPlaybackRegionResult = _check_stream_support(
		stream,
		known_length_seconds,
		validation
	)
	if support_issue != null:
		return support_issue

	var duplicated_resource: Resource = _duplicate_stream(stream)
	if duplicated_resource == stream or not (duplicated_resource is AudioStream):
		return _unsupported(
			&"stream_duplicate_failed",
			"Audio stream did not produce a usable private duplicate.",
			validation
		)
	var prepared_audio_stream: AudioStream = duplicated_resource
	var applied: GFAudioPlaybackRegionResult = _make_result(
		GFAudioPlaybackRegionResult.Status.APPLIED,
		&"stream_prepared",
		"Audio playback region was applied to a private stream duplicate."
	)
	_copy_effective_fields(validation, applied)
	applied.prepared_stream = prepared_audio_stream

	if prepared_audio_stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = prepared_audio_stream
		_apply_wav(wav_stream, applied)
	elif prepared_audio_stream is AudioStreamOggVorbis:
		var ogg_stream: AudioStreamOggVorbis = prepared_audio_stream
		ogg_stream.loop = loop_mode == LoopMode.FORWARD
		if loop_mode == LoopMode.FORWARD:
			ogg_stream.loop_offset = applied.loop_start_seconds
			ogg_stream.beat_count = 0
	elif prepared_audio_stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = prepared_audio_stream
		mp3_stream.loop = loop_mode == LoopMode.FORWARD
		if loop_mode == LoopMode.FORWARD:
			mp3_stream.loop_offset = applied.loop_start_seconds
			mp3_stream.beat_count = 0
	elif prepared_audio_stream is AudioStreamPlaylist:
		var playlist_stream: AudioStreamPlaylist = prepared_audio_stream
		playlist_stream.loop = loop_mode == LoopMode.FORWARD
	return applied


## 创建相同字段的独立区间资源。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 独立的播放区间资源。
func duplicate_region() -> GFAudioPlaybackRegion:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = start_seconds
	region.end_seconds = end_seconds
	region.loop_mode = loop_mode
	region.loop_start_seconds = loop_start_seconds
	return region


## 转换为字典。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 播放区间字典。
## [br]
## @schema return: Dictionary with start_seconds, end_seconds, loop_mode, and loop_start_seconds fields.
func to_dictionary() -> Dictionary:
	return {
		"start_seconds": start_seconds,
		"end_seconds": end_seconds,
		"loop_mode": loop_mode,
		"loop_start_seconds": loop_start_seconds,
	}


# --- 私有/辅助方法 ---

func _check_stream_support(
	stream: AudioStream,
	known_length_seconds: float,
	validation: GFAudioPlaybackRegionResult
) -> GFAudioPlaybackRegionResult:
	if stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = stream
		if loop_mode == LoopMode.BACKWARD:
			return _unsupported(
				&"wav_backward_start_unsupported",
				"Godot WAV backward looping cannot preserve the requested initial playback position.",
				validation
			)
		if wav_stream.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
			if validation.start_seconds != 0.0:
				return _unsupported(
					&"ima_adpcm_start_unsupported",
					"IMA ADPCM WAV playback regions must start at 0 seconds.",
					validation
				)
			if loop_mode != LoopMode.DISABLED and loop_mode != LoopMode.FORWARD:
				return _unsupported(
					&"ima_adpcm_loop_mode_unsupported",
					"IMA ADPCM WAV supports only forward looping.",
					validation
				)
		if loop_mode != LoopMode.DISABLED:
			if wav_stream.mix_rate <= 0 or known_length_seconds < 0.0:
				return _unsupported(
					&"wav_loop_bounds_unavailable",
					"WAV looping requires a positive mix rate and known stream length.",
					validation
				)
		if wav_stream.mix_rate > 0 and validation.end_seconds >= 0.0:
			var sample_count: int = roundi(
				known_length_seconds * float(wav_stream.mix_rate)
			)
			var start_frame: int = roundi(
				validation.start_seconds * float(wav_stream.mix_rate)
			)
			var end_boundary_frame: int = mini(
				roundi(validation.end_seconds * float(wav_stream.mix_rate)),
				sample_count
			)
			if sample_count <= 0 or start_frame >= end_boundary_frame:
				return _unsupported(
					&"wav_quantized_region_empty",
					"WAV frame quantization would collapse the playback region.",
					validation
				)
			if loop_mode != LoopMode.DISABLED:
				var loop_start_frame: int = roundi(
					validation.loop_start_seconds * float(wav_stream.mix_rate)
				)
				var loop_end_frame: int = end_boundary_frame - 1
				if (
					loop_start_frame < 0
					or loop_start_frame > loop_end_frame
					or loop_end_frame >= sample_count
				):
					return _unsupported(
						&"wav_quantized_loop_empty",
						"WAV frame quantization would collapse the loop interval.",
						validation
					)
		return null

	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		if loop_mode != LoopMode.DISABLED and loop_mode != LoopMode.FORWARD:
			return _unsupported(
				&"compressed_loop_mode_unsupported",
				"Ogg Vorbis and MP3 support only forward playback-region looping.",
				validation
			)
		if loop_mode == LoopMode.FORWARD and not _uses_natural_end():
			return _unsupported(
				&"compressed_loop_end_unsupported",
				"Ogg Vorbis and MP3 loops must continue to the natural stream end.",
				validation
			)
		return null

	if stream is AudioStreamPlaylist:
		if loop_mode == LoopMode.DISABLED:
			if _is_full_stream_region(validation):
				return null
			return _unsupported(
				&"playlist_region_unsupported",
				"AudioStreamPlaylist supports only full-stream playback regions.",
				validation
			)
		if (
			loop_mode != LoopMode.FORWARD
			or validation.start_seconds != 0.0
			or validation.loop_start_seconds != 0.0
			or not _uses_natural_end()
		):
			return _unsupported(
				&"playlist_loop_unsupported",
				"AudioStreamPlaylist supports only full-stream forward looping.",
				validation
			)
		return null

	return _unsupported(
		&"stream_type_unsupported",
		"Audio stream type requires an explicit backend playback-region contract.",
		validation
	)


func _get_known_stream_length(stream: AudioStream) -> float:
	if stream is AudioStreamOggVorbis:
		var ogg_stream: AudioStreamOggVorbis = stream
		if ogg_stream.packet_sequence == null:
			return -1.0
	elif stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = stream
		if mp3_stream.data.is_empty():
			return -1.0
	var reported_length_seconds: float = stream.get_length()
	if not is_finite(reported_length_seconds) or reported_length_seconds <= 0.0:
		return -1.0
	return reported_length_seconds


func _duplicate_stream(stream: AudioStream) -> Resource:
	return stream.duplicate()


func _apply_wav(stream: AudioStreamWAV, applied: GFAudioPlaybackRegionResult) -> void:
	if loop_mode == LoopMode.DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		applied.loop_start_seconds = -1.0
		if stream.mix_rate <= 0:
			return
		applied.start_seconds = float(roundi(applied.start_seconds * float(stream.mix_rate))) / float(stream.mix_rate)
		if applied.end_seconds >= 0.0:
			var disabled_end_frame: int = roundi(applied.end_seconds * float(stream.mix_rate))
			applied.end_seconds = float(disabled_end_frame) / float(stream.mix_rate)
		return
	if stream.mix_rate <= 0:
		return
	var mix_rate: float = float(stream.mix_rate)
	applied.start_seconds = float(roundi(applied.start_seconds * mix_rate)) / mix_rate
	var sample_count: int = roundi(stream.get_length() * mix_rate)
	var end_boundary_frame: int = mini(
		roundi(applied.end_seconds * mix_rate),
		sample_count
	)
	applied.end_seconds = float(end_boundary_frame) / mix_rate

	var loop_start_frame: int = roundi(applied.loop_start_seconds * mix_rate)
	var loop_end_frame: int = end_boundary_frame - 1
	stream.loop_begin = loop_start_frame
	stream.loop_end = loop_end_frame
	applied.loop_start_seconds = float(loop_start_frame) / mix_rate
	match loop_mode:
		LoopMode.FORWARD:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		LoopMode.PING_PONG:
			stream.loop_mode = AudioStreamWAV.LOOP_PINGPONG


func _uses_natural_end() -> bool:
	return end_seconds == -1.0


func _is_full_stream_region(validation: GFAudioPlaybackRegionResult) -> bool:
	return (
		loop_mode == LoopMode.DISABLED
		and validation.start_seconds == 0.0
		and _uses_natural_end()
	)


func _is_valid_loop_mode(value: int) -> bool:
	return (
		value == LoopMode.DISABLED
		or value == LoopMode.FORWARD
		or value == LoopMode.PING_PONG
		or value == LoopMode.BACKWARD
	)


func _invalid(reason_id: StringName, result_message: String) -> GFAudioPlaybackRegionResult:
	return _make_result(GFAudioPlaybackRegionResult.Status.INVALID, reason_id, result_message)


func _unsupported(
	reason_id: StringName,
	result_message: String,
	source: GFAudioPlaybackRegionResult
) -> GFAudioPlaybackRegionResult:
	var result: GFAudioPlaybackRegionResult = _make_result(
		GFAudioPlaybackRegionResult.Status.UNSUPPORTED,
		reason_id,
		result_message
	)
	_copy_effective_fields(source, result)
	return result


func _make_result(
	result_status: GFAudioPlaybackRegionResult.Status,
	reason_id: StringName,
	result_message: String
) -> GFAudioPlaybackRegionResult:
	var result: GFAudioPlaybackRegionResult = GFAudioPlaybackRegionResult.new()
	result.status = result_status
	result.reason = reason_id
	result.message = result_message
	result.start_seconds = start_seconds
	result.end_seconds = end_seconds
	result.loop_start_seconds = loop_start_seconds
	result.loop_mode = loop_mode
	return result


func _copy_effective_fields(
	source: GFAudioPlaybackRegionResult,
	target: GFAudioPlaybackRegionResult
) -> void:
	target.start_seconds = source.start_seconds
	target.end_seconds = source.end_seconds
	target.loop_start_seconds = source.loop_start_seconds
	target.loop_mode = source.loop_mode
