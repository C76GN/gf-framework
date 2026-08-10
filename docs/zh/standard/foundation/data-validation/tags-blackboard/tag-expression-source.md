# 标签表达式与来源适配

需要表达更复杂的组合条件时，用 `GFTagExpression` 组合多个 `GFTagQuery`。

```gdscript
var burning_enemy := GFTagExpression.from_query(
	GFTagQuery.new().configure([&"team.enemy", &"state.burning"])
)
var boss := GFTagExpression.from_query(
	GFTagQuery.new().configure([&"rank.boss"])
)

var target_rule := GFTagExpression.new().configure_any([burning_enemy, boss])
if target_rule.matches(tags):
	pass
```

`get_match_report()` 会同时给出 `valid` 与 `matched`：前者表示表达式图可以可靠求值，后者表示合法表达式的逻辑结果；只有两者都为 `true` 时 `ok` 才为 `true`。null、非 `GFTagExpression` Resource、循环、超过 32 层的直接 Resource 图和显式未知的序列化 operator 都会失败关闭，并通过 `reason`、`invalid_indices` 与嵌套 `child_reports` 保留证据。字典完全缺少 operator 时仍使用既有的 `QUERY` 默认；“字段缺失”不会与“字段存在但非法”混为一谈。

`GFTagSourceAdapter` 可读取 `GFTagSet`、`Array`、`PackedStringArray`、`Dictionary`，也可读取实现了 `has_tag()`、`get_tag_count()`、`get_tags()` 的对象。需要把不同来源汇入同一套规则时，先通过 `get_tag_counts()`、`to_tag_set()` 或 `merge_sources()` 规范化，再交给查询或表达式执行匹配。

```gdscript
var merged := GFTagSourceAdapter.merge_sources([
	unit_tags,
	equipment_tags,
	{ "tag_counts": { &"state.burning": 2 } },
])

if rule.matches(merged):
	pass
```

Array 与 `PackedStringArray` 的计数会在一次遍历中完成，再按标签排序输出，重复标签仍按出现次数累计。来源适配只负责把对象暴露为可查询标签视图，不规定标签命名、层级设计或匹配后的业务行为。
