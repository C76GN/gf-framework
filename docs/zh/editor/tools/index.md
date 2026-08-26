# 工具包

GF 制作期工具用于编辑、导入、构建或 CI 流程。工具可以依赖它服务的运行时能力；运行时代码不能反向依赖这些工具。

## 阅读入口

- [Config Pipeline 导表工具包](config-pipeline.md)：把通用 CSV / JSON / XLSX 表来源或批量 Profile 构建为 `GFConfigTableResource` / `GFConfigDatabaseResource`，并保存为 Godot `.tres/.res` 或 JSON 导出。
- [Dialogue Text 对话文本工具包](dialogue-text.md)：把严格 JSON 文本编译为 `GFDialogueResource`，并在制作期报告字段类型、跳转目标和资源结构问题。
- [Project Layout 项目结构工具包](project-layout.md)：在 GF Workspace 中按需执行只读扫描、问题解释、影响模拟和计划展示；profile 是项目显式选择的策略，Feature Cohesive 只是一份示例。
- [LSP WorkspaceEdit 安全提交工具](lsp-workspace-edit.md)：把调用方已取得的闭合文本编辑绑定到工作区、文档版本和来源摘要，并通过一次性计划与文件事务安全提交项目内 GDScript；它不是 LSP 客户端。
- [AI Developer Kit](ai-developer.md)：用显式项目契约、版本化 GF 知识、Agent 适配和受控反馈流程，为项目侧 AI 提供可验证的框架上下文。
- [Asset Browser 素材浏览模型](asset-browser.md)：当前只提供 model-first 状态能力，在不注册 Dock、目录扫描或业务分类的前提下组织隔离 catalog、稳定选择、有界分页和缩略图任务代际。

## 使用边界

这些工具只沉淀通用、可复用、可测试的制作期机制。具体策划表目录、Excel 多 sheet 约定、平台发布流程、热更新打包、加密压缩、远程拉取和业务字段语义仍属于项目流水线或独立插件策略。
