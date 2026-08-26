# GFProjectLayoutDock

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/project_layout/editor/gf_project_layout_dock.gd`
- 模块：`Tools`
- 继承：`VBoxContainer`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`unreleased`

GF Project Layout 只读工作区页面。 页面按用户操作捕获项目库存，在后台生成分析结果，并展示 finding、解释、影响和计划。 它不提供 Apply、自动修复、创建、移动、重命名或删除入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATE_IDLE`](#member-gfprojectlayoutdock-constants-state_idle) | `const STATE_IDLE: String = "idle"` |
| 常量 | [`STATE_CAPTURING`](#member-gfprojectlayoutdock-constants-state_capturing) | `const STATE_CAPTURING: String = "capturing"` |
| 常量 | [`STATE_ANALYZING`](#member-gfprojectlayoutdock-constants-state_analyzing) | `const STATE_ANALYZING: String = "analyzing"` |
| 常量 | [`STATE_COMPLETE`](#member-gfprojectlayoutdock-constants-state_complete) | `const STATE_COMPLETE: String = "complete"` |
| 常量 | [`STATE_PARTIAL`](#member-gfprojectlayoutdock-constants-state_partial) | `const STATE_PARTIAL: String = "partial"` |
| 常量 | [`STATE_CANCELLED`](#member-gfprojectlayoutdock-constants-state_cancelled) | `const STATE_CANCELLED: String = "cancelled"` |
| 常量 | [`STATE_FAILED`](#member-gfprojectlayoutdock-constants-state_failed) | `const STATE_FAILED: String = "failed"` |
| 方法 | [`scan_project`](#member-gfprojectlayoutdock-methods-scan_project) | `func scan_project() -> void:` |
| 方法 | [`cancel_scan`](#member-gfprojectlayoutdock-methods-cancel_scan) | `func cancel_scan() -> void:` |
| 方法 | [`get_state`](#member-gfprojectlayoutdock-methods-get_state) | `func get_state() -> String:` |
| 方法 | [`get_last_result`](#member-gfprojectlayoutdock-methods-get_last_result) | `func get_last_result() -> Dictionary:` |

## 常量

<a id="member-gfprojectlayoutdock-constants-state_idle"></a>

### `STATE_IDLE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_IDLE: String = "idle"
```

页面尚未开始捕获。

<a id="member-gfprojectlayoutdock-constants-state_capturing"></a>

### `STATE_CAPTURING`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_CAPTURING: String = "capturing"
```

页面正在主线程分批捕获库存。

<a id="member-gfprojectlayoutdock-constants-state_analyzing"></a>

### `STATE_ANALYZING`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_ANALYZING: String = "analyzing"
```

页面正在后台分析冻结库存。

<a id="member-gfprojectlayoutdock-constants-state_complete"></a>

### `STATE_COMPLETE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_COMPLETE: String = "complete"
```

分析完整结束。

<a id="member-gfprojectlayoutdock-constants-state_partial"></a>

### `STATE_PARTIAL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_PARTIAL: String = "partial"
```

输入或分析不完整。

<a id="member-gfprojectlayoutdock-constants-state_cancelled"></a>

### `STATE_CANCELLED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_CANCELLED: String = "cancelled"
```

用户取消了请求。

<a id="member-gfprojectlayoutdock-constants-state_failed"></a>

### `STATE_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_FAILED: String = "failed"
```

请求因输入或执行错误失败。

## 方法

<a id="member-gfprojectlayoutdock-methods-scan_project"></a>

### `scan_project`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func scan_project() -> void:
```

请求一次新的只读项目扫描。

<a id="member-gfprojectlayoutdock-methods-cancel_scan"></a>

### `cancel_scan`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_scan() -> void:
```

取消当前捕获或后台分析。

<a id="member-gfprojectlayoutdock-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_state() -> String:
```

返回页面当前状态。

返回：String，页面当前状态；值属于 STATE_* 常量闭集。

<a id="member-gfprojectlayoutdock-methods-get_last_result"></a>

### `get_last_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_last_result() -> Dictionary:
```

返回最近一次 data-only 页面结果；输入不完整时仍保留 partial 结果供解释。

返回：Dictionary，包含 analysis、plan 和 impact。

结构：

- `return`: Dictionary，精确包含 analysis、plan 和 impact；尚无相应结果时值为空 Dictionary。
