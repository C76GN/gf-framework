# Variant 深拷贝与 JSON 转换

通用 Variant 基础件分为几个明确职责：`GFVariantData` 负责深拷贝、字典 / metadata 合并、options 读取、基础类型收窄、默认值合并、差异报告和 Resource 可选复制；`GFVariantJsonCodec` 负责 JSON 友好的 Godot 值类型转换，以及独立版本化的确定性 JSON 文本；`GFVariantKeyCodec` 负责把稳定 Variant 转成可比较 key token；`GFVariantReferenceCodec` 负责显式 Resource / Node 引用标记。`GFReportValueCodec` 属于 kernel 层统一报告边界，负责公开报告和诊断快照的 JSON-safe 脱敏输出，standard 与 extensions 都应复用它而不是各自写 sanitizer。

它们都不依赖 `GFArchitecture`，适合存档、配置、校验报告、网络消息、命中上下文等需要复制集合但保留标量语义，或把 Godot 值转成纯数据的地方。

## 深拷贝与默认值

```gdscript
var payload := {
	"stats": {
		"hp": 10,
	},
}
var copied: Dictionary = GFVariantData.copy_value(payload)
if not copied.ok:
	push_error(str(copied.error_kind))
	return
var copy: Dictionary = copied.value

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

`GFVariantData.copy_value()` 在同一次遍历中校验并复制纯数据值树，返回 `ok`、`value`、`counts_complete`、计量与失败位置。简便入口 `duplicate_variant(value, limits)` 返回副本，失败返回 null；需要区分合法 null 时使用结构化结果。Array、Dictionary 的内建类型声明及全部具体 PackedArray 类型保留。共享子容器在每个位置独立展开；循环、Object、Resource、Callable、Signal、RID 以及声明 Object 类型的容器被拒绝。

默认限制为 1,000,000 个节点和 Packed 元素、64 层深度、每字符串 1,048,576 字符、64 MiB 逻辑载荷和 30,000 毫秒。可通过 `max_items`、`max_depth`（最多 256）、`max_string_length`、`max_payload_bytes`、`max_elapsed_msec` 覆盖，并传入 `cancel_token: GFCancellationToken`。数值限制必须是正整数，未知字段或非文本键被拒绝。逻辑载荷统计标量固定宽度、UTF-8 字符串和 Packed 内容；容器管理成本由节点预算约束，不能把该数值等同于实际堆内存。失败返回 `value=null`，计量只描述已处理部分，绝不发布部分树。

需要对象身份、容器别名或循环时，显式调用 `duplicate_graph(value, deep, duplicate_resources)`。它默认保留 Object/Resource 引用；第三个参数为 true 时复制 Resource。该入口维护全图身份，最坏可能出现平方级容器查找成本，适合确实具有图语义的状态。编辑器撤销、对象黑板和通用异步结果使用这个契约。普通大数据、持久化值和后台输入使用值树复制或快照。

`to_dictionary()` / `to_array()` 是带副本的形状收窄，`as_dictionary()` / `as_array()` 返回引用；它们不提供纯数据准入或完整预算保证。把数据交给线程、哈希或持久化边界时，显式选择相应结构化入口。

## 只读数据快照

`GFDataSnapshot.capture(value, limits)` 使用同样的值树规则。捕获成功后发布 `snapshot`，失败时该字段为 null。快照拥有隔离后的树，公开读取不返回可写的内部容器：

```gdscript
var captured: Dictionary = GFDataSnapshot.capture(payload)
if not captured.ok:
	return
var snapshot: GFDataSnapshot = captured.snapshot
var stats: Dictionary = snapshot.get_statistics()
var hp: Variant = snapshot.get_value(["stats", "hp"])
var working: Dictionary = snapshot.copy_value()
if working.ok:
	var mutable_payload: Dictionary = working.value
	mutable_payload["stats"]["hp"] = 20
```

`get_value(path)` 只复制选定的子树；空路径导出根，路径无效或选定值为 null 都返回 null。`copy_value(limits)` 显式导出完整可变树并返回失败诊断；它可以收紧或覆盖原捕获预算。所有公开导出彼此隔离。快照的不可变性来自独占所有权和只读 API；仅框架编码器的内部借用按合作只读约定使用。

捕获是有界的同步准备工作，需要源数据在调用期间稳定。生产大型数据时应安排好捕获时机和预算，再把同一个快照交给多个消费者。`GFDeterministicVariantSerializer.hash_result(snapshot)` 和 `GFBackgroundWorkUtility.submit_cpu_work(worker, snapshot)` 都直接接收已准备的快照，提交不会再次复制其载荷。修改型 worker 必须主动调用 `copy_value()`。

旧 `duplicate_variant(value, deep, duplicate_resources)` 和 `duplicate_collection()` 调用应按真实语义迁移：普通数据使用 `copy_value()`，引用图使用 `duplicate_graph()`，跨任务只读数据使用快照；不再保留旧多布尔参数别名。


## 固定版本与分帧快照

需要在同一时刻固定数据版本，再按共享帧预算读取时，参见 [版本化与分帧快照](versioned-snapshots.md)。该能力可按数据域采用，提供框架受控容器和项目不可变适配器。

## Variant 差异报告

当配置、存档、导入结果、校验上下文或网络载荷需要展示“变了什么”时，可使用 `GFVariantData.diff_variant()` 生成纯数据报告：

```gdscript
var report := GFVariantData.diff_variant(previous_payload, next_payload, {
	"max_changes": 256,
	"max_depth": 64,
	"max_nodes": 16384,
	"max_collection_items": 65536,
})

if not report["complete"]:
	push_warning("Diff traversal was incomplete: %s" % report["traversal_reason"])

for change in report["changes"]:
	print(change["kind"], " ", change["path"])
```

报告包含 `changed`、`complete`、`change_count`、`truncated`、`max_changes`、`traversal_truncated`、`traversal_reason` 和 `changes`。每条差异包含 `kind`、`path`、`path_segments`、`old_value`、`new_value`、`old_type` 与 `new_type`；`kind` 只可能是 `added`、`removed`、`changed` 或 `type_changed`。默认会复制差异值，避免修改报告污染原始数据；如果只需要轻量观察，可传 `{ "copy_values": false }`。`String` 与 `StringName` 字典键按同名字段匹配，和 options / merge 工具保持一致。

Array / Dictionary 按展开后的数据内容比较，不比较共享引用拓扑。同一引用（包括 NaN、自引用容器和共享循环图）与自身比较恒为 unchanged；遍历独立循环图时，活动引用 pair 的重入只写入有界 `diagnostics`，`kind = cycle_detected`，不会伪造第五种 change。可通过 `max_diagnostics` 控制诊断数量；诊断截断不改变 `changed`。

`max_changes` 只限制输出条数；遍历工作量由 `max_depth`、`max_nodes` 和 `max_collection_items` 分别约束，默认值依次为 64、16384 和 65536，传入小于等于 0 的值表示不限制。命中遍历预算时，报告会设置 `complete = false`、`traversal_truncated = true`，并写入 `kind = traversal_budget_exceeded` 的诊断。此时 `changed = false` 只表示已访问部分没有发现差异，不能解释为两份完整输入相等。

该方法只比较 Variant 数据形状，不读取文件、不实例化脚本、不扫描对象属性，也不理解业务身份。需要对象图序列化、资源导入或领域级变更解释时，应在具体模块先转换成稳定 ID、路径或纯数据字典，再交给 diff 工具处理。

## Variant 等值判断

`GFVariantData.values_equal()` 提供通用浅层等值判断，适合状态 store、导入计划、缓存键预检和轻量工具比较标量值。`int` / `int` 保持完整 64 位精度；`float` / `float` 可通过 `numeric_epsilon` 设置容差；`int` / `float` 只有在 float 有限、无小数、位于 int64 范围且双向转换精确往返时才等价，epsilon 不会放宽这条混合类型规则。

```gdscript
var same_number := GFVariantData.values_equal(1, 1.0)
var close_value := GFVariantData.values_equal(0.1 + 0.2, 0.3, {
	"numeric_epsilon": 0.00001,
})
```

如果项目明确希望把 `String` 与 `StringName` 的同名值视为相等，可以传入 `{ "match_string_names": true }`。该入口不做深层对象图比较，也不加载 Resource；复杂结构的差异仍应使用 `diff_variant()` 或先转换成稳定纯数据后再比较。

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

`GFDataProjection.project_with_report()` 在配置 `GFDictionarySchema` 时会使用 report-aware 字段规范化：可转换值会按 schema 输出，转换失败会写入返回报告并保留原始输入，不会把坏值降级成字段类型 fallback 后继续投影。

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

var json_text := GFVariantJsonCodec.stringify_json_compatible({
	"score": 10,
	"position": Vector3(1.0, INF, NAN),
}, "  ", true)
var restored_text := GFVariantJsonCodec.parse_json_compatible_text(json_text, {}) as Dictionary

var pretty_json := GFVariantJsonCodec.format_json_text("{\"b\":2,\"a\":1}", "  ", true)
var compact_json := GFVariantJsonCodec.compact_json_text(pretty_json)
```

`GFVariantJsonCodec.variant_to_json_compatible()` 会为 `Vector2/3/4`、整数向量、`Color`、`Rect2`、`Transform2D/3D`、`Basis`、`Quaternion`、`AABB`、`Plane`、`NodePath`、`StringName` 和常见 PackedArray 写入专用 `__gf_variant__` 类型标记，再由 `json_compatible_to_variant()` 恢复。`NaN`、`INF` 和 `-INF` 不能由 JSON number 表达，因此会写成 `Float` 类型标记，而不是交给 Godot `JSON.stringify()` 替换成 `null`。

编码与解码共享 `max_depth`、`max_nodes` 和 `max_collection_items` 遍历预算，默认值依次为 64、16384 和 65536，小于等于 0 表示不限制。编码超限时不会返回部分业务树，而是返回顶层 `TraversalLimit` typed marker，其中包含 `reason` 与已消费预算；解码超限时返回 `traversal_limit` 选项的副本，默认是 `"<traversal_limit>"`。因此，任何把“解码结果等于业务值”作为成功条件的调用方，都应为 `traversal_limit` 提供业务域外的专用 sentinel。

这些预算约束的是 `JSON.parse()` 已经物化后的 Variant 图遍历，不是 JSON 文本的解析前准入，也不限制输入字节数或解析器看到的词法嵌套深度。`parse_json_compatible_text()`、`parse_json_text()`、`format_json_text()` 和 `compact_json_text()` 都会先调用 Godot JSON 解析器，因此不能用它们的后续遍历预算替代不可信输入的字节/深度门禁。项目运行时或工具读取外部 JSON object 时，应先用 [`GFBoundedJsonObjectReader`](../../../../kernel/index.md) 完成有硬上限的文本或文件准入，确认报告 `ok` 后再把 `data` 交给 `json_compatible_to_variant()`；两层预算应同时保留。

如果调用方最终就是要得到 JSON 文本，优先使用 `stringify_json_compatible()`，它会先执行 `variant_to_json_compatible()` 再调用 Godot `JSON.stringify()`，避免把 `NaN`、`Infinity`、`Vector3`、`Color`、PackedArray 等值直接送进 JSON 边界。读取这类文本时用 `parse_json_compatible_text()`，它会在解析成功后自动恢复 GF typed marker；解析失败时返回调用方提供的 fallback。

`parse_json_text()`、`format_json_text()` 和 `compact_json_text()` 面向已经是 JSON 文本的输入：它们先通过 Godot JSON 解析器确认文本有效，再返回解析值、格式化文本或去除非必要空白后的文本。解析失败时返回调用方提供的 fallback，不会把无效输入静默改写成空集合。

## 确定性 JSON

需要稳定、可恢复且保留类型的文本导出时，使用 `encode_deterministic_result()` 与 `decode_deterministic_result()`。独立格式 `gf.variant-json-deterministic` v1 的使用示例、类型节点、浮点精度、预算和失败报告见[确定性 JSON](deterministic-json.md)。

## 显式引用标记

`GFVariantReferenceCodec` 用于少数确实需要保存对象引用的位置。Resource 引用会保存 `resource_path`、可用时的 `ResourceUID` 文本和类型提示；恢复时先尝试 UID，再回退到路径。Node 引用只保存相对调用方提供 root 的 `NodePath`，解码时也必须传入同一个语义 root，不会从场景树全局搜索。

```gdscript
var encoded_resource := GFVariantReferenceCodec.encode_reference(texture)
var decoded_resource := GFVariantReferenceCodec.decode_reference(encoded_resource, {
	GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_ROOTS: PackedStringArray(["res://content"]),
})

var encoded_node := GFVariantReferenceCodec.encode_reference(target_node, {
	GFVariantReferenceCodec.OPTION_ROOT_NODE: scope_root,
})
var decoded_node := GFVariantReferenceCodec.decode_reference(encoded_node, {
	GFVariantReferenceCodec.OPTION_ROOT_NODE: scope_root,
})
```

解码 Resource 引用必须显式限制可加载路径。`allowed_resource_roots` 按目录根匹配，`allowed_resource_patterns` 按 Godot `String.match()` 通配模式匹配；两者都为空时会拒绝恢复 Resource，避免未确认来源标记直接进入 `ResourceLoader.load()`。

```gdscript
var decoded_resource := GFVariantReferenceCodec.decode_reference(encoded_resource, {
	GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_ROOTS: PackedStringArray(["res://content/items"]),
	GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_PATTERNS: PackedStringArray(["user://trusted_exports/*.tres"]),
})
```

引用 codec 不处理对象图、脚本自动实例化、无路径内嵌 Resource、跨 Scope 节点扫描或业务身份映射。需要保存复杂对象时，项目应先转换成稳定 ID、Resource 路径、显式 NodePath 或纯数据字典。

## 使用边界

普通 JSON 兼容转换的 `max_depth` 与 `max_nodes` 按还原后的 Variant 结构计量，固定 typed marker 包装及向量分量不额外消耗节点或深度。PackedArray 仍按元素数累计 `max_collection_items`；typed Dictionary 的实际 key/value 仍分别消耗节点与深度预算。有效编码不会因为这些固定包装重复计费而解码失败，非法嵌套 marker 仍会被拒绝。确定性 JSON 使用[独立定义的闭合预算与结构化结果](deterministic-json.md)。

普通整数在 JSON 安全范围内仍保持数字；超出 JSON 安全范围的 64 位整数会自动写成 `Int64` 类型标记，避免 Godot JSON 往返后丢失精度。只有 `__gf_variant__` 标记是字典唯一字段时才会被解码为 Godot 类型，因此普通业务字典里的 `type`、`value`、`_gf_type` 等字段会按普通数据保留。

默认普通 Dictionary 仍使用字符串键；如果确实需要保留非字符串键，可传 `{ "encode_dictionary_keys": true }`。JSON codec 遇到不支持的对象默认写成 `null`；需要持久化对象时，应在项目层先转换成资源路径、ID 或纯数据字典。

## 报告值与稳定 Key

公开报告、调试快照、事件历史或 CI 输出不应直接包含运行时 `Object`、`Resource`、`Callable`、`Signal`、`RID` 或非有限浮点。需要把任意报告值交给 `JSON.stringify()` 前，先使用 `GFReportValueCodec`：

```gdscript
var safe_report := GFReportValueCodec.to_json_compatible({
	"target": some_node,
	"value": NAN,
	"position": Vector3(1.0, 2.0, 3.0),
})
var json_text := JSON.stringify(safe_report, "\t")
```

`GFReportValueCodec` 会使用 GF typed marker 处理 Vector、Color、`NaN` / `INF` / `-INF` 等 Godot 值，PackedArray 则写成保留具体 collection type 和已处理 items 的 report marker；不安全 `PackedInt64Array` 元素仍使用精确 `Int64` 字符串 marker。运行时对象、未知 Variant 和循环引用只输出受限 `__gf_report_value__` marker，不调用任意值的 `str()`，也不接受自定义循环 replacement。

路径字符串和 Resource 路径默认会被脱敏；开发态确实需要完整路径时，显式选择 `debug` profile 或传入 `{ "path_redaction": "none" }`。未知 profile 会忽略可能放宽暴露面的 overrides，并规范化为最严格的 `privacy`。普通 String 字典键可保持 JSON object 形态；其他键或脱敏后变化的键统一转为 entries envelope。用户数据中的 `__gf_report_value__` 保留键也会转义，不能伪造内部截断或脱敏 marker。该 codec 适合报告和日志边界，不用于保存可恢复对象图；需要恢复 Resource 或 Node 引用时仍使用 `GFVariantReferenceCodec`。

公开对象如果需要标准报告形态，可以实现 `to_report_dictionary(options)` 并在内部调用 `GFReportValueCodec.to_report_dictionary()`。这个入口会把任意值包成 `{ "ok": true, "value": ... }` 或错误报告字典，适合导出命令、诊断面板和测试统一断言 JSON-safe 边界。

大型集合不应完整塞进错误报告或支持报告。`GFReportValueCodec.make_collection_summary()` 会输出 `count`、固定数量 `sample`、`truncated` 和 `encoded_preview_hash`，适合配置校验、导入器和诊断面板展示“足够定位问题但不膨胀报告”的上下文。`encoded_preview_hash` 只覆盖经过深度、节点、集合和字节预算限制后的编码预览，不能作为完整集合的内容指纹。

缓存、索引、查询签名和 keyed 异步 gate 需要“同一输入稳定得到同一 token”，应使用 `GFVariantKeyCodec`。默认允许 `bool`、`int`、`String`、`StringName`、`NodePath`、有限 `float`、有限 Vector/Rect/Color 这类稳定值；拒绝 `Array`、`Dictionary`、Object/Resource、Callable、RID、Signal 和 `NaN` / `Infinity`。

```gdscript
var token := GFVariantKeyCodec.make_key_token(Vector2i(4, 8))
if token.is_empty():
	push_error("Key must be a stable scalar or math value.")
```

`GFValueIndex`、`GFQuerySignature`、`GFCacheDiagnostics`、`GFAsyncKeyedGate` 和 `GFAsyncProgressAggregator` 都复用这套 key 合同。项目如果需要用复杂业务对象作为 key，应先在业务层提取稳定 ID、资源路径、坐标或枚举值，不要把可变集合或运行时对象交给框架底层。

## 与确定性序列化的关系

普通 JSON 兼容转换用于已有 JSON 数据形状；[确定性 JSON](deterministic-json.md)用于保留类型、稳定比较及恢复纯数据的文本导出。[`GFDeterministicVariantSerializer`](../../scalars/deterministic-serialization.md) 使用独立的 canonical v2 二进制协议提供字节与 SHA-256，不提供 JSON 文本入口。

两种确定性格式有意保留不同契约：文本保留容器类型声明并支持显式非有限浮点；二进制内容哈希忽略容器类型声明，默认拒绝浮点，启用后也只允许有限值。导出 JSON 不改变 canonical v2 字节、Network 契约摘要或稳定 seed。存档压缩、metadata、checksum 与兼容读取仍由 `GFStorageCodec` 负责。
