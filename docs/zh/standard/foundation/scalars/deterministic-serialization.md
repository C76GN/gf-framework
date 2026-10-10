# 确定性序列化

`GFDeterministicVariantSerializer` 为纯 Variant 数据生成稳定的 canonical value、JSON、UTF-8 bytes 和 SHA-256。它适合锁步输入、回放快照、黄金测试、配置内容 hash 和 deterministic math 状态比对。

## 定位

它不替代 `GFVariantJsonCodec` 或 `GFStorageCodec`：

- `GFVariantJsonCodec` 负责 Godot Variant 与 JSON 兼容数据往返。
- `GFStorageCodec` 负责存档字典的编码、压缩、metadata、完整性校验和混淆。
- `GFDeterministicVariantSerializer` 只负责稳定类型标记、字典 key 排序、规范文本、规范 bytes 和 hash。

该工具不读取文件、不参与 `GFArchitecture` 生命周期、不解释业务字段，也不扫描对象属性。需要保存 `Resource`、`Node` 或业务对象时，先在项目层转换成稳定 ID、路径或纯数据字典。

## 常用流程

```gdscript
var payload := {
	"rng": rng.to_dict(),
	"position": fixed_position.to_dict(),
	"turn": 12,
}

var canonical_json := GFDeterministicVariantSerializer.to_canonical_json(payload)
var canonical_bytes := GFDeterministicVariantSerializer.to_canonical_bytes(payload)
var content_hash := GFDeterministicVariantSerializer.sha256(payload)
```

相同数据即使 Dictionary 插入顺序不同，也会得到相同 canonical JSON、bytes 和 hash。数组顺序会被保留，因为数组顺序通常承载业务语义。

## 预算预检与增量 hash

需要先判断载荷能否进入规范编码时，使用安静的 `measure_canonical()`：

```gdscript
var options := {
	"max_items": 100_000,
	"max_output_bytes": 16 * 1024 * 1024,
}
var report := GFDeterministicVariantSerializer.measure_canonical(payload, options)
if report.ok:
	print(report.items, report.packed_items, report.output_bytes)
	var content_hash := GFDeterministicVariantSerializer.sha256(payload, options)
else:
	print(report.failure_kind, report.error)
```

报告固定包含 `ok`、`error`、`failure_kind`、`items`、`packed_items` 和 `output_bytes`。成功时，`output_bytes` 是完整规范 JSON 的精确 UTF-8 字节数；`items` 包括每个 Variant 节点及 packed 元素，`packed_items` 只统计 packed 元素。Array 和 Dictionary 自身各计一个节点，字典的 key 与 value 分别计数；packed 容器计一个节点再加元素个数，向量分量不额外计数。`Transform3D` 沿用 typed 编码规则，只额外计入 `basis` 节点。失败的计数只描述已经检查的部分，输出计数最多为 `max_output_bytes`，不能用作完整载荷大小。`failure_kind` 成功时为空，失败时为 `input_invalid` 或 `output_limit`；`error` 用于展示说明。

JSON、bytes 和 SHA-256 入口均先重新预检，再生成结果；输入错误优先于最终输出超限。默认预算为深度 256、元素 100,000、单字符串 1,048,576 个字符和输出 16 MiB，所有预算最小为 1。packed 元素预算在展开前整批检查，字符串长度按字符计数，输出预算按转义后的 UTF-8 字节计数。

预检不构建完整 typed tree、packed 普通数组或规范 JSON 文本。两种 hash 入口采用不同的资源策略，但生成相同字节协议的摘要，并执行相同输入和输出预算：

- `sha256()` 预检后构建完整 typed tree 和规范 JSON，再调用原生 SHA-256，优先降低编码 CPU 开销。
- `sha256_incremental()` 逐片编码，并以最多 64 KiB 的缓冲更新摘要，避免完整 typed tree 和 JSON 文本的工作内存；分段编码可能增加 CPU 开销。

```gdscript
var content_hash := GFDeterministicVariantSerializer.sha256(payload, options)
var incremental_hash := GFDeterministicVariantSerializer.sha256_incremental(payload, options)
assert(content_hash == incremental_hash)
```

需要控制大载荷的编码工作内存时，可以显式选择增量入口；频繁计算 hash 时应结合实际载荷测量 CPU 和内存成本。增量入口的字符串分段交给 Godot 自身做 JSON 转义，整数文本、浮点位模式、字典排序和 schema 字段顺序与 typed 编码保持一致。bytes 入口仍需保存完整最终字节数组，JSON 入口还需返回完整字符串，`to_canonical_value()` 仍会构建完整 typed tree。

字典排序必须保留 canonical key 文本，因此增量 hash 的总工作内存还包括当前递归路径及各层字典的 key 排序工作集；复合 key 的文本也可能较大。这些文本受输出预算约束，工具不承诺常量内存或固定执行时间。对任意入口的整个同步调用，以及预检到随后编码之间，项目必须保持输入结构不变；预检报告不能授权已经被修改的数据。各编码入口独立执行预算检查，失败时不会发布部分 bytes 或 hash。

## 定点数与定点向量

`GFFixedDecimal`、`GFFixedVector2` 和 `GFFixedVector3` 已提供 JSON 安全状态字典。确定性序列化应消费这些 `to_dict()` 输出，而不是直接传入对象：

```gdscript
var price := GFFixedDecimal.from_string("12.34", 2)
var offset := GFFixedVector2.from_decimal_strings("1.25", "-3.50", 2)

var hash := GFDeterministicVariantSerializer.sha256({
	"price": price.to_dict(),
	"offset": offset.to_dict(),
})
```

这样可以避免通用 serializer 通过反射调用任意对象方法，也让数值类型自己的版本字段、raw 文本和字节格式继续由数值模块维护。

## 浮点边界

默认情况下，`float`、`Vector2`、`Color`、`Transform3D` 等浮点值会被拒绝。需要确定性真值时，优先使用定点数或整数网格坐标。

工具链或配置 hash 确实需要纳入有限浮点值时，可以显式开启：

```gdscript
var hash := GFDeterministicVariantSerializer.sha256({
	"preview_position": Vector2(1.5, -2.25),
}, {
	"allow_floats": true,
})
```

即使开启 `allow_floats`，`NaN` 和 `Inf` 也会失败；`0.0` 与 `-0.0` 会归一到同一编码。有限的浮点向量、矩形、颜色、平面、四元数、AABB、Basis、Transform 与 `Projection` 也会按固定分量顺序编码；`Projection` 使用 `x/y/z/w` 四列共 16 个分量。

## 使用边界

- 支持纯 Variant 数据、字符串 / 名称 / 路径、整数向量、数组、字典和常见 packed 数组；显式开启 `allow_floats` 后支持文档化的有限浮点复合类型。
- 字典 key 会按 key 的 canonical 表达排序，`1`、`"1"`、`StringName("1")` 不会被压成同一个字符串 key。
- Object、Resource、Callable、RID、Signal、循环引用和超过 `max_depth` 的结构会失败。
- `to_canonical_value()` 的预算作用于遍历深度、集合项和字符串长度；它不生成唯一字节表示，因此不把 `max_output_bytes` 作为保证。`max_output_bytes` 只由 JSON、bytes 和 SHA-256 入口执行。
- 如果只是写入存档并需要压缩、metadata 或 checksum，继续使用 `GFStorageCodec`。
- 如果只是把 Godot 值转成 JSON 兼容结构并恢复，继续使用 `GFVariantJsonCodec`。
