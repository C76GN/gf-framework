# 面板栈与可扩展层级

`GFUIUtility` 用逻辑层和层内栈管理项目 UI。`HUD`、`POPUP`、`TOP` 是开箱即用的默认层，不是固定上限；项目可以用 `GFUILayerDefinition` 注册任意非负逻辑层 ID。逻辑层 ID 用于路由、栈和诊断，`canvas_layer` 只决定 Godot 绘制顺序，两者不应共用一套数字语义。

`GFUIUtility` 属于 `gf.standard.ui.navigation`，不会因为插件存在而自动注册到项目架构。完整包已经包含该 package；最小 kernel 安装需要先安装它及其依赖。

## 启动装配

长期使用的 UI 与 Router 应在项目 Installer 中注册。需要自定义层时，先配置同一个 UI 实例，再交给架构接管：

```gdscript
class_name GameInstaller
extends GFInstaller


const CHAT_LAYER: int = 100
const INVENTORY_LAYER: int = 101


func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	var ui := GFUIUtility.new()
	ui.register_layer(GFUILayerDefinition.new().configure(
		CHAT_LAYER,
		&"CHAT",
		60,
		false
	))
	ui.register_layer(GFUILayerDefinition.new().configure(
		INVENTORY_LAYER,
		&"INVENTORY",
		60,
		false
	))

	if not await architecture.register_utility_instance(ui):
		architecture.fail_initialization("GFUIUtility 注册失败。")
		return
	if scope.is_cancel_requested():
		return
	if not await architecture.register_utility_instance(GFUIRouterUtility.new()):
		architecture.fail_initialization("GFUIRouterUtility 注册失败。")
```

把 Installer 写入 `Project Settings > gf/project/installers`，并检查初始化结果后再查询 Utility：

```gdscript
if not await Gf.init():
	push_error(Gf.get_architecture().last_initialization_error)
	return

var ui := Gf.get_utility(GFUIUtility, true) as GFUIUtility
if ui == null:
	push_error("GFUIUtility 未完成装配。")
	return
```

## 基本操作

```gdscript
ui.push_panel_async("res://ui/settings_panel.tscn", GFUIUtility.Layer.POPUP)
ui.push_panel("res://ui/inventory_panel.tscn", GFUIUtility.Layer.POPUP)

var inventory_panel := preload("res://ui/inventory_panel.tscn").instantiate()
ui.push_panel_instance(inventory_panel, GFUIUtility.Layer.POPUP)

ui.pop_panel(GFUIUtility.Layer.POPUP)
ui.replace_layer("res://ui/main_menu.tscn", GFUIUtility.Layer.POPUP)
ui.pop_to_panel(inventory_panel, GFUIUtility.Layer.POPUP)
```

## 并行窗口与遮挡策略

左右窗口需要独立打开、返回和清理时，应使用两个逻辑层，即使它们共享同一个 `canvas_layer`。这样聊天和背包各自维护栈，不会因为一个区域 `pop` 或 `replace` 而改变另一区域。

同一导航域中的常驻资源条、非全屏通知和临时窗口可以留在同一栈，但由压在上方的面板声明 `hide_under = false`：

```gdscript
ui.push_panel_instance(resource_bar, GFUIUtility.Layer.HUD)
ui.push_panel_instance_with_options(activity_notice, GFUIUtility.Layer.HUD, {
	"hide_under": false,
})
```

默认 `hide_under = true`，适合真正覆盖当前流程的全屏页面或 Modal。遮挡面板弹出后，GF 会从栈顶向下重新计算完整可见性链，不只恢复相邻面板。

可以用 `set_layer_auto_hide_under(layer_id, false)` 修改某个逻辑层的默认值；`configure(false)` 会修改所有已注册层，通常只适合全局策略初始化。单次面板差异优先用 `hide_under`，避免把一个通知需求扩散成全局行为。

## 面板选项

`push_panel_with_options()`、`push_panel_async_with_options()`、`push_panel_instance_with_options()` 和对应 replace 入口支持：

- `mode` / `modal`：普通或 Modal 行为。
- `hide_under`：当前面板可见时是否隐藏同栈更低面板。
- `dismiss_on_cancel`：取消请求是否关闭面板。
- `focus_on_open` / `restore_focus_on_close`：焦点进入与恢复策略。
- `metadata`：项目自定义路由和诊断元数据。

```gdscript
ui.push_panel_instance_with_options(settings_panel, GFUIUtility.Layer.POPUP, {
	"modal": true,
	"dismiss_on_cancel": true,
	"focus_on_open": true,
	"restore_focus_on_close": true,
	"metadata": { "route": "settings" },
})
```

## 节点父链与场景生命周期

所有层根节点都创建在 `SceneTree.root` 下，Panel 会被重挂到对应 `CanvasLayer`，不会随 `SceneTree.current_scene` 自动销毁。场景专属面板应在离场时显式 `pop_panel()`、`clear_layer()` 或 `clear_all()`；`GFUIUtility.dispose()` 会释放全部 Panel 和层根。

Panel 重挂后会离开原来的 `GFNodeContext` 子树。必须消费局部战斗 Model/System 的 HUD 应留在该 Context 下的项目 `CanvasLayer`；根级 Panel 只短暂展示局部结果时，通过配置回调传入 DTO 或项目适配器，并在 Context 退出前关闭。
