# 编辑器命令、动作与工具协议

复杂编辑器工具建议把入口、交互和修改拆开，让 UI 按钮只负责触发动作，真正修改资源或节点的逻辑集中到命令中，并自然接入 Godot UndoRedo。

## 协议类型

- `GFEditorCommand`：封装一次可执行、可撤销的编辑器修改，可直接 `execute()` / `revert()`，也可写入 `EditorUndoRedoManager`。
- `GFEditorCommandSession`：围绕一组命令提供 preview、commit、revert history 和 debug snapshot，适合需要连续交互的编辑器工具。
- `GFEditorActionDefinition`：描述菜单、按钮或快捷键入口，通过 `command_factory` 按上下文创建命令。
- `GFEditorTool`：封装需要持续激活、接收输入和绘制辅助的交互工具。
- `GFEditorToolContext`：在工具、动作和命令之间传递 `EditorPlugin`、UndoRedo、当前场景根节点、选中节点和元数据。
- `GFEditorToolOption` / `GFEditorToolOptionSchema`：声明工具设置项和值规范化规则，供项目自己的工具面板生成 UI 或持久化配置。
- `GFEditorPickOperation`：描述拾取、预览、ready、应用和取消这类分阶段交互。

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
