extends GutTest


func test_default_region_validates_without_claiming_application() -> void:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()

	var result: GFAudioPlaybackRegionResult = region.validate()

	assert_true(result.is_success())
	assert_false(result.is_applied())
	assert_eq(result.status, GFAudioPlaybackRegionResult.Status.VALID)
	assert_eq(result.reason, &"valid")
	assert_almost_eq(result.start_seconds, 0.0, 0.0001)
	assert_almost_eq(result.end_seconds, -1.0, 0.0001)
	assert_almost_eq(result.loop_start_seconds, -1.0, 0.0001)
	assert_eq(result.loop_mode, GFAudioPlaybackRegion.LoopMode.DISABLED)


func test_validate_resolves_natural_end_and_default_loop_start() -> void:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.25
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD

	var result: GFAudioPlaybackRegionResult = region.validate(2.0)

	assert_true(result.is_success())
	assert_almost_eq(result.start_seconds, 0.25, 0.0001)
	assert_almost_eq(result.end_seconds, 2.0, 0.0001)
	assert_almost_eq(result.loop_start_seconds, 0.25, 0.0001)
	assert_eq(result.loop_mode, GFAudioPlaybackRegion.LoopMode.FORWARD)


func test_validate_rejects_non_finite_and_invalid_boundaries() -> void:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = NAN
	assert_eq(region.validate(2.0).reason, &"non_finite_start")

	region.start_seconds = 0.5
	region.end_seconds = INF
	assert_eq(region.validate(2.0).reason, &"non_finite_end")

	region.end_seconds = 0.5
	assert_eq(region.validate(2.0).reason, &"end_not_after_start")

	region.end_seconds = 2.5
	assert_eq(region.validate(2.0).reason, &"end_exceeds_stream")

	region.end_seconds = -1.0
	region.loop_start_seconds = 0.75
	assert_eq(region.validate(2.0).reason, &"loop_start_requires_loop")

	region.loop_start_seconds = -1.0
	region.end_seconds = -0.999_999
	assert_eq(region.validate(2.0).reason, &"invalid_end", "自然结尾只接受精确 -1 哨兵。")

	region.end_seconds = 2.000_001
	assert_eq(region.validate(2.0).reason, &"end_exceeds_stream", "显式终点不得靠近似比较越过流长度。")

	region.end_seconds = -1.0
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	region.loop_start_seconds = -0.999_999
	assert_eq(region.validate(2.0).reason, &"invalid_loop_start", "默认循环起点只接受精确 -1 哨兵。")


func test_validate_rejects_loop_outside_region() -> void:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.5
	region.end_seconds = 1.5
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	region.loop_start_seconds = 0.25
	assert_eq(region.validate(2.0).reason, &"loop_start_before_region")

	region.loop_start_seconds = 1.5
	assert_eq(region.validate(2.0).reason, &"loop_start_not_before_end")


func test_duplicate_region_and_dictionary_do_not_alias_fields() -> void:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.25
	region.end_seconds = 1.5
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.BACKWARD
	region.loop_start_seconds = 0.5

	var duplicated: GFAudioPlaybackRegion = region.duplicate_region()
	duplicated.start_seconds = 0.75
	var snapshot: Dictionary = region.to_dictionary()

	assert_not_same(duplicated, region)
	assert_almost_eq(region.start_seconds, 0.25, 0.0001)
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "end_seconds"), 1.5, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(snapshot, "loop_mode"),
		GFAudioPlaybackRegion.LoopMode.BACKWARD
	)
	assert_almost_eq(
		GFVariantData.get_option_float(snapshot, "loop_start_seconds"),
		0.5,
		0.0001
	)


func test_prepare_wav_applies_rounded_loop_points_to_private_copy() -> void:
	var source: AudioStreamWAV = _make_wav(2.0, 1_000)
	source.loop_mode = AudioStreamWAV.LOOP_DISABLED
	source.loop_begin = 7
	source.loop_end = 11
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.2514
	region.end_seconds = 1.7506
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.PING_PONG
	region.loop_start_seconds = 0.5006

	var result: GFAudioPlaybackRegionResult = region.prepare_stream(source)

	assert_true(result.is_applied())
	assert_true(result.prepared_stream is AudioStreamWAV)
	var prepared: AudioStreamWAV = result.prepared_stream
	assert_not_same(prepared, source)
	assert_eq(prepared.loop_mode, AudioStreamWAV.LOOP_PINGPONG)
	assert_eq(prepared.loop_begin, 501)
	assert_eq(prepared.loop_end, 1_750, "WAV 原生 loop_end 必须是最后一个有效帧索引。")
	assert_almost_eq(result.start_seconds, 0.251, 0.0001)
	assert_almost_eq(result.loop_start_seconds, 0.501, 0.0001)
	assert_almost_eq(result.end_seconds, 1.751, 0.0001)
	assert_eq(source.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_eq(source.loop_begin, 7)
	assert_eq(source.loop_end, 11)


func test_prepare_wav_natural_end_uses_last_valid_frame_for_unaligned_length() -> void:
	var source: AudioStreamWAV = _make_wav(0.13, 1_000)
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD

	var result: GFAudioPlaybackRegionResult = region.prepare_stream(source)

	assert_true(result.is_applied())
	var prepared: AudioStreamWAV = result.prepared_stream
	assert_eq(prepared.loop_begin, 0)
	assert_eq(prepared.loop_end, 129, "130 帧流的末点必须保持在有效索引 0..129 内。")
	assert_almost_eq(result.end_seconds, 0.13, 0.0001)


func test_prepare_disabled_wav_does_not_mutate_shared_loop_state() -> void:
	var source: AudioStreamWAV = _make_wav(1.0, 1_000)
	source.loop_mode = AudioStreamWAV.LOOP_FORWARD
	source.loop_begin = 100
	source.loop_end = 900
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()

	var result: GFAudioPlaybackRegionResult = region.prepare_stream(source)

	assert_true(result.is_applied())
	assert_true(result.prepared_stream is AudioStreamWAV)
	var prepared: AudioStreamWAV = result.prepared_stream
	assert_not_same(prepared, source)
	assert_eq(prepared.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_eq(source.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(source.loop_begin, 100)
	assert_eq(source.loop_end, 900)


func test_prepare_disabled_region_rejects_bounded_non_natural_end() -> void:
	var source: AudioStreamWAV = _make_wav(2.0, 1_000)
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.end_seconds = 1.0

	var result: GFAudioPlaybackRegionResult = region.prepare_stream(source)

	assert_eq(result.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(result.reason, &"bounded_end_unsupported")
	assert_null(result.prepared_stream)


func test_prepare_wav_rejects_regions_collapsed_by_frame_quantization() -> void:
	var source: AudioStreamWAV = _make_wav(1.0, 10)
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.96

	var empty_region: GFAudioPlaybackRegionResult = region.prepare_stream(source)

	assert_eq(empty_region.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(empty_region.reason, &"wav_quantized_region_empty")
	assert_null(empty_region.prepared_stream)

	region.start_seconds = 0.0
	region.end_seconds = 0.14
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	region.loop_start_seconds = 0.11
	var empty_loop: GFAudioPlaybackRegionResult = region.prepare_stream(source)
	assert_eq(empty_loop.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(empty_loop.reason, &"wav_quantized_loop_empty")
	assert_null(empty_loop.prepared_stream)


func test_prepare_ima_adpcm_rejects_nonzero_start_and_non_forward_loop() -> void:
	var source: AudioStreamWAV = _make_wav(1.0, 1_000, AudioStreamWAV.FORMAT_IMA_ADPCM)
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1

	var start_result: GFAudioPlaybackRegionResult = region.prepare_stream(source)

	assert_eq(start_result.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(start_result.reason, &"ima_adpcm_start_unsupported")

	region.start_seconds = 0.0
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.PING_PONG
	var mode_result: GFAudioPlaybackRegionResult = region.prepare_stream(source)
	assert_eq(mode_result.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(mode_result.reason, &"ima_adpcm_loop_mode_unsupported")


func test_prepare_wav_rejects_backward_when_initial_position_cannot_be_preserved() -> void:
	var source: AudioStreamWAV = _make_wav(1.0, 1_000)
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.2
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.BACKWARD

	var result: GFAudioPlaybackRegionResult = region.prepare_stream(source)

	assert_eq(result.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(result.reason, &"wav_backward_start_unsupported")
	assert_null(result.prepared_stream)


func test_prepare_ogg_and_mp3_clear_beat_count_on_private_forward_loop() -> void:
	var ogg_stream: AudioStreamOggVorbis = AudioStreamOggVorbis.new()
	var mp3_stream: AudioStreamMP3 = AudioStreamMP3.new()
	ogg_stream.bpm = 120.0
	ogg_stream.beat_count = 8
	mp3_stream.bpm = 90.0
	mp3_stream.beat_count = 6
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	region.loop_start_seconds = 0.25

	var ogg_result: GFAudioPlaybackRegionResult = region.prepare_stream(ogg_stream)
	assert_true(ogg_result.is_applied())
	assert_not_same(ogg_result.prepared_stream, ogg_stream)
	var prepared_ogg: AudioStreamOggVorbis = ogg_result.prepared_stream
	assert_true(prepared_ogg.loop)
	assert_almost_eq(prepared_ogg.loop_offset, 0.25, 0.0001)
	assert_eq(prepared_ogg.beat_count, 0, "节拍元数据不得缩短类型化自然结尾循环。")
	assert_eq(ogg_stream.beat_count, 8, "源 Ogg 不得被修改。")

	var mp3_region: SafeMP3DuplicateRegion = SafeMP3DuplicateRegion.new()
	mp3_region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	mp3_region.loop_start_seconds = 0.25
	var mp3_result: GFAudioPlaybackRegionResult = mp3_region.prepare_stream(mp3_stream)
	assert_true(mp3_result.is_applied())
	assert_not_same(mp3_result.prepared_stream, mp3_stream)
	var prepared_mp3: AudioStreamMP3 = mp3_result.prepared_stream
	assert_true(prepared_mp3.loop)
	assert_almost_eq(prepared_mp3.loop_offset, 0.25, 0.0001)
	assert_eq(prepared_mp3.beat_count, 0, "节拍元数据不得缩短类型化自然结尾循环。")
	assert_eq(mp3_stream.beat_count, 6, "源 MP3 不得被修改。")


func test_prepare_ogg_and_mp3_reject_non_forward_or_bounded_loops() -> void:
	for source: AudioStream in [AudioStreamOggVorbis.new(), AudioStreamMP3.new()]:
		var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
		region.loop_mode = GFAudioPlaybackRegion.LoopMode.PING_PONG
		var unsupported_mode: GFAudioPlaybackRegionResult = region.prepare_stream(source)
		assert_eq(unsupported_mode.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
		assert_eq(unsupported_mode.reason, &"compressed_loop_mode_unsupported")

		region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
		region.end_seconds = 1.0
		var unsupported_end: GFAudioPlaybackRegionResult = region.prepare_stream(source)
		assert_eq(unsupported_end.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
		assert_eq(unsupported_end.reason, &"compressed_loop_end_unsupported")


func test_prepare_playlist_supports_only_full_stream_forward_loop() -> void:
	var source: AudioStreamPlaylist = AudioStreamPlaylist.new()
	source.loop = false
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD

	var applied: GFAudioPlaybackRegionResult = region.prepare_stream(source)

	assert_true(applied.is_applied())
	assert_true(applied.prepared_stream is AudioStreamPlaylist)
	var prepared: AudioStreamPlaylist = applied.prepared_stream
	assert_true(prepared.loop)
	assert_false(source.loop)

	region.start_seconds = 0.25
	var unsupported: GFAudioPlaybackRegionResult = region.prepare_stream(source)
	assert_eq(unsupported.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(unsupported.reason, &"playlist_loop_unsupported")


func test_prepare_unknown_stream_requires_explicit_backend_contract() -> void:
	var source: AudioStreamGenerator = AudioStreamGenerator.new()
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()

	var default_result: GFAudioPlaybackRegionResult = region.prepare_stream(source)
	assert_eq(default_result.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(default_result.reason, &"stream_type_unsupported")
	assert_null(default_result.prepared_stream)

	region.start_seconds = 0.25
	var unsupported: GFAudioPlaybackRegionResult = region.prepare_stream(source)
	assert_eq(unsupported.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(unsupported.reason, &"stream_type_unsupported")
	assert_null(unsupported.prepared_stream)


func test_prepare_rejects_duplicate_that_aliases_source() -> void:
	var source: AudioStreamWAV = _make_wav(1.0, 1_000)
	var region: SameDuplicateRegion = SameDuplicateRegion.new()

	var result: GFAudioPlaybackRegionResult = region.prepare_stream(source)

	assert_eq(result.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(result.reason, &"stream_duplicate_failed")
	assert_null(result.prepared_stream)


func test_result_factory_and_dictionary_exclude_stream_payload() -> void:
	var pending_result: GFAudioPlaybackRegionResult = GFAudioPlaybackRegionResult.new()
	assert_false(pending_result.is_success(), "NONE 只表示尚未执行，不能被当作成功。")
	assert_eq(
		GFAudioPlaybackRegionResult.status_to_string(GFAudioPlaybackRegionResult.Status.VALID),
		&"valid"
	)

	var unsupported: GFAudioPlaybackRegionResult = GFAudioPlaybackRegionResult.unsupported(
		&"backend_region_unsupported",
		"Backend cannot apply the requested region."
	)
	assert_eq(unsupported.status, GFAudioPlaybackRegionResult.Status.UNSUPPORTED)
	assert_eq(unsupported.reason, &"backend_region_unsupported")
	assert_false(unsupported.is_success())

	var source: AudioStreamWAV = _make_wav(1.0, 1_000)
	var result: GFAudioPlaybackRegionResult = GFAudioPlaybackRegion.new().prepare_stream(source)
	var snapshot: Dictionary = result.to_dictionary()

	assert_eq(GFVariantData.get_option_string(snapshot, "status"), "applied")
	assert_true(GFVariantData.get_option_bool(snapshot, "success"))
	assert_true(GFVariantData.get_option_bool(snapshot, "applied"))
	assert_true(GFVariantData.get_option_bool(snapshot, "has_prepared_stream"))
	assert_false(snapshot.has("prepared_stream"))


func test_result_normalizes_untrusted_reason_identifiers() -> void:
	var result: GFAudioPlaybackRegionResult = GFAudioPlaybackRegionResult.new()

	result.reason = &"backend.region-unsupported_2"
	assert_eq(result.reason, &"backend.region-unsupported_2")

	result.reason = StringName("backend payload\nsecret")
	assert_eq(result.reason, &"invalid_reason")

	result.reason = StringName("a".repeat(129))
	assert_eq(result.reason, &"invalid_reason")


func _make_wav(
	duration_seconds: float,
	mix_rate: int,
	format: AudioStreamWAV.Format = AudioStreamWAV.FORMAT_8_BITS
) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = format
	stream.mix_rate = mix_rate
	stream.stereo = false
	var bytes_per_sample: int = 1
	if format == AudioStreamWAV.FORMAT_16_BITS:
		bytes_per_sample = 2
	var sample_bytes: PackedByteArray = PackedByteArray()
	var sample_count: int = maxi(roundi(duration_seconds * float(mix_rate)), 1)
	var _resize_error: Error = sample_bytes.resize(sample_count * bytes_per_sample) as Error
	stream.data = sample_bytes
	return stream


class SameDuplicateRegion:
	extends GFAudioPlaybackRegion

	func _duplicate_stream(stream: AudioStream) -> Resource:
		return stream


class SafeMP3DuplicateRegion:
	extends GFAudioPlaybackRegion

	func _duplicate_stream(stream: AudioStream) -> Resource:
		if not (stream is AudioStreamMP3):
			return null
		var source: AudioStreamMP3 = stream
		var duplicated_stream: AudioStreamMP3 = AudioStreamMP3.new()
		duplicated_stream.loop = source.loop
		duplicated_stream.loop_offset = source.loop_offset
		duplicated_stream.bpm = source.bpm
		duplicated_stream.beat_count = source.beat_count
		duplicated_stream.bar_beats = source.bar_beats
		return duplicated_stream
