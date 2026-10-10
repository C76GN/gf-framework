# GFDeterministicVariantSerializer

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

纯 Variant 数据的确定性规范编码器。 该类型为锁步、回放、黄金测试和内容 hash 提供稳定的 canonical value、JSON、 UTF-8 bytes 与 SHA-256。强确定性输入应使用整数、字符串、布尔、整数向量、 PackedByteArray 或定点数编码；`allow_floats` 仅用于接受 Godot 浮点值的规范文本， 不承诺跨平台、跨 Godot 版本或跨编译配置的数值演算一致性。它不读取文件， 不处理存档 metadata、压缩、混淆或对象图。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`to_canonical_value`](#member-gfdeterministicvariantserializer-methods-to_canonical_value) | `static func to_canonical_value(value: Variant, options: Dictionary = {}) -> Variant:` |
| 方法 | [`to_canonical_json`](#member-gfdeterministicvariantserializer-methods-to_canonical_json) | `static func to_canonical_json(value: Variant, options: Dictionary = {}) -> String:` |
| 方法 | [`to_canonical_bytes`](#member-gfdeterministicvariantserializer-methods-to_canonical_bytes) | `static func to_canonical_bytes(value: Variant, options: Dictionary = {}) -> PackedByteArray:` |
| 方法 | [`sha256`](#member-gfdeterministicvariantserializer-methods-sha256) | `static func sha256(value: Variant, options: Dictionary = {}) -> String:` |
| 方法 | [`sha256_incremental`](#member-gfdeterministicvariantserializer-methods-sha256_incremental) | `static func sha256_incremental(value: Variant, options: Dictionary = {}) -> String:` |
| 方法 | [`measure_canonical`](#member-gfdeterministicvariantserializer-methods-measure_canonical) | `static func measure_canonical(value: Variant, options: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfdeterministicvariantserializer-methods-to_canonical_value"></a>

### `to_canonical_value`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func to_canonical_value(value: Variant, options: Dictionary = {}) -> Variant:
```

将 Variant 转换为 JSON 兼容的规范值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待编码的 Variant。应为纯数据结构；Object、Resource、Callable、RID 和循环引用会失败。 |
| `options` | 可选项。支持 allow_floats、max_depth、max_items 和 max_string_length；该入口不生成 bytes，因此不接受 max_output_bytes 作为输出保证。 |

返回：规范化后的 JSON 兼容 Variant；失败时返回 null 并输出错误。

结构：

- `value`: Variant value made from scalar, string, path, vector, rectangle, color, plane, quaternion, AABB, basis, transform, projection, array, dictionary, and packed array values. Float-based values require `options.allow_floats = true`.
- `options`: Dictionary with optional allow_floats, max_depth, max_items, and max_string_length limits.
- `return`: Typed marker Dictionary using `__gf_deterministic_variant__`, or null when unsupported input is detected.

<a id="member-gfdeterministicvariantserializer-methods-to_canonical_json"></a>

### `to_canonical_json`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func to_canonical_json(value: Variant, options: Dictionary = {}) -> String:
```

将 Variant 编码为规范 JSON 文本。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待编码的 Variant。 |
| `options` | 可选项。 |

返回：规范 JSON 文本；失败时返回空字符串。

结构：

- `value`: Variant value supported by `to_canonical_value()`.
- `options`: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.

<a id="member-gfdeterministicvariantserializer-methods-to_canonical_bytes"></a>

### `to_canonical_bytes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func to_canonical_bytes(value: Variant, options: Dictionary = {}) -> PackedByteArray:
```

将 Variant 编码为规范 UTF-8 字节。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待编码的 Variant。 |
| `options` | 可选项。 |

返回：规范 JSON 文本的 UTF-8 bytes；失败时返回空数组。

结构：

- `value`: Variant value supported by `to_canonical_value()`.
- `options`: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.

<a id="member-gfdeterministicvariantserializer-methods-sha256"></a>

### `sha256`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func sha256(value: Variant, options: Dictionary = {}) -> String:
```

计算 Variant 规范编码的 SHA-256，预检后构建完整 typed tree 和 JSON 文本以优先降低编码 CPU 开销。 大载荷需要控制工作内存时，使用生成相同摘要的 sha256_incremental()。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待编码的 Variant。 |
| `options` | 可选项。 |

返回：SHA-256 hex 字符串；失败时返回空字符串。

结构：

- `value`: Variant value supported by `to_canonical_value()`.
- `options`: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.

<a id="member-gfdeterministicvariantserializer-methods-sha256_incremental"></a>

### `sha256_incremental`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func sha256_incremental(value: Variant, options: Dictionary = {}) -> String:
```

逐片计算 Variant 规范编码的 SHA-256，不构建完整 typed tree 或规范 JSON 文本。 hash 缓冲最多 64 KiB；字典排序仍保留 canonical key 文本，工作内存不是常量。 调用期间必须保持输入结构不变，增量编码可能增加 CPU 开销。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待编码的纯 Variant 数据。 |
| `options` | 与 sha256() 相同的编码选项和预算。 |

返回：与 sha256() 相同的 SHA-256 hex 字符串；失败时返回空字符串。

结构：

- `value`: Variant value supported by `to_canonical_value()`.
- `options`: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.

<a id="member-gfdeterministicvariantserializer-methods-measure_canonical"></a>

### `measure_canonical`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func measure_canonical(value: Variant, options: Dictionary = {}) -> Dictionary:
```

只读预检规范编码的输入预算和精确输出字节数，不构建完整 typed tree 或输出文本，也不输出错误。 调用期间必须保持输入结构不变；报告不为后续已修改的数据提供编码资格。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待测量的纯 Variant 数据。 |
| `options` | 与规范 bytes 和 SHA-256 相同的编码选项和预算。 |

返回：预检报告；成功时计数精确，失败时计数仅描述已遍历部分，不能视为完整输入或输出的大小。

结构：

- `value`: Variant value supported by `to_canonical_value()`.
- `options`: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.
- `return`: Closed Dictionary with ok: bool, error: String, failure_kind: String (empty, input_invalid, or output_limit), items: int (Variant nodes plus packed elements), packed_items: int (packed elements only), and output_bytes: int (exact on success; partial and capped by max_output_bytes on failure).
