# 控件焦点顺序

`GFControlFocusUtility` 提供通用 Control 焦点顺序工具，用于把一组控件的显式顺序写入 Godot 的 `focus_next`、`focus_previous` 和方向邻居属性。它适合设置页、菜单、表单、弹窗和手柄/键盘可操作 UI，不提供具体控件、不接管输入动作，也不规定视觉布局。

## 定位

Godot 的 Control 已经内置焦点属性，但项目经常需要在动态 UI、模板列表或弹窗打开时重新建立稳定导航顺序。`GFControlFocusUtility` 只负责三件事：

- 从节点树收集 `focus_mode` 可用、可见且未禁用的 Control。
- 按显式数组或场景树顺序写入 Tab 顺序和方向邻居。
- 在自定义输入处理中计算或抓取下一项焦点。

不应把它用于表达页面业务状态、按钮启用规则或具体菜单层级。控件是否可聚焦仍应由项目通过 `focus_mode`、可见性和控件状态决定。

## 典型流程

静态表单可以直接传入显式顺序：

```gdscript
GFControlFocusUtility.apply_focus_order(
	[name_edit, difficulty_option, apply_button, back_button],
	{
		"axis": GFControlFocusUtility.AXIS_VERTICAL,
		"wrap": true,
	}
)
```

动态页面可以从根节点收集：

```gdscript
var report: Dictionary = GFControlFocusUtility.apply_focus_order_from_root(settings_panel, {
	"axis": GFControlFocusUtility.AXIS_BOTH,
	"include_hidden": false,
})

if not GFVariantData.get_option_bool(report, "ok"):
	push_warning("焦点顺序存在不可连接项。")
```

自定义输入只需要计算目标时，可以不写入 Control 属性：

```gdscript
var next_control: Control = GFControlFocusUtility.get_next_focus_control(
	controls,
	get_viewport().gui_get_focus_owner(),
	1,
	true
)
if next_control != null:
	next_control.grab_focus()
```

## 常用 API

- `collect_focusable_controls(root, options)`：按场景树顺序收集可聚焦控件；默认排除隐藏、禁用和 `FOCUS_NONE` 控件。
- `apply_focus_order(controls, options)`：按数组顺序写入焦点路径，并返回 `ok`、数量、条目和问题报告。
- `apply_focus_order_from_root(root, options)`：先收集，再按收集顺序应用。
- `get_next_focus_control(controls, current, step, wrap_enabled)`：计算下一项焦点，不产生副作用。
- `grab_next_focus(controls, current, step, wrap_enabled)`：计算并调用 `grab_focus()`。

`axis` 可使用 `AXIS_NONE`、`AXIS_HORIZONTAL`、`AXIS_VERTICAL` 或 `AXIS_BOTH`。`AXIS_NONE` 只写入 Tab 顺序，不写方向邻居。

当只布线某个方向轴时，工具默认会清空未布线方向上的旧邻居，避免动态 UI 重建后留下上一轮布局的路径。例如 `AXIS_HORIZONTAL` 会写入 left/right，并清空 top/bottom。项目确实需要保留手工维护的另一轴邻居时，传入 `"preserve_unwired_directional_neighbors": true`。

## 注意事项

控件之间必须位于同一节点树分支中，工具才能写入相对 `NodePath`。报告中的 `issues` 会暴露无法连接的条目，动态生成 UI 后应优先检查报告，而不是假设所有路径都能成立。

隐藏控件和禁用按钮默认不会进入顺序。项目如果需要预先为暂时隐藏的页面片段生成路径，可以显式传入 `include_hidden` 或 `include_disabled`，但更常见的做法是在页面显示后重新应用焦点顺序。
