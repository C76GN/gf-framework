# GFRuntimeDebuggerPlugin

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/editor/gf_runtime_debugger_plugin.gd`
- 模块：`Standard`
- 继承：`EditorDebuggerPlugin`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`6.0.0`

GF 运行时诊断 EditorDebugger 插件。 为每个 Godot 调试会话安装 GF Runtime 页，并把运行时 GFDiagnosticsUtility 通过 EngineDebugger 返回的消息转发给对应页面。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_debug_snapshot`](#member-gfruntimedebuggerplugin-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfruntimedebuggerplugin-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取插件调试快照。

返回：调试快照。

结构：

- `return`: Dictionary with session_ids and tab_count.
