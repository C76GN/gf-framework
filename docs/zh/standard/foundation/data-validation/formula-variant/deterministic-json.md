# 确定性 JSON

需要把纯数据导出为便于审查、比较和恢复的稳定文本时，使用 `encode_deterministic_result()` 与 `decode_deterministic_result()`。它们使用独立的 `gf.variant-json-deterministic` 格式，当前版本为 `1`；普通 JSON 兼容转换和 canonical v2 二进制序列化各自保持原有职责。

```gdscript
var encoded: Dictionary = GFVariantJsonCodec.encode_deterministic_result({
	"position": Vector3(1.0, 2.0, 3.0),
	"ids": PackedInt64Array([9223372036854775807]),
})
if not encoded.ok:
	print(encoded.error_kind, encoded.error_path, encoded.limit_kind)
	return
var text: String = encoded.text
var decoded: Dictionary = GFVariantJsonCodec.decode_deterministic_result(text)
if decoded.ok:
	var restored: Variant = decoded.value
	print(restored)
```

编码器固定两空格缩进、LF 换行和末尾 LF；按完整类型化键的紧凑编码排序 Dictionary，不使用 `str(key)` 或哈希摘要排序。输入插入顺序不影响成功输出。Array 顺序保留，String 不做 Unicode 规范化，String 与 StringName 保留不同类型。相同类型、值和容器类型声明产生相同文本；NaN 统一表示，负零归一为正零。

支持 null、bool、完整 int64、float、String、StringName、NodePath、全部内建数学值（含 Projection）、全部具体 PackedArray 类型，以及递归纯数据 Array / Dictionary。内建类型声明会保留，例如空 `Array[int]` 与普通空 Array 的文本不同。数学分量和 PackedFloat32 元素恢复时必须精确可表示，越界或精度损失返回失败。U+0000、孤立代理项等当前 Godot String 无法无损承载的文本被拒绝，其他合法 Unicode 标量可往返。

共享容器按出现位置独立展开，循环、Object、Resource、Callable、Signal、RID 以及声明 Object 类型的空容器被拒绝。编码过程不修改源数据；调用期间源树必须稳定。编码器也接受已就绪的 [GFDataSnapshot](variant-data-json.md#只读数据快照)，直接借用其只读树，不调用公开副本导出。解码成功返回独立可变树，保留类型声明，不恢复引用别名或只读标记。

## 文本协议 v1

根对象字段按 `format`、`version`、`value` 排列，null 的完整输出如下，结束大括号之后仍有一个 LF：

```json
{
  "format": "gf.variant-json-deterministic",
  "version": 1,
  "value": ["Nil"]
}
```

每个值使用显式类型节点，用户字典也编码为条目数组，因此业务字段不会碰撞协议标签。

| 值 | 节点结构 |
| --- | --- |
| null / bool | `["Nil"]` / `["Bool", true]` |
| int64 | `["Int64", "9223372036854775807"]`；十进制字符串不经过 JSON number |
| float | `["Float64", "1.0@000000000000f03f"]`；下述浮点文本规则 |
| String / StringName / NodePath | `["String", "text"]` 等；标签就是类型名 |
| 数学值 | `["Vector2", ["1.0@000000000000f03f", "0.0"]]` 等；整数分量为十进制字符串 |
| Array | `["Array", "Variant", [节点, ...]]`；类型化 Array 把 `Variant` 替换为元素类型标签 |
| Dictionary | `["Dictionary", "Variant", "Variant", [[键节点, 值节点], ...]]`；两个声明分别对应键、值类型 |
| PackedArray | `["PackedInt64Array", ["1", "2"]]` 等；元素省略重复类型标签，数学元素使用分量数组 |

类型标签采用上表及 Godot 内建数学、Packed 类型的固定名称，整数和浮点标量分别叫 `Int64`、`Float64`。容器声明用 `Variant` 表示未类型化；不接受脚本或对象类型名。数学分量按 x/y/z/w、position 后接 size、矩阵列顺序、basis 后接 origin 排列，与[二进制协议的分量顺序](../../scalars/deterministic-serialization.md#canonical-v2-字节协议)一致。

有限非零浮点文本由全精度十进制展示、`@` 和 16 位小写十六进制组成；十六进制是 IEEE 754 binary64 的小端字节。读取以位模式恢复精确值，再校验展示部分一致，不依赖十进制解析器处理极小数或舍入边界。零统一为 `"0.0"`，NaN 统一为 `"NaN"`，正负无穷为 `"+Inf"` / `"-Inf"`。PackedFloat32 元素按其已经量化的值提升为 binary64 表达，解码不得引入第二次舍入。

十进制展示使用 Godot 的全精度 JSON 数字格式，协议黄金测试约束当前支持的引擎；引擎升级必须核对这些向量，格式变化需要显式版本决策。文本格式不承诺不同平台的浮点计算产生相同输入，也不是 RFC 8785 JCS。

解码器允许 JSON 空白、合法字符串转义及未排序条目，随后重新编码会归一为固定输出。根字段顺序必须符合本协议，未知版本、额外字段、尾随内容、未知标签、错误载荷数量、重复键及无效 NodePath 都返回失败。重复键同时按原生字典等值和归一化键文本检查，防止静默覆盖。

## 预算、所有权与失败

| 选项 | 默认值 | 含义 |
| --- | ---: | --- |
| `max_items` | 100,000 | Variant 节点与 Packed 元素总数 |
| `max_depth` | 64 | 根为 0，最大允许配置为 256 |
| `max_key_depth` | 64 | 从最外层字典键根起计算的容器嵌套层数，最大 64；在原生字典哈希前拒绝过深复合键 |
| `max_string_length` | 1,048,576 | 单个数据字符串的字符数 |
| `max_output_bytes` | 16 MiB | 仅编码接受，最终文本 UTF-8 字节数，含缩进和末尾 LF |
| `max_input_bytes` | 16 MiB | 仅解码接受，输入文本 UTF-8 字节数 |
| `max_sort_bytes` | 16 MiB | 当前所有嵌套字典保留的逻辑排序工作区 |
| `max_elapsed_msec` | 30,000 | 整次同步操作经过的毫秒 |
| `cancel_token` | null | 可选 `GFCancellationToken` |

所有数值限制必须是正整数。未知选项、错误方向的字节选项和非法类型返回 `invalid_options`，不能用零或负数关闭限制。键子树中的嵌套字典值也计入 `max_key_depth`；普通值树仍可显式允许 256 层。

每个容器计一个节点；Dictionary 的实际键和值各自计数；Packed 元素在容器之外额外计入 `items` 和 `packed_items`，但不增加逻辑深度。协议包装、类型声明与数学分量不另计节点。输出前验证编码预算；解码先分块验证输入字节，再直接读取类型节点，不调用整份文本的 `JSON.parse()`，也不构建另一份通用 JSON 树。

排序工作区累计每条记录 128 逻辑字节，以及每个保留键文本字符 8 逻辑字节（覆盖构建和最终存储）；嵌套排序同时入账。编码器在写入值之前释放已经输出的键文本，解码器为重复检测保留当前字典的键文本。该计量连同节点、深度、输入/输出限制约束工作量，不代表精确的进程内存上限。时间与取消在有界步骤间检查，无法抢占原生字符串合并、排序或 Packed 转换。

两种结果都包含 `ok`、`format_id`、`format_version`、`counts_complete`、`items`、`packed_items`、`input_bytes`、`output_bytes`、`maximum_depth`、`peak_sort_bytes`、`error_kind`、`error_path`、`limit_kind`、`limit`、`observed`。编码另有 `text`，解码另有 `value`；方向不适用的字节计数为零。成功时 `counts_complete=true`；失败只描述已经处理的部分，并且 `text=""` 或 `value=null`，不发布部分结果。合法 null 也返回 `value=null`，调用方必须检查 `ok`。

首次失败决定报告，后续清理不覆盖原因。预算失败是 `limit_exceeded`，`observed` 为确定下界，整数边界时可能饱和。其他分类包括 `cancelled`、`cycle`、`unsupported_type`、`snapshot_unavailable`、`ambiguous_dictionary_key`、`duplicate_dictionary_key`、`type_mismatch`、`precision_loss`、`number_out_of_range` 及协议/文本校验错误。`error_path` 使用 `$[0].key`、`$[0].value` 这类结构位置，不拼入用户键文本；失败位置随访问顺序决定，不要求不同插入顺序产生相同错误路径。
