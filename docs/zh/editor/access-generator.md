# 访问器生成

`GFAccessGenerator` 扫描项目中注册到 GF 架构的公开类型，生成类型化访问器，减少项目侧到处手写 `Gf.get_model(...) as ...` 的重复样板。

生成器的传统入口返回 `Error`；需要做保存前预览、禁止覆盖或产物差异审查时，使用 `generate_with_report()`、`generate_project_access_with_report()` 或 `save_source_with_report()`。这些入口返回 `GFGeneratedArtifactReport` 统一格式的字典，包含产物状态、是否写入、是否 dry-run、错误码、内容 hash、上一个文件 hash、生成器 ID、来源 ID 和产物所有权。`skipped` 表示工具明确选择不写入，不等同于 `failed`；如果流程需要把禁止覆盖、用户文件保护等跳过结果视为阻断条件，应读取 `error_code` 或项目自己的策略字段。

批量工具可以用 `GFGeneratedArtifactReport.summarize_reports()` 聚合多份报告，得到状态计数、写入数量、dry-run 数量、失败数量和 `generated` / `user` / `external` 所有权分布。生成器只应自动覆盖 `generated` 产物；`user` 或 `external` 产物需要调用方显式决定是否跳过、提示或交给外部流程处理。

保存生成物时可以给 `GFGeneratedArtifactReport.save_text()` 传入 `allowed_roots`，把写入限制在 `res://` 或 `user://` 的指定生成目录内。绝对文件系统路径、非 Godot URI 和越过允许根目录的路径会被报告为失败；项目工具不应把生成脚本直接写进手写源码目录，除非调用方明确声明该目录属于生成物。

## 扩展生成结果

扩展可以通过 manifest 的 `access_generator_extension_paths` 扩展生成结果。扩展脚本可实现以下约定方法：

- `append_access_records(records)`：向记录列表追加扩展内类型。
- `append_access_source(builder, records)`：直接使用 `GFSourceBuilder` 追加源码。
- `get_access_source_sections(records)`：返回源码片段数组。

访问器扩展只从当前启用扩展读取。禁用扩展后重新生成访问器，可以避免新生成文件继续引用被禁用扩展路径。
