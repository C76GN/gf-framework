# 更新日志 (Changelog)

## 📝 日志条目结构标准

每次版本更新应包含以下核心模块（若无相关变动可省略该模块）：

1. **版本号与日期**：格式为 `## [主版本.次版本.修订号] - YYYY-MM-DD`
2. **版本概述**：简短描述该版本的核心目标（如：大型特性更新、紧急修复、性能重构等）。
3. **🚀 新增特性 (Added)**：新加入的类、方法、系统、扩展组件等。
4. **🔄 机制更改 (Changed)**：对现有功能逻辑的修改、内部重构、性能优化等。
5. **🐛 Bug 修复 (Fixed)**：修复的逻辑错误、内存泄漏、崩溃问题等。
6. **⚠️ 废弃与移除 (Deprecated/Removed)**：标记为废弃（将在未来移除）或本次直接移除的接口、文件。
7. **🔧 API 变动说明 (API Changes)**：详细列出函数签名改变、属性重命名等直接导致旧代码报错的改动。
8. **📘 升级指南 (Migration Guide)**：为使用旧版本框架的开发者提供 Step-by-Step 的升级建议和兼容性处理方案。
9. **📁 核心受影响文件 (Affected Files)**：列出改动最大的核心源码文件，方便开发者进行二次开发比对。

## 维护策略

每个正式版本只记录相对上一个稳定版本的增量。开发期在当前页维护 `[未发布]`；发布时将其转为目标版本，并从工作树删除旧正式版本。发布态当前页只保留目标正式版本；已发布历史以不可变 Git tag 和 GitHub Release 为准，不另建 Markdown 归档，也不得把旧版本改名伪装成新版本。GitHub Release 只提取当前目标版本自身的段落。

---

## [9.0.1] - 2026-07-20

**版本概述**：修复 Godot 原生 Package Manager 在 Linux 等平台安装含隐藏文件的合法包后无法完整清理事务暂存目录的问题，并保持隐藏链接审计继续 fail closed。

### 🔄 机制更改 (Changed)

- Package Transaction Engine 的树清理与链接审计、Package Manager Backend 的兜底清理现在都会显式枚举隐藏目录项。该行为适用于所有合法 package 载荷，不为特定文件名或业务包增加例外。

### 🐛 Bug 修复 (Fixed)

- 修复合法 package 包含 `.gdignore` 等点号文件时，Linux 上的 `DirAccess` 默认隐藏文件过滤会让 `.gf/t` 保留 staging 副本的问题。该残留此前会被 release 全包 Godot matrix 判定为意外运行时写入，并阻止 GitHub Release 创建。
- 修复事务树链接审计可能遗漏隐藏目录项的问题；隐藏符号链接或目录链接现在与普通目录项使用同一拒绝策略。

### 🔧 API 变动说明 (API Changes)

- 无公开 API、package schema、lockfile schema、持久化格式、协议或默认配置变化。

### 📘 升级指南 (Migration Guide)

- `9.0.0` 使用方可直接替换为 `9.0.1`。已安装的 package 文件和 `.gf/packages.lock.json` 无需迁移；如果项目残留旧 `.gf/t` 暂存目录，可在确认没有正在运行的 package 操作后删除该临时目录。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/kernel/package/gf_package_transaction_engine.gd`
- `addons/gf/kernel/package/gf_package_manager_backend.gd`
- `tests/gf_core/kernel/package/test_gf_package_manager_backend.gd`
- `tests/gf_core/maintenance/test_package_transaction_boundary_validation.gd`
