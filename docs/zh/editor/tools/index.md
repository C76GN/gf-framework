# 工具包

GF 工具包用于制作期、编辑器期、导入期、构建期或 CI 期流程。工具包可以依赖它服务的运行时包；运行时包不能反向依赖工具包。

## 阅读入口

- [Config Pipeline 导表工具包](config-pipeline.md)：把通用 CSV / JSON / XLSX 表来源或批量 Profile 构建为 `GFConfigTableResource` / `GFConfigDatabaseResource`，并保存为 Godot `.tres/.res` 或 JSON 导出。
- [Dialogue Text 对话文本工具包](dialogue-text.md)：把严格 JSON 文本编译为 `GFDialogueResource`，并在制作期报告字段类型、跳转目标和资源结构问题。
- [Project Layout 项目结构工具包](project-layout.md)：提供内聚式项目结构 profile 模板和维护校验规则，帮助业务项目把目录、命名、生成物和 Feature 边界沉淀为可审查约定。
- [AI Developer Kit](ai-developer.md)：用显式项目契约、版本化 GF 知识、Agent 适配和受控反馈流程，为项目侧 AI 提供可验证的框架上下文。

## 使用边界

工具包只沉淀通用、可复用、可测试的制作期机制。具体策划表目录、Excel 多 sheet 约定、平台发布流程、热更新打包、加密压缩、远程拉取和业务字段语义仍属于项目流水线或独立插件策略。
