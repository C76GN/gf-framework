# Foundation 校验报告与结果字典

这一组 Foundation 能力提供通用校验报告、资源化校验套件、CI 输出和轻量结果字典。它们统一问题结构和返回值字段，但不定义具体资源、配置表或场景节点的业务合法性。

## 阅读入口

- [校验报告与诊断](reports-diagnostics/index.md)：`GFSourceSpan`、`GFValidationIssue`、`GFValidationReport` 和兼容字典报告。
- [通用策略注册表](policy-registry.md)：`GFPolicyProvider` 与 `GFPolicyRegistry` 的 artifact 策略分发和结果汇总。
- [校验规则套件与 Runner](suites-runner.md)：`GFValidationRule`、`GFValidationSuite`、`GFValidationRunner` 和 JUnit 导出。
- [轻量结果字典](result-dictionary.md)：`GFResultDictionary` 的成功、失败、原因、元数据和轻量问题载荷结构。

## 使用边界

需要严重级别、摘要、统计和下一步建议时，使用校验报告。只表达一次操作的成功、失败、原因、载荷和少量问题时，使用轻量结果字典。
