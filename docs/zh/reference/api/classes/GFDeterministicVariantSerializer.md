# GFDeterministicVariantSerializer

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

有界纯数据的 canonical v2 二进制编码。 哈希、计量和字节导出使用同一遍历；成功报告计数精确，失败不发布部分摘要或字节。 输入可为调用期间稳定的纯 Variant 或 GFDataSnapshot。别名按值展开，循环和对象被拒绝。 浮点默认禁用；启用后拒绝非有限值并归一负零，不保证数值运算本身跨平台一致。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`CANONICAL_VERSION`](#member-gfdeterministicvariantserializer-constants-canonical_version) | `const CANONICAL_VERSION: int = 2` |
| 方法 | [`hash_result`](#member-gfdeterministicvariantserializer-methods-hash_result) | `static func hash_result(value: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`encode_result`](#member-gfdeterministicvariantserializer-methods-encode_result) | `static func encode_result(value: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`measure_canonical`](#member-gfdeterministicvariantserializer-methods-measure_canonical) | `static func measure_canonical(value: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`sha256`](#member-gfdeterministicvariantserializer-methods-sha256) | `static func sha256(value: Variant, options: Dictionary = {}) -> String:` |
| 方法 | [`to_canonical_bytes`](#member-gfdeterministicvariantserializer-methods-to_canonical_bytes) | `static func to_canonical_bytes(value: Variant, options: Dictionary = {}) -> PackedByteArray:` |

## 常量

<a id="member-gfdeterministicvariantserializer-constants-canonical_version"></a>

### `CANONICAL_VERSION`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
const CANONICAL_VERSION: int = 2
```

与哈希一同持久化的编码版本；v2 与旧 JSON 摘要不相同。

## 方法

<a id="member-gfdeterministicvariantserializer-methods-hash_result"></a>

### `hash_result`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
static func hash_result(value: Variant, options: Dictionary = {}) -> Dictionary:
```

单次遍历生成 SHA-256 及完整计量，不复制源树或构建完整输出。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 稳定的纯数据或已捕获快照。 |
| `options` | 编码政策及有限预算。 |

返回：失败时 hash 为空且 counts_complete 为 false；所有入口均不输出错误日志。

结构：

- `value`: Scalar, math, String, StringName, NodePath, Array, Dictionary, packed arrays, or GFDataSnapshot. Objects, executable values, RID and cycles are rejected.
- `options`: Dictionary with allow_floats: bool (false), positive max_depth (64, at most 256), max_items (100000), max_string_length (1048576 characters), max_output_bytes (16777216 canonical bytes), max_sort_bytes (16777216 logical sorting workspace bytes), max_elapsed_msec (30000), and optional cancel_token: GFCancellationToken.
- `return`: Dictionary with ok, canonical_version, hash, bytes, counts_complete, items, packed_items, output_bytes, maximum_depth, peak_sort_bytes, error, error_kind, error_path, failure_kind, limit_kind, limit, observed and observed_is_lower_bound. Failure counters describe processed input only. bytes is empty in hash and measurement modes.

<a id="member-gfdeterministicvariantserializer-methods-encode_result"></a>

### `encode_result`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
static func encode_result(value: Variant, options: Dictionary = {}) -> Dictionary:
```

单次遍历导出完整 canonical v2 字节及相同计量；受输出预算约束。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 纯数据或已捕获快照。 |
| `options` | 编码政策及预算。 |

返回：成功时 bytes 包含完整编码，hash 为空。

结构：

- `value`: Same input domain as hash_result.
- `options`: Same options as hash_result.
- `return`: Same result fields as hash_result, with bytes: PackedByteArray.

<a id="member-gfdeterministicvariantserializer-methods-measure_canonical"></a>

### `measure_canonical`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
static func measure_canonical(value: Variant, options: Dictionary = {}) -> Dictionary:
```

只计量规范编码，不生成摘要或完整字节，也不授予后续编码资格。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 调用期间稳定的纯数据或快照。 |
| `options` | 编码政策和预算。 |

返回：成功时字节数精确，失败立即停止；字典排序仍使用有界工作区。

结构：

- `value`: Same input domain as hash_result.
- `options`: Same options as hash_result.
- `return`: Same result fields as hash_result, with empty hash and bytes.

<a id="member-gfdeterministicvariantserializer-methods-sha256"></a>

### `sha256`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func sha256(value: Variant, options: Dictionary = {}) -> String:
```

返回 canonical v2 SHA-256；需要失败诊断时使用 hash_result。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 纯数据或快照。 |
| `options` | 编码政策和预算。 |

返回：成功时返回摘要，失败返回空字符串。

结构：

- `value`: Same input domain as hash_result.
- `options`: Same options as hash_result.

<a id="member-gfdeterministicvariantserializer-methods-to_canonical_bytes"></a>

### `to_canonical_bytes`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func to_canonical_bytes(value: Variant, options: Dictionary = {}) -> PackedByteArray:
```

返回完整 canonical v2 字节；需要失败诊断时使用 encode_result。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 纯数据或快照。 |
| `options` | 编码政策和预算。 |

返回：成功时返回二进制编码，失败返回空数组。

结构：

- `value`: Same input domain as hash_result.
- `options`: Same options as hash_result.
