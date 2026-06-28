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

## 使用边界

`GFByteCursor` 不定义包头、消息 ID、校验和、压缩、加密或版本迁移。项目应在自己的协议层声明字段顺序、兼容规则和安全策略，再用游标处理底层字节读写。
