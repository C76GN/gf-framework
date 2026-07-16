# GFVariantKeyCodec

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_variant_key_codec.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

稳定 Variant key token 编码器。 用于缓存、索引、查询签名和异步 keyed gate 等底层设施，把可稳定比较的 Variant 明确编码为 token。默认只接受稳定、有限、不可变语义明确的值； Array、Dictionary、Object、Resource、Callable、RID、Signal 和非有限 float 会被拒绝。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_stable_key`](#member-gfvariantkeycodec-methods-is_stable_key) | `static func is_stable_key(value: Variant) -> bool:` |
| 方法 | [`try_make_key_token`](#member-gfvariantkeycodec-methods-try_make_key_token) | `static func try_make_key_token(value: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_key_token`](#member-gfvariantkeycodec-methods-make_key_token) | `static func make_key_token(value: Variant, options: Dictionary = {}) -> String:` |

## 方法

<a id="member-gfvariantkeycodec-methods-is_stable_key"></a>

### `is_stable_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func is_stable_key(value: Variant) -> bool:
```

判断值是否可以作为稳定 key。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待检查的 Variant。 |

返回：值可稳定编码时返回 true。

结构：

- `value`: Variant key candidate.

<a id="member-gfvariantkeycodec-methods-try_make_key_token"></a>

### `try_make_key_token`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func try_make_key_token(value: Variant, options: Dictionary = {}) -> Dictionary:
```

尝试把 Variant 编码为稳定 key token。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待编码的 key 值。 |
| `options` | 保留给未来扩展；当前不解释。 |

返回：编码报告。

结构：

- `value`: Variant key candidate.
- `options`: Dictionary reserved for future key encoding options.
- `return`: Dictionary with ok, key_token, value_type, and reason.

<a id="member-gfvariantkeycodec-methods-make_key_token"></a>

### `make_key_token`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_key_token(value: Variant, options: Dictionary = {}) -> String:
```

把 Variant 编码为稳定 key token；不可编码时返回空字符串。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待编码的 key 值。 |
| `options` | 传给 try_make_key_token() 的编码选项。 |

返回：稳定 key token，失败时为空字符串。

结构：

- `value`: Variant key candidate.
- `options`: Dictionary reserved for future key encoding options.
