# Dialogue 通用对话资源

Dialogue 扩展提供抽象对话资源、运行上下文和对话推进器。它负责表达行、响应、跳转、条件和 mutation 请求，不规定剧本语言、对话框 UI、本地化表、角色数据、存档结构或项目状态字段。

Dialogue 适合作为对话流程的最小运行时抽象。项目可以在自己的导入器、图编辑器、UI、文本解析器、条件处理器、mutation 处理器和存档系统中解释业务语义。

## 阅读入口

- `GFDialogueResource`：保存起始行和行集合。
- `GFDialogueLine`：表达文本、mutation、跳转或结束点。
- `GFDialogueResponse`：描述可选响应及其后继。
- `GFDialogueContext`：保存运行时值表，并提供条件、mutation 和文本解析回调。
- `GFDialogueRunner`：推进资源，发出行、响应、mutation 和结束信号。
- 可选制作期 [Dialogue Text 工具包](../../editor/tools/dialogue-text.md)：把严格 JSON 文本编译为同一运行时资源，并输出结构化校验报告。

## 最小流程

```gdscript
var resource := GFDialogueResource.new()
resource.start_line_id = &"start"

var start := GFDialogueLine.new()
start.line_id = &"start"
start.text = "hello_key"
start.next_line_id = &"end"
resource.set_line(start)

var end := GFDialogueLine.new()
end.line_id = &"end"
end.kind = GFDialogueLine.LineKind.END
resource.set_line(end)

var context := GFDialogueContext.new()
context.text_resolver = func(text_key: String, _line: GFDialogueLine) -> String:
	return tr(text_key)

var runner := GFDialogueRunner.new()
runner.start(resource, &"", context)
runner.advance()
```

## 运行快照

`GFDialogueRunner.create_runtime_snapshot()` 会产出只包含运行状态的字典：结构版本、是否运行中、当前行 ID 和 `GFDialogueContext` 的值表。
项目存档仍负责保存资源键、章节 ID 或文件路径；恢复时把对应 `GFDialogueResource` 重新传给 `restore_runtime_snapshot()`。

恢复快照只重建当前位置和上下文值，不会重新发出开始、到达行或 mutation 信号，也不会再次执行已经经过的 mutation。调用方可使用 `restore_runtime_snapshot()` 返回的当前行刷新 UI。

当前可恢复 checkpoint 必须位于可展示的 `TEXT` 行。项目应只在 `get_current_line() != null` 时持久化运行快照；`dialogue_started`、`mutation_requested` 或自动跳转等同步回调仍处于推进中的位置，这些位置生成的字典不应作为长期存档。如何正式表达推进中 checkpoint 尚属于后续快照协议决策，Runner 不会猜测或重放 mutation。

Runner 在 `start()` 前同步计算完整资源指纹，恢复时要求指纹精确一致。字典插入顺序不会改变指纹，但文本、metadata、payload、行或响应内容的变化都会改变指纹。身份输入必须无循环、不含运行时 Object/Callable/Signal/RID，并受完整复制预算约束；身份不完整或超限时 `start()` 会返回 `null`。因此，当前实现适合对内容完全一致的资源做严格恢复，不应把它当作跨内容修订的存档迁移协议。

## 资源校验与推进边界

- `validate_resource()` 会拒绝空图、空或重复行 ID、非法 `LineKind`、缺失后继和无条件自动循环；它仍不判断剧情设计是否合理。
- `max_steps_per_advance` 只计算被跳过的条件行以及实际执行的 JUMP/MUTATION 等非展示转换；到达 TEXT 本身不消耗预算。小于等于 `0` 表示不启用步数上限，循环检测仍然生效。
- 条件、mutation 和 Runner 信号都是同步项目代码边界。回调可以停止或替换当前会话；一旦会话改变，旧推进栈会作废并返回 `null`，不会覆盖新会话。
- mutation 处理器返回失败时，Runner 只阻止推进，不可能自动回滚项目已经产生的外部副作用。处理器应在成功前自行保持原子性或幂等性；是否提供框架级事务/once 协议仍需单独决策。

## 使用边界

- 条件和 mutation 只保存 ID 与载荷，实际含义由项目通过 `GFDialogueContext` 的回调处理。
- Runner 不创建 UI，也不读取输入；项目界面负责显示 `get_current_line()` 和 `get_available_responses()`。
- 可复用的严格 JSON 编译可以安装独立 `gf.tool.dialogue_text`；分支可视化、语音、字幕、本地化表、内容目录和存档恢复仍放在项目层或独立插件里。
- `validate_resource()` 与 Runner 都只处理通用图结构，不替项目决定内容发布、版本迁移或副作用事务策略。

## API Reference

完整类、方法和信号列表见 [Dialogue API Reference](../../reference/api/extensions-dialogue.md)。
