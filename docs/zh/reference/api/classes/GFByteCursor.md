# GFByteCursor

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/binary/gf_byte_cursor.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`7.0.0`

PackedByteArray 读写游标。 提供边界检查、显式字节序和 varuint 编码，适合网络包、存档片段、 二进制配置或工具导入器复用。它只处理字节游标，不规定协议字段或消息语义。 一次公开操作失败时不会推进位置或发布部分写入；成功操作会把最近错误重置为 OK。 返回 void 的写入方法失败后，调用方必须立即读取 get_last_error()。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`little_endian`](#member-gfbytecursor-properties-little_endian) | `var little_endian: bool = false` |
| 属性 | [`max_read_byte_count`](#member-gfbytecursor-properties-max_read_byte_count) | `var max_read_byte_count: int = _DEFAULT_MAX_READ_BYTE_COUNT` |
| 属性 | [`max_write_byte_count`](#member-gfbytecursor-properties-max_write_byte_count) | `var max_write_byte_count: int = _DEFAULT_MAX_WRITE_BYTE_COUNT` |
| 方法 | [`_init`](#member-gfbytecursor-methods-_init) | `func _init(source_bytes: PackedByteArray = PackedByteArray(), p_little_endian: bool = false) -> void:` |
| 方法 | [`from_bytes`](#member-gfbytecursor-methods-from_bytes) | `static func from_bytes(source_bytes: PackedByteArray, offset: int = 0, p_little_endian: bool = false) -> GFByteCursor:` |
| 方法 | [`reset`](#member-gfbytecursor-methods-reset) | `func reset(source_bytes: PackedByteArray = PackedByteArray()) -> void:` |
| 方法 | [`get_bytes`](#member-gfbytecursor-methods-get_bytes) | `func get_bytes() -> PackedByteArray:` |
| 方法 | [`get_position`](#member-gfbytecursor-methods-get_position) | `func get_position() -> int:` |
| 方法 | [`set_position`](#member-gfbytecursor-methods-set_position) | `func set_position(offset: int) -> bool:` |
| 方法 | [`size`](#member-gfbytecursor-methods-size) | `func size() -> int:` |
| 方法 | [`remaining`](#member-gfbytecursor-methods-remaining) | `func remaining() -> int:` |
| 方法 | [`is_eof`](#member-gfbytecursor-methods-is_eof) | `func is_eof() -> bool:` |
| 方法 | [`has_bytes`](#member-gfbytecursor-methods-has_bytes) | `func has_bytes(byte_count: int) -> bool:` |
| 方法 | [`read_u8`](#member-gfbytecursor-methods-read_u8) | `func read_u8() -> int:` |
| 方法 | [`read_i8`](#member-gfbytecursor-methods-read_i8) | `func read_i8() -> int:` |
| 方法 | [`try_read_u8`](#member-gfbytecursor-methods-try_read_u8) | `func try_read_u8() -> Dictionary:` |
| 方法 | [`try_read_i8`](#member-gfbytecursor-methods-try_read_i8) | `func try_read_i8() -> Dictionary:` |
| 方法 | [`read_u16`](#member-gfbytecursor-methods-read_u16) | `func read_u16() -> int:` |
| 方法 | [`read_i16`](#member-gfbytecursor-methods-read_i16) | `func read_i16() -> int:` |
| 方法 | [`try_read_u16`](#member-gfbytecursor-methods-try_read_u16) | `func try_read_u16() -> Dictionary:` |
| 方法 | [`try_read_i16`](#member-gfbytecursor-methods-try_read_i16) | `func try_read_i16() -> Dictionary:` |
| 方法 | [`read_u32`](#member-gfbytecursor-methods-read_u32) | `func read_u32() -> int:` |
| 方法 | [`read_i32`](#member-gfbytecursor-methods-read_i32) | `func read_i32() -> int:` |
| 方法 | [`try_read_u32`](#member-gfbytecursor-methods-try_read_u32) | `func try_read_u32() -> Dictionary:` |
| 方法 | [`try_read_i32`](#member-gfbytecursor-methods-try_read_i32) | `func try_read_i32() -> Dictionary:` |
| 方法 | [`read_var_uint`](#member-gfbytecursor-methods-read_var_uint) | `func read_var_uint() -> int:` |
| 方法 | [`try_read_var_uint`](#member-gfbytecursor-methods-try_read_var_uint) | `func try_read_var_uint() -> Dictionary:` |
| 方法 | [`read_bytes`](#member-gfbytecursor-methods-read_bytes) | `func read_bytes(byte_count: int) -> PackedByteArray:` |
| 方法 | [`try_read_bytes`](#member-gfbytecursor-methods-try_read_bytes) | `func try_read_bytes(byte_count: int) -> Dictionary:` |
| 方法 | [`to_json_compatible_read_report`](#member-gfbytecursor-methods-to_json_compatible_read_report) | `static func to_json_compatible_read_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`read_utf8`](#member-gfbytecursor-methods-read_utf8) | `func read_utf8(byte_count: int) -> String:` |
| 方法 | [`try_read_utf8`](#member-gfbytecursor-methods-try_read_utf8) | `func try_read_utf8(byte_count: int) -> Dictionary:` |
| 方法 | [`read_var_utf8`](#member-gfbytecursor-methods-read_var_utf8) | `func read_var_utf8() -> String:` |
| 方法 | [`try_read_var_utf8`](#member-gfbytecursor-methods-try_read_var_utf8) | `func try_read_var_utf8() -> Dictionary:` |
| 方法 | [`write_u8`](#member-gfbytecursor-methods-write_u8) | `func write_u8(value: int) -> void:` |
| 方法 | [`write_i8`](#member-gfbytecursor-methods-write_i8) | `func write_i8(value: int) -> void:` |
| 方法 | [`write_u16`](#member-gfbytecursor-methods-write_u16) | `func write_u16(value: int) -> void:` |
| 方法 | [`write_i16`](#member-gfbytecursor-methods-write_i16) | `func write_i16(value: int) -> void:` |
| 方法 | [`write_u32`](#member-gfbytecursor-methods-write_u32) | `func write_u32(value: int) -> void:` |
| 方法 | [`write_i32`](#member-gfbytecursor-methods-write_i32) | `func write_i32(value: int) -> void:` |
| 方法 | [`write_var_uint`](#member-gfbytecursor-methods-write_var_uint) | `func write_var_uint(value: int) -> bool:` |
| 方法 | [`write_bytes`](#member-gfbytecursor-methods-write_bytes) | `func write_bytes(value: PackedByteArray) -> void:` |
| 方法 | [`write_utf8`](#member-gfbytecursor-methods-write_utf8) | `func write_utf8(value: String) -> void:` |
| 方法 | [`write_var_utf8`](#member-gfbytecursor-methods-write_var_utf8) | `func write_var_utf8(value: String) -> bool:` |
| 方法 | [`get_last_error`](#member-gfbytecursor-methods-get_last_error) | `func get_last_error() -> Error:` |
| 方法 | [`clear_error`](#member-gfbytecursor-methods-clear_error) | `func clear_error() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfbytecursor-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfbytecursor-properties-little_endian"></a>

### `little_endian`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var little_endian: bool = false
```

是否使用小端读写多字节整数。false 表示大端。

<a id="member-gfbytecursor-properties-max_read_byte_count"></a>

### `max_read_byte_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_read_byte_count: int = _DEFAULT_MAX_READ_BYTE_COUNT
```

单次公开读取允许的最大字节数。复合字段包含前缀与 payload；小于等于 0 表示不限制。 该属性不限制游标总长度或整条消息累计读取量。

<a id="member-gfbytecursor-properties-max_write_byte_count"></a>

### `max_write_byte_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_write_byte_count: int = _DEFAULT_MAX_WRITE_BYTE_COUNT
```

单次公开写入允许的最大字节数。复合字段包含前缀与 payload；小于等于 0 表示不限制。 该属性不限制游标总长度或整条消息累计写入量。

## 方法

<a id="member-gfbytecursor-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func _init(source_bytes: PackedByteArray = PackedByteArray(), p_little_endian: bool = false) -> void:
```

构造字节游标。

参数：

| 名称 | 说明 |
|---|---|
| `source_bytes` | 初始字节。 |
| `p_little_endian` | 是否使用小端。 |

<a id="member-gfbytecursor-methods-from_bytes"></a>

### `from_bytes`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func from_bytes(source_bytes: PackedByteArray, offset: int = 0, p_little_endian: bool = false) -> GFByteCursor:
```

从字节创建游标。

参数：

| 名称 | 说明 |
|---|---|
| `source_bytes` | 初始字节。 |
| `offset` | 初始位置。 |
| `p_little_endian` | 是否使用小端。 |

返回：新游标。

<a id="member-gfbytecursor-methods-reset"></a>

### `reset`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func reset(source_bytes: PackedByteArray = PackedByteArray()) -> void:
```

替换内部字节并重置位置。

参数：

| 名称 | 说明 |
|---|---|
| `source_bytes` | 新字节。 |

<a id="member-gfbytecursor-methods-get_bytes"></a>

### `get_bytes`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_bytes() -> PackedByteArray:
```

获取字节副本。

返回：当前字节副本。

<a id="member-gfbytecursor-methods-get_position"></a>

### `get_position`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_position() -> int:
```

获取当前位置。

返回：当前位置。

<a id="member-gfbytecursor-methods-set_position"></a>

### `set_position`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func set_position(offset: int) -> bool:
```

设置当前位置。

参数：

| 名称 | 说明 |
|---|---|
| `offset` | 新位置。 |

返回：设置成功返回 true。

<a id="member-gfbytecursor-methods-size"></a>

### `size`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func size() -> int:
```

获取总字节数。

返回：总长度。

<a id="member-gfbytecursor-methods-remaining"></a>

### `remaining`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func remaining() -> int:
```

获取剩余可读字节数。

返回：剩余长度。

<a id="member-gfbytecursor-methods-is_eof"></a>

### `is_eof`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_eof() -> bool:
```

是否已经到达末尾。

返回：到达末尾返回 true。

<a id="member-gfbytecursor-methods-has_bytes"></a>

### `has_bytes`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_bytes(byte_count: int) -> bool:
```

检查是否还能读取指定长度。

参数：

| 名称 | 说明 |
|---|---|
| `byte_count` | 字节数。 |

返回：可读取返回 true。

<a id="member-gfbytecursor-methods-read_u8"></a>

### `read_u8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_u8() -> int:
```

读取一个无符号 8 位整数。

返回：读取到的值；越界时返回 0。

<a id="member-gfbytecursor-methods-read_i8"></a>

### `read_i8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_i8() -> int:
```

读取一个有符号 8 位整数。

返回：读取到的值；越界时返回 0。

<a id="member-gfbytecursor-methods-try_read_u8"></a>

### `try_read_u8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_u8() -> Dictionary:
```

尝试读取一个无符号 8 位整数，并返回结构化报告。

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-try_read_i8"></a>

### `try_read_i8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_i8() -> Dictionary:
```

尝试读取一个有符号 8 位整数，并返回结构化报告。

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-read_u16"></a>

### `read_u16`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_u16() -> int:
```

读取一个无符号 16 位整数。

返回：读取到的值；越界时返回 0。

<a id="member-gfbytecursor-methods-read_i16"></a>

### `read_i16`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_i16() -> int:
```

读取一个有符号 16 位整数。

返回：读取到的值；越界时返回 0。

<a id="member-gfbytecursor-methods-try_read_u16"></a>

### `try_read_u16`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_u16() -> Dictionary:
```

尝试读取一个无符号 16 位整数，并返回结构化报告。

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-try_read_i16"></a>

### `try_read_i16`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_i16() -> Dictionary:
```

尝试读取一个有符号 16 位整数，并返回结构化报告。

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-read_u32"></a>

### `read_u32`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_u32() -> int:
```

读取一个无符号 32 位整数。

返回：读取到的值；越界时返回 0。

<a id="member-gfbytecursor-methods-read_i32"></a>

### `read_i32`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_i32() -> int:
```

读取一个有符号 32 位整数。

返回：读取到的值；越界时返回 0。

<a id="member-gfbytecursor-methods-try_read_u32"></a>

### `try_read_u32`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_u32() -> Dictionary:
```

尝试读取一个无符号 32 位整数，并返回结构化报告。

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-try_read_i32"></a>

### `try_read_i32`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_i32() -> Dictionary:
```

尝试读取一个有符号 32 位整数，并返回结构化报告。

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-read_var_uint"></a>

### `read_var_uint`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_var_uint() -> int:
```

读取 Godot int 可表达范围内的 varuint，使用 7-bit continuation 编码。

返回：读取到的值；损坏或越界时返回 0。

<a id="member-gfbytecursor-methods-try_read_var_uint"></a>

### `try_read_var_uint`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_var_uint() -> Dictionary:
```

尝试读取 Godot int 可表达范围内的 varuint，并返回结构化报告。

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-read_bytes"></a>

### `read_bytes`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_bytes(byte_count: int) -> PackedByteArray:
```

读取指定长度的字节。

参数：

| 名称 | 说明 |
|---|---|
| `byte_count` | 字节数。 |

返回：字节副本；越界时返回空数组。

<a id="member-gfbytecursor-methods-try_read_bytes"></a>

### `try_read_bytes`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_bytes(byte_count: int) -> Dictionary:
```

尝试读取指定长度的字节，并返回结构化报告。

参数：

| 名称 | 说明 |
|---|---|
| `byte_count` | 字节数。 |

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: PackedByteArray`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-to_json_compatible_read_report"></a>

### `to_json_compatible_read_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func to_json_compatible_read_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将读取报告转换为 JSON.stringify() 安全的诊断报告。 try_read_bytes() 会保留 PackedByteArray 作为功能返回值；日志、导出和跨进程诊断应使用该方法。

参数：

| 名称 | 说明 |
|---|---|
| `report` | try_read_*() 返回的读取报告。 |
| `options` | 编码选项，透传给 GFReportValueCodec。 |

返回：JSON-safe 读取报告。

结构：

- `report`: Dictionary raw byte cursor read report.
- `options`: Dictionary report value codec options.
- `return`: Dictionary safe for JSON.stringify().

<a id="member-gfbytecursor-methods-read_utf8"></a>

### `read_utf8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_utf8(byte_count: int) -> String:
```

读取 UTF-8 字符串。

参数：

| 名称 | 说明 |
|---|---|
| `byte_count` | 字节数。 |

返回：解码后的字符串。

<a id="member-gfbytecursor-methods-try_read_utf8"></a>

### `try_read_utf8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_utf8(byte_count: int) -> Dictionary:
```

尝试读取 UTF-8 字符串，并返回结构化报告。

参数：

| 名称 | 说明 |
|---|---|
| `byte_count` | 字节数。 |

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: String`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-read_var_utf8"></a>

### `read_var_utf8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func read_var_utf8() -> String:
```

读取 varuint 长度前缀的 UTF-8 字符串。

返回：解码后的字符串；长度或 UTF-8 校验失败时返回空字符串。

<a id="member-gfbytecursor-methods-try_read_var_utf8"></a>

### `try_read_var_utf8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_read_var_utf8() -> Dictionary:
```

尝试读取 varuint 长度前缀的 UTF-8 字符串，并返回结构化报告。

返回：读取报告。

结构：

- `return`: Dictionary with `ok: bool`, `value: String`, `error: int`, `position: int`, `next_position: int`.

<a id="member-gfbytecursor-methods-write_u8"></a>

### `write_u8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_u8(value: int) -> void:
```

写入一个无符号 8 位整数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入的值，范围为 0..255。 |

<a id="member-gfbytecursor-methods-write_i8"></a>

### `write_i8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_i8(value: int) -> void:
```

写入一个有符号 8 位整数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入的值，范围为 -128..127。 |

<a id="member-gfbytecursor-methods-write_u16"></a>

### `write_u16`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_u16(value: int) -> void:
```

写入一个无符号 16 位整数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入的值，范围为 0..65535。 |

<a id="member-gfbytecursor-methods-write_i16"></a>

### `write_i16`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_i16(value: int) -> void:
```

写入一个有符号 16 位整数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入的值，范围为 -32768..32767。 |

<a id="member-gfbytecursor-methods-write_u32"></a>

### `write_u32`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_u32(value: int) -> void:
```

写入一个无符号 32 位整数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入的值，范围为 0..4294967295。 |

<a id="member-gfbytecursor-methods-write_i32"></a>

### `write_i32`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_i32(value: int) -> void:
```

写入一个有符号 32 位整数。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入的值，范围为 -2147483648..2147483647。 |

<a id="member-gfbytecursor-methods-write_var_uint"></a>

### `write_var_uint`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_var_uint(value: int) -> bool:
```

写入 Godot int 可表达范围内的 varuint，使用 7-bit continuation 编码。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 非负整数。 |

返回：写入成功返回 true。

<a id="member-gfbytecursor-methods-write_bytes"></a>

### `write_bytes`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_bytes(value: PackedByteArray) -> void:
```

写入字节数组。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要追加的字节。 |

<a id="member-gfbytecursor-methods-write_utf8"></a>

### `write_utf8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_utf8(value: String) -> void:
```

写入 UTF-8 字符串。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入的字符串。 |

<a id="member-gfbytecursor-methods-write_var_utf8"></a>

### `write_var_utf8`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func write_var_utf8(value: String) -> bool:
```

写入 varuint 长度前缀的 UTF-8 字符串。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入的字符串。 |

返回：写入成功返回 true。

<a id="member-gfbytecursor-methods-get_last_error"></a>

### `get_last_error`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_last_error() -> Error:
```

获取最近一次操作的错误码。 任一后续成功操作都会把该值重置为 OK；void 写入方法的调用方必须在下一次操作前读取。

返回：最近错误码。

<a id="member-gfbytecursor-methods-clear_error"></a>

### `clear_error`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_error() -> void:
```

清除最近错误码。

<a id="member-gfbytecursor-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 size、position、remaining、little_endian 和 last_error。
