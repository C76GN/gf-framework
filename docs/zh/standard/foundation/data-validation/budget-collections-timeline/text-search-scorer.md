# 文本检索评分

`GFTextSearchScorer` 是轻量文本匹配与排序工具。调用方传入查询文本和候选字典，评分器按字段权重计算匹配报告，再返回稳定排序结果。它只处理字符串、数组和字典中的候选字段，不扫描文件系统、不打开编辑器窗口，也不保存任何索引状态。

```gdscript
var candidates: Array[Dictionary] = [
	{
		"title": "Audio Bank",
		"keywords": ["import", "library"],
		"path": "res://audio/banks/main.tres",
	},
	{
		"title": "Save Slot",
		"keywords": ["profile"],
	},
]

var results := GFTextSearchScorer.rank_candidates("audio import", candidates)
var best := results[0]["candidate"]
```

## 字段权重

默认字段读取 `title`、`name`、`keywords`、`detail` 和 `path`，其中标题类字段权重更高。项目也可以通过 `fields` 传入自己的字段集合，字段值可以是 `String`、`StringName`、`Array` 或 `PackedStringArray`。

```gdscript
var results := GFTextSearchScorer.rank_candidates("dash cooldown", actions, {
	"fields": [
		{ "key": "display_name", "weight": 4.0 },
		{ "key": "tags", "weight": 2.0 },
		{ "key": "description", "weight": 1.0 },
	],
	"limit": 20,
})
```

`rank_candidates()` 返回的是匹配报告数组，而不是修改后的候选字典。每个报告包含 `matched`、`score`、`matched_tokens`、`field_scores`、`candidate` 和原始 `index`，这样不会覆盖项目候选里已有的 `score`、`rank` 或其它业务字段。

## 匹配规则

查询会按空格、路径符号、下划线、短横线和常见标点切成去重 token，并统一转成小写。评分会优先完整短语，其次是字段前缀、词前缀、包含匹配和子序列匹配。默认要求所有查询 token 都命中；如果项目想保留部分命中，可把 `require_all_tokens` 设为 `false`。

```gdscript
var partial := GFTextSearchScorer.rank_candidates("audio missing", candidates, {
	"require_all_tokens": false,
})
```

默认结果只包含命中的候选。需要在调用方 UI 中显示未命中项或调试空分数时，可以启用 `include_unmatched`。

## 使用边界

`GFTextSearchScorer` 适合命令面板、资源选择器、设置搜索、运行时列表过滤和项目自定义工具的基础评分。它不负责文件遍历、缓存失效、异步索引、编辑器快捷键、打开资源或高亮渲染；这些流程应由上层 Utility、Editor 插件或项目代码组合。

需要按精确字段值查询时优先使用 `GFValueIndex`；需要展示大量列表可见范围时使用 `GFVirtualListModel`；需要运行时控制台命令补全时由 `GFConsoleUtility` 负责 UI 和命令生命周期。
