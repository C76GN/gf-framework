# 兼容字典报告

已有模块如果仍返回字典报告，可以先使用 `GFValidationReportDictionary.append_issue()` 和 `GFValidationReportDictionary.finalize_report()` 统一统计字段，而不必立刻迁移成对象式报告。

## 归一化报告

```gdscript
var legacy_report := {
	"row_count": 2,
	"issues": [],
}

GFValidationReportDictionary.append_source_issue(
	legacy_report,
	"warning",
	&"missing_optional",
	"Optional field is missing.",
	{ "source": "res://data/items.csv", "line": 10 },
	{ "row_key": 1 }
)
GFValidationReportDictionary.finalize_report(legacy_report, "Config table")
```

`finalize_report()` 会把 `issues` 中的字典问题归一化为标准问题字典，并稳定回写 `ok`、`healthy`、`issue_count`、`error_count`、`warning_count`、`summary` 和 `next_action`。旧的 `code` / `type` 不再作为问题类别别名读取，也不会继续透出；需要稳定问题标识时请显式写入 `kind`。

## 报告合并

多个工具链步骤需要汇总诊断时，使用 `merge_report()` 复制来源报告的问题，再按需要通过 `copy_fields` 复制调用方明确声明的统计字段。合并本身不会自动 `finalize_report()`，因此调用方可以先继续追加问题，再统一计算最终统计。

```gdscript
GFValidationReportDictionary.merge_report(registration_report, graph_report, {
	"copy_fields": PackedStringArray(["package_count", "ordered_package_ids"]),
})
GFValidationReportDictionary.finalize_report(registration_report, "Registration")
```

`merge_report()` 只处理通用问题结构和显式列出的字段，不解释配置表、内容包、资源扫描或项目业务含义。来源报告不会被修改，复制到目标报告的问题会按 `GFValidationIssue` 字典格式归一化。报告与自身合并，或两个包装字典共享同一个 `issues` Array 时，问题合并是幂等空操作；显式 `copy_fields` 仍会复制，避免别名输入在遍历期间无限放大。

## 过滤与基线

项目工具或 CI 需要保留历史基线、忽略已接受问题或按目录排除生成物时，可以先生成问题指纹，再对报告副本做过滤：

```gdscript
var fingerprint := GFValidationReportDictionary.make_issue_fingerprint({
	"severity": "warning",
	"kind": "large_texture",
	"path": "res://legacy/title.png",
	"message": "Texture is large.",
})

var filtered_report := GFValidationReportDictionary.filter_issues(scan_report, {
	"baseline_fingerprints": PackedStringArray([fingerprint]),
	"ignored_path_patterns": PackedStringArray(["res://generated/**"]),
})
```

`filter_issues()` 不修改输入报告，会返回重新 `finalize_report()` 后的副本，并默认写入 `original_issue_count` 与 `filtered_issue_count`。过滤规则只基于通用问题字段，例如 `kind`、`path`、`source_path`、`key` 和指纹；具体扫描项、基线文件读写和 UI 展示仍应由项目工具自己负责。

`make_issue_fingerprint()` 只为可跨进程规范化的纯 Variant 值生成指纹。默认字段中只要包含 Object、Resource、Callable、Signal、RID、其他运行时身份值，或结构超过稳定遍历预算，函数就返回空字符串；调用方不得把空字符串加入 baseline。复杂业务对象应先提取稳定 ID、坐标或受控路径，再作为 issue key。

## 使用边界

复杂数据结构如果需要输出质量审计报告，也应优先复用这套格式：用 `extra_fields` 或字典报告的自定义字段携带 `stats`、`quality_score`、`checked_count` 等统计，用 `issues` 表达可定位的问题。这样编辑器、导入器、CI 和项目工具仍能共享 `ok`、`healthy`、`error_count`、`warning_count`、`summary` 与 `next_action`，而不是为每个数据结构重新定义报告字段。
