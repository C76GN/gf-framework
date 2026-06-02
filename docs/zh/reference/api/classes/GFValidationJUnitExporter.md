# GFValidationJUnitExporter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_validation_junit_exporter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

将 GFValidationReport 导出为 JUnit XML。 该导出器只负责把通用校验报告转成 CI 友好的文本，不决定测试命名、 构建失败策略或项目修复流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`export_report`](#member-gfvalidationjunitexporter-methods-export_report) | `static func export_report(report: GFValidationReport, options: Dictionary = {}) -> String:` |
| 方法 | [`export_reports`](#member-gfvalidationjunitexporter-methods-export_reports) | `static func export_reports(reports: Array, options: Dictionary = {}) -> String:` |

## 方法

<a id="member-gfvalidationjunitexporter-methods-export_report"></a>

### `export_report`

- API：`public`

```gdscript
static func export_report(report: GFValidationReport, options: Dictionary = {}) -> String:
```

导出单个报告。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 校验报告。 |
| `options` | 可选参数，支持 suite_name、warnings_as_failures、include_passing_case。 |

返回：JUnit XML 文本。

结构：

- `options`: Dictionary JUnit export options.

<a id="member-gfvalidationjunitexporter-methods-export_reports"></a>

### `export_reports`

- API：`public`

```gdscript
static func export_reports(reports: Array, options: Dictionary = {}) -> String:
```

导出多个报告。

参数：

| 名称 | 说明 |
|---|---|
| `reports` | 校验报告数组。 |
| `options` | 可选参数，支持 suite_name、warnings_as_failures、include_passing_case。 |

返回：JUnit XML 文本。

结构：

- `reports`: Array of GFValidationReport values.
- `options`: Dictionary JUnit export options.
