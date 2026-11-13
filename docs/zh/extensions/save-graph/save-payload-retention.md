# 载荷保留政策

`GFSavePayloadPolicy` 描述当前程序能够解释的数据，以及明确允许往返保留的数据。它由
`GFSaveSectionProvider.payload_policy` 声明，首次注册时复制并锁定。没有政策的 Provider
继续接受 Save 原有的原生持久化值；不要求标量、数组或场景图载荷改成字典。

## 声明已知结构

使用 `GFSchemaField` 作为根，字典使用 `GFDictionarySchema`，数组使用 `array_item_schema`。
根字段名必须非空。政策拒绝隐式类型转换：已知字段类型不匹配时失败，修复需要显式迁移。
字段校验规则须为有界、无副作用的校验；运行状态应用和业务副作用仍属于 Provider。

```gdscript
var policy := GFSavePayloadPolicy.new()
policy.schema = root_field
policy.retained_fields = {
	"": PackedStringArray(["future_flags"]),
	"/items/*": PackedStringArray(["future_attributes"]),
}
policy.collections = {
	"/items": {
		"id_field": "content_id",
		"active_ids": [101, 102],
		"preserve_unknown": true,
	},
}
provider.payload_policy = policy
```

路径采用 JSON Pointer 的 `~0`、`~1` 转义；空路径表示根，独立 `*` 路径段表示数组元素。
`retained_fields` 的值列出该字典节点允许保留的未知字段，列表中的 `*` 明确允许该节点
全部未知字段。已声明为 `ANY` 或没有子 schema 的值属于项目明确声明的不透明已知子树。

集合必须声明必需、不可空的整数或文本身份字段。省略 `active_ids` 表示所有合法身份均
可用；显式列表只激活其中的身份。未激活条目只有在 `preserve_unknown` 为 true 时保留，
且不会进入运行投影。它们仍需满足可持久化值和身份类型检查。内容重新激活后，全部已知
结构重新校验，不能因为曾经作为不透明内容保存过就直接投入运行。

## 读取、回写与删除

读取时，Profile 保存独立的完整持久化基线，只把已知投影交给 Provider。基线归属于
Profile 和分区；多个档位共享同一个 Provider，也不会共享保留数据。回滚快照同时包含
运行数据和保留数据，Provider 回滚只接收已知投影。

回写时，当前已知值优先。已知字段或条目在当前候选中缺失表示删除，不从旧基线恢复。
数组依稳定 ID 关联保留字段，当前已知条目的顺序优先；旧未知条目沿原有的、仍存在的
后继条目插入，没有后继时放在末尾。无修改往返保持原顺序，重排不会把字段绑定到错误元素。

保留内容的缺失本身不表示删除。显式删除通过 `make_snapshot()`、`make_completed_snapshot()`
或 `GFSaveSectionMutation.take_ownership()` 的 `retention_deletions` 参数提交：

```gdscript
var deletions := {
	"": ["future_flags"],
	"/items": [9001],
}
deletions[GFSavePayloadPolicy.item_path("/items", 101)] = ["future_attributes"]
return make_completed_snapshot(runtime_payload, {}, deletions)
```

字典路径的列表表示保留字段名，集合路径的列表表示未激活内容 ID；元素路径由
`item_path()` 构造，不能用数组下标。删除只作用于保留内容，已知数据由当前候选决定。
指令不是业务 payload、元数据或持久化文档字段。快照和 Mutation 都接管指令所有权，
调用方必须同时放弃其中的嵌套别名。Mutation 的删除随事务应用，落盘失败时与运行状态
一起回滚；普通快照的删除在写入确认后提交。结果未知期间不能将删除当成已确认。

## 成本与边界

政策按完整载荷检查深度、节点数和规范编码字节，包含所有保留内容。默认上限为 32 层、
10000 节点、16 MiB，可在政策中调整到规定的硬上限。超过预算直接失败，不截断数据。
完整基线包含已知值，用来支持身份合并和回滚，因此额外占用内存；在途候选还会保有独立基线。

Provider 的快照构造继续使用协作式 Operation。政策的投影、验证和合并是主线程上按
分区执行的有界步骤，并不是逐节点分片；预算限制数据规模，不保证单次操作满足某个
毫秒上限。大型数据应按所有权划分分区，并测量候选准备、回滚和同时驻留的内存成本。
不要在 begin 回调中临时深复制大型数据，也不要把最坏规模预算当作推荐运行规模。

保留不是上传权限。云同步仍需独立声明上传字段，且未来文档格式、未来已知 schema 版本、
资源对象、循环引用和非有限数都不能借保留政策进入有效存档。


## 预算预检与旧选项迁移

`policy.get_limits()` 读取当前有效预算，`policy.measure_payload(value)` 复用实际投影/合并的原生值和
预算准入，不生成 projection/baseline；已知字段结构仍须由 `project()` 验证。
未知整分区可用 `GFSaveDocumentSchema.get_preserved_section_limits()` 和
`measure_preserved_section(section)` 检查，允许保留的 ID 仍以 schema 为准。
同步确认快照可用 `GFSaveProfileUtility.get_sync_snapshot_limits()` 与 `measure_sync_snapshot(data)` 检查。
这些上限属于不同层，不能相加，也不能因本地载荷通过就认定远端请求可以容纳。
所有诊断包含 `ok/error_kind/path`；计量失败只报告已遍历部分，不复制非法数据，也不截断后继续保存。

旧 `allow_unknown_sections` 不能自动转换为一份安全的保留名单。Schema 的 `validate_configuration()`
可只读预检完整参数；`try_configure()` 原子应用并返回诊断。废弃键返回 `removed_option`，其他未知键
返回 `unknown_option`。旧 `configure()` 仍返回当前对象；失败时原字段不变，但对象被标为配置失败，
`validate_schema()`/`validate_document()` 不能成功，`to_dict()` 为空，直到使用合法参数重新配置。
仅进行只读预检不会改变当前对象。不要忽略配置错误后继续保存。

迁移时，旧 reject 对应空 `preserved_sections`；旧 preserve 要列出准确分区 ID，或把扩展内容设计为
一个已知容器；旧 drop 应改为项目明确的文档迁移。先保留源档位，不得把未知玩家数据悄悄丢弃。
