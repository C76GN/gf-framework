# Project Layout 项目结构工具包

`gf.tool.project_layout` 是可选制作期工具，由 `GFProjectLayoutDock` 提供编辑器入口，用来观察项目库存、检查项目自己的布局规则、解释问题、生成只读目录候选计划和模拟路径变更。它不会替项目创建、移动、删除或改写文件，也不规定所有项目使用同一种目录。

GDScript 是 Profile 的唯一权威。编辑器和维护 CLI 使用同一个严格编译器、九类规则执行器及捕获范围核心。Python 维护入口只传输原始 Profile 文本、监督可信 Godot 工具进程和接收报告；没有 Python 规则解释器或失败后的语言回退。

## 第一次使用

1. 启用 GF 编辑器插件，从 `工具 > GF > 打开 GF 工作区` 打开 [GF Workspace](../workspace.md)。
2. 选择“结构”页面，先保留 `无（只观察）`，再点击“扫描项目”。页面打开时不会自动扫描。
3. 查看总览、问题与解释。无 Profile 时只观察库存，不用推荐目录评判项目。
4. 选择 `Feature Cohesive 示例` 可以体验项目自选规则；它是示例，不是强制规范。
5. “复制报告”只写剪贴板。超过 1 MiB 时复制带 digest、摘要和原始字节数的合法 JSON envelope，不把截断文本伪装成完整报告。

编辑器分帧捕获目录，再把冻结 snapshot 交给后台分析和规划。解释和影响查询绑定同一 `generation + input_digest`，新请求取消旧查询，迟到结果被丢弃。各阶段均有有限工作量和取消检查；截断、取消、读取失败或预算耗尽会明确返回不完整状态，不把未知事实包装成通过。

## 页面与结论

总览显示文件/目录数、诊断计数、输入完整性和摘要。`effects.writes_project` 固定为 `false`；digest 绑定本次冻结来源与范围，不能替代备份或版本控制。

问题与解释展示观察、含义、建议、确定性和证据。列表分帧加载，最多展开 256 条；总览保留报告总数。达到诊断预算时整体降级为 incomplete，不静默省略后声称完整。

影响模拟接受项目相对路径的 `delete`、`move` 或 `rename`。`UNSAFE` 表示已有明确 blocker；`UNKNOWN` 表示证据不足；只有来源与依赖覆盖都完整才可能 `SAFE`。当前依赖覆盖是 `filesystem_only`，因此没有观察到引用也不能证明可安全删除。

只读计划从 zone 与 `feature_module_contract` 提取候选目录、前置条件、风险和 blocker。其他规则参与分析，不被伪装成待执行命令。工具没有 Apply；项目必须自行审查和验证实际修改。

## 自选 Profile 与 v2 契约

Feature 示例在：

```text
res://addons/gf/tools/project_layout/profiles/feature_cohesive_v2.json
```

示例按 `app`、`features/<feature_id>`、`shared`、`generated`、`.gf` 和 `tests` 表达边界。已有成熟目录规范可以继续使用；不要为模仿示例制造空目录或搬迁稳定功能。

长期团队规则放入项目自己的 `gf_project_profile.json`。维护入口依次查找该文件、`.gf/project_profile.json`、`project_profile.json`；没有 Profile 时明确“不适用”，不会暗中选择示例。当前 Dock 提供无 Profile 和内置示例，自定义 Profile 使用 Session/API 或维护 CLI。

Profile、snapshot、analysis 和 plan 使用 schema v2。旧 schema 不自动升级，没有兼容字段别名或 legacy/shadow 模式。严格准入拒绝未知字段、错误类型、重复 ID、重复 JSON 键、孤立 Unicode surrogate、非有限数值和不规范路径；无效 Profile 在捕获库存之前失败。集合规范化后的重复值保留第一项并报告 warning。

Profile 必需 `schema_version: 2`、`id`、`zones`、`rules`；可选 `display_name`、`description`、`metadata`、`capture_scope`。每类规则只接受自己的闭合字段，不接受跨规则但被忽略的 operands。

唯一执行器支持全部九类规则：

| 规则 | 观察内容 |
|---|---|
| `path_exists` | 明确路径全部存在，或 `any=true` 时至少一个存在 |
| `files_under_roots` | 按 include/exclude/extensions 选中的文件是否位于允许根 |
| `extension_allowlist` | 选中文件的扩展名是否在允许集合 |
| `extension_denylist` | 选中文件的扩展名是否命中禁止集合 |
| `forbid_root_files` | 根目录文件是否列入 allowed_files |
| `naming_convention` | path/name/stem 是否匹配命名模式 |
| `feature_module_contract` | Feature ID、子目录及根文件边界 |
| `generated_boundary` | 匹配的生成文件是否位于声明生成根 |
| `bucket_size` | 指定根下文件数是否超出有限阈值 |

Zone 的 `roots`、`required`、`allow_extensions`、`deny_extensions`、`exclude` 和 `severity` 都执行。可选 zone 不要求存在，但其已存在文件仍受扩展名与 exclude 规则约束。

`pattern` 和 `feature_id_pattern` 使用 `portable_safe_v1`：最多 1024 UTF-8 字节，仅可打印 ASCII；支持字面量、简单字符类、`.`、`^`、`$`、顶层 `|` 和 `*`/`+`/`?`。最多 32 分支，每分支最多一个量词，带量词的分支必须以 `^` 锚定。分组、lookaround、backreference、速记类、花括号量词和方言转义被拒绝。这是有界的产品语法，避免直接暴露 PCRE2 的全部表达能力。

## 声明生成证据与可丢弃根

固定排除 `.git`、`.godot`、`.import`。大量可重建证据可以由 Profile 显式排除，而不是提高无穷上限或自动读取 `.gitignore`/`.gdignore`。

```json
{
  "schema_version": 2,
  "id": "my.layout",
  "zones": [],
  "rules": [],
  "capture_scope": {
    "schema_version": 1,
    "root_path": "res://",
    "required_roots": ["app", "features"],
    "excluded_roots": [
      {"path": "build/evidence", "kind": "generated_evidence"},
      {"path": ".gf/preview_cache", "kind": "disposable"}
    ]
  }
}
```

`capture_scope.root_path` 是相对唯一 `source_root` 的逻辑容器。`res://` 明确表示来源项目根；`res://subdir` 映射该来源根内子目录。实际请求 `root_path` 必须恰好匹配这个映射。改变 API 选项到另一子根不会重新解释同一 Profile 的 exclusions。

Profile 声明是持久权威。`options.capture_scope` 若存在，必须与规范化后的 Profile 声明完全相等；不合并两份 policy。无 Profile 的观察可以通过 options 明确声明范围。无声明时只使用固定状态排除。

根必须是 portable ASCII literal 相对路径，无 glob、空段、点段、协议、盘符、反斜杠、尾点、设备名或大小写 alias。最多 64 个 required roots、61 个额外排除根；重复、父子覆盖或与固定状态根相交均失败。用途仅 `generated_evidence` 或 `disposable`，不能把源码或必须导入的生成脚本伪装为证据。

硬保护包含 required_roots、required zones、全部 `path_exists` 路径、Feature 模块根、真实 Profile 文件、项目配置和契约来源。排除根与保护根双向相交均拒绝，不能隐藏保护根的父目录或其后代。一般规则只对 included scope 做结论：每条 rule result 明示 `coverage` 与 `complete`/`scope_limited`/`skipped`，没有观察对象的规则不会伪装为 success。

排除在目录递归之前执行，后代不计文件、目录或深度预算。排除根及父链仍检查实际条目的精确拼写、目录资格、link/junction 和前后路径状态；每次身份资格检查最多枚举 40,000 个父目录条目，同一父目录只枚举一次，不进入排除后代。Windows 大小写别名不能代替 literal 根；大小写敏感文件系统上的不同目录仍分别观察。缺失的可丢弃根允许出现为明确缺失状态，扫描时变化会使来源不完整。声明、来源根、实际捕获根、保护根、排除集合和 policy digest 都进入冻结 scope 与 inventory digest。

默认包含隐藏源码目录。`include_hidden=false` 或 scope 与已准入 policy 不匹配时不能证明输入完整，也不执行把“未看到”当成“确定缺失”的 Profile 规则。实际 included 库存仍最多 20,000 文件、20,000 目录，深度 32；选项只能收紧共享封套。

这是一项应用层只读防护。Godot 的 DirAccess 无法提供 OS 级原子 no-follow 证明；请使用受信、单写者来源，不在捕获期间由外部进程替换目录拓扑。

## Session 与 Godot API

`GFProjectLayoutSession` 拥有一次编译、一份冻结报告和一次闭合验证索引；plan、explain、impact 不重新编译或扫描。导出的 report 为深复制，修改返回值不会改变后续查询。`close()` 释放本次策略、报告和索引。

```gdscript
var session: GFProjectLayoutSession = GFProjectLayoutSession.new()
var profile: Dictionary = {
    "schema_version": 2,
    "id": "my.layout",
    "zones": [],
    "rules": [],
}
var analysis: Dictionary = session.open_profile(profile)
var plan: Dictionary = session.plan()
var impact: Dictionary = session.impact({
    "kind": "delete",
    "source_path": "features/inventory",
    "target_path": "",
})
session.close()
```

`open_profile_text(text, source_path, options)` 用于文件来源：真实文件必须位于 source_root、严格有界，bytes 与原文一致。纯数据 `open_profile(profile, options)` 不声明文件来源。`observe(options)` 不执行规则；未打开或 close 后查询返回不完整结果。

`GFProjectLayoutAnalyzer` 仍提供直接分析和 detached snapshot 消费。`GFProjectLayoutPlanner` 只投影目录候选。接收外部 report 的公开消费入口重新验证闭合 contract；内部拥有的 Session 索引不能借给外部后继续声称同一身份。检查 `input_complete`、`evaluation_complete`、`plan.complete` 和 blockers，不能仅把 success 或诊断数量作为完整证明。

## 维护 CLI 与隔离工具进程

在 GF 仓库运行：

```powershell
python tools\gf_maintenance.py project-profile-boundary --root D:\path\to\project --profile gf_project_profile.json --json
```

目标 Profile 必须位于 `--root` 内。维护 Python 只做有限稳定读取和结果传输；原始 JSON 由 GDScript 决定。配置支持的 Godot 工具可执行文件，例如 `GF_GODOT`。找不到 Godot、子进程超时或输出信封失效均明确失败，不回退到 Python 规则。

监督器启动独立可信工具 fixture，并提供私有 userdata 与临时目录，不启动目标 project.godot 的游戏/编辑器，不执行其 autoload、EditorPlugin、脚本或场景。目标目录仅由 Layout 作为只读文件数据访问。deadline、输出字节、身份拥有的终止/清理均由维护监督器执行。

Quick 的纯 Python 检查验证静态分发材料与 transport 契约；实际九类规则、范围与会话行为属于 GUT/集成门禁。完整验证包含 native fixture acceptance，证明目标项目中的恶意 autoload 不被执行，并证明大量显式排除证据不扩大 included 文件上限。

## 迁移与项目责任

- 旧 v1 Profile 明确改写为 v2，删除跨规则兼容字段；旧 snapshot/report 重新生成，不隐式升级。
- `GFProjectLayoutValidator` 已删除，直接分析迁移到 Analyzer，多次查询迁移到 Session。
- legacy/shadow 模式已删除；迁移完成以当前唯一 strict authority 的实际结果为准。
- 生成源码仍进入 Godot 导入与脚本解析，应留在 included scope，并由 generated_boundary 规则管理。
- `.gf/project_contract.json` 是人工维护的项目意图；可重建证据适合显式 disposable/generated_evidence 根。忽略策略与 Layout 捕获声明是不同契约。
- 手工目录变更后重新捕获，并运行项目导入、场景、测试与版本控制检查。Layout 文件系统图不能替代游戏行为验证。
