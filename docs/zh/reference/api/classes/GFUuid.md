# GFUuid

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/identity/gf_uuid.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.19.0`

通用 UUID 生成与校验工具。 只处理 RFC 4122 形态的字符串标识，不绑定存档、分析、网络请求或编辑器资源语义。 v4 适合匿名随机标识，v7 适合需要大致按生成时间排序的标识；同一进程、同一毫秒内的 v7 会写入递增序列以保证 canonical 字符串严格递增。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`BYTE_COUNT`](#member-gfuuid-constants-byte_count) | `const BYTE_COUNT: int = 16` |
| 常量 | [`CANONICAL_LENGTH`](#member-gfuuid-constants-canonical_length) | `const CANONICAL_LENGTH: int = 36` |
| 方法 | [`generate_v4`](#member-gfuuid-methods-generate_v4) | `static func generate_v4() -> String:` |
| 方法 | [`generate_v7`](#member-gfuuid-methods-generate_v7) | `static func generate_v7(unix_time_msec: int = -1) -> String:` |
| 方法 | [`is_valid`](#member-gfuuid-methods-is_valid) | `static func is_valid(value: String, version: int = 0) -> bool:` |

## 常量

<a id="member-gfuuid-constants-byte_count"></a>

### `BYTE_COUNT`

- API：`public`

```gdscript
const BYTE_COUNT: int = 16
```

UUID 字节长度。

<a id="member-gfuuid-constants-canonical_length"></a>

### `CANONICAL_LENGTH`

- API：`public`

```gdscript
const CANONICAL_LENGTH: int = 36
```

UUID 规范字符串长度。

## 方法

<a id="member-gfuuid-methods-generate_v4"></a>

### `generate_v4`

- API：`public`

```gdscript
static func generate_v4() -> String:
```

生成随机 UUID v4。

返回：小写 canonical UUID 字符串。

<a id="member-gfuuid-methods-generate_v7"></a>

### `generate_v7`

- API：`public`

```gdscript
static func generate_v7(unix_time_msec: int = -1) -> String:
```

生成时间有序 UUID v7。

参数：

| 名称 | 说明 |
|---|---|
| `unix_time_msec` | Unix epoch 毫秒；小于 0 时使用系统当前时间。 |

返回：小写 canonical UUID 字符串。

<a id="member-gfuuid-methods-is_valid"></a>

### `is_valid`

- API：`public`

```gdscript
static func is_valid(value: String, version: int = 0) -> bool:
```

判断字符串是否为 canonical UUID。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待校验字符串。 |
| `version` | 可选版本过滤；0 表示接受任意版本。 |

返回：字符串符合 canonical UUID 形态且版本匹配时返回 true。
