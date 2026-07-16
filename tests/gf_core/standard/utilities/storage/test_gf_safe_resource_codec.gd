## 测试安全资源图编解码策略。
extends GutTest


func test_safe_resource_codec_round_trips_allowlisted_resource() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var resource: Resource = Resource.new()
	resource.resource_name = "Inventory"

	var encoded: Dictionary = GFSafeResourceCodec.encode(resource, policy)
	var decoded: Dictionary = GFSafeResourceCodec.decode(GFVariantData.get_option_dictionary(encoded, "data"), policy)
	var decoded_value: Variant = GFVariantData.get_option_value(decoded, "value")

	assert_true(GFVariantData.get_option_bool(encoded, "ok"), "允许的 Resource 应可编码。")
	assert_true(GFVariantData.get_option_bool(decoded, "ok"), "允许的 Resource 应可解码。")
	assert_true(decoded_value is Resource, "解码结果应是 Resource。")
	if decoded_value is Resource:
		var decoded_resource: Resource = decoded_value
		assert_eq(decoded_resource.resource_name, "Inventory", "Resource 存储属性应往返。")


func test_safe_resource_codec_rejects_objects_without_allowlist() -> void:
	var resource: Resource = Resource.new()
	resource.resource_name = "Blocked"

	var encoded: Dictionary = GFSafeResourceCodec.encode(resource)

	assert_false(GFVariantData.get_option_bool(encoded, "ok"), "默认策略不应编码对象图。")
	assert_true(GFVariantData.get_option_string(encoded, "error").contains("Class is not allowed"), "失败报告应说明 allowlist。")


func test_safe_resource_codec_policy_normalizes_paths_and_rejects_parent_segments() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodecPolicy.new()
	var _resource_result: GFSafeResourceCodecPolicy = policy.allow_resource_path(" res://safe\\audio/*.tres ")
	var _script_result: GFSafeResourceCodecPolicy = policy.allow_script_path("res://safe\\scripts/*.gd")
	var _blocked_result: GFSafeResourceCodecPolicy = policy.allow_resource_path("res://safe/../outside/*.tres")

	assert_true(policy.allows_resource_path("res://safe/audio/click.tres"), "资源路径匹配前应统一路径分隔符。")
	assert_true(policy.allows_script_path("res://safe/scripts/player.gd"), "脚本路径匹配前应统一路径分隔符。")
	assert_false(policy.allows_resource_path("res://safe/audio/../outside/secret.tres"), "候选资源路径不应通过 .. 逃逸 allowlist。")
	assert_false(policy.allows_script_path("res://safe/scripts/../outside/evil.gd"), "候选脚本路径不应通过 .. 逃逸 allowlist。")
	assert_false(policy.allows_resource_path("res://outside/secret.tres"), "包含 .. 的 allowlist 规则应被拒绝。")


func test_safe_resource_codec_preserves_repeated_references_when_allowed() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var shared: Resource = Resource.new()
	shared.resource_name = "Shared"
	var payload: Array = [shared, shared]

	var encoded: Dictionary = GFSafeResourceCodec.encode(payload, policy)
	var decoded: Dictionary = GFSafeResourceCodec.decode(GFVariantData.get_option_dictionary(encoded, "data"), policy)
	var decoded_array: Array = GFVariantData.get_option_array(decoded, "value")

	assert_true(GFVariantData.get_option_bool(encoded, "ok"), "重复引用对象图应可编码。")
	assert_true(GFVariantData.get_option_bool(decoded, "ok"), "重复引用对象图应可解码。")
	assert_eq(decoded_array.size(), 2, "解码数组应保留元素数量。")
	var raw_first_decoded: Variant = decoded_array[0]
	var raw_second_decoded: Variant = decoded_array[1]
	var first_decoded: Resource = raw_first_decoded if raw_first_decoded is Resource else null
	var second_decoded: Resource = raw_second_decoded if raw_second_decoded is Resource else null
	assert_same(first_decoded, second_decoded, "重复引用应恢复为同一对象实例。")


func test_safe_resource_codec_rejects_forged_direct_object_value() -> void:
	var forged_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"value",
		GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_OBJECT,
		GFSafeResourceCodec.KEY_VALUE: RefCounted.new(),
	}

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "伪造 direct value 不应绕过 Object allowlist。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"value_type_not_allowed", "拒绝原因应指向直接值类型非法。")


func test_safe_resource_codec_rejects_forged_non_storage_properties() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var forged_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"object",
		GFSafeResourceCodec.KEY_OBJECT_ID: 1,
		GFSafeResourceCodec.KEY_CLASS: "Resource",
		GFSafeResourceCodec.KEY_SCRIPT_PATH: "",
		GFSafeResourceCodec.KEY_PROPERTIES: [
			{
				"name": "resource_path",
				"value": {
					GFSafeResourceCodec.KEY_KIND: &"value",
					GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_STRING,
					GFSafeResourceCodec.KEY_VALUE: "res://outside.tres",
				},
			},
		],
	}

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "伪造 resource_path 属性不应被写入 allowlisted Resource。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"property_not_allowed", "拒绝原因应指向属性白名单。")


func test_safe_resource_codec_preflights_external_resource_script_dependencies() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var _resource_result: GFSafeResourceCodecPolicy = policy.allow_resource_path(
		"res://tests/gf_core/fixtures/storage/external_scripted_resource.tres"
	)
	var forged_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"external_resource",
		GFSafeResourceCodec.KEY_CLASS: "Resource",
		GFSafeResourceCodec.KEY_RESOURCE_PATH: "res://tests/gf_core/fixtures/storage/external_scripted_resource.tres",
	}

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy, {
		"load_external_resources": true,
	})
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "外部资源的脚本依赖未进入 allowlist 时应在加载前拒绝。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"script_not_allowed", "拒绝原因应指向脚本路径。")
	assert_true(GFVariantData.get_option_string(first_issue, "message").contains("before load"), "报告应明确这是加载前依赖预检。")
