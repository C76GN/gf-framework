## 测试安全资源图编解码策略。
extends GutTest


const _SAFE_TYPED_RESOURCE_SCRIPT = preload("res://tests/gf_core/fixtures/storage/safe_typed_resource.gd")
const _SAFE_TYPED_RESOURCE_SCRIPT_PATH: String = "res://tests/gf_core/fixtures/storage/safe_typed_resource.gd"
const _SAFE_TYPED_CHILD_RESOURCE_SCRIPT = preload("res://tests/gf_core/fixtures/storage/safe_typed_child_resource.gd")
const _SAFE_TYPED_CHILD_RESOURCE_SCRIPT_PATH: String = "res://tests/gf_core/fixtures/storage/safe_typed_child_resource.gd"
const _SAFE_TYPED_SIBLING_RESOURCE_SCRIPT_PATH: String = "res://tests/gf_core/fixtures/storage/safe_typed_sibling_resource.gd"
const _SAFE_INCOMPATIBLE_NODE_SCRIPT = preload("res://tests/gf_core/fixtures/storage/safe_incompatible_node.gd")
const _SAFE_INCOMPATIBLE_NODE_SCRIPT_PATH: String = "res://tests/gf_core/fixtures/storage/safe_incompatible_node.gd"


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


func test_safe_resource_codec_preserves_typed_root_containers() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var number_payload: Array[int] = [3, 5, 8]
	var count_payload: Dictionary[String, int] = {
		"potion": 2,
		"sword": 1,
	}

	var encoded_numbers: Dictionary = GFSafeResourceCodec.encode(number_payload, policy)
	var decoded_numbers: Dictionary = GFSafeResourceCodec.decode(
		GFVariantData.get_option_dictionary(encoded_numbers, "data"),
		policy
	)
	var encoded_counts: Dictionary = GFSafeResourceCodec.encode(count_payload, policy)
	var decoded_counts: Dictionary = GFSafeResourceCodec.decode(
		GFVariantData.get_option_dictionary(encoded_counts, "data"),
		policy
	)
	var decoded_number_value: Variant = GFVariantData.get_option_value(decoded_numbers, "value")
	var decoded_count_value: Variant = GFVariantData.get_option_value(decoded_counts, "value")

	assert_true(GFVariantData.get_option_bool(decoded_numbers, "ok"), "类型化根数组应可解码。")
	assert_true(decoded_number_value is Array, "数组载荷应恢复为 Array。")
	if decoded_number_value is Array:
		var decoded_number_array: Array = decoded_number_value
		assert_true(decoded_number_array.is_typed(), "根数组的类型约束不应丢失。")
		assert_eq(decoded_number_array.get_typed_builtin(), TYPE_INT, "根数组元素类型应保持为 int。")
		assert_eq(decoded_number_array, number_payload, "根数组内容应往返。")
	assert_true(GFVariantData.get_option_bool(decoded_counts, "ok"), "类型化根字典应可解码。")
	assert_true(decoded_count_value is Dictionary, "字典载荷应恢复为 Dictionary。")
	if decoded_count_value is Dictionary:
		var decoded_count_dictionary: Dictionary = decoded_count_value
		assert_true(decoded_count_dictionary.is_typed(), "根字典的类型约束不应丢失。")
		assert_eq(decoded_count_dictionary.get_typed_key_builtin(), TYPE_STRING, "根字典键类型应保持为 String。")
		assert_eq(decoded_count_dictionary.get_typed_value_builtin(), TYPE_INT, "根字典值类型应保持为 int。")
		assert_eq(decoded_count_dictionary, count_payload, "根字典内容应往返。")


func test_safe_resource_codec_round_trips_typed_scripted_resource_properties() -> void:
	var policy: GFSafeResourceCodecPolicy = _make_typed_resource_policy()
	var resource: _SAFE_TYPED_RESOURCE_SCRIPT = _SAFE_TYPED_RESOURCE_SCRIPT.new()
	var child: _SAFE_TYPED_RESOURCE_SCRIPT = _SAFE_TYPED_RESOURCE_SCRIPT.new()
	var typed_child: _SAFE_TYPED_CHILD_RESOURCE_SCRIPT = _SAFE_TYPED_CHILD_RESOURCE_SCRIPT.new()
	resource.value = 7
	resource.numbers.assign([1, 4, 9])
	resource.counts.assign({ "coins": 12 })
	child.value = 11
	resource.resources.append(child)
	typed_child.value = 17
	resource.child = typed_child

	var encoded: Dictionary = GFSafeResourceCodec.encode(resource, policy)
	var decoded: Dictionary = GFSafeResourceCodec.decode(GFVariantData.get_option_dictionary(encoded, "data"), policy)
	var decoded_value: Variant = GFVariantData.get_option_value(decoded, "value")

	assert_true(GFVariantData.get_option_bool(encoded, "ok"), "allowlist 内的脚本 Resource 应可编码。")
	assert_true(GFVariantData.get_option_bool(decoded, "ok"), "类型化脚本 Resource 应可解码。")
	assert_true(decoded_value is _SAFE_TYPED_RESOURCE_SCRIPT, "解码结果应恢复原脚本类型。")
	if decoded_value is _SAFE_TYPED_RESOURCE_SCRIPT:
		var decoded_resource: _SAFE_TYPED_RESOURCE_SCRIPT = decoded_value
		assert_true(decoded_resource.numbers.is_typed(), "Array[int] 属性应保持类型约束。")
		assert_eq(decoded_resource.numbers, resource.numbers, "Array[int] 属性内容应往返。")
		assert_true(decoded_resource.counts.is_typed(), "Dictionary[String, int] 属性应保持类型约束。")
		assert_eq(decoded_resource.counts, resource.counts, "类型化 Dictionary 属性内容应往返。")
		assert_true(decoded_resource.resources.is_typed(), "Array[Resource] 属性应保持类型约束。")
		assert_eq(decoded_resource.resources.size(), 1, "Array[Resource] 属性应保留元素。")
		if not decoded_resource.resources.is_empty():
			var decoded_child: Resource = decoded_resource.resources[0]
			assert_true(decoded_child is _SAFE_TYPED_RESOURCE_SCRIPT, "Array[Resource] 元素应恢复脚本 Resource。")
			if decoded_child is _SAFE_TYPED_RESOURCE_SCRIPT:
				var typed_decoded_child: _SAFE_TYPED_RESOURCE_SCRIPT = decoded_child
				assert_eq(typed_decoded_child.value, 11, "Array[Resource] 元素属性应往返。")
		assert_true(decoded_resource.child is _SAFE_TYPED_CHILD_RESOURCE_SCRIPT, "自定义脚本类型属性应恢复约束类型。")
		if decoded_resource.child is _SAFE_TYPED_CHILD_RESOURCE_SCRIPT:
			var decoded_typed_child: _SAFE_TYPED_CHILD_RESOURCE_SCRIPT = decoded_resource.child
			assert_eq(decoded_typed_child.value, 17, "自定义脚本类型属性内容应往返。")


func test_safe_resource_codec_round_trips_custom_resource_typed_array_with_script_allowlist() -> void:
	var blocked_payload: Array[_SAFE_TYPED_RESOURCE_SCRIPT] = []
	var blocked_policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var blocked: Dictionary = GFSafeResourceCodec.encode(blocked_payload, blocked_policy)
	var blocked_issues: Array = GFVariantData.get_option_array(blocked, "issues")
	var blocked_issue: Dictionary = GFVariantData.as_dictionary(blocked_issues[0]) if not blocked_issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(blocked, "ok"), "空的自定义 Resource 类型数组也必须校验元素脚本 allowlist。")
	assert_eq(GFVariantData.get_option_string_name(blocked_issue, "kind"), &"script_not_allowed", "拒绝原因应指向类型脚本。")

	var policy: GFSafeResourceCodecPolicy = _make_typed_resource_policy()
	var resource: _SAFE_TYPED_RESOURCE_SCRIPT = _SAFE_TYPED_RESOURCE_SCRIPT.new()
	resource.value = 23
	var payload: Array[_SAFE_TYPED_RESOURCE_SCRIPT] = [resource]
	var encoded: Dictionary = GFSafeResourceCodec.encode(payload, policy)
	var decoded: Dictionary = GFSafeResourceCodec.decode(GFVariantData.get_option_dictionary(encoded, "data"), policy)
	var decoded_value: Variant = GFVariantData.get_option_value(decoded, "value")

	assert_true(GFVariantData.get_option_bool(encoded, "ok"), "allowlist 内的自定义 Resource 类型数组应可编码。")
	assert_true(GFVariantData.get_option_bool(decoded, "ok"), "allowlist 内的自定义 Resource 类型数组应可解码。")
	assert_true(decoded_value is Array, "自定义 Resource 类型数组应恢复为 Array。")
	if decoded_value is Array:
		var decoded_array: Array = decoded_value
		assert_true(decoded_array.is_typed(), "自定义 Resource 数组应保留类型约束。")
		var decoded_type_script: Variant = decoded_array.get_typed_script()
		assert_true(decoded_type_script is Script, "自定义 Resource 数组应恢复脚本类型描述。")
		if decoded_type_script is Script:
			var typed_script: Script = decoded_type_script
			assert_same(typed_script, _SAFE_TYPED_RESOURCE_SCRIPT, "数组元素脚本类型应往返。")
		assert_eq(decoded_array.size(), 1, "自定义 Resource 数组应保留元素。")
		if not decoded_array.is_empty():
			var decoded_resource: Variant = decoded_array[0]
			assert_true(decoded_resource is _SAFE_TYPED_RESOURCE_SCRIPT, "数组元素应恢复自定义 Resource 类型。")
			if decoded_resource is _SAFE_TYPED_RESOURCE_SCRIPT:
				var typed_decoded_resource: _SAFE_TYPED_RESOURCE_SCRIPT = decoded_resource
				assert_eq(typed_decoded_resource.value, 23, "数组元素属性应往返。")


func test_safe_resource_codec_round_trips_resource_self_cycle() -> void:
	var policy: GFSafeResourceCodecPolicy = _make_typed_resource_policy()
	var resource: _SAFE_TYPED_RESOURCE_SCRIPT = _SAFE_TYPED_RESOURCE_SCRIPT.new()
	resource.peer = resource

	var encoded: Dictionary = GFSafeResourceCodec.encode(resource, policy)
	var decoded: Dictionary = GFSafeResourceCodec.decode(GFVariantData.get_option_dictionary(encoded, "data"), policy)
	var decoded_value: Variant = GFVariantData.get_option_value(decoded, "value")

	assert_true(GFVariantData.get_option_bool(encoded, "ok"), "Resource 自环应可编码。")
	assert_true(GFVariantData.get_option_bool(decoded, "ok"), "Resource 自环应可解码。")
	assert_true(decoded_value is _SAFE_TYPED_RESOURCE_SCRIPT, "自环根对象应恢复脚本类型。")
	if decoded_value is _SAFE_TYPED_RESOURCE_SCRIPT:
		var decoded_resource: _SAFE_TYPED_RESOURCE_SCRIPT = decoded_value
		assert_same(decoded_resource.peer, decoded_resource, "自环应指回解码后的同一实例。")
		decoded_resource.peer = null
	resource.peer = null


func test_safe_resource_codec_round_trips_two_resource_cycle() -> void:
	var policy: GFSafeResourceCodecPolicy = _make_typed_resource_policy()
	var first: _SAFE_TYPED_RESOURCE_SCRIPT = _SAFE_TYPED_RESOURCE_SCRIPT.new()
	var second: _SAFE_TYPED_RESOURCE_SCRIPT = _SAFE_TYPED_RESOURCE_SCRIPT.new()
	first.peer = second
	second.peer = first

	var encoded: Dictionary = GFSafeResourceCodec.encode(first, policy)
	var decoded: Dictionary = GFSafeResourceCodec.decode(GFVariantData.get_option_dictionary(encoded, "data"), policy)
	var decoded_value: Variant = GFVariantData.get_option_value(decoded, "value")

	assert_true(GFVariantData.get_option_bool(encoded, "ok"), "双节点 Resource 环应可编码。")
	assert_true(GFVariantData.get_option_bool(decoded, "ok"), "双节点 Resource 环应可解码。")
	assert_true(decoded_value is _SAFE_TYPED_RESOURCE_SCRIPT, "双节点环根对象应恢复脚本类型。")
	if decoded_value is _SAFE_TYPED_RESOURCE_SCRIPT:
		var decoded_first: _SAFE_TYPED_RESOURCE_SCRIPT = decoded_value
		assert_true(decoded_first.peer is _SAFE_TYPED_RESOURCE_SCRIPT, "双节点环的第二个对象应恢复脚本类型。")
		if decoded_first.peer is _SAFE_TYPED_RESOURCE_SCRIPT:
			var decoded_second: _SAFE_TYPED_RESOURCE_SCRIPT = decoded_first.peer
			assert_same(decoded_second.peer, decoded_first, "第二个对象应回指解码后的根对象。")
			decoded_second.peer = null
		decoded_first.peer = null
	first.peer = null
	second.peer = null


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


func test_safe_resource_codec_rejects_nonpositive_object_ids() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	for object_id: int in [0, -1, -2]:
		var decoded: Dictionary = GFSafeResourceCodec.decode(_make_forged_resource_object(object_id), policy)
		var issues: Array = GFVariantData.get_option_array(decoded, "issues")
		var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

		assert_false(GFVariantData.get_option_bool(decoded, "ok"), "对象编号必须是正整数：%d。" % object_id)
		assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"invalid_object_id", "拒绝原因应指向非法对象编号。")


func test_safe_resource_codec_rejects_coercible_noninteger_object_ids() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	for object_id: Variant in [true, 1.9, "1"]:
		var decoded: Dictionary = GFSafeResourceCodec.decode(_make_forged_resource_object(object_id), policy)
		var issues: Array = GFVariantData.get_option_array(decoded, "issues")
		var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

		assert_false(GFVariantData.get_option_bool(decoded, "ok"), "可转换值也不能冒充整数对象编号：%s。" % object_id)
		assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"invalid_object_id", "拒绝原因应指向原始编号类型非法。")


func test_safe_resource_codec_rejects_duplicate_object_ids() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var forged_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"array",
		GFSafeResourceCodec.KEY_ITEMS: [
			_make_forged_resource_object(1, "First"),
			_make_forged_resource_object(1, "Second"),
		],
	}

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "重复对象编号不应覆盖先前注册的对象。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"duplicate_object_id", "拒绝原因应指向重复对象编号。")


func test_safe_resource_codec_rejects_duplicate_dictionary_keys() -> void:
	var forged_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"dictionary",
		GFSafeResourceCodec.KEY_ENTRIES: [
			{
				"key": _make_direct_value_node("same-key"),
				"value": _make_direct_value_node(1),
			},
			{
				"key": _make_direct_value_node("same-key"),
				"value": _make_direct_value_node(2),
			},
		],
	}

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "伪造字典中的重复键不能使用 last-write-wins。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"duplicate_dictionary_key", "拒绝原因应指向重复字典键。")


func test_safe_resource_codec_rejects_duplicate_object_properties() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var forged_data: Dictionary = _make_forged_resource_object(1)
	forged_data[GFSafeResourceCodec.KEY_PROPERTIES] = [
		{
			"name": "resource_name",
			"value": _make_direct_value_node("First"),
		},
		{
			"name": "resource_name",
			"value": _make_direct_value_node("Second"),
		},
	]

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "同一属性不能被伪造载荷重复写入并触发多次 setter。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"duplicate_property", "拒绝原因应指向重复属性。")


func test_safe_resource_codec_rejects_nonpositive_object_reference_ids() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var forged_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"object_reference",
		GFSafeResourceCodec.KEY_OBJECT_ID: 0,
	}

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "非正数引用编号不应进入引用查找。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"invalid_object_id", "拒绝原因应指向非法引用编号。")


func test_safe_resource_codec_rejects_coercible_noninteger_object_reference_ids() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	for object_id: Variant in [true, 1.9, "1"]:
		var forged_data: Dictionary = {
			GFSafeResourceCodec.KEY_KIND: &"object_reference",
			GFSafeResourceCodec.KEY_OBJECT_ID: object_id,
		}
		var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
		var issues: Array = GFVariantData.get_option_array(decoded, "issues")
		var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

		assert_false(GFVariantData.get_option_bool(decoded, "ok"), "可转换值也不能冒充整数引用编号：%s。" % object_id)
		assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"invalid_object_id", "拒绝原因应指向原始引用编号类型非法。")


func test_safe_resource_codec_reports_forged_property_type_mismatch() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var forged_data: Dictionary = _make_forged_resource_object(1)
	forged_data[GFSafeResourceCodec.KEY_PROPERTIES] = [
		{
			"name": "resource_name",
			"value": {
				GFSafeResourceCodec.KEY_KIND: &"value",
				GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_INT,
				GFSafeResourceCodec.KEY_VALUE: 42,
			},
		},
	]

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "错误属性类型应返回结构化失败，不能裸写入对象。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"property_write_failed", "拒绝原因应指向属性写入失败。")


func test_safe_resource_codec_reports_forged_typed_container_property_mismatch() -> void:
	var policy: GFSafeResourceCodecPolicy = _make_typed_resource_policy()
	var forged_data: Dictionary = _make_forged_resource_object(1)
	forged_data[GFSafeResourceCodec.KEY_SCRIPT_PATH] = _SAFE_TYPED_RESOURCE_SCRIPT_PATH
	forged_data[GFSafeResourceCodec.KEY_PROPERTIES] = [
		{
			"name": "numbers",
			"value": {
				GFSafeResourceCodec.KEY_KIND: &"array",
				GFSafeResourceCodec.KEY_ITEMS: [
					{
						GFSafeResourceCodec.KEY_KIND: &"value",
						GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_STRING,
						GFSafeResourceCodec.KEY_VALUE: "not-an-int",
					},
				],
				"array_type": {
					GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_STRING,
					GFSafeResourceCodec.KEY_CLASS: "",
					GFSafeResourceCodec.KEY_SCRIPT_PATH: "",
				},
			},
		},
	]

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "伪造的 Array[String] 不应写入 Array[int] 属性。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"property_write_failed", "类型化容器不匹配应返回属性写入失败。")


func test_safe_resource_codec_rejects_sibling_script_for_custom_typed_property() -> void:
	var policy: GFSafeResourceCodecPolicy = _make_typed_resource_policy()
	var _sibling_result: GFSafeResourceCodecPolicy = policy.allow_script_path(
		_SAFE_TYPED_SIBLING_RESOURCE_SCRIPT_PATH
	)
	var sibling_data: Dictionary = _make_forged_resource_object(2, "Sibling")
	sibling_data[GFSafeResourceCodec.KEY_SCRIPT_PATH] = _SAFE_TYPED_SIBLING_RESOURCE_SCRIPT_PATH
	var forged_data: Dictionary = _make_forged_resource_object(1)
	forged_data[GFSafeResourceCodec.KEY_SCRIPT_PATH] = _SAFE_TYPED_RESOURCE_SCRIPT_PATH
	forged_data[GFSafeResourceCodec.KEY_PROPERTIES] = [
		{
			"name": "child",
			"value": sibling_data,
		},
	]

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "同为 Resource 的 sibling 脚本不应绕过自定义属性类型。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"property_write_failed", "拒绝原因应指向自定义属性类型不匹配。")


func test_safe_resource_codec_rejects_incompatible_native_class_and_script() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var _class_result: GFSafeResourceCodecPolicy = policy.allow_class("Node")
	var _script_result: GFSafeResourceCodecPolicy = policy.allow_script_path(_SAFE_INCOMPATIBLE_NODE_SCRIPT_PATH)
	var forged_data: Dictionary = _make_forged_resource_object(1)
	forged_data[GFSafeResourceCodec.KEY_SCRIPT_PATH] = _SAFE_INCOMPATIBLE_NODE_SCRIPT_PATH
	forged_data[GFSafeResourceCodec.KEY_PROPERTIES] = []

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "allowlist 内的原生类和脚本也必须是可附加组合。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"script_class_mismatch", "拒绝原因应指向脚本与原生类不兼容。")


func test_safe_resource_codec_rejects_forged_container_script_class_mismatch() -> void:
	var policy: GFSafeResourceCodecPolicy = _make_typed_resource_policy()
	var forged_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"array",
		GFSafeResourceCodec.KEY_ITEMS: [],
		"array_type": {
			GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_OBJECT,
			GFSafeResourceCodec.KEY_CLASS: "Node",
			GFSafeResourceCodec.KEY_SCRIPT_PATH: _SAFE_TYPED_RESOURCE_SCRIPT_PATH,
		},
	}

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "类型脚本与声明类不一致时不应进入容器构造。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"container_type_invalid", "拒绝原因应指向伪造的类型描述。")


func test_safe_resource_codec_rejects_null_for_nonnullable_property() -> void:
	var policy: GFSafeResourceCodecPolicy = _make_typed_resource_policy()
	var forged_data: Dictionary = _make_forged_resource_object(1)
	forged_data[GFSafeResourceCodec.KEY_SCRIPT_PATH] = _SAFE_TYPED_RESOURCE_SCRIPT_PATH
	forged_data[GFSafeResourceCodec.KEY_PROPERTIES] = [
		{
			"name": "value",
			"value": {
				GFSafeResourceCodec.KEY_KIND: &"value",
				GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_NIL,
				GFSafeResourceCodec.KEY_VALUE: null,
			},
		},
	]

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "null 不应写入 int 等非空内建属性。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"property_write_failed", "非空属性收到 null 应返回属性写入失败。")


func test_safe_resource_codec_rejects_missing_or_wrong_collection_shapes() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var malformed_payloads: Array[Dictionary] = [
		{
			GFSafeResourceCodec.KEY_KIND: &"value",
			GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_NIL,
		},
		{
			GFSafeResourceCodec.KEY_KIND: &"array",
		},
		{
			GFSafeResourceCodec.KEY_KIND: &"dictionary",
			GFSafeResourceCodec.KEY_ENTRIES: {},
		},
		{
			GFSafeResourceCodec.KEY_KIND: &"object",
			GFSafeResourceCodec.KEY_OBJECT_ID: 1,
			GFSafeResourceCodec.KEY_CLASS: "Resource",
			GFSafeResourceCodec.KEY_SCRIPT_PATH: "",
			GFSafeResourceCodec.KEY_PROPERTIES: {},
		},
	]

	for malformed_payload: Dictionary in malformed_payloads:
		var decoded: Dictionary = GFSafeResourceCodec.decode(malformed_payload, policy)
		var issues: Array = GFVariantData.get_option_array(decoded, "issues")
		var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

		assert_false(GFVariantData.get_option_bool(decoded, "ok"), "缺失或错误类型的集合字段不能静默退化为空值。")
		assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"encoded_shape_invalid", "拒绝原因应指向编码结构非法。")


func test_safe_resource_codec_preflights_container_cardinality_before_shape_scan() -> void:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var oversized_payloads: Array[Dictionary] = [
		{
			GFSafeResourceCodec.KEY_KIND: &"array",
			GFSafeResourceCodec.KEY_ITEMS: [{}, "invalid_late_item"],
		},
		{
			GFSafeResourceCodec.KEY_KIND: &"dictionary",
			GFSafeResourceCodec.KEY_ENTRIES: [
				{ "key": {}, "value": {} },
				"invalid_late_entry",
			],
		},
		{
			GFSafeResourceCodec.KEY_KIND: &"object",
			GFSafeResourceCodec.KEY_OBJECT_ID: 1,
			GFSafeResourceCodec.KEY_CLASS: "Resource",
			GFSafeResourceCodec.KEY_SCRIPT_PATH: "",
			GFSafeResourceCodec.KEY_PROPERTIES: [
				{ "name": "resource_name", "value": {} },
				"invalid_late_property",
			],
		},
	]

	for payload: Dictionary in oversized_payloads:
		var decoded: Dictionary = GFSafeResourceCodec.decode(payload, policy, { "max_items": 1 })
		var issues: Array = GFVariantData.get_option_array(decoded, "issues")
		var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

		assert_false(GFVariantData.get_option_bool(decoded, "ok"), "容器基数超出剩余预算时必须失败关闭。")
		assert_eq(
			GFVariantData.get_option_string_name(first_issue, "kind"),
			&"max_items_exceeded",
			"预算必须在遍历或暂存完整容器形状之前命中。"
		)


func test_safe_resource_codec_rejects_coercible_variant_type_metadata() -> void:
	var direct_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"value",
		GFSafeResourceCodec.KEY_VARIANT_TYPE: "2",
		GFSafeResourceCodec.KEY_VALUE: 7,
	}
	var container_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"array",
		GFSafeResourceCodec.KEY_ITEMS: [],
		"array_type": {
			GFSafeResourceCodec.KEY_VARIANT_TYPE: true,
			GFSafeResourceCodec.KEY_CLASS: "",
			GFSafeResourceCodec.KEY_SCRIPT_PATH: "",
		},
	}

	var direct_decoded: Dictionary = GFSafeResourceCodec.decode(direct_data)
	var direct_issues: Array = GFVariantData.get_option_array(direct_decoded, "issues")
	var direct_issue: Dictionary = GFVariantData.as_dictionary(direct_issues[0]) if not direct_issues.is_empty() else {}
	var container_decoded: Dictionary = GFSafeResourceCodec.decode(container_data)
	var container_issues: Array = GFVariantData.get_option_array(container_decoded, "issues")
	var container_issue: Dictionary = GFVariantData.as_dictionary(container_issues[0]) if not container_issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(direct_decoded, "ok"), "字符串不能冒充直接值 Variant.Type。")
	assert_eq(GFVariantData.get_option_string_name(direct_issue, "kind"), &"value_type_invalid", "直接值应报告类型元数据非法。")
	assert_false(GFVariantData.get_option_bool(container_decoded, "ok"), "布尔值不能冒充容器 Variant.Type。")
	assert_eq(GFVariantData.get_option_string_name(container_issue, "kind"), &"container_type_invalid", "容器应报告类型元数据非法。")


func test_safe_resource_codec_rolls_back_cycles_after_late_decode_failure() -> void:
	_SAFE_TYPED_RESOURCE_SCRIPT.last_instance = null
	var policy: GFSafeResourceCodecPolicy = _make_typed_resource_policy()
	var forged_data: Dictionary = _make_forged_resource_object(1)
	forged_data[GFSafeResourceCodec.KEY_SCRIPT_PATH] = _SAFE_TYPED_RESOURCE_SCRIPT_PATH
	forged_data[GFSafeResourceCodec.KEY_PROPERTIES] = [
		{
			"name": "peer",
			"value": {
				GFSafeResourceCodec.KEY_KIND: &"object_reference",
				GFSafeResourceCodec.KEY_OBJECT_ID: 1,
			},
		},
		{
			"name": "value",
			"value": {
				GFSafeResourceCodec.KEY_KIND: &"value",
				GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_STRING,
				GFSafeResourceCodec.KEY_VALUE: "not-an-int",
			},
		},
	]

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var failed_instance: WeakRef = _SAFE_TYPED_RESOURCE_SCRIPT.last_instance

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "后续属性失败时整个对象图解码应失败。")
	assert_not_null(failed_instance, "fixture 应记录解码阶段创建的脚本 Resource。")
	if failed_instance != null:
		assert_true(failed_instance.get_ref() == null, "失败回滚必须拆除已经写入的自环，不能泄漏 RefCounted。")


func test_safe_resource_codec_frees_non_refcounted_objects_after_late_decode_failure() -> void:
	_SAFE_INCOMPATIBLE_NODE_SCRIPT.last_instance = null
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodecPolicy.new()
	var _class_result: GFSafeResourceCodecPolicy = policy.allow_class("Node")
	var _script_result: GFSafeResourceCodecPolicy = policy.allow_script_path(_SAFE_INCOMPATIBLE_NODE_SCRIPT_PATH)
	var forged_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"object",
		GFSafeResourceCodec.KEY_OBJECT_ID: 1,
		GFSafeResourceCodec.KEY_CLASS: "Node",
		GFSafeResourceCodec.KEY_SCRIPT_PATH: _SAFE_INCOMPATIBLE_NODE_SCRIPT_PATH,
		GFSafeResourceCodec.KEY_PROPERTIES: [
			{
				"name": "missing_property",
				"value": _make_direct_value_node(1),
			},
		],
	}

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var failed_instance: WeakRef = _SAFE_INCOMPATIBLE_NODE_SCRIPT.last_instance

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "Node 后续属性失败时整个对象图解码应失败。")
	assert_not_null(failed_instance, "fixture 应记录解码阶段创建的脚本 Node。")
	if failed_instance != null:
		assert_true(failed_instance.get_ref() == null, "失败清理必须释放非 RefCounted 对象，不能留下 orphan Node。")


func test_safe_resource_codec_preflights_object_shape_before_script_instantiation() -> void:
	_SAFE_INCOMPATIBLE_NODE_SCRIPT.last_instance = null
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodecPolicy.new()
	var _class_result: GFSafeResourceCodecPolicy = policy.allow_class("Node")
	var _script_result: GFSafeResourceCodecPolicy = policy.allow_script_path(_SAFE_INCOMPATIBLE_NODE_SCRIPT_PATH)
	var forged_data: Dictionary = {
		GFSafeResourceCodec.KEY_KIND: &"object",
		GFSafeResourceCodec.KEY_OBJECT_ID: 1,
		GFSafeResourceCodec.KEY_CLASS: "Node",
		GFSafeResourceCodec.KEY_SCRIPT_PATH: _SAFE_INCOMPATIBLE_NODE_SCRIPT_PATH,
		GFSafeResourceCodec.KEY_PROPERTIES: {},
	}

	var decoded: Dictionary = GFSafeResourceCodec.decode(forged_data, policy)
	var issues: Array = GFVariantData.get_option_array(decoded, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(decoded, "ok"), "畸形属性结构必须在脚本实例化前拒绝。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"encoded_shape_invalid", "拒绝原因应指向编码结构非法。")
	assert_null(_SAFE_INCOMPATIBLE_NODE_SCRIPT.last_instance, "结构预检失败不能执行 allowlisted 脚本的 _init。")


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


func _make_typed_resource_policy() -> GFSafeResourceCodecPolicy:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodec.make_resource_policy()
	var _script_result: GFSafeResourceCodecPolicy = policy.allow_script_path(_SAFE_TYPED_RESOURCE_SCRIPT_PATH)
	var _child_script_result: GFSafeResourceCodecPolicy = policy.allow_script_path(
		_SAFE_TYPED_CHILD_RESOURCE_SCRIPT_PATH
	)
	return policy


func _make_forged_resource_object(object_id: Variant, resource_name: String = "Forged") -> Dictionary:
	return {
		GFSafeResourceCodec.KEY_KIND: &"object",
		GFSafeResourceCodec.KEY_OBJECT_ID: object_id,
		GFSafeResourceCodec.KEY_CLASS: "Resource",
		GFSafeResourceCodec.KEY_SCRIPT_PATH: "",
		GFSafeResourceCodec.KEY_PROPERTIES: [
			{
				"name": "resource_name",
				"value": {
					GFSafeResourceCodec.KEY_KIND: &"value",
					GFSafeResourceCodec.KEY_VARIANT_TYPE: TYPE_STRING,
					GFSafeResourceCodec.KEY_VALUE: resource_name,
				},
			},
		],
	}


func _make_direct_value_node(value: Variant) -> Dictionary:
	return {
		GFSafeResourceCodec.KEY_KIND: &"value",
		GFSafeResourceCodec.KEY_VARIANT_TYPE: typeof(value),
		GFSafeResourceCodec.KEY_VALUE: value,
	}
