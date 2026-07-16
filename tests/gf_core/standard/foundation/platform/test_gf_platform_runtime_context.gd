## 测试平台运行时上下文和桥接纯数据契约。
extends GutTest


# --- 测试方法 ---

func test_platform_capability_set_tracks_limits_and_merges() -> void:
	var capability_set: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new().configure(
		&"sample_platform",
		PackedStringArray(["share", "auth", "auth"]),
		{"source": "primary"},
		&"sample_adapter"
	)
	var _limit_written: bool = capability_set.set_limit(&"share", &"max_payload_bytes", 1024)
	var other: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new().configure(
		&"sample_platform",
		PackedStringArray(["cloud_storage"]),
		{"source": "secondary"}
	)
	var _merged: GFPlatformCapabilitySet = capability_set.merge_from(other, false)
	var copy: GFPlatformCapabilitySet = GFPlatformCapabilitySet.from_dict(capability_set.to_dict())
	var share_payload_limit: int = GFVariantData.to_int(capability_set.get_limit(&"share", &"max_payload_bytes"))
	var source_metadata: String = GFVariantData.get_option_string(capability_set.metadata, "source")

	assert_true(capability_set.has_all(PackedStringArray(["auth", "share"])), "能力集合应能检查全部能力。")
	assert_true(capability_set.has_capability(&"cloud_storage"), "合并后应包含新增能力。")
	assert_eq(share_payload_limit, 1024, "能力限制字段应能往返读取。")
	assert_eq(source_metadata, "primary", "非覆盖合并不应改写已有元数据。")
	assert_true(copy.has_capability(&"share"), "能力集合应能字典往返。")


func test_platform_runtime_context_builds_compatibility_profile() -> void:
	var capability_set: GFPlatformCapabilitySet = GFPlatformCapabilitySet.new().configure(
		&"sample_platform",
		PackedStringArray(["auth", "cloud_storage"])
	)
	var _persistent_written: bool = capability_set.set_limit(&"cloud_storage", &"persistent", true)
	var context: GFPlatformRuntimeContext = GFPlatformRuntimeContext.new().configure(
		&"sample_platform",
		{
			"adapter_id": &"sample_adapter",
			"display_name": "Sample Platform",
			"locale": "zh_CN",
			"fallback_locale": "zh",
			"pixel_ratio": 2.0,
			"window_size": [360, 640],
			"screen_size": Vector2i(720, 1280),
			"safe_area": {"x": 0, "y": 24, "width": 360, "height": 616},
			"storage_roots": {"user": "platform://user"},
			"capabilities": capability_set,
			"launch_options": {"scene": "entry"},
		}
	)
	var profile: GFCompatibilityProfile = context.make_compatibility_profile(&"runtime")
	var copy: GFPlatformRuntimeContext = GFPlatformRuntimeContext.from_dict(context.to_dict())
	var copied_persistent_limit: bool = GFVariantData.to_bool(
		copy.capabilities.get_limit(&"cloud_storage", &"persistent")
	)

	assert_true(context.has_capability(&"auth"), "上下文应代理能力查询。")
	assert_eq(context.window_size, Vector2i(360, 640), "窗口尺寸应从数组收窄为 Vector2i。")
	assert_eq(context.safe_area.size, Vector2i(360, 616), "安全区域应从字典收窄为 Rect2i。")
	assert_eq(context.get_storage_root(&"user"), "platform://user", "存储 root 应能读取。")
	assert_true(profile.has_platform("sample_platform"), "兼容性 Profile 应包含平台标识。")
	assert_true(profile.has_feature(&"cloud_storage"), "兼容性 Profile 应包含能力标识。")
	assert_eq(copied_persistent_limit, true, "上下文应能深拷贝能力限制。")


func test_platform_lifecycle_event_round_trips() -> void:
	var event: GFPlatformLifecycleEvent = GFPlatformLifecycleEvent.new().configure(
		GFPlatformLifecycleEvent.TYPE_BACKGROUND,
		&"sample_platform",
		{"reason": "pause"},
		7,
		1234,
		{"source": "adapter"}
	)
	var copy: GFPlatformLifecycleEvent = GFPlatformLifecycleEvent.from_dict(event.to_dict())

	assert_true(event.is_type(GFPlatformLifecycleEvent.TYPE_BACKGROUND), "生命周期事件应能检查类型。")
	assert_eq(copy.sequence, 7, "事件序号应能字典往返。")
	assert_eq(GFVariantData.get_option_string(copy.payload, "reason"), "pause", "事件 payload 应深拷贝。")


func test_platform_bridge_request_and_result_round_trip() -> void:
	var request: GFPlatformBridgeRequest = GFPlatformBridgeRequest.new().configure(
		&"req_1",
		&"platform.storage",
		&"save",
		{"path": "user://save.dat"},
		5000
	)
	var success: GFPlatformBridgeResult = GFPlatformBridgeResult.new().configure_success(
		request,
		{"saved": true},
		&"ok",
		100,
		160
	)
	var failure: GFPlatformBridgeResult = GFPlatformBridgeResult.new().configure_failure(
		request,
		"permission denied",
		&"permission_denied",
		100,
		150
	)
	var success_copy: GFPlatformBridgeResult = GFPlatformBridgeResult.from_dict(success.to_dict())
	var success_payload: Dictionary = GFVariantData.to_dictionary(success_copy.value)

	assert_false(request.is_empty(), "完整桥接请求不应为空。")
	assert_true(success.ok, "成功结果应标记 ok。")
	assert_eq(success.get_duration_msec(), 60, "桥接结果应报告耗时。")
	assert_false(failure.ok, "失败结果不应标记 ok。")
	assert_eq(failure.error, "permission denied", "失败结果应保留错误描述。")
	assert_eq(GFVariantData.get_option_bool(success_payload, "saved"), true, "桥接结果应能字典往返。")
