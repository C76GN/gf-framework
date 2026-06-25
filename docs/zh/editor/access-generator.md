# 访问器生成

`GFAccessGenerator` 扫描项目中注册到 GF 架构的公开类型，生成类型化访问器，减少项目侧到处手写 `Gf.get_model(...) as ...` 的重复样板。

生成器的传统入口返回 `Error`；需要做保存前预览、禁止覆盖或产物差异审查时，使用 `generate_with_report()`、`generate_project_access_with_report()` 或 `save_source_with_report()`。这些入口返回 `GFGeneratedArtifactReport` 统一格式的字典，包含产物状态、是否写入、是否 dry-run 和错误码。

## 扩展生成结果

扩展可以通过 manifest 的 `access_generator_extension_paths` 扩展生成结果。扩展脚本可实现以下约定方法：

- `append_access_records(records)`：向记录列表追加扩展内类型。
- `append_access_source(builder, records)`：直接使用 `GFSourceBuilder` 追加源码。
- `get_access_source_sections(records)`：返回源码片段数组。

访问器扩展只从当前启用扩展读取。禁用扩展后重新生成访问器，可以避免新生成文件继续引用被禁用扩展路径。
