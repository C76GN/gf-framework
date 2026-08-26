# Project Layout 项目结构工具包

`gf.tool.project_layout` 是可选制作期工具包，用来回答四个问题：当前项目有哪些目录和文件、它们是否符合项目自己选择的规则、某条问题为什么出现，以及一次目录变更可能影响什么。它不属于运行时层，不要求所有项目使用同一种目录，也不会替项目创建、移动、重命名、删除或改写文件。

11.0 的核心能力是永久只读的 scan / analyze / plan / explain / impact；这些名称描述能力，不表示必须按一条串行流水线执行。这里的 plan 只是可审查建议，不是待执行命令；工具没有 Apply，也没有隐藏的自动整理流程。

## 第一次使用

Project Layout 已包含在完整 GF 插件中，并会进入 `GF Workspace`。启用 GF 编辑器插件后：

1. 从 `工具 > GF > 打开 GF 工作区` 打开 [GF Workspace](../workspace.md)。
2. 选择简称为“结构”的 `GF Project Layout` 页面。
3. 第一次先保留 `无（只观察）`，点击“扫描项目”。页面初始保持空闲，不会在打开时自动扫描。
4. 查看“总览”和“问题与解释”。无 profile 时只建立当前项目的文件系统库存，不会拿任何推荐目录评判项目。
5. 想体验一套完整规则时，选择 `Feature Cohesive 示例`，再次点击“扫描项目”。
6. 需要保存结果时点击“复制报告”。它只把 data-only JSON 放入剪贴板，不会在项目中生成报告文件；完整 JSON 超过 1 MiB 时会改为复制带摘要、输入 digest 和原始字节数的合法 JSON envelope，避免把被截断的文本伪装成可解析报告。

扫描先由主线程分帧捕获目录库存，再把冻结 snapshot 交给同一个后台请求连续完成 analyze 与 plan。选择 finding 或提交影响模拟时，Dock 会启动绑定同一 `generation + input_digest` 的独立后台 query；新请求协作式取消旧 query，迟到或身份不匹配的结果直接丢弃。所有后台阶段都有不可关闭的工作量上限和取消检查。输入被截断、读取不完整、用户取消或任一预算耗尽时，页面会显示 partial，并以稳定状态说明原因，把不能证明的安全结论降级为 `UNKNOWN`，不会静默丢掉问题后伪装成完整结果。

扫描范围固定为当前 Godot 项目的规范 `res://` 源码树，可以选择其规范子目录，但不接受 `user://`、主机绝对路径、`..`、重复分隔符或 `.` 路径别名。默认包含 `.config` 等隐藏项目目录，只明确排除版本库和 Godot 生成状态 `.git`、`.godot`、`.import`。报告会把 root、隐藏目录策略、排除前缀和捕获预算写入 `scope` 与输入 digest；调用 API 时若关闭隐藏目录或提供非权威 scope，分析仍可返回观察结果，但不会执行会把“未看到”解释成“确定缺失”的 profile 规则。

扫描会在目录入队和打开前后逐级拒绝 Godot 能识别的 symbolic link、junction 或不可读路径。请求根本身不安全时会直接 failed 且不发布 snapshot；扫描途中遇到不安全子路径时会保守地返回 partial / `UNKNOWN`。这是一项只读的应用层防护，不是操作系统级沙箱：同一账户下的其他进程若在检查与打开之间并发替换目录，Godot 的 `DirAccess` 不能提供原子 no-follow 句柄证明。请只扫描受信、单写者的项目树，并避免在扫描期间由外部工具改写目录拓扑。

## 四个页面怎么看

### 总览

总览显示文件数、目录数、错误数、警告数、输入是否完整以及输入摘要。`writes_project` 固定为 `false`。摘要用于辨认报告对应哪次冻结库存，不能替代版本控制或文件备份。

### 问题与解释

选择一条 finding 后，页面会展示观察事实、可能含义、下一步建议、确定性和证据。finding 是“值得检查的结构事实”，不是自动修复指令；先确认 profile 是否真的表达了团队约定，再决定是否调整项目。为保持编辑器响应，列表分帧加载并最多展开 256 条；总览仍显示本次报告的 finding 总数，达到分析预算时报告会明确标成 incomplete，而不是静默省略结论。

### 影响模拟

影响模拟只接受项目相对路径，并可模拟 `delete`、`move` 或 `rename`。它只计算受影响节点、已知 blocker 和证据，不执行变更。

状态应这样理解：

- `UNSAFE`：已经观察到明确 blocker，例如源路径不存在、目标路径已存在或项目根被当作变更目标。
- `UNKNOWN`：现有证据不足以证明安全，应继续检查资源引用、脚本路径、导入关系和项目运行行为。
- `SAFE`：只有输入和依赖覆盖都完整时才可能成立。

当前版本的图只完整描述文件系统包含关系，依赖覆盖标记为 `filesystem_only`。因此，即使没有观察到外部引用，普通模拟也会保持 `UNKNOWN`；“没看见引用”不会被包装成“可以安全删除”。

### 只读计划

只有选择 profile 后才会生成计划。当前 Dock 按所选 profile 的默认项列出候选相对目录、前置条件、风险和 blocker；它不会为现有项目生成批量搬迁命令，也不会创建目录。正确用法是审查建议，在版本控制保护下自行完成一个小改动，再重新扫描。

## 为什么不直接强制传统目录

传统结构通常把所有脚本、场景和资源分别放进全局 `scripts/`、`scenes/`、`resources/`。它在小项目中直观，但一个业务功能增长后，相关文件会横跨多个大目录，审查、移动和删除一个功能时更容易遗漏。

Feature 内聚式结构先按业务边界分组，再在模块内部区分脚本、场景和资源：

| 关注点 | 全局类型目录 | Feature 内聚目录 |
|---|---|---|
| 查找一个功能的全部文件 | 需要跨多个目录搜索 | 通常集中在同一 Feature 根下 |
| 审查或迁移一个功能 | 容易漏掉资源、测试或局部工具 | 可以按模块边界检查 |
| 跨功能复用 | 容易让全局目录继续膨胀 | 需要显式放入 `shared` |
| 小型项目上手成本 | 更低 | 需要先理解 Feature 边界 |

这不是“Feature 一定更好”的框架结论。小项目、强资产流水线或已有成熟规范可以继续使用自己的布局；先用无 profile 扫描观察，再由团队决定是否值得建立 profile。

## Feature Cohesive 只是示例

工具包附带的示例位于：

```text
res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json
```

它大致表达下面的项目边界：

```text
res://
  app/
  features/
    inventory/
      scripts/
      scenes/
      resources/
      tests/
  shared/
  generated/
  .gf/
  tests/
```

- `app`：项目入口、启动场景和跨 Feature 装配。
- `features/<feature_id>`：一个业务能力拥有自己的脚本、场景、资源、测试、文档和局部工具。
- `shared`：确实跨 Feature 复用的通用内容，不是业务逻辑倾倒区。
- `generated`：可再生源码和资源的显式边界。
- `.gf`：GF 项目意图与本地工具状态边界。
- `tests`：跨模块测试和 smoke 场景。

示例只用于说明 profile 能表达什么。不要为了让目录看起来一致而制造空目录，也不要在没有收益时搬迁稳定项目。

## 建立项目自己的 profile

需要长期执行团队规则时，把示例复制到项目根的 `gf_project_profile.json`，再修改副本；不要编辑 `addons/gf` 内的随包示例。维护侧命令也会依次查找 `gf_project_profile.json`、`.gf/project_profile.json` 和 `project_profile.json`。没有找到 profile 时检查按“不适用”通过，不会偷偷选择 Feature 示例。

schema v1 使用统一的严格契约：未知字段、错误类型、重复 ID、非法正则，以及带前导 `/`、反斜杠、盘符、协议、空段或 `..` 的相对路径都会被拒绝。契约准入后，各执行器还会公布自己的 capability；Analyzer 会拒绝无法评估的规则类型，Planner 则只对无关规则做 schema 检查，不能把“profile 被读取”误认为“每条规则都已经执行”。

`pattern` 与 `feature_id_pattern` 使用 canonical contract 定义的 `portable_safe_v1` 子集，而不是直接暴露 Python `re` 或 Godot PCRE2 的全部方言。模式最多 1024 个 UTF-8 字节，只接受可打印 ASCII；支持字面量、简单字符类、`.`、`^`、`$`、顶层 `|` 和 `*` / `+` / `?`，最多 32 个分支且每个分支最多一个量词；使用量词的分支必须以 `^` 锚定。不接受分组、lookaround、backreference、速记字符类、花括号量词或方言专属转义；例如 `(a+)+$`、`a*a$` 与 `\R` 都会以 `PROJECT_LAYOUT_PROFILE_REGEX_UNSAFE` 拒绝。这个窄子集让 Python 和 Godot 对已接受模式使用同一种可解释语义，并在执行前排除灾难性回溯形状。

Godot Analyzer 当前执行这些规则：

- `forbid_root_files`
- `naming_convention`
- `feature_module_contract`
- `generated_boundary`
- `bucket_size`

维护侧严格检查另外支持 `path_exists`、`files_under_roots`、`extension_allowlist` 和 `extension_denylist`。Planner 只从 zone 和 `feature_module_contract` 提取候选目录步骤；其他规则仍可参与分析，但不会被伪装成可执行计划。

当前 Dock 只提供“无（只观察）”和内置 Feature 示例两个选择。自定义 profile 通过 Godot API 或下面的维护命令使用；Dock 不会自动读取项目根的 profile。

## 维护命令与 strict 迁移

在 GF 源码仓库或项目 CI 中，可以运行可选的 Python 维护入口；普通游戏运行、GF 插件启用和 Project Layout Dock 都不依赖 Python：

```powershell
python tools\gf_maintenance.py project-profile-boundary --profile gf_project_profile.json --json
```

命令行只有一个模式参数 `--profile-mode`，可取 `strict`、`legacy` 或 `shadow`：

| 模式 | 11.0 行为 | 建议 |
|---|---|---|
| `strict` | 默认且权威；先按 canonical schema v1 准入，profile 无效时不会继续收集项目库存 | 所有新 profile 和已迁移项目使用 |
| `legacy` | 显式使用旧的宽松语义作为权威结果 | 仅用于短期迁移；已弃用，12.0.0 删除 |
| `shadow` | legacy 结果仍然权威，同时附加非权威的 strict 迁移诊断 | 只用于比较迁移差异；已弃用，12.0.0 删除 |

需要临时比较时必须明确写出模式：

```powershell
python tools\gf_maintenance.py project-profile-boundary --profile gf_project_profile.json --profile-mode shadow --json
```

`shadow` 中的 strict 结果不会改变 legacy 的结果或退出码，不能作为通过证明。即使 strict 拒绝项目库存，顶层的库存、审计、`issues`、`file_count`、`ok` 和命令退出码仍与显式 `legacy` 完全一致；strict 失败只出现在非权威的嵌套 `shadow` 报告中。迁移完成的标准是直接使用默认 `strict` 并通过，而不是长期保留 `legacy` 或 `shadow`。

三个模式共享同一套不可关闭的维护侧安全封套。每次 Git tracked/untracked 子进程输出分别在读取时限制为 16 MiB stdout 与 64 KiB stderr，并有 30 秒期限；合并库存最多 20,000 条路径，单路径最多 16,384 个 UTF-8 字节、总计最多 16 MiB，排序估算最多 400,000 work units。一次 profile 审计最多 12,000,000 work units 和 256 条诊断，并为 terminal 诊断保留位置。任一边界耗尽都会清空库存或丢弃已累积的普通诊断，只返回 `PROJECT_LAYOUT_PROFILE_RESOURCE_LIMIT_EXCEEDED`，不能把 partial 结果当作权威通过。`shadow` 仍只捕获一次 raw Git 库存，再从同一份有界字节生成 legacy 与 strict 视图。

## Godot API

主要入口如下：

- `GFProjectLayoutAnalyzer`：无 profile 观察、严格 profile 分析、finding 解释和变更影响模拟；所有入口只读。
- `GFProjectLayoutPlanner`：从同一份完整分析快照生成闭合只读计划；`capabilities.writes_project` 固定为 `false`。
- `GFProjectLayoutDock`：编辑器中的按需扫描、解释、影响模拟、计划展示和剪贴板导出页面。
- `GFProjectLayoutValidator`：11.0 保留的弃用兼容入口，只委托 Analyzer；新代码不要再使用。

最小观察调用不需要 profile：

```gdscript
var analyzer: GFProjectLayoutAnalyzer = GFProjectLayoutAnalyzer.new()
var analysis: Dictionary = analyzer.analyze()
```

选择示例后，可以让分析和计划绑定到同一份库存摘要：

```gdscript
var analyzer: GFProjectLayoutAnalyzer = GFProjectLayoutAnalyzer.new()
var analysis: Dictionary = analyzer.analyze_example_profile()

var planner: GFProjectLayoutPlanner = GFProjectLayoutPlanner.new()
var plan: Dictionary = planner.plan_example_profile(analysis)
```

不要把 `plan.steps` 直接转换成文件系统操作。先检查 `analysis.input_complete`、`plan.complete`、`plan.blockers` 和来源摘要，再由项目自己的受审查流程决定是否手工变更。

## 11.0 迁移

- `GFProjectLayoutScaffolder` 已移除。原先依赖 `dry_run` 后切换为真实创建的代码，应改为 Analyzer + Planner，并把真实项目修改留给独立、显式、可审查的流程。
- `GFProjectLayoutValidator` 已弃用。`validate_default_profile()`、`validate_profile_path()` 和 `validate_profile()` 分别迁移到 Analyzer 的 `analyze_example_profile()`、`analyze_profile_path()` 和 `analyze_profile()`。
- Validator 的 `allow_absolute_root` 已删除。Analyzer 的 `root_path` 只接受规范的 `res://` 或其规范子目录，不再接受 `user://` 和主机绝对路径；原先扫描项目外目录的迁移工具必须在自身明确的文件系统权限边界内实现，不能把该权限转交给 Project Layout。
- Validator report schema 已替换为 Analyzer report schema，不保留字段兼容别名。机器消费者应按 `schema_version` 和 `kind` 解析，并改读 `evaluation_status`、`evaluation_complete`、`input_complete`、`findings`、`graph`、`rule_results`、`capabilities` 与 `effects`；不要继续把旧报告的 `success`、计数和 `issues` 组合当成完整性证明。
- 旧 profile 先用 `--profile-mode shadow` 查看 strict 诊断，再修正 profile，最后回到默认 strict。不要把 shadow 当成长期运行模式；legacy 和 shadow 都将在 12.0.0 删除。
- 完成任何手工目录变更后重新扫描，并运行项目场景、导入、测试和版本控制检查。Project Layout 的文件系统图不能替代这些行为验证。

## GF 受管产物路径

GF 内核通过 `GFProjectArtifactPaths` 和只读策略镜像统一这些默认路径：

- `res://generated/gf_access.gd`
- `res://generated/gf_project_access.gd`
- `res://generated/gf_config_access.gd`
- `res://generated/network/`
- `.gf/project_contract.json`
- `.gf/ai/project_snapshot.json`
- `.gf/ai/feedback/`

`res://generated/**` 会进入 Godot 导入和脚本解析，项目应明确决定是否版本化可复现产物；`.gf/project_contract.json` 是人工维护的项目意图，应提交；`.gf/ai/**` 是可重建的本地观测，应忽略。自定义生成路径仍应落入 profile 明确声明的 generated zone。

9.0 起默认生成根已从 `res://gf/generated/**` 迁移到 `res://generated/**`。旧项目应先停止生成器，清理旧产物，再用当前生成器重建；不要同时保留两套可能声明相同 `class_name` 的产物。
