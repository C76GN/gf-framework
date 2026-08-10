# 字节游标

`GFByteCursor` 为 `PackedByteArray` 提供带边界检查的位置游标。它适合协议包、二进制配置片段、导入器缓存和 golden 测试中重复读写整数、变长整数、字节片段或 UTF-8 文本。

## 典型流程

```gdscript
var cursor := GFByteCursor.new()
cursor.write_u16(0x1234)
cursor.write_var_uint(300)
cursor.write_utf8("ok")

var reader := GFByteCursor.from_bytes(cursor.get_bytes())
var magic := reader.read_u16()
var count := reader.read_var_uint()
var label := reader.read_utf8(2)
```

默认使用大端；需要小端时在构造或 `from_bytes()` 中传入 `true`。越界读取会返回零值或空数组，并把 `get_last_error()` 设为 `ERR_FILE_EOF`。

需要区分“真实读到了默认值”和“读取失败”时，使用 `try_read_*()` 系列入口。报告包含 `ok`、`value`、`error`、`position` 和 `next_position`；失败读取会回滚到调用前位置，并保留稳定错误码。字符串字段可用 `write_var_utf8()` / `try_read_var_utf8()` 写入和读取 varuint 长度前缀的 UTF-8 文本。

`try_read_bytes()` 的 `value` 会保留原始 `PackedByteArray`，方便协议层继续处理字节数据。需要把读取报告写入 JSON 日志、CI 结果或跨进程诊断时，先调用 `GFByteCursor.to_json_compatible_read_report(report)`，不要直接把包含 PackedArray 或非有限数值的报告交给 `JSON.stringify()`。

## 错误与原子性

一次公开字段操作是最小提交单元：读取失败不会推进 position，写入失败不会修改 bytes 或 position。`write_var_uint()` / `write_var_utf8()` 会直接返回成功状态；`write_u8()`、`write_i8()`、`write_u16()`、`write_i16()`、`write_u32()`、`write_i32()`、`write_bytes()` 与 `write_utf8()` 返回 `void`，调用方必须在下一次游标操作前立即读取 `get_last_error()`。`last_error` 描述最近一次操作，后续成功操作会把它重置为 `OK`，它不是 sticky 的事务错误汇总。

固定宽度写入不会截断越界整数：无符号 8/16/32 位范围分别为 `0..255`、`0..65535`、`0..4294967295`，有符号范围分别为 `-128..127`、`-32768..32767`、`-2147483648..2147483647`。超出范围会以 `ERR_INVALID_PARAMETER` 原子拒绝。

## 单次字节预算

`max_read_byte_count` 和 `max_write_byte_count` 约束一次公开操作的总字节数；小于等于 0 表示不限制。复合字段必须把长度前缀与 payload 合计，例如 var UTF-8 的限制是 `varuint_prefix_bytes + utf8_payload_bytes`，不能把两个内部步骤分别套用同一个上限。

这两个属性不是游标总容量或整条消息预算。处理不可信字段数量时，协议层仍应独立限制消息总字节数、字段数和循环次数；不要因为每次写入都低于单次上限，就把可无限增长的游标当作已有总容量保护。

## 使用边界

`GFByteCursor` 不定义包头、消息 ID、校验和、压缩、加密或版本迁移。项目应在自己的协议层声明字段顺序、兼容规则和安全策略，再用游标处理底层字节读写。
