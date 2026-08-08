# 2D Spatial Canvas

`GFSpatialCanvas2D` 是面向游戏内建造界面、战术地图、关卡沙盘和其他 2D 空间交互的运行时 `Control`。它把世界坐标与画布坐标转换、平移缩放、网格吸附、候选查询、稳定选择和受控放置会话放在一个有硬预算的通用边界内；项目仍拥有节点、模型、占位规则、权限和最终业务命令。

该能力位于可选包 `gf.standard.spatial.canvas`。包依赖 `gf.kernel`、`gf.standard.base`、`gf.standard.input` 和 `gf.standard.spatial`，也包含在 `gf.preset.2d_toolkit` 中。

## 创建画布与挂载内容

画布内部提供一个 `Node2D` 内容根。项目把自己的可视节点挂到该根节点，GF 只随视图更新它的位置和缩放，不接管、释放或重挂项目内容。

```gdscript
var canvas := GFSpatialCanvas2D.new()
add_child(canvas)
canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

var world_layer := canvas.get_content_root()
world_layer.add_child(project_world_visuals)

if not canvas.set_view(Vector2(512.0, 384.0), 1.0):
	push_error("Invalid spatial canvas view")
```

`world_to_canvas()` 和 `canvas_to_world()` 使用本 `Control` 的局部画布坐标；`world_to_screen()` 和 `screen_to_world()` 额外包含父级与 `CanvasLayer` 变换，适合 Viewport 屏幕坐标。`zoom_at()` 在不触发世界边界约束时保持焦点下的世界位置不变；设置世界边界后，边缘缩放优先保持可见范围合法，视口大于世界时则稳定居中。

所有视图、边界和网格配置都拒绝 `NaN`、无穷值、零尺寸等非法输入，并保持原配置不变。调用方必须检查布尔返回值，不应把失败当作隐式纠正。

## 网格与输入

`configure_grid()` 配置网格原点、单元尺寸和可选旋转步长。位置转换对负坐标使用 `floor` 语义，避免原点两侧格子身份不一致。

```gdscript
var configured := canvas.configure_grid(
	Vector2.ZERO,
	Vector2(32.0, 32.0),
	{ "rotation_step_radians": PI / 4.0 }
)
if configured:
	var cell := canvas.world_to_cell(pointer_world)
	var center := canvas.cell_to_world(cell, true)
	var snapped_position := canvas.snap_world_position(pointer_world)
	var snapped_rotation := canvas.snap_rotation(candidate_rotation)
```

`GFSpatialCanvasInputPolicy` 以纯数据声明平移、选择、滚轮、原始触摸、系统手势和放置取消输入。默认策略保持中键平移、左键选择、垂直滚轮缩放、单指平移，以及双指平移和捏合缩放；取消只使用 InputMap 的 `ui_cancel`，没有 raw Escape 特判。项目可以替换直接按钮或改用已经存在的 InputMap action：

```gdscript
var policy := GFSpatialCanvasInputPolicy.new()
policy.pan_mouse_button = MOUSE_BUTTON_NONE
policy.pan_action = &"tactical_canvas_pan"
policy.wheel_routing = GFSpatialCanvasInputPolicy.WheelRouting.MODIFIER_GATED
policy.wheel_modifier_mask = GFSpatialCanvasInputPolicy.ModifierMask.CTRL
policy.consume_wheel_events = true
policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.NONE
policy.touch_multi_pan_enabled = false
policy.touch_multi_zoom_enabled = true

policy.selection_modifier_bindings.clear()
var add_binding := GFSpatialCanvasSelectionModeBinding.new()
add_binding.modifier_mask = GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
add_binding.selection_mode = GFSpatialCanvas2D.SelectionMode.ADD
policy.selection_modifier_bindings.append(add_binding)

if not canvas.set_input_policy(policy):
	push_error("Invalid spatial canvas input policy")
```

`set_input_policy()` 先把候选公开字段及嵌套 `GFSpatialCanvasSelectionModeBinding` 逐字段复制到纯 GF 基类实例，再完整校验和原子替换；它不会调用候选子类可覆写的校验或复制方法。失败时保留上一份策略，`get_input_policy()` 也只返回纯基类隔离副本。直接 pan 按钮精确匹配 `pan_modifier_mask`；pan action 的完整 chord 由 InputMap 精确匹配，此时 `pan_modifier_mask` 必须为零。选择绑定同样按完整修饰键掩码精确匹配，按下时冻结选择模式，捕获后由同一物理按钮释放，期间 modifier 变化不会改写本次操作。direct 与 action、两个 action 之间的物理 chord 重叠会使策略失败；如果 InputMap 在应用策略后被改成冲突映射，运行时也会忽略该冲突事件且不修改状态。选择修饰键绑定最多 15 个，单个 action 校验和运行期匹配最多扫描 64 个事件，超限直接失败关闭。

`placement_cancel_action` 必须是非指针动作：任何鼠标、触摸或位置手势事件都会让策略失败，避免取消优先级抢占 pan、selection 或 wheel。画布在每次匹配取消前都会重新执行同一 64-event 有界检查；如果项目在策略应用后修改 InputMap 使其包含指针事件或超过预算，本次取消匹配失败关闭，原指针事件仍可由正常画布行为解释。

`handle_input_event()` 接受本 `Control` 的局部画布坐标，`handle_screen_input_event()` 则复制 Viewport 屏幕坐标事件并局部化。二者返回 `GFSpatialCanvas2D.InputDisposition`：`IGNORED` 表示未修改状态，`HANDLED` 表示已处理但允许继续传播，`CONSUMED` 表示 GUI 边界应停止传播。手工转发方法不会调用 Viewport handled API，调用方必须显式解释返回值。

画布自身使用 `MOUSE_FILTER_PASS`。`_gui_input()` 只对 `CONSUMED` 调用 `accept_event()`；`consume_handled_events` 控制一般输入，`consume_wheel_events` 单独控制滚轮。`PARENT_ONLY` 的滚轮、`MODIFIER_GATED` 下未精确匹配 modifier 的滚轮都返回 `IGNORED`，因此能自然冒泡给父 `ScrollContainer`；被画布消费的滚轮不会被强制穿透。垂直与水平轴可独立选择，平滑滚轮的有限正 `event.factor` 作为有硬上限的指数参与缩放，非法或过大 factor 被忽略。

一次被接受的鼠标平移/选择 press 或可能形成已启用行为的第一个原始触摸 press 会建立唯一的物理输入捕获所有权。raw touch 持有期间，全部 `InputEventMouse`（包括 wheel）都返回 `IGNORED`；鼠标持有期间，raw touch press/drag/release 都返回 `IGNORED`；两者都会排除系统 `PanGesture` / `MagnifyGesture`。冲突事件不更新视图、选择几何或手势追踪，只有匹配的鼠标 release、最后一个已接管触点的 release 或显式 cancel 才释放所有权。Godot 标记为 `canceled` 的当前鼠标按钮或已跟踪 touch 只释放整份瞬态捕获，绝不把取消位置解释成正常 release，也不会提交 selection 或 placement；不属于当前 owner 的取消事件仍保持 `IGNORED`。系统手势在没有物理捕获时仍可正常工作；placement 会话本身不构成物理输入捕获。

原始触摸可整体关闭，单指主行为可独立设为 `NONE`、pan 或 select，多指 pan 与 pinch zoom 也各自显式开关；系统 `PanGesture` 与 `MagnifyGesture` 继续使用各自开关。单指为 `NONE` 且两个多指行为都关闭时，raw touch 全程 `IGNORED`，不会暗中建立捕获；只要任一多指行为启用，首触点必须先被捕获以确定性等待第二触点，但单指移动仍不修改视图或选择。第二触点进入允许的多指手势时会结束尚未提交的单指选择捕获，但不会取消活动 placement。禁用输入、成功替换策略、Control 失焦、应用失焦或暂停、Canvas 变为不可见以及退出场景树都会释放鼠标和触摸的瞬态捕获，同时保留条目、当前选择和 placement 会话；清理后的迟到 release 不会复活旧 owner。

## 候选、命中与选择

`upsert_item()` 只登记稳定 `StringName`、世界空间 `Rect2` 和少量通用选项。它不会跟踪项目节点；节点移动、销毁或模型变化后，由项目显式更新或移除记录。

```gdscript
canvas.upsert_item(
	&"building:42",
	building_bounds,
	{
		"selectable": true,
		"selection_priority": 10,
		"exact_hit": func(
			item_id: StringName,
			world_point: Vector2,
			bounds: Rect2
		) -> bool:
			return project_shapes.contains_point(item_id, world_point, bounds),
	}
)

var hit_ids := canvas.query_items_at(pointer_world)
var selected_ids := canvas.set_selection(
	hit_ids,
	GFSpatialCanvas2D.SelectionMode.REPLACE
)
```

点查询先按 AABB 取候选，再执行项目提供的可选精确命中回调。画布遍历底层空间索引返回的候选，并用有界 top-K 保留全局 `selection_priority` 最高、稳定 ID 最小的查询窗口；`max_query_candidates` 限制窗口、精确命中回调和返回结果，不替代底层索引自身受 `max_items` 约束的空间遍历。点选与框选在构造窗口前过滤不可选条目，因此不可选条目不会占用选择查询预算。`set_selection()` 支持替换、追加、切换和减去：候选先按稳定 ID 排序，容量只限制最终新增或替换结果，减去与切换仍会处理绝对输入上限内的全部候选。返回数组和 `selection_changed` 信号参数均为隔离副本，调用方修改它们不会改写画布内部状态。

`exact_hit` 是同步、受信的项目回调。回调只应做快速纯判断，不应重入画布、执行 IO 或承载任意项目载荷；已配置但目标失效的回调会失败关闭。

## 受控放置会话

放置会话保存稳定类型 ID、局部边界、世界位置、旋转和吸附选项。项目可以提供同步校验器与历史 Hook；只有校验和历史 Hook 都接受后，`commit_placement()` 才返回成功并结束会话。

```gdscript
canvas.set_placement_validator(
	func(candidate: Dictionary) -> Dictionary:
		return project_occupancy.validate_candidate(candidate)
)
canvas.set_history_hook(
	func(operation: Dictionary) -> bool:
		return project_commands.record_spatial_operation(operation)
)

var session_id := canvas.begin_placement(
	&"tower",
	Rect2(Vector2(-16.0, -16.0), Vector2(32.0, 32.0)),
	{
		"initial_world_position": pointer_world,
		"snap_to_grid": true,
		"snap_rotation": true,
	}
)
if session_id > 0:
	var report := canvas.commit_placement()
	if not GFVariantData.get_option_bool(report, "ok"):
		push_warning(
			"Placement rejected: %s"
			% GFVariantData.get_option_string_name(report, "reason")
		)
```

校验拒绝、历史拒绝、失效回调、非法 `ok` 类型或回调重入都失败关闭，并保留活动预览供项目修正或取消。`cancel_placement()` 只结束 GF 会话并返回稳定报告，不释放项目内容。画布生成的操作记录是通用结构，不替代项目的撤销/重做系统、网络权限、资源消耗或最终模型提交。所有 options 字典只接受文档列出的字段与严格类型；未知或类型错误字段会原子拒绝，不会静默回退。

## Asset Catalog 到编辑器命令的组合配方

项目素材面板或关卡工具可以组合现有能力形成 `GFAssetCatalog` 稳定 ID → `GFThumbnailRenderer` 缩略图 → `GFDragDropUtility` 类型化拖放 → `GFSpatialCanvas2D` placement → `GFEditorCommandSession` 提交的制作流程，不需要新增业务化运行时类：

1. 素材列表只把 `asset_id` 当作持久身份；资源路径、列表下标、已加载 Object 和缩略图节点都不是权威引用。缩略图只为有界可见项或当前选择生成，缓存键同时包含稳定 ID 和当前内容身份，工具关闭时取消任务并释放预览节点。
2. 拖放使用项目命名空间下的单一 `drag_type`，payload 采用 closed schema，例如 `schema_version`、`asset_id`、`expected_type` 和 `catalog_revision`。落点必须从当前 Catalog 重新解析 ID，并拒绝缺失、过期、超预算或类型伪造的 payload，不能信任拖拽开始时携带的路径或对象。
3. 校验后的落点坐标通过 `screen_to_world()` 或 `canvas_to_world()` 转换；项目 Adapter 决定 footprint 与 placement type，再调用 `begin_placement()`、`update_placement()` 和 `commit_placement()`。画布只冻结操作记录，占位、权限、资源消耗和场景合法性继续由项目 validator 判断。
4. history hook 从稳定 `asset_id` 和冻结 placement operation 创建一次性的项目 `GFEditorCommand`。命令在 `execute()` 中重新验证权威状态、在 `revert()` 中对称恢复，并通过 `GFEditorCommandSession.preview_command()` / `commit_command()` 或 Godot UndoRedo 提交。只有命令提交成功后 hook 才返回成功；不要再让 `placement_committed` 的另一个监听器重复修改同一权威状态。

AI Developer Kit 中的 Recipe ID 为 `asset-catalog-spatial-placement`。它描述的是组件边界和验收组合，不规定项目素材分类、场景工厂、节点类型、碰撞规则或保存格式。至少应覆盖 stale ID、拖放类型伪造、坐标换算、非法 footprint、预算耗尽、命令拒绝、撤销/重做、取消和 owner 释放。

## 预算与诊断

`configure_budgets()` 可降低实例预算，但不能突破类定义的绝对上限。当前预算覆盖：

- 登记条目总数；
- 选择结果数量；
- 单次查询候选数量；
- 单次网格绘制线数。

容量耗尽时，新条目和非法预算配置会被拒绝；查询达到候选上限时只返回全局优先级 top-K，并在 `get_debug_snapshot()` 中记录 `last_query_truncated`。所有公开坐标、网格吸附、视图与放置入口除了检查输入有限性，还会检查变换、除法、旋转 AABB 等派生结果；派生出 `INF`/`NAN` 时保持原状态并返回失败或文档声明的稳定哨兵。诊断快照保持 JSON-safe，只包含数量、状态和截断等框架诊断，不包含项目回调、任意业务载荷或内容节点数据。

项目应根据可见区域和预期密度主动收紧预算，并把大规模实体查询继续交给 [逻辑空间查询](spatial-query.md) 的索引能力。画布的条目表服务于 UI 交互一致性，不是通用 ECS、物理世界或无限场景数据库。

## 边界

- GF 不创建或销毁项目可视节点，也不自动同步节点变换与条目边界。
- GF 不定义占位、地形、阵营、费用、科技、权限、保存或网络确认规则。
- 放置校验器和历史 Hook 是受信同步 Adapter，不是脚本沙箱、异步任务队列或远程协议。
- `GFSpatialCanvas2D` 是运行时 `Control`，不替代 Godot 编辑器插件或项目专用关卡编辑器。
- 框选、点选和放置只产生通用稳定 ID 与操作报告；最终业务模型必须由项目明确提交。

完整类、方法、枚举和信号列表见 [Standard API Reference](../../reference/api/standard.md)。
