# Variant 深拷贝与 JSON 转换

通用 Variant 基础件分为三个明确职责：`GFVariantData` 负责深拷贝、字典 / metadata 合并、options 读取、基础类型收窄、默认值合并、差异报告和 Resource 可选复制；`GFVariantJsonCodec` 负责 JSON 友好的 Godot 值类型转换；`GFVariantReferenceCodec` 负责显式 Resource / Node 引用标记。

它们都不依赖 `GFArchitecture`，适合存档、配置、校验报告、网络消息、命中上下文等需要复制集合但保留标量语义，或把 Godot 值转成纯数据的地方。

## 深拷贝与默认值

```gdscript
var payload := {
	"stats": {
		"hp": 10,
	},
}
var copy := GFVariantData.duplicate_variant(payload) as Dictionary

var settings := {
	"audio": {
		"volume": 0.8,
	},
}
GFVariantData.deep_merge_defaults(settings, {
	"audio": {
		"mute": false,
	},
	"language": "zh",
})
```

`GFVariantData.duplicate_variant()` 默认只深拷贝 `Dictionary` 和 `Array`，其他值保持原样返回；如果值中包含 `Object` 或 `Resource`，仍是引用语义。需要复制资源值时，可显式传入 `duplicate_variant(value, true, true)`。

## Variant 差异报告

当配置、存档、导入结果、校验上下文或网络载荷需要展示“变了什么”时，可使用 `GFVariantData.diff_variant()` 生成纯数据报告：

```gdscript
var report := GFVariantData.diff_variant(previous_payload, next_payload, {
	"max_changes": 256,
})

for change in report["changes"]:
	print(change["kind"], " ", change["path"])
```

报告包含 `changed`、`change_count`、`truncated`、`max_changes` 和 `changes`。每条差异包含 `kind`、`path`、`path_segments`、`old_value`、`new_value`、`old_type` 与 `new_type`；`kind` 可为 `added`、`removed`、`changed` 或 `type_changed`。默认会复制差异值，避免修改报告污染原始数据；如果只需要轻量观察，可传 `{ "copy_values": false }`。`String` 与 `StringName` 字典键按同名字段匹配，和 options / merge 工具保持一致。

该方法只比较 Variant 数据形状，不读取文件、不实例化脚本、不扫描对象属性，也不理解业务身份。需要对象图序列化、资源导入或领域级变更解释时，应在具体模块先转换成稳定 ID、路径或纯数据字典，再交给 diff 工具处理。

## Metadata 与 Options

项目自定义 `metadata` 应保持普通 `Dictionary`，框架只复制、合并和透传，不解释业务键。需要合并时优先使用 `merge_metadata()`，避免不同模块手写深拷贝和嵌套合并规则：

```gdscript
var metadata := GFVariantData.duplicate_metadata(base_metadata)
GFVariantData.merge_metadata(metadata, {
	"source": "importer",
	"tags": ["preview"],
})
```

公共 API 的 `options` 字典应使用稳定字段名，并通过 `get_option_bool()`、`get_option_int()`、`get_option_float()`、`get_option_dictionary()` 等读取。读取器支持 `String` 与 `StringName` 键互查，集合返回副本，避免调用方和框架共享内部状态。`merge_dictionary()` / `merge_metadata()` 判断已有字段时也遵循同一套等价键规则，因此不会因为来源字典使用 `StringName`、目标字典使用 `String` 而生成重复字段。

## Variant 收窄

当数据来自 `Dictionary.get()`、反射调用、JSON 解码、网络消息或编辑器配置时，先使用 `GFVariantData` 做显式收窄，再进入业务逻辑：

```gdscript
var retry_count := GFVariantData.to_int(options.get("retry_count", 0), 0)
var enabled := GFVariantData.to_bool(options.get("enabled", true), true)
var route_id := GFVariantData.to_string_name(record.get("route_id", &""))
```

`to_bool()`、`to_int()`、`to_float()`、`to_text()`、`to_string_name()`、`to_vector2()` 和 `to_vector3()` 都要求调用方显式给出 fallback 语义；非法文本不会被静默解释为 `0` 或 `false`。`Vector2` / `Vector3` 收窄支持同维或相邻维度向量、`x/y/z` 字典和数值数组。常见标量集合可用 `to_string_array()`、`to_string_name_array()` 和 `to_int_array()` 逐项归一并返回副本，options 字段则对应使用 `get_option_string_array()`、`get_option_string_name_array()` 和 `get_option_int_array()`。

集合有两组入口：`as_dictionary()` / `as_array()` 返回原引用，适合继续修改运行时状态；`to_dictionary()` / `to_array()` 返回副本，适合公开快照、metadata、options 和持久化数据。对象、Resource、节点、Callable 等领域类型仍应由具体模块本地收窄，不放进通用 Variant 工具。

## JSON 兼容转换

```gdscript
var saved_position := GFVariantJsonCodec.vector2_to_array(Vector2(12.0, 4.0))
var position := GFVariantJsonCodec.array_to_vector2(saved_position)

var json_payload := GFVariantJsonCodec.variant_to_json_compatible({
	"position": Vector3(1.0, 2.0, 3.0),
	"tags": PackedStringArray(["state.ready"]),
})
var restored := GFVariantJsonCodec.json_compatible_to_variant(
	JSON.parse_string(JSON.stringify(json_payload))
) as Dictionary

var pretty_json := GFVariantJsonCodec.format_json_text("{\"b\":2,\"a\":1}", "  ", true)
var compact_json := GFVariantJsonCodec.compact_json_text(pretty_json)
```

`GFVariantJsonCodec.variant_to_json_compatible()` 会为 `Vector2/3/4`、整数向量、`Color`、`Rect2`、`Transform2D/3D`、`Basis`、`Quaternion`、`AABB`、`Plane`、`NodePath`、`StringName` 和常见 PackedArray 写入专用 `__gf_variant__` 类型标记，再由 `json_compatible_to_variant()` 恢复。

`parse_json_text()`、`format_json_text()` 和 `compact_json_text()` 面向已经是 JSON 文本的输入：它们先通过 Godot JSON 解析器确认文本有效，再返回解析值、格式化文本或去除非必要空白后的文本。解析失败时返回调用方提供的 fallback，不会把无效输入静默改写成空集合。

## 显式引用标记

`GFVariantReferenceCodec` 用于少数确实需要保存对象引用的位置。Resource 引用会保存 `resource_path`、可用时的 `ResourceUID` 文本和类型提示；恢复时先尝试 UID，再回退到路径。Node 引用只保存相对调用方提供 root 的 `NodePath`，解码时也必须传入同一个语义 root，不会从场景树全局搜索。

```gdscript
var encoded_resource := GFVariantReferenceCodec.encode_reference(texture)
var decoded_resource := GFVariantReferenceCodec.decode_reference(encoded_resource)

var encoded_node := GFVariantReferenceCodec.encode_reference(target_node, {
	GFVariantReferenceCodec.OPTION_ROOT_NODE: scope_root,
})
var decoded_node := GFVariantReferenceCodec.decode_reference(encoded_node, {
	GFVariantReferenceCodec.OPTION_ROOT_NODE: scope_root,
})
```

引用 codec 不处理对象图、脚本自动实例化、无路径内嵌 Resource、跨 Scope 节点扫描或业务身份映射。需要保存复杂对象时，项目应先转换成稳定 ID、Resource 路径、显式 NodePath 或纯数据字典。

## 使用边界

普通整数在 JSON 安全范围内仍保持数字；超出 JSON 安全范围的 64 位整数会自动写成 `Int64` 类型标记，避免 Godot JSON 往返后丢失精度。只有 `__gf_variant__` 标记是字典唯一字段时才会被解码为 Godot 类型，因此普通业务字典里的 `type`、`value`、`_gf_type` 等字段会按普通数据保留。

默认普通 Dictionary 仍使用字符串键；如果确实需要保留非字符串键，可传 `{ "encode_dictionary_keys": true }`。JSON codec 遇到不支持的对象默认写成 `null`；需要持久化对象时，应在项目层先转换成资源路径、ID 或纯数据字典。
