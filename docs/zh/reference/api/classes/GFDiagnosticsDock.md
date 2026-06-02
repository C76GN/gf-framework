# GFDiagnosticsDock

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/editor/gf_diagnostics_dock.gd`
- 模块：`Standard`
- 继承：`Control`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

GF 诊断工作区页面。 采集通用运行时、性能、监控和场景树诊断快照，供编辑器内只读查看。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`collect_snapshot`](#member-gfdiagnosticsdock-methods-collect_snapshot) | `func collect_snapshot() -> void:` |
| 方法 | [`get_last_snapshot`](#member-gfdiagnosticsdock-methods-get_last_snapshot) | `func get_last_snapshot() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfdiagnosticsdock-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfdiagnosticsdock-methods-collect_snapshot"></a>

### `collect_snapshot`

- API：`public`

```gdscript
func collect_snapshot() -> void:
```

采集诊断快照。

<a id="member-gfdiagnosticsdock-methods-get_last_snapshot"></a>

### `get_last_snapshot`

- API：`public`

```gdscript
func get_last_snapshot() -> Dictionary:
```

获取最近一次诊断快照。

返回：快照副本。

结构：

- `return`: Dictionary，包含 GFDiagnosticsUtility.collect_snapshot() 返回的诊断分区。

<a id="member-gfdiagnosticsdock-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取面板调试快照。

返回：面板调试快照。

结构：

- `return`: Dictionary，包含 last_snapshot、summary_text、details_text 和 ui 分区。
