# Changelog 编写契约

`docs/zh/changelog.md` 是面向使用者的当前版本发布说明，只保留“发生了什么、对使用者有何影响、怎样迁移”。作者模板、门禁实现和仓库文件清单属于维护者信息，只维护在本页、`AI_MAINTENANCE.md` 与工具自测中。

## 当前文档形态

公开 changelog 的顶层结构只能是：

1. `# 更新日志 (Changelog)`。
2. 唯一候选段：开发态为 `## [未发布]`，稳定发布态为 `## [x.y.z] - YYYY-MM-DD`。

候选段的第一条可见内容必须是非空 `**版本概述**：...`，并至少包含一个非空标准分类。分类不得重复，出现时按以下顺序排列：

1. `### 🚀 新增特性 (Added)`
2. `### 🔄 机制更改 (Changed)`
3. `### 🐛 Bug 修复 (Fixed)`
4. `### ⚠️ 废弃与移除 (Deprecated/Removed)`
5. `### 🔧 API 变动说明 (API Changes)`
6. `### 📘 升级指南 (Migration Guide)`

没有相关变动的分类应省略。不要新增 `Affected Files` 分类，也不要把只有 `addons/gf/...`、`tests/...`、`tools/...` 等仓库路径的列表放进其他分类；变更文件由 Git commit、PR 和 release artifact 提供精确证据。

## 生命周期规则

- 开发态当前页只保留唯一 `[未发布]`，不得混入正式版本历史。
- 发布时把 `[未发布]` 转成唯一目标正式段，并填写有效日期。
- 已发布历史只由不可变 Git tag 和 GitHub Release 保存，不建立平行 Markdown 归档，也不重写已发布 tag。
- 版本概述和分类正文写消费者可观察的能力、修复、行为变化与迁移义务；内部重构只有影响这些结果时才记录。
- API 破坏、删除或改名必须同时进入 `API Changes` 与 `Migration Guide`，并服从 API baseline 的 SemVer 门禁。
- API baseline 的自动选择与显式 `--base-tag` 使用同一资格规则：只接受低于目标版本、能 peel 到 commit、且其 commit 是当前 `HEAD` 祖先的 annotated 稳定 SemVer tag。工具以有界 tag 清单捕获的对象 OID 为根；旧 Git 只展开一层 tag 时，再用一次有界批处理递归 peel，并始终以最终 commit OID 读取基线。Git 查询失败、输出被截断、stderr 非空、格式异常或没有合格 tag 时失败关闭，不能退回 lightweight、分叉或未来版本 tag。

## 验证

```powershell
python tools\gf_maintenance.py changelog-policy --json
python tools\gf_maintenance.py maintenance-self-test --json
```

`changelog_policy` 属于 docs、quick、full 与 release 门禁。解析器只接受规范 ATX 标题和可见 Markdown；原始 HTML、注释与可见内容混写、非 ASCII 标题空格、渲染为空的概述或分类正文都会失败关闭。API baseline 的 `breaking_change_count` 大于零时，同一解析器会强制当前开发态或稳定态候选段同时提供非空 `API Changes` 与 `Migration Guide`；`check` 调用会把同一个 `--allow-breaking-api` 值传给 `changelog_policy` 与 `release_metadata`，包括所有并行 Full 子进程，但它只影响 SemVer 例外，不免除迁移说明。修改契约时必须同步 `tools/gf_changelog.py` 与 maintenance self-test fixture。
