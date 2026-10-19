# 表合并与构建 Profile

如果项目需要对基础表应用补丁表，可以使用 `GFConfigTableMergePolicy` 和 `GFConfigTableMergeTools`。默认策略按 `id` 生成记录键，支持插入、更新、删除标记和嵌套 Dictionary 字段合并。

项目可以改用复合 key、Dictionary 外层 key、整条替换或禁用插入/删除。它只处理通用表结构，不决定补丁来自热更、编辑器覆盖、模组还是构建步骤。

Dictionary 输出中，不同逻辑记录不能占用同一个外层 key。插入发生这种冲突时，结果包含 `outer_key_collision` 错误；不会通过覆盖外层槽位静默丢失记录。合并发生任一错误时 `ok` 为 `false`、`data` 为 `null`，输入保持不变，计数仅用于诊断。

传给自定义 `make_record_key()`、`is_delete_record()` 和 `merge_record()` 的记录、外层键及其嵌套 Array / Dictionary 容器在预算准入后复制。策略修改这些容器不会回写调用方输入，即使后续记录导致整批合并失败。Resource 仍保留叶引用，策略不得修改其内部状态。

`MERGE_FIELDS` 递归合并同名 Dictionary。`GFConfigWorkBudget` 在复制前准入数据图，拒绝循环、超深及超量输入，并对重复遍历累计工作量与字符串/Packed 载荷。`merge_tables()` 的第四个参数接受 `work_limits` 或共享 `work_budget`，默认值与[直接导入预算](../validation-importer/json-csv-import.md#工作预算与批次)一致；结果中的 `budget_report` 提供本次累计用量和首次预算错误。合并只构造数据图，载荷计入 `value_bytes`，不计原文 `input_bytes` 或序列化 `output_bytes`。共享子容器允许存在，Resource 按叶引用保留；该预算不统计 Resource 内部属性或引擎全部内存。

记录键的各个分量只接受 String、StringName、int、bool 和有限 float；复合键使用类型和长度区分边界，不通过对象序列化构造身份。复杂业务身份应先转换为稳定标量。`make_record_key()` 的编码格式已经改变，持久化过旧键的项目须从原始 ID 重新生成，不能混用两种编码。直接调用 `merge_record()` 时，同样检查结果的 `ok` 后再读取 `data`，不能把返回报告当成记录。

```gdscript
var policy := GFConfigTableMergePolicy.new()
policy.key_fields = PackedStringArray(["id"])
policy.update_mode = GFConfigTableMergePolicy.UpdateMode.MERGE_FIELDS

var merged := GFConfigTableMergeTools.merge_tables(base_rows, patch_rows, policy)
if merged["ok"]:
	rows = merged["data"]
```

## 构建 Profile

多目标构建可以用 `GFConfigBuildProfile` 按 metadata 中的 groups/tags 过滤 schema 和记录。GF 不内置任何分端含义，`include_groups`、`exclude_groups`、`include_tags` 和 `exclude_tags` 的命名都由项目自己决定；记录级 metadata 默认读取 `_metadata` 字段，字段、索引、引用以及字段/记录/表校验规则读取各自的 `metadata`。同一个 `GFConfigValidationRule` 的裁剪语义不因挂在 column、record 或 table 层而改变；未写 profile metadata 的规则默认保留，避免默认 profile 意外删除基础安全约束。

```gdscript
var profile := GFConfigBuildProfile.new()
profile.include_groups = PackedStringArray(["runtime"])
profile.exclude_tags = PackedStringArray(["internal_only"])

var runtime_schema := profile.filter_schema(schema)
var runtime_rows := profile.filter_records(rows)
```
