# 确定性序列化

`GFDeterministicVariantSerializer` 用 canonical v2 二进制格式描述纯 Variant 值，并计算 SHA-256。配置内容摘要、回放校验和黄金测试可以复用同一格式。对象应先由项目转换成稳定 ID、路径或数据；需要稳定、可恢复的文本导出时使用 [`GFVariantJsonCodec` 的确定性 JSON](../data-validation/formula-variant/deterministic-json.md)，该文本协议独立版本化，不改变本页的字节或摘要。

## 一次计算取得摘要与计量

```gdscript
var report: Dictionary = GFDeterministicVariantSerializer.hash_result(
	payload,
	{
		"max_items": 4_000_000,
		"max_output_bytes": 64 * 1024 * 1024,
	}
)
if report.ok:
	print(report.canonical_version, report.hash)
	print(report.items, report.packed_items, report.output_bytes)
else:
	print(report.error_kind, report.error_path, report.limit_kind)
```

`hash_result()` 在同一次树遍历中校验、计量和更新摘要，不先复制输入，不构建完整 typed tree 或 JSON。Packed 整数数组按本机块取得字节并统一端序；哈希缓冲最多 64 KiB。

`encode_result()` 使用相同编码器返回完整 `bytes: PackedByteArray`；`measure_canonical()` 只返回计量。两者的 `hash` 为空；hash 模式的 `bytes` 为空。简便入口 `sha256()` 和 `to_canonical_bytes()` 分别在失败时返回空字符串和空数组。

需要摘要及计量时直接使用 `hash_result()`。单独的测量用于容量检查，不能授权之后发生变化的数据，也不应作为每次哈希前必经的步骤。

## 所有权与复用

同步调用期间，项目必须保持输入及其嵌套容器稳定。跨任务复用数据时先捕获 [GFDataSnapshot](../data-validation/formula-variant/variant-data-json.md#只读数据快照)：

```gdscript
var captured: Dictionary = GFDataSnapshot.capture(payload)
if captured.ok:
	var snapshot: GFDataSnapshot = captured.snapshot
	var first: Dictionary = GFDeterministicVariantSerializer.hash_result(snapshot)
	var second: Dictionary = GFDeterministicVariantSerializer.hash_result(snapshot)
	assert(first.hash == second.hash)
```

快照捕获只隔离一次源数据。哈希快照时借用其内部只读树，不调用公开导出，也不复制载荷。每次哈希仍按本次政策执行完整编码，不缓存可变预检凭据。

Array 的顺序保留，Dictionary 按键的完整编码排序。共享子容器在不同位置按值展开；容器类型声明不进入字节，所以内容相同的普通数组与 `Array[int]` 相同。Object 类型的数组或字典即使为空也被拒绝。循环、Object、Resource、Callable、Signal 和 RID 无法编码。

## 预算与失败报告

| 选项 | 默认值 | 单位 |
| --- | ---: | --- |
| `max_depth` | 64 | 根为 0，最大允许配置为 256 |
| `max_items` | 100,000 | 每次出现的 Variant 节点及 Packed 元素 |
| `max_string_length` | 1,048,576 | 每个字符串的字符数 |
| `max_output_bytes` | 16 MiB | 包含格式头的 canonical v2 字节 |
| `max_sort_bytes` | 16 MiB | 当前嵌套字典排序工作区的逻辑字节 |
| `max_elapsed_msec` | 30,000 | 单次操作经过的毫秒 |
| `allow_floats` | false | 是否允许有限浮点值 |
| `cancel_token` | null | 可选 `GFCancellationToken` |

数值预算必须为正整数，未知选项或无效类型直接返回 `invalid_options`。检查先于相关展开；时间和取消在有界步骤之间观察，不能抢占引擎的单次本机复制或排序。

每个 Array、Dictionary、Packed 容器各计一个节点；字典键和值分别计数，Packed 元素另外计入 `items` 和 `packed_items`。向量、矩阵与 Transform3D 都是一个 Variant 节点，分量不另外计数。

结果包含 `ok`、`canonical_version`、`counts_complete`、`items`、`packed_items`、`output_bytes`、`maximum_depth`、`peak_sort_bytes`，以及 `error_kind`、`error_path`、`error`、`failure_kind`、`limit_kind`、`limit`、`observed`、`observed_is_lower_bound`。

成功时 `counts_complete=true`，字节数精确。失败立即停止，计数只描述已处理部分；不发布部分 hash 或 bytes。预算失败的 `error_kind` 为 `limit_exceeded`，`observed` 是确定下界。其他分类包括 `cycle`、`unsupported_type`、`float_disabled`、`nonfinite_float`、`cancelled`、`snapshot_unavailable`、`ambiguous_dictionary_key` 和 `hash_failed`。不要解析展示用的 `error` 文本。所有入口均通过返回值报告失败，不输出错误日志。

排序工作区按保留的键字节、十六进制排序文本的 UTF-32 存储量及每项 128 字节逻辑成本计量，并累计嵌套字典。它与节点、深度、字符串和输出预算一起约束工作量，不代表精确的进程堆内存上限。字典排序仍需额外空间，bytes 模式还会保留完整输出。

## canonical v2 字节协议

格式头固定为四字节 `47 46 43 02`，即 ASCII `GFC` 加版本 2。之后是一个值。标签使用下面的固定编号，与 Godot 的 Variant 枚举编号无关。所有整数与浮点字节均为小端；长度使用 uint64，整数值及整数数学分量使用 int64。

| 标签（十进制） | 类型 | 标签之后的载荷 |
| --- | --- | --- |
| 0 | null | 无 |
| 1 | bool | 1 字节，0 或 1 |
| 2 | int | int64 |
| 3 | float | IEEE 754 binary64 |
| 4 / 5 / 6 | String / StringName / NodePath | UTF-8 字节长度，然后原始 UTF-8；NodePath 使用其文本表示 |
| 10 / 11 / 12 | Vector2i / Vector3i / Vector4i | 按 x、y、z、w 排列的 int64 分量 |
| 13 | Rect2i | position.x、position.y、size.x、size.y |
| 20 / 21 / 22 | Vector2 / Vector3 / Vector4 | 按坐标顺序排列的 binary64 分量 |
| 23 | Rect2 | position.x、position.y、size.x、size.y |
| 24 | Transform2D | x 列、y 列、origin，各两个分量 |
| 25 / 26 | Plane / Quaternion | normal.x、normal.y、normal.z、d / x、y、z、w |
| 27 | AABB | position 后接 size，各三个分量 |
| 28 | Basis | x、y、z 三列，各三个分量 |
| 29 | Transform3D | basis 的九个分量，后接 origin 三个分量 |
| 30 | Projection | x、y、z、w 四列，各四个分量 |
| 31 | Color | r、g、b、a |
| 40 | Array | 元素数量，随后逐项完整值编码 |
| 41 | Dictionary | 条目数量，随后按排序结果逐项写完整键编码和完整值编码 |
| 50 | PackedByteArray | 元素数量，随后原始字节 |
| 51 / 52 | PackedInt32Array / PackedInt64Array | 元素数量，随后连续 int32 / int64 |
| 53 / 54 | PackedFloat32Array / PackedFloat64Array | 元素数量，随后连续 binary32 / binary64 |
| 55 | PackedStringArray | 元素数量；每项为 UTF-8 字节长度及字节，不重复 String 标签 |
| 56 / 57 / 58 / 59 | PackedVector2Array / PackedVector3Array / PackedVector4Array / PackedColorArray | 元素数量；逐项按对应数学类型顺序写 binary64 分量，不重复标签 |

所有未另行指定宽度的浮点数学分量使用 binary64。浮点输入必须显式启用；NaN、正负无穷被拒绝，负零归一为正零。PackedFloat32Array 保留其已经量化为 binary32 的值。编码固定输入值的表示，不保证产生这些值的浮点运算跨平台一致。

Dictionary 的键允许上述纯值，包括复合键；按完整键编码的无符号字节字典序排序，不包含文件格式头。如果两个不同键产生相同编码，则拒绝为 `ambiguous_dictionary_key`。字符串不做 Unicode 规范化，String 与 StringName 使用不同标签。

示例：null 的完整编码为 `4746430200`，SHA-256 为 `c2f6f4900d26c5cc047b4a6f94200f7fe30dcf229c8c3f7bcfb85d80798bcc83`。

## 从旧规范 JSON 迁移

v2 不读取或生成旧规范 JSON，也不提供旧摘要兼容层。持久化摘要时同时记录 `canonical_version`，重新生成配置内容摘要、Network 契约访问器和依赖这些值的缓存、黄金向量。

- 删除 `to_canonical_value()` 和 `to_canonical_json()`；稳定文本导出改用 `GFVariantJsonCodec.encode_deterministic_result()`，对应恢复使用 `decode_deterministic_result()`；普通 JSON 继续使用兼容转换。新的文本格式不读取旧规范 JSON，哈希或字节校验改用本页入口。
- 删除 `sha256_incremental()`；`sha256()` 和 `hash_result()` 已统一为分块哈希。
- 内部哈希准备对象已删除；跨任务保留输入改用 `GFDataSnapshot`。
- 旧“先测量再哈希”调用改为一次 `hash_result()`；输出预算现在计算二进制字节，必须重新评估原有阈值。
- 失败采用首次遇错即停止，不再继续扫描以覆盖先前的输出超限错误。
- `GFSeedUtility.try_make_stable_seed()` 对 v2 字节执行 FNV-1a 32 位派生，结构化 seed 随格式升级而改变；纯文本 seed 算法保持原有定义。Network schema 描述版本为 2，版本记录同时携带 canonical 版本。
