# 编辑器命令、动作与工具协议

复杂编辑器工具建议把入口、交互和修改拆开，让 UI 按钮只负责触发动作，真正修改资源或节点的逻辑集中到命令中，并自然接入 Godot UndoRedo。

## 协议类型

- `GFEditorCommand`：封装一次可执行、可撤销的编辑器修改，可直接 `execute()` / `revert()`，也可写入 `EditorUndoRedoManager`。
- `GFEditorPropertyBatchCommand`：对多个 Object 属性做全量预检、原子提交、失败补偿和可撤销恢复。
- `GFEditorSceneMetadataPatch`：把节点 metadata 的写入或移除封装成可撤销命令，适合场景级编辑器工具保存自己的纯数据标记。
- `GFEditorCommandSession`：围绕一组命令提供 preview、commit、revert history 和 debug snapshot，适合需要连续交互的编辑器工具。
- `GFEditorActionDefinition`：描述菜单、按钮或快捷键入口，通过 `command_factory` 按上下文创建命令。
- `GFEditorCommandRegistry`：按稳定动作 ID 收集动作贡献，并为命令面板、工具栏或菜单解析布局。
- `GFTemplateGenerationManifest`：从字典或 JSON sidecar 读取模板 ID、模板路径、输出路径、变量、要求和产物所有权，并衔接 `GFGeneratedArtifactReport`。
- `GFEditorOperationPlan`：把预览、dry-run、执行步骤和生成产物报告汇总为统一操作摘要，供 Dock、工具栏或 CI 预检展示。
- `GFBakeDependencyReport`：记录编辑器烘焙或导入工具的输入、输出、逻辑依赖和失效原因，并汇总 current / stale / missing / failed 状态。
- `GFScriptPatchUtility`：对 GDScript 头部注解做纯文本补丁，并保持 `@tool`、注解、文档注释、`class_name` 和 `extends` 的顺序。
- `GFEditorTool`：封装需要持续激活、接收输入和绘制辅助的交互工具。
- `GFEditorToolContext`：在工具、动作和命令之间传递 `EditorPlugin`、UndoRedo、当前场景根节点、选中节点和元数据。
- `GFEditorToolOption` / `GFEditorToolOptionSchema`：声明工具设置项和值规范化规则，供项目自己的工具面板生成 UI 或持久化配置。
- `GFEditorPickOperation`：描述拾取、预览、ready、应用和取消这类分阶段交互。
- `GFEditorBackgroundRequestTask`：框架内部后台请求句柄，用于 Dock 在退出时统一取消、等待并归属 worker 结果。

这些类都位于 `kernel/editor`，只定义协议，不知道标准库或 GF 内置扩展的具体类型。标准库、GF 内置扩展、外部扩展和项目插件都可以复用这套拆分。

工具选项 Schema 只描述“有哪些设置、默认值和基础类型”，不创建具体控件；拾取操作只传递通用字典，不假设拾取的是节点、点、资源还是端口：

```gdscript
var radius := GFEditorToolOption.new()
radius.option_id = &"radius"
radius.value_type = GFEditorToolOption.ValueType.INT
radius.default_value = 3
radius.min_value = 1.0
radius.max_value = 16.0

var schema := GFEditorToolOptionSchema.new()
schema.add_option(radius)
tool.set_option_schema(schema)
tool.set_tool_option(&"radius", 8)
```

## 命令会话

`GFEditorCommandSession` 用于把“预览”和“提交”分开。交互式工具可以在鼠标移动、拖拽或参数调整时调用 `preview_command()` 只执行临时效果；用户确认后再调用 `commit_command()` 写入命令历史或 Godot `EditorUndoRedoManager`。取消或回退时调用 `revert_last()`，不需要工具 UI 自己维护一套命令栈。

```gdscript
var session := GFEditorCommandSession.new()
session.configure(&"paint_tiles", "Paint Tiles", { "tool": "tile_painter" })

session.preview_command(preview_command, context)

if accepted:
	session.commit_command(final_command, context, true)
else:
	session.revert_last()
```

会话只管理通用命令生命周期和历史，不知道命令修改的是节点、资源、TileMap、曲线还是项目自定义数据。具体命令仍由工具或扩展按 `GFEditorCommand` 协议实现。

命令实例代表一次编辑动作。`execute()` 成功后，或命令成功提交到 `EditorUndoRedoManager` 后，实例会冻结配置；工具需要执行下一次编辑时应创建新的命令实例，而不是复用旧实例重新 `configure()`。这样 redo / undo 回调始终使用同一份配置和首次执行前的快照，不会因为后续 UI 状态变化改变历史动作含义。

## 场景 Metadata 命令

编辑器工具如果需要把纯数据状态保存到当前场景根节点或某个工具节点，可以用 `GFEditorSceneMetadataPatch` 包装 metadata 修改，再通过 `GFEditorToolContext.commit_command()` 接入 UndoRedo：

```gdscript
var command := GFEditorSceneMetadataPatch.new()
command.configure(scene_root, &"project_tool_state", {
	"version": 1,
	"items": items,
})

context.commit_command(command, true)
```

metadata key 和 payload 仍由工具或项目定义。GF 只负责捕获旧值、执行写入或移除、撤销恢复，以及保持命令协议一致；不要把节点分组、资源分类或项目业务状态写进通用命令本身。

## 多目标属性事务

编辑器批处理需要同时修改多个节点或资源属性时，可使用 `GFEditorPropertyBatchCommand`。命令会先对全部目标、selector、可写性、类型和规范化值做零写入预检；只有全批通过才捕获首次快照并开始写入：

```gdscript
var command := GFEditorPropertyBatchCommand.new()
command.configure([
	{
		"target": resource_a,
		"property_name": &"priority",
		"new_value": 20,
		"metadata": { "row": 0 },
	},
	{
		"target": node_b,
		"property_path": ^"position:x",
		"new_value": 96.0,
		"metadata": { "row": 1 },
	},
], {
	"command_name": "Edit Selected Properties",
})

var preview := command.validate()
if preview.ok:
	context.commit_command(command, true)
```

`property_name` 表示精确直接属性名，包含 `/` 或 `:` 时不会被当作路径；`property_path` 使用 Godot indexed path 语义。每个 change 必须且只能使用其中一个 selector。同一目标上的重复 selector、直接根属性与其子路径、或彼此包含的路径会在预检阶段失败；同根下互不包含的兄弟子路径可以组合。

首次进入写阶段时，命令会冻结配置并保留不可变 undo 基线。apply 按调用方顺序执行，undo 按相反顺序执行；失败补偿使用相反于当前阶段的顺序。每个阶段结束后还会再次读取全部显式属性，防止后续 setter 间接改坏前面已写入的目标。完整补偿后的失败报告使用 `apply_failed` 或 `revert_failed`，并令 `rolled_back = true`；补偿仍有残余时使用 `rollback_failed` 和 `recovery_required = true`。

待恢复快照始终来自“本次失败操作开始前”的 attempt guard，而不是固定的首次 undo 基线，因此 redo 前的外部状态不会被错误覆盖。调用方修复目标可写条件后可调用 `recover()` 恢复该 guard；未处于 executed 状态的 apply / redo 失败也允许用 `revert()` 触发同一恢复。undo 补偿失败时应先调用 `recover()` 回到完整 executed guard，再重试 `revert()`。

事务边界只包含 changes 中显式声明的属性值。setter 发出的信号、网络请求、文件写入、资源保存或其他不可逆副作用不会自动回滚；带这类副作用的 setter 不应直接参加属性事务。Array、Dictionary 和 PackedArray 配置值会复制，Resource/Object 默认保留身份；确实需要独立 Resource 值时可显式传 `duplicate_resources = true`。

## 动作注册表

`GFEditorCommandRegistry` 适合让多个包或插件主动贡献动作，再由命令面板、工具栏、菜单或项目自己的快捷键设置只保存动作 ID。注册表不扫描任意脚本，也不把业务逻辑写进布局配置：

```gdscript
var registry := GFEditorCommandRegistry.new()
registry.register_action(action, {
	"source_id": &"gf.tool.example",
	"group": &"generation",
})

var layout := registry.resolve_layout(PackedStringArray(["generate_report"]), context)
registry.invoke_action(&"generate_report", context, undo_redo)
```

动作的可执行逻辑仍由 `GFEditorActionDefinition.command_factory` 创建 `GFEditorCommand`。`group`、`source_id` 和 `sort_order` 只服务展示、过滤和诊断，不表达跨包依赖。

## 模板生成清单

生成器需要从模板、变量和输出路径生成文件时，可以用 `GFTemplateGenerationManifest` 统一描述这次生成。JSON sidecar 只保存模板数据，不要求特定模板语法：

```gdscript
var manifest := GFTemplateGenerationManifest.from_json_text(text, {
	"generator_id": "project.generator",
})

var report := GFTemplateGenerationManifest.save_text_from_manifest(manifest, source, {
	"dry_run": true,
})
```

清单中的 `variables` 与 `requirements` 会进入产物报告 metadata，方便生成器在 dry-run、覆盖检查、批量摘要和漂移审查时复用同一套结构。实际模板渲染、依赖安装和输出目录策略仍由调用方决定。

模板或批处理工具真正写入文件时，应把输出目录作为生成物根传给 `GFGeneratedArtifactReport.save_text(..., { "allowed_roots": [...] })`。这样 dry-run、编辑器按钮和 CI 校验会使用同一套路径边界，避免模板清单里的错误输出路径写到手写模块或工程外部。

## 操作计划报告

编辑器批处理工具可以用 `GFEditorOperationPlan` 先收集步骤，再把 `GFGeneratedArtifactReport` 的产物结果加入同一份摘要：

```gdscript
var plan := GFEditorOperationPlan.new()
plan.configure(&"generate_items", "Generate Items", true)
plan.add_step(&"scan", "Scan Sources", { "target": "res://data" })
plan.mark_step(&"scan", GFEditorOperationPlan.STATUS_PREVIEWED)
plan.add_artifact_report(report)

var summary := plan.summarize({ "include_steps": true })
```

计划对象不执行文件写入、节点修改或 UndoRedo。它只提供统一报告形状，让工具 UI、日志、测试和提交前检查读取同一份结构化结果。

## 烘焙依赖报告

`GFBakeDependencyReport` 适合在导入器、批量生成器或编辑器预检中回答“这次产物为什么需要重建”。输入、输出和逻辑依赖都由调用方显式添加；GF 不扫描项目目录，也不假设产物类型：

```gdscript
var bake := GFBakeDependencyReport.new()
bake.configure(&"navmesh-preview", "Navmesh Preview")
bake.add_input("res://levels/arena.tscn", { "exists": true })
bake.add_output("res://generated/arena_navmesh.tres", { "exists": false })
bake.add_dependency(&"settings", {
	"status": GFBakeDependencyReport.STATUS_STALE,
	"version": settings_revision,
})
bake.mark_stale("settings_changed", { "dependency_id": &"settings" })

var summary := bake.summarize({ "include_invalidations": true })
```

`missing` 输入会让摘要失败，`stale` 输出或依赖表示需要重建但不是错误。真正写入产物时继续使用 `GFGeneratedArtifactReport`，再通过 `add_artifact_report()` 合并到同一份摘要。

## 脚本头部补丁

编辑器工具需要给脚本添加或替换头部注解时，应使用 `GFScriptPatchUtility` 先在文本层生成补丁，再通过 `GFGeneratedArtifactReport` 写回并获得产物报告：

```gdscript
var result := GFScriptPatchUtility.patch_script_path_annotation(
	"res://actors/player.gd",
	"@tool",
	{
		"scan_filesystem": true,
	}
)
```

该工具只处理头部注解行，不解析业务代码、不执行脚本，也不固定某个具体注解。需要替换同类注解时传入 `replacement_prefix`；需要 dry-run 或限制输出根时继续使用 `GFGeneratedArtifactReport.save_text()` 支持的选项。
