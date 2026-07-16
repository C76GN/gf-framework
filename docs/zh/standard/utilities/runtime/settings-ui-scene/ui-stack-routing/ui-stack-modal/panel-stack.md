# 面板栈与层级

`GFUIUtility` 用分层栈管理项目 UI。常见层级包括 HUD、POPUP 和 TOP；同一层内按栈顺序维护打开面板，并可在压入新面板时隐藏旧顶层面板。

## 基本操作

```gdscript
var ui_util := Gf.get_utility(GFUIUtility) as GFUIUtility

# 异步推入一个面板到 POPUP 层，优先结合 GFAssetUtility 加载面板。
ui_util.push_panel_async("res://ui/settings_panel.tscn", GFUIUtility.Layer.POPUP)

# 同步加载并推入面板场景。
ui_util.push_panel("res://ui/inventory_panel.tscn", GFUIUtility.Layer.POPUP)

# 已经实例化的面板使用 push_panel_instance()。
var inventory_panel := preload("res://ui/inventory_panel.tscn").instantiate()
ui_util.push_panel_instance(inventory_panel, GFUIUtility.Layer.POPUP, func(panel: Node) -> void:
	panel.name = "InventoryPanel"
)

# 弹出栈顶面板。
ui_util.pop_panel(GFUIUtility.Layer.POPUP)

# 替换当前 POPUP 流程，或回退到某个已打开面板。
ui_util.replace_layer("res://ui/main_menu.tscn", GFUIUtility.Layer.POPUP)
ui_util.pop_to_panel(inventory_panel, GFUIUtility.Layer.POPUP)
```

## 节点父链与场景生命周期

三个层级根节点都创建在 `SceneTree.root` 下，入栈 Panel 会被重挂到对应根级 `CanvasLayer`。因此它们不会随 `SceneTree.current_scene` 自动销毁；场景专属面板应在离场时显式 `pop_panel()`、`clear_layer()` 或由项目统一 `clear_all()`。拥有这些层的 `GFUIUtility.dispose()` 仍会释放 Panel 并移除根级层。

这也意味着 Panel 会离开原来的 `GFNodeContext` 子树。Panel 内的 `GFController` 只能沿新的父链解析依赖，找不到局部 Context 时会回退全局架构。必须消费局部战斗 Model / System 的 HUD 应保留在该 Context 下的场景内 `CanvasLayer`，不要通过当前 UI 栈重挂。根级 Panel 只需要短暂展示局部结果时，可以通过 `config_callback` 传 DTO 或项目适配器，并在 Context 退出前关闭。

## 配置入口

`configure(false)` 会关闭“压入新面板时自动隐藏同层旧顶层面板”的行为。`push_panel()`、`push_panel_async()`、`push_panel_instance()`、`replace_layer()`、`replace_layer_async()` 和 `replace_layer_instance()` 都支持可选 `config_callback`。回调在面板入栈前收到实例，适合设置初始 DTO、连接信号或写入项目级上下文。

## 面板选项

需要声明通用交互策略时，使用对应的 `*_with_options()` 入口，或对已打开面板调用 `set_panel_options()`：

```gdscript
ui_util.push_panel_instance_with_options(settings_panel, GFUIUtility.Layer.POPUP, {
	"modal": true,
	"dismiss_on_cancel": true,
	"focus_on_open": true,
	"restore_focus_on_close": true,
	"metadata": {
		"route": "settings",
	},
})

if ui_util.request_dismiss_top(-1, "cancel"):
	print("top panel dismissed")
```

`metadata` 会随面板选项保存，可用于诊断、项目路由或业务日志。`focus_on_open`、`restore_focus_on_close` 和 `keep_focus_inside_top_modal()` 提供通用焦点辅助；完整 Modal 结果协议见 [Modal 协议](modal-protocol.md)。
