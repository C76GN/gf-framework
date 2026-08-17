# 访问器生成

`GFAccessGenerator` 扫描项目中注册到 GF 架构的公开类型，生成类型化访问器，减少项目侧到处手写 `Gf.get_model(...) as ...` 的重复样板。

生成器的传统入口返回 `Error`；需要做保存前预览、禁止覆盖或产物差异审查时，使用 `generate_with_report()`、`generate_project_access_with_report()` 或 `save_source_with_report()`。这些入口返回 `GFGeneratedArtifactReport` 统一格式的字典，包含产物状态、是否写入、是否 dry-run、冲突标记、错误码、内容 hash、上一个文件 hash、期望基线 hash、生成器 ID、来源 ID 和产物所有权。`skipped` 表示工具明确选择不写入，不等同于 `failed`；如果流程需要把禁止覆盖、用户文件保护等跳过结果视为阻断条件，应读取 `error_code` 或项目自己的策略字段。传统 `Error` 入口是兼容投影：只要 `written = true` 就返回 `OK`，避免调用方对已经物理提交的结果自动重试；需要诊断提交后的复核或清理失败时，必须改用对应的 `*_with_report()` 并同时检查 `written` 与原始 `error_code`。

批量工具可以用 `GFGeneratedArtifactReport.summarize_reports()` 聚合多份报告，得到状态计数、写入数量、dry-run 数量、失败数量和 `generated` / `user` / `external` 所有权分布。生成器只应自动覆盖 `generated` 产物；`user` 或 `external` 产物需要调用方显式决定是否跳过、提示或交给外部流程处理。

保存生成物时可以给 `GFGeneratedArtifactReport.save_text()` 传入 `allowed_roots`，把写入限制在 `res://` 或 `user://` 的指定生成目录内。省略该键只保留历史路径校验，不代表调用方拥有对应物理目录；显式提供时必须给出非空且全部有效的资源根目录集合。启用后，读取、目录创建、临时写入、最终替换、清理与回滚会在各个可观察边界前后拒绝符号链接、Windows junction 或其他重解析组件。绝对文件系统路径、非 Godot URI、越过允许根目录的路径以及穿过上述物理链接的路径都会被报告为失败；项目工具不应把生成脚本直接写进手写源码目录，除非调用方明确声明该目录属于生成物。

这些复核用于在现有 Godot 文件 API 上失败关闭，但不会持有目录句柄，也不构成对恶意并发文件系统修改的原子 CAS。最终 rename 已经提交、随后物理复核、暂存路径被未知实体重新占用或 backup 清理失败时，报告可以同时满足 `status = failed`、`success = false` 与 `written = true`；未知实体会被保留而不会被当作本次暂存文件删除。调用方必须先独立检查 `written`，再决定是否重试、恢复或提示人工检查，不能仅凭 `success` 重新写入。请求 `scan_filesystem = true` 时，只要本次操作已经改变可观察文件系统状态，即使最终报告失败，也会请求一次编辑器文件系统扫描。

对已经读取并准备修改的用户文件，应把读取内容的 SHA-256 作为 `expected_previous_sha256` 一并提交。保存前目标内容发生变化时会返回结构化冲突并拒绝覆盖；`GFScriptPatchUtility` 已默认使用这一约束。该比较能阻断可观察到的陈旧快照覆盖，但不替代操作系统级原子比较交换，也不替代需要显式恢复句柄和完整故障事务的多文件写入。

## 冻结模块访问策略

`gf/codegen/access_policies` 可以按稳定的 `res://` 脚本路径为 Model、System 和 Utility 声明生成策略：

```gdscript
{
	"res://game/models/player_model.gd": {
		"scope": "inherited",
		"required": true,
		"require_ready": true,
	},
	"res://game/debug/local_console_utility.gd": {
		"scope": "local",
		"required": false,
		"require_ready": false,
	},
}
```

- `scope = "inherited"` 使用当前架构的父链规则；`scope = "local"` 只查询传入的当前架构。
- `required = true` 保留 `strict_dependency_lookup` 下的必需项缺失诊断；`false` 表示可选查询，未命中时静默返回 `null`。该字段只定义生成访问器的消费语义，不会替代模块的 required dependency Hook。
- `require_ready = true` 会过滤已注册但尚未完成 `ready()` 的实例。

没有配置的类型默认使用 `inherited` / `required = true` / `require_ready = false`。生成器在扩展已追加记录后深复制候选记录，完整验证设置根、每个精确路径和全部策略值，再把三项值作为字面量写入 `GFAccess`；运行时不再读取 ProjectSettings，扩展持有的原始记录也不会被生成过程改写。策略字段键接受 `String` 或 `StringName`，验证后统一冻结为 canonical `String` 键；验证器会拒绝规范化后仍可观测到的等价重复字段，而普通 Godot `Dictionary` 会在赋值阶段先折叠同文本的 `String` / `StringName` 键。修改策略后需要重新生成访问器。设置根类型非法、路径不是当前可生成的 Model/System/Utility、未知或重复字段、未知 `scope`、非布尔值或非 Dictionary 策略都会使本次生成整体返回 `failed`，且不会覆盖已有产物；`build_source()` 同样会在创建源码 Builder 和调用扩展钩子前验证完整批次，因此不会输出部分访问器或静默回落默认策略。

父架构回退、严格查询与 ready 遮蔽的完整语义见[依赖诊断](../kernel/architecture/assembly-diagnostics/dependency-diagnostics.md)。

## 扩展生成结果

扩展可以通过 `editor/gf_tool_contribution.json` 的 `access_generator_extension_paths` 扩展生成结果；该字段不属于运行时 `gf_extension.json`。扩展脚本可实现以下约定方法：

- `append_access_records(records)`：向记录列表追加扩展内类型。
- `append_access_source(builder, records)`：直接使用 `GFSourceBuilder` 追加源码。
- `get_access_source_sections(records)`：返回源码片段数组。

访问器扩展只从当前启用扩展读取。禁用扩展后重新生成访问器，可以避免新生成文件继续引用被禁用扩展路径。
