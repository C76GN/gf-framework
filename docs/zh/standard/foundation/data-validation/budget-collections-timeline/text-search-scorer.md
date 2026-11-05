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

Array 字段通过迭代式、identity-aware 遍历展开：self-cycle、双节点 cycle 和很深的无环数组都不会依赖递归调用栈，循环边会被跳过，其余有限文本仍可参与评分。字段 weight 必须为正有限数，并且乘权与累计结果也必须保持有限；无效或溢出的字段会失败关闭，不会把 NaN/Infinity 送入排序报告。

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

## 搜索排序

默认预设 `relevance` 将命中放在前面，按精确分数降序排列。精确同分时按小写标题（缺失时取 `name`）升序，同名再按原输入索引。旧版使用两两近似比较，升级后分数接近的候选可能换位。启用 `include_unmatched` 后，未命中项排在所有命中项之后，按名称和原输入索引排列。空查询或只含分隔符时没有命中，默认返回空数组。

名称浏览预设 `name_browse` 先按分数分档，高档优先。同档内只比较名称和原输入索引。默认档宽为 **100**，边界从零开始，左端包含、右端不包含。例如 3,100 至不足 3,200 分属于同一档，3,200 分属于再高一档。使用默认字段的标题样本中，搜索 `audio` 时 `UI Audio` 得 3,188 分，`Background Audio` 得 3,156 分，`Deep Underwater Environment Audio` 得 3,088 分。档宽 25 会把前两项拆开，500 会把三项全部合并。100 让前两项同档按名称浏览，第三项仍留在下一档。

```gdscript
# 资源选择器采用名称浏览预设，无需提供档宽。
var page := GFTextSearchScorer.rank_candidates("audio", candidates, {
	"sort_preset": "name_browse",
	"limit": 20,
})
```

评分尺度取决于字段权重。使用自定义权重的项目可以在名称浏览预设中设置正有限数 `band_width`，无效值回退到 100，未知预设采用精确排序。两种策略都先排列完整结果，再截取 `limit`。原输入顺序改变时，同分同名候选的先后也可能改变。

## 使用边界

`GFTextSearchScorer` 适合命令面板、资源选择器、设置搜索、运行时列表过滤和项目自定义工具的基础评分。它不负责文件遍历、缓存失效、异步索引、编辑器快捷键、打开资源或高亮渲染；这些流程应由上层 Utility、Editor 插件或项目代码组合。

需要按精确字段值查询时优先使用 `GFValueIndex`；需要展示大量列表可见范围时使用 `GFVirtualListModel`；需要运行时控制台命令补全时由 `GFConsoleUtility` 负责 UI 和命令生命周期。
