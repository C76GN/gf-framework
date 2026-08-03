# GFUIUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

栈式 UI 管理器。 负责可扩展逻辑层中的入栈、出栈、层内可见性策略与异步加载， 适合 HUD、并行窗口、弹窗和顶层遮罩等需要分层管理的 UI 场景。 逻辑层彼此独立：绘制顺序由各层 CanvasLayer.layer 决定，层内 hide_under 不会清理其他层。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`panel_opened`](#member-gfuiutility-signals-panel_opened) | `signal panel_opened(panel: Node, layer: int)` |
| 信号 | [`panel_closed`](#member-gfuiutility-signals-panel_closed) | `signal panel_closed(panel: Node, layer: int)` |
| 信号 | [`navigation_changed`](#member-gfuiutility-signals-navigation_changed) | `signal navigation_changed(layer: int, top_panel: Node)` |
| 信号 | [`panel_dismiss_requested`](#member-gfuiutility-signals-panel_dismiss_requested) | `signal panel_dismiss_requested(panel: Node, layer: int, reason: String)` |
| 信号 | [`panel_async_load_started`](#member-gfuiutility-signals-panel_async_load_started) | `signal panel_async_load_started(path: String, layer: int, operation: StringName)` |
| 信号 | [`panel_async_load_finished`](#member-gfuiutility-signals-panel_async_load_finished) | `signal panel_async_load_finished(path: String, layer: int, operation: StringName, status: int, panel: Node)` |
| 枚举 | [`Layer`](#member-gfuiutility-enums-layer) | `enum Layer` |
| 枚举 | [`PanelMode`](#member-gfuiutility-enums-panelmode) | `enum PanelMode` |
| 枚举 | [`AsyncPanelLoadStatus`](#member-gfuiutility-enums-asyncpanelloadstatus) | `enum AsyncPanelLoadStatus` |
| 常量 | [`DEFAULT_LAYER_ID`](#member-gfuiutility-constants-default_layer_id) | `const DEFAULT_LAYER_ID: int = 1` |
| 方法 | [`init`](#member-gfuiutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfuiutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`configure`](#member-gfuiutility-methods-configure) | `func configure(auto_hide_under: bool = true) -> void:` |
| 方法 | [`register_layer`](#member-gfuiutility-methods-register_layer) | `func register_layer(definition: GFUILayerDefinition, replace_existing: bool = false) -> bool:` |
| 方法 | [`has_layer`](#member-gfuiutility-methods-has_layer) | `func has_layer(layer: int) -> bool:` |
| 方法 | [`get_layer_definition`](#member-gfuiutility-methods-get_layer_definition) | `func get_layer_definition(layer: int) -> GFUILayerDefinition:` |
| 方法 | [`get_layer_ids`](#member-gfuiutility-methods-get_layer_ids) | `func get_layer_ids() -> Array[int]:` |
| 方法 | [`set_layer_auto_hide_under`](#member-gfuiutility-methods-set_layer_auto_hide_under) | `func set_layer_auto_hide_under(layer: int, auto_hide_under: bool) -> bool:` |
| 方法 | [`push_panel_async`](#member-gfuiutility-methods-push_panel_async) | `func push_panel_async( path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable(), completion_callback: Callable = Callable() ) -> GFUIPanelAsyncOperation:` |
| 方法 | [`push_panel_async_with_options`](#member-gfuiutility-methods-push_panel_async_with_options) | `func push_panel_async_with_options( path: String, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable(), completion_callback: Callable = Callable() ) -> GFUIPanelAsyncOperation:` |
| 方法 | [`push_panel`](#member-gfuiutility-methods-push_panel) | `func push_panel(path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable()) -> Node:` |
| 方法 | [`push_panel_with_options`](#member-gfuiutility-methods-push_panel_with_options) | `func push_panel_with_options( path: String, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable() ) -> Node:` |
| 方法 | [`replace_layer`](#member-gfuiutility-methods-replace_layer) | `func replace_layer(path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable()) -> Node:` |
| 方法 | [`replace_layer_with_options`](#member-gfuiutility-methods-replace_layer_with_options) | `func replace_layer_with_options( path: String, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable() ) -> Node:` |
| 方法 | [`replace_layer_async`](#member-gfuiutility-methods-replace_layer_async) | `func replace_layer_async( path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable(), completion_callback: Callable = Callable() ) -> GFUIPanelAsyncOperation:` |
| 方法 | [`replace_layer_async_with_options`](#member-gfuiutility-methods-replace_layer_async_with_options) | `func replace_layer_async_with_options( path: String, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable(), completion_callback: Callable = Callable() ) -> GFUIPanelAsyncOperation:` |
| 方法 | [`push_panel_instance`](#member-gfuiutility-methods-push_panel_instance) | `func push_panel_instance( panel_instance: Node, layer: int = Layer.POPUP, config_callback: Callable = Callable() ) -> void:` |
| 方法 | [`push_panel_instance_with_options`](#member-gfuiutility-methods-push_panel_instance_with_options) | `func push_panel_instance_with_options( panel_instance: Node, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable() ) -> void:` |
| 方法 | [`replace_layer_instance`](#member-gfuiutility-methods-replace_layer_instance) | `func replace_layer_instance( panel_instance: Node, layer: int = Layer.POPUP, config_callback: Callable = Callable() ) -> void:` |
| 方法 | [`replace_layer_instance_with_options`](#member-gfuiutility-methods-replace_layer_instance_with_options) | `func replace_layer_instance_with_options( panel_instance: Node, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable() ) -> void:` |
| 方法 | [`pop_panel`](#member-gfuiutility-methods-pop_panel) | `func pop_panel(layer: int = Layer.POPUP, do_free: bool = true) -> void:` |
| 方法 | [`pop_to_panel`](#member-gfuiutility-methods-pop_to_panel) | `func pop_to_panel(panel: Node, layer: int = Layer.POPUP, do_free: bool = true) -> bool:` |
| 方法 | [`clear_layer`](#member-gfuiutility-methods-clear_layer) | `func clear_layer(layer: int) -> void:` |
| 方法 | [`clear_all`](#member-gfuiutility-methods-clear_all) | `func clear_all() -> void:` |
| 方法 | [`get_top_panel`](#member-gfuiutility-methods-get_top_panel) | `func get_top_panel(layer: int = Layer.POPUP) -> Node:` |
| 方法 | [`get_panel_stack`](#member-gfuiutility-methods-get_panel_stack) | `func get_panel_stack(layer: int = Layer.POPUP) -> Array[Node]:` |
| 方法 | [`get_stack_count`](#member-gfuiutility-methods-get_stack_count) | `func get_stack_count(layer: int = Layer.POPUP) -> int:` |
| 方法 | [`is_panel_open`](#member-gfuiutility-methods-is_panel_open) | `func is_panel_open(panel: Node, layer: int = -1) -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfuiutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`get_layer_root`](#member-gfuiutility-methods-get_layer_root) | `func get_layer_root(layer: int) -> CanvasLayer:` |
| 方法 | [`set_panel_options`](#member-gfuiutility-methods-set_panel_options) | `func set_panel_options(panel: Node, options: Dictionary) -> void:` |
| 方法 | [`get_panel_options`](#member-gfuiutility-methods-get_panel_options) | `func get_panel_options(panel: Node) -> Dictionary:` |
| 方法 | [`is_panel_modal`](#member-gfuiutility-methods-is_panel_modal) | `func is_panel_modal(panel: Node) -> bool:` |
| 方法 | [`has_modal_open`](#member-gfuiutility-methods-has_modal_open) | `func has_modal_open(layer: int = -1) -> bool:` |
| 方法 | [`has_pending_async_panel`](#member-gfuiutility-methods-has_pending_async_panel) | `func has_pending_async_panel(layer: int = -1, path: String = "") -> bool:` |
| 方法 | [`get_pending_async_panel_requests`](#member-gfuiutility-methods-get_pending_async_panel_requests) | `func get_pending_async_panel_requests(layer: int = -1) -> Array[Dictionary]:` |
| 方法 | [`get_modal_count`](#member-gfuiutility-methods-get_modal_count) | `func get_modal_count(layer: int = -1) -> int:` |
| 方法 | [`request_dismiss_top`](#member-gfuiutility-methods-request_dismiss_top) | `func request_dismiss_top(layer: int = -1, reason: String = "cancel") -> bool:` |
| 方法 | [`keep_focus_inside_top_modal`](#member-gfuiutility-methods-keep_focus_inside_top_modal) | `func keep_focus_inside_top_modal(layer: int = Layer.POPUP) -> bool:` |

## 信号

<a id="member-gfuiutility-signals-panel_opened"></a>

### `panel_opened`

- API：`public`

```gdscript
signal panel_opened(panel: Node, layer: int)
```

面板成功进入 UI 栈后发出。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 面板实例。 |
| `layer` | 目标层级。 |

<a id="member-gfuiutility-signals-panel_closed"></a>

### `panel_closed`

- API：`public`

```gdscript
signal panel_closed(panel: Node, layer: int)
```

面板离开 UI 栈后发出。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 面板实例。 |
| `layer` | 原层级。 |

<a id="member-gfuiutility-signals-navigation_changed"></a>

### `navigation_changed`

- API：`public`

```gdscript
signal navigation_changed(layer: int, top_panel: Node)
```

指定层级的栈顶面板变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 发生变化的层级。 |
| `top_panel` | 新栈顶面板；层级为空时为 null。 |

<a id="member-gfuiutility-signals-panel_dismiss_requested"></a>

### `panel_dismiss_requested`

- API：`public`

```gdscript
signal panel_dismiss_requested(panel: Node, layer: int, reason: String)
```

面板请求被取消或关闭时发出。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 请求关闭的面板。 |
| `layer` | 所在层级。 |
| `reason` | 关闭原因。 |

<a id="member-gfuiutility-signals-panel_async_load_started"></a>

### `panel_async_load_started`

- API：`public`

```gdscript
signal panel_async_load_started(path: String, layer: int, operation: StringName)
```

异步面板加载请求开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `operation` | 打开操作，可能为 push 或 replace。 |

<a id="member-gfuiutility-signals-panel_async_load_finished"></a>

### `panel_async_load_finished`

- API：`public`

```gdscript
signal panel_async_load_finished(path: String, layer: int, operation: StringName, status: int, panel: Node)
```

异步面板加载请求结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `operation` | 打开操作，可能为 push 或 replace。 |
| `status` | 结束状态，使用 AsyncPanelLoadStatus。 |
| `panel` | 成功打开的面板；失败或取消时为 null。 |

## 枚举

<a id="member-gfuiutility-enums-layer"></a>

### `Layer`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
enum Layer {
	## 基础信息层，如主界面、血条 HUD 等。
	HUD = 0,
	## 弹窗层，如背包、设置菜单、对话框等。
	POPUP = 1,
	## 顶层，如全屏遮罩、断线重连提示等。
	TOP = 2,
}
```

预置 UI 逻辑层 ID。预置绘制值依次为 HUD=50、POPUP=60、TOP=70； 自定义逻辑层的绘制顺序只由 GFUILayerDefinition.canvas_layer 决定，而不是 layer_id 大小。

<a id="member-gfuiutility-enums-panelmode"></a>

### `PanelMode`

- API：`public`

```gdscript
enum PanelMode {
	## 普通面板。
	NORMAL,
	## Modal 面板，通常会独占当前交互焦点。
	MODAL,
}
```

面板交互模式。

<a id="member-gfuiutility-enums-asyncpanelloadstatus"></a>

### `AsyncPanelLoadStatus`

- API：`public`

```gdscript
enum AsyncPanelLoadStatus {
	## 面板已完成加载并进入 UI 栈。
	OPENED,
	## 加载资源、实例化或入栈失败。
	FAILED,
	## 请求被弹出、清层、替换层或销毁 UI 工具取消。
	CANCELLED,
}
```

异步面板加载结束状态。

## 常量

<a id="member-gfuiutility-constants-default_layer_id"></a>

### `DEFAULT_LAYER_ID`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
const DEFAULT_LAYER_ID: int = 1
```

未指定 layer 参数时使用的默认逻辑层 ID，与 Layer.POPUP 相同。

## 方法

<a id="member-gfuiutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化 UI 层级根节点并激活管理器。

<a id="member-gfuiutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放 UI 层级、面板栈和未完成异步请求。

<a id="member-gfuiutility-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func configure(auto_hide_under: bool = true) -> void:
```

配置 UI 管理器。

参数：

| 名称 | 说明 |
|---|---|
| `auto_hide_under` | 所有已注册逻辑层的新默认遮挡策略。 |

<a id="member-gfuiutility-methods-register_layer"></a>

### `register_layer`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func register_layer(definition: GFUILayerDefinition, replace_existing: bool = false) -> bool:
```

注册或替换一个 UI 逻辑层。

参数：

| 名称 | 说明 |
|---|---|
| `definition` | 层 ID、显示排序与默认遮挡策略。 |
| `replace_existing` | 已存在同 ID 定义时是否替换。 |

返回：注册成功返回 true；定义无效、ID 冲突或无法创建根节点时返回 false。

<a id="member-gfuiutility-methods-has_layer"></a>

### `has_layer`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func has_layer(layer: int) -> bool:
```

检查逻辑层是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 逻辑层 ID。 |

返回：已注册返回 true。

<a id="member-gfuiutility-methods-get_layer_definition"></a>

### `get_layer_definition`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func get_layer_definition(layer: int) -> GFUILayerDefinition:
```

获取逻辑层定义副本。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 逻辑层 ID。 |

返回：已注册层的独立定义副本；不存在时返回 null。

<a id="member-gfuiutility-methods-get_layer_ids"></a>

### `get_layer_ids`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func get_layer_ids() -> Array[int]:
```

获取按逻辑层 ID 升序排列的已注册层。

返回：已注册逻辑层 ID 列表。

<a id="member-gfuiutility-methods-set_layer_auto_hide_under"></a>

### `set_layer_auto_hide_under`

- API：`public`
- 首次版本：`8.1.0`

```gdscript
func set_layer_auto_hide_under(layer: int, auto_hide_under: bool) -> bool:
```

设置指定逻辑层的新面板默认遮挡策略。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 逻辑层 ID。 |
| `auto_hide_under` | 新面板未指定 hide_under 时采用的默认值。 |

返回：层存在并完成更新时返回 true。

<a id="member-gfuiutility-methods-push_panel_async"></a>

### `push_panel_async`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func push_panel_async( path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable(), completion_callback: Callable = Callable() ) -> GFUIPanelAsyncOperation:
```

异步压入一个面板场景。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `config_callback` | 实例化后、入栈前的可选配置回调。 |
| `completion_callback` | 可选终态回调，接收当前 GFUIPanelAsyncOperation；同步回退时可能在本方法返回前调用。 |

返回：已接受请求的类型化句柄；路径无效时返回 null。

<a id="member-gfuiutility-methods-push_panel_async_with_options"></a>

### `push_panel_async_with_options`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func push_panel_async_with_options( path: String, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable(), completion_callback: Callable = Callable() ) -> GFUIPanelAsyncOperation:
```

异步压入一个带策略选项的面板场景。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `options` | 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。 |
| `config_callback` | 实例化后、入栈前的可选配置回调。 |
| `completion_callback` | 可选终态回调，接收当前 GFUIPanelAsyncOperation；同步回退时可能在本方法返回前调用。 |

返回：已接受请求的类型化句柄；同步回退可能返回已完成句柄，路径无效时返回 null。

结构：

- `options`: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。

<a id="member-gfuiutility-methods-push_panel"></a>

### `push_panel`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func push_panel(path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable()) -> Node:
```

同步压入一个面板场景。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `config_callback` | 实例化后、入栈前的可选配置回调。 |

返回：成功时返回面板实例，失败时返回 `null`。

<a id="member-gfuiutility-methods-push_panel_with_options"></a>

### `push_panel_with_options`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func push_panel_with_options( path: String, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable() ) -> Node:
```

同步压入一个带策略选项的面板场景。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `options` | 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。 |
| `config_callback` | 实例化后、入栈前的可选配置回调。 |

返回：成功时返回面板实例，失败时返回 `null`。

结构：

- `options`: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。

<a id="member-gfuiutility-methods-replace_layer"></a>

### `replace_layer`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func replace_layer(path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable()) -> Node:
```

同步替换指定逻辑层的面板栈，不改变其他逻辑层。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `config_callback` | 实例化后、入栈前的可选配置回调。 |

返回：成功时返回面板实例，失败时返回 `null`。

<a id="member-gfuiutility-methods-replace_layer_with_options"></a>

### `replace_layer_with_options`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func replace_layer_with_options( path: String, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable() ) -> Node:
```

同步替换指定层级为带策略选项的面板。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `options` | 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。 |
| `config_callback` | 实例化后、入栈前的可选配置回调。 |

返回：成功时返回面板实例，失败时返回 `null`。

结构：

- `options`: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。

<a id="member-gfuiutility-methods-replace_layer_async"></a>

### `replace_layer_async`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func replace_layer_async( path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable(), completion_callback: Callable = Callable() ) -> GFUIPanelAsyncOperation:
```

异步替换指定层级的面板栈。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `config_callback` | 实例化后、入栈前的可选配置回调。 |
| `completion_callback` | 可选终态回调，接收当前 GFUIPanelAsyncOperation；同步回退时可能在本方法返回前调用。 |

返回：已接受请求的类型化句柄；路径无效时返回 null。

<a id="member-gfuiutility-methods-replace_layer_async_with_options"></a>

### `replace_layer_async_with_options`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func replace_layer_async_with_options( path: String, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable(), completion_callback: Callable = Callable() ) -> GFUIPanelAsyncOperation:
```

异步替换指定层级为带策略选项的面板。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 面板场景路径。 |
| `layer` | 目标层级。 |
| `options` | 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。 |
| `config_callback` | 实例化后、入栈前的可选配置回调。 |
| `completion_callback` | 可选终态回调，接收当前 GFUIPanelAsyncOperation；同步回退时可能在本方法返回前调用。 |

返回：已接受请求的类型化句柄；同步回退可能返回已完成句柄，路径无效时返回 null。

结构：

- `options`: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。

<a id="member-gfuiutility-methods-push_panel_instance"></a>

### `push_panel_instance`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func push_panel_instance( panel_instance: Node, layer: int = Layer.POPUP, config_callback: Callable = Callable() ) -> void:
```

压入一个已实例化的面板节点。

参数：

| 名称 | 说明 |
|---|---|
| `panel_instance` | 面板实例。 |
| `layer` | 目标层级。 |
| `config_callback` | 入栈前的可选配置回调。 |

<a id="member-gfuiutility-methods-push_panel_instance_with_options"></a>

### `push_panel_instance_with_options`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func push_panel_instance_with_options( panel_instance: Node, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable() ) -> void:
```

压入一个已实例化且带策略选项的面板节点。

参数：

| 名称 | 说明 |
|---|---|
| `panel_instance` | 面板实例。 |
| `layer` | 目标层级。 |
| `options` | 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。 |
| `config_callback` | 入栈前的可选配置回调。 |

结构：

- `options`: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。

<a id="member-gfuiutility-methods-replace_layer_instance"></a>

### `replace_layer_instance`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func replace_layer_instance( panel_instance: Node, layer: int = Layer.POPUP, config_callback: Callable = Callable() ) -> void:
```

用已实例化面板替换指定层级的面板栈。

参数：

| 名称 | 说明 |
|---|---|
| `panel_instance` | 面板实例。 |
| `layer` | 目标层级。 |
| `config_callback` | 入栈前的可选配置回调。 |

<a id="member-gfuiutility-methods-replace_layer_instance_with_options"></a>

### `replace_layer_instance_with_options`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func replace_layer_instance_with_options( panel_instance: Node, layer: int = Layer.POPUP, options: Dictionary = {}, config_callback: Callable = Callable() ) -> void:
```

用已实例化且带策略选项的面板替换指定层级的面板栈。

参数：

| 名称 | 说明 |
|---|---|
| `panel_instance` | 面板实例。 |
| `layer` | 目标层级。 |
| `options` | 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。 |
| `config_callback` | 入栈前的可选配置回调。 |

结构：

- `options`: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。

<a id="member-gfuiutility-methods-pop_panel"></a>

### `pop_panel`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func pop_panel(layer: int = Layer.POPUP, do_free: bool = true) -> void:
```

弹出指定层级的顶部面板。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标层级。 |
| `do_free` | 是否在弹出后释放面板。 |

<a id="member-gfuiutility-methods-pop_to_panel"></a>

### `pop_to_panel`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func pop_to_panel(panel: Node, layer: int = Layer.POPUP, do_free: bool = true) -> bool:
```

弹出面板直到指定面板成为栈顶。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 目标面板实例。 |
| `layer` | 目标层级。 |
| `do_free` | 是否释放被弹出的面板。 |

返回：找到目标面板并完成回退时返回 true。

<a id="member-gfuiutility-methods-clear_layer"></a>

### `clear_layer`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear_layer(layer: int) -> void:
```

清空指定逻辑层的所有面板，不改变其他逻辑层。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标层级。 |

<a id="member-gfuiutility-methods-clear_all"></a>

### `clear_all`

- API：`public`

```gdscript
func clear_all() -> void:
```

清空所有层级的所有面板。

<a id="member-gfuiutility-methods-get_top_panel"></a>

### `get_top_panel`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_top_panel(layer: int = Layer.POPUP) -> Node:
```

获取指定层级的顶部面板。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标层级。 |

返回：栈顶面板；为空时返回 `null`。

<a id="member-gfuiutility-methods-get_panel_stack"></a>

### `get_panel_stack`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_panel_stack(layer: int = Layer.POPUP) -> Array[Node]:
```

获取指定层级当前面板栈的副本。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标层级。 |

返回：从底到顶排列的面板列表。

<a id="member-gfuiutility-methods-get_stack_count"></a>

### `get_stack_count`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_stack_count(layer: int = Layer.POPUP) -> int:
```

获取指定层级当前面板数量。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标层级。 |

返回：面板数量。

<a id="member-gfuiutility-methods-is_panel_open"></a>

### `is_panel_open`

- API：`public`

```gdscript
func is_panel_open(panel: Node, layer: int = -1) -> bool:
```

检查面板是否已进入 UI 栈。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 面板实例。 |
| `layer` | 指定层级；小于 0 时检查所有层级。 |

返回：面板已打开时返回 true。

<a id="member-gfuiutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 UI 管理器诊断快照。

返回：包含各层级栈数量和栈顶名称的字典。

结构：

- `return`: Dictionary，包含 active、auto_hide_under、pending_async_panel_count 和 layers；layers 按逻辑层 ID 索引，每项包含 display_name、canvas_layer、auto_hide_under、count、top_panel 和 top_modal。

<a id="member-gfuiutility-methods-get_layer_root"></a>

### `get_layer_root`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_layer_root(layer: int) -> CanvasLayer:
```

获取指定层级的 CanvasLayer。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标层级。 |

返回：对应的 `CanvasLayer` 实例。

<a id="member-gfuiutility-methods-set_panel_options"></a>

### `set_panel_options`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func set_panel_options(panel: Node, options: Dictionary) -> void:
```

设置已打开面板的策略选项。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 面板实例。 |
| `options` | 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。 |

结构：

- `options`: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。

<a id="member-gfuiutility-methods-get_panel_options"></a>

### `get_panel_options`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_panel_options(panel: Node) -> Dictionary:
```

获取面板策略选项。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 面板实例。 |

返回：策略选项副本。

结构：

- `return`: Dictionary，包含 mode、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。

<a id="member-gfuiutility-methods-is_panel_modal"></a>

### `is_panel_modal`

- API：`public`

```gdscript
func is_panel_modal(panel: Node) -> bool:
```

判断面板是否按 modal 策略管理。

参数：

| 名称 | 说明 |
|---|---|
| `panel` | 面板实例。 |

返回：是 modal 面板时返回 true。

<a id="member-gfuiutility-methods-has_modal_open"></a>

### `has_modal_open`

- API：`public`

```gdscript
func has_modal_open(layer: int = -1) -> bool:
```

检查是否存在打开的 modal 面板。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 指定层级；小于 0 时检查所有层级。 |

返回：存在 modal 面板时返回 true。

<a id="member-gfuiutility-methods-has_pending_async_panel"></a>

### `has_pending_async_panel`

- API：`public`

```gdscript
func has_pending_async_panel(layer: int = -1, path: String = "") -> bool:
```

检查是否存在仍在等待资源回调的异步面板请求。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 指定层级；小于 0 时检查所有层级。 |
| `path` | 指定面板路径；为空时不按路径过滤。 |

返回：存在匹配请求时返回 true。

<a id="member-gfuiutility-methods-get_pending_async_panel_requests"></a>

### `get_pending_async_panel_requests`

- API：`public`
- 首次版本：`3.15.0`

```gdscript
func get_pending_async_panel_requests(layer: int = -1) -> Array[Dictionary]:
```

获取仍在等待资源回调的异步面板请求快照。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 指定层级；小于 0 时返回所有层级。 |

返回：请求快照数组，每项包含 path、layer、operation、serial 和 operation_handle。

结构：

- `return`: Array，元素为 Dictionary，包含 path、layer、operation、serial 和 GFUIPanelAsyncOperation operation_handle。

<a id="member-gfuiutility-methods-get_modal_count"></a>

### `get_modal_count`

- API：`public`

```gdscript
func get_modal_count(layer: int = -1) -> int:
```

获取打开的 modal 面板数量。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 指定层级；小于 0 时统计所有层级。 |

返回：modal 面板数量。

<a id="member-gfuiutility-methods-request_dismiss_top"></a>

### `request_dismiss_top`

- API：`public`

```gdscript
func request_dismiss_top(layer: int = -1, reason: String = "cancel") -> bool:
```

按顶层优先顺序处理取消请求。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 指定层级；小于 0 时从最高层级开始查找。 |
| `reason` | 关闭原因。 |

返回：找到可取消面板并处理时返回 true。

<a id="member-gfuiutility-methods-keep_focus_inside_top_modal"></a>

### `keep_focus_inside_top_modal`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func keep_focus_inside_top_modal(layer: int = Layer.POPUP) -> bool:
```

尝试把焦点保持在指定层级栈顶 modal 面板内。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标层级。 |

返回：发生焦点修正时返回 true。
