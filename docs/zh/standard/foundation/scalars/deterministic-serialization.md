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
- 如果只是写入存档并需要压缩、metadata 或 checksum，继续使用 `GFStorageCodec`。
- 如果只是把 Godot 值转成 JSON 兼容结构并恢复，继续使用 `GFVariantJsonCodec`。
