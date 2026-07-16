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
| `options` | 可选项。支持 allow_floats、max_depth、max_items、max_string_length 和 max_output_bytes。 |

返回：规范化后的 JSON 兼容 Variant；失败时返回 null 并输出错误。

结构：

- `value`: Variant value made from nil, bool, int, String, StringName, NodePath, integer vectors, arrays, dictionaries and packed scalar arrays. Float-based values require `options.allow_floats = true`.
- `options`: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.
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

计算 Variant 规范编码的 SHA-256。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待编码的 Variant。 |
| `options` | 可选项。 |

返回：SHA-256 hex 字符串；失败时返回空字符串。

结构：

- `value`: Variant value supported by `to_canonical_value()`.
- `options`: Dictionary with optional allow_floats, max_depth, max_items, max_string_length, and max_output_bytes limits.
