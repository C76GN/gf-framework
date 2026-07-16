# 校验报告与诊断

本组页面说明通用校验报告、诊断适配和兼容字典报告。它们不绑定配置表、存档、能力、网络或编辑器工具的具体语义，只提供问题条目、报告聚合、统计、摘要和字典兼容辅助。

## 阅读入口

- [报告对象](report-objects.md)：`GFSourceSpan`、`GFValidationIssue` 和 `GFValidationReport`。
- [诊断适配](diagnostic-adapter.md)：`GFValidationDiagnosticAdapter` 的诊断字典和行记录。
- [兼容字典报告](dictionary-reports.md)：`GFValidationReportDictionary` 的旧报告归一化。
- [兼容性、产物与激活预检](compatibility-artifacts-activation.md)：`GFCompatibilityProfile`、`GFCompatibilityPreflight`、`GFArtifactFreshnessReport` 与 `GFActivationTransaction`。
- [安全文本生成边界](source-text-generation.md)：`GFDataProjection`、`GFExecutionBudget`、`GFTextGenerationContext`、`GFDelimitedTextTools` 与 `GFSourceTextPatchTools` 的纯数据上下文、文本扫描、范围补丁和预算诊断。

## 使用边界

这些页面只说明通用问题条目、报告聚合和诊断格式。具体配置表、存档、场景节点、扩展 manifest 或项目资源是否合法，应由对应模块或项目校验器判断。
