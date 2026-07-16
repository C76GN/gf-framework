# 值索引与变更批次

`GFValueIndex` 是轻量多字段索引。调用方把任意 `item_id`、值和字段字典写进去，再按字段值查询匹配条目。字段值可以是单值、`Array` 或 `PackedStringArray`；索引只维护查找结构，不解释字段语义，也不持有全局注册表。

字段值应使用稳定、不可变、可比较的 Variant 值，例如 String、StringName、int、float、bool、NodePath、Vector 或 Color。`Dictionary`、`Array`、Object/Resource、Callable 和非有限浮点不会作为索引字段写入；失败写入不会移除已有条目，避免外部可变值让旧索引残留。

```gdscript
var index := GFValueIndex.new()
index.set_item(&"entry_a", { "score": 1 }, {
	"tag": ["fast", "visible"],
	"tier": 1,
})

var fast_ids := index.query(&"tag", "fast")
var tier_ids := index.query_many({
	"tag": "fast",
	"tier": 1,
})
```

## 变更批次

`GFMutationBatch` 把一组 `Callable` 作为可提交、可回滚的批次执行。它适合编辑器工具、导入流程、资源批处理或项目自己的事务边界；框架只管理顺序、结果归一化和反向回滚，不知道操作修改的是资源、存档、场景还是内存模型。

```gdscript
var batch := GFMutationBatch.new()
batch.add_operation(
	func() -> Dictionary:
		model["value"] = 10
		return { "ok": true },
	func() -> void:
		model["value"] = 0
)

var result := batch.commit()
if not result["ok"]:
	batch.rollback_committed()
```

`GFMutationBatch` 默认在失败时停止并保留失败操作，便于调用方修正后重试；如果项目希望失败后继续处理后续操作，可关闭 `stop_on_error`。回滚只调用已提交操作的 rollback，不假设操作具备天然可逆性，因此可逆边界应由调用方显式提供。

提交或回滚前会复验对应 `Callable` 是否仍有效。提交回调失效会作为 `invalid_callable` 失败并按 `stop_on_error` 保留待处理项；回滚回调失效会作为失败保留在 committed 栈中，不会被当成“没有配置 rollback”的跳过项。
