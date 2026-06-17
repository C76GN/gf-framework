# 更新日志 (Changelog)

## 📝 日志条目结构标准

每次版本更新应包含以下核心模块（若无相关变动可省略该模块）：

1. **版本号与日期**：格式为 `## [主版本.次版本.修订号] - YYYY-MM-DD`
2. **版本概述**：简短描述该版本的核心目标（如：大型特性更新、紧急修复、性能重构等）。
3. **🚀 新增特性 (Added)**：新加入的类、方法、系统、扩展组件等。
4. **🔄 机制更改 (Changed)**：对现有功能逻辑的修改、内部重构、性能优化等。
5. **🐛 Bug 修复 (Fixed)**：修复的逻辑错误、内存泄漏、崩溃问题等。
6. **⚠️ 废弃与移除 (Deprecated/Removed)**：标记为废弃（将在未来移除）或本次直接移除的接口、文件。
7. **🔌 API 变动说明 (API Changes)**：详细列出函数签名改变、属性重命名等直接导致旧代码报错的改动。
8. **📘 升级指南 (Migration Guide)**：为使用旧版本框架的开发者提供 Step-by-Step 的升级建议和兼容性处理方案。
9. **📁 核心受影响文件 (Affected Files)**：列出改动最大的核心源码文件，方便开发者进行二次开发比对。

---

## 维护策略

正式文档中的更新日志只保留当前最新发布版本。发布新版本时，应将 `[未发布]` 合并为具体版本条目，并删除上一个正式版本条目；旧版本历史以 Git 历史和 GitHub Releases 为准，避免正式文档长期膨胀。

---

## [5.1.0] - 2026-06-17

### 🚀 新增特性 (Added)

- `GFAssetUtility` 新增异步加载进度信号 `asset_load_progress` 与 `get_load_progress()`，诊断快照同步暴露 `pending_progress`。
- `GFAudioClip` 新增通用 `metadata` 字典与元数据 helper，供导入器、编辑器工具或项目层附加片段信息。
- GF 编辑器插件新增通用 Resource 预览生成器，资源可通过 `get_gf_preview_texture()` / `get_gf_icon_texture()` 或 `preview_texture` / `icon` 字段为 Godot 资源面板提供等比缩略图。
- GF 编辑器插件新增资源路径字符串 Inspector，对可识别的 `@export_file()` Resource 字段显示 ResourcePicker，并优先保存 `uid://` 稳定路径。

### 🔄 机制更改 (Changed)

- `GFAudioBankTools` 的路径导入选项新增 `metadata` 与 `metadata_by_path`，可在生成 `GFAudioClip` 时按批次和资源路径透传元数据。
- `GF Package Manager` 工作区页面现在会在刷新、预览安装、安装、预览卸载和卸载期间显示阶段进度，并把耗时的 Godot 原生包管理后端调用放入后台线程，避免编辑器页面看起来无响应。
- `GF Package Manager` 包列表现在用 `+ 可安装`、`✓ 已安装`、`↑ 可更新` 标记包状态，包详情同步展示人读状态，并在 GF 源码开发仓库中提示源码目录存在不等于 lockfile 已安装。
- `GFConfigResourcePathValidationRule` 默认接受 `uid://` 资源路径，并在扩展名校验时使用 UID 解析出的真实资源路径。
- `package-boundary` 现在明确 `gf.tool.*` 是制作期工具包：tool 可以依赖它服务的 `gf.kernel`、`gf.standard.*` 或 `gf.extension.*`，运行时包不能依赖 tool，普通 tool 之间也不能互相依赖。

### 🐛 Bug 修复 (Fixed)

- API Reference 生成器现在保留 enum / block 签名的多行格式，避免文档页面把带注释的块声明压成过长单行。
