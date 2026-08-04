# 虚拟列表布局与焦点模型

`GFVirtualListModel` 是一个纯布局模型，用来维护大量可变尺寸条目的估算尺寸、实测尺寸、累计偏移和可见范围。`GFVirtualListFocusModel` 用数据索引维护虚拟焦点，让回收式列表不用把键盘或手柄焦点绑定到临时物化的 `Control`。需要框架接管可见行的创建、复用、测量和焦点交接时，使用 owner-bound 的 `GFVirtualListBinder`；每轮结果通过 `GFVirtualListSyncResult` 返回。

## 定位

布局模型只回答四个问题：列表有多少条目、每个条目的尺寸是多少、当前滚动窗口应该显示哪些索引、尺寸变化后是否需要修正滚动偏移。焦点模型只回答当前哪个数据索引拥有虚拟焦点、前后移动应落到哪个可聚焦索引、数据数量变化后焦点应如何修正。它们都不创建 `Control`，不保存条目数据，也不规定选择、拖拽、搜索或视觉样式。

Binder 只补齐通用的节点物化边界：监听滚动与模型版本，按稳定 identity 复用行，执行对称 bind/unbind，更新绝对布局并在 owner 退出树时确定性释放。条目数据、稳定 ID、行视觉、选择、激活、输入和无障碍语义仍由项目持有，因此运行时 UI 与编辑器工具可以使用同一套 primitive，而不把业务层写进框架。

## 布局流程

```gdscript
var model := GFVirtualListModel.new()
model.estimated_item_extent = 56.0
model.overscan_items = 2
model.trailing_padding = 24.0
model.set_item_count(entries.size())

func refresh_visible_rows(scroll_y: float, viewport_height: float) -> void:
	var viewport_range := model.get_viewport_range(scroll_y, viewport_height)
	var visible_range := model.get_visible_range(scroll_y, viewport_height)
	for index in range(visible_range.x, visible_range.y):
		var offset := model.get_item_offset(index)
		var extent := model.get_item_extent(index)
		# 项目在这里创建或复用自己的 Control，并放到 offset。
```

`get_viewport_range()` 是不含 overscan 的真实视口范围，`get_visible_range()` 是加入 overscan 后的请求范围。模型的每次有效公开写操作只推进一次 `get_revision()` 并发出一次 `layout_changed(revision)`；无变化或被拒绝的写入不会制造版本噪声。Binder 会用真实视口范围优先分配节点预算，再把剩余预算用于 overscan。

当某个行控件完成布局后，把实际高度写回模型。若被修改的条目位于当前视口之前，报告会给出 `scroll_adjustment`，调用方可以把滚动偏移加上这个值来减少内容跳动。

```gdscript
var report := model.set_item_extent(row_index, measured_height, true, scroll_y)
if report["changed"] and report["scroll_adjustment"] != 0.0:
	scroll_container.scroll_vertical += int(report["scroll_adjustment"])
```

## 受控节点物化

`GFVirtualListBinder.bind()` 需要一个已进入 SceneTree 的生命周期 owner、`ScrollContainer`、作为其直接子节点的绝对布局 `Control`，以及布局模型和项目回调。`content_root` 不能是会重新排列子节点的 `Container`。factory 必须返回 parentless `Control`；成功返回后该节点的所有权转交 Binder。

```gdscript
var binder := GFVirtualListBinder.new()
binder.max_materialized_items = 128
binder.max_pooled_items = 24

var bound := binder.bind(
	self,
	$ScrollContainer,
	$ScrollContainer/Content,
	model,
	func() -> Control:
		return row_scene.instantiate(),
	func(row: Control, index: int, item_id: Variant) -> bool:
		row.present(entries[index])
		return true,
	func(row: Control, _index: int, _item_id: Variant) -> void:
		row.reset_presentation(),
	func(index: int) -> Variant:
		return entries[index].stable_id,
	focus
)

if bound:
	binder.request_sync()
```

四个回调遵循以下契约：

- identity 回调必须为当前请求范围返回唯一、稳定且可由 `GFVariantKeyCodec` 编码的 key；不得把数组索引冒充跨排序稳定 ID。
- bind 回调只把当前条目投影到给定 Control，并以 `bool` 明确接受或拒绝。每次已调用的 bind 都会对应一次 unbind，包括 bind 拒绝、同步中止和 dispose。
- unbind 回调应断开项目自己建立的信号、清除条目引用和瞬态视觉状态；不得 `free()`、`queue_free()` 或重挂载 Binder 持有的 Control。该约束也适用于 callback 能间接访问的其他 active/pool Control，而不只适用于本次参数。
- factory、identity、bind、unbind 与可选测量/焦点回调都可能触发项目代码。Binder 会在任何项目回调前冻结本轮 data/layout revision、条目数量、范围、目标 geometry、content extent、滚动主轴、交叉轴尺寸与填充策略，以及活动节点/自动测量预算；并在每次项目回调后的下一项回调、每个 Control 位置或尺寸写入、权威尺寸写入或 `grab_focus()` 前重验 generation、data revision 与完整 Control 所有权。callback 内的布局/轴/填充/预算修改、重测与 `request_sync()` 只合并到下一轮；`invalidate_items()` 使当前 data-generation 快照失效并返回非成功 `STATUS_DEFERRED`。若失效发生在绑定副作用前，旧 materialization 保持不变；若已进入 bind/unbind、测量、布局或焦点副作用，Binder 会按 Control 身份去重、对称解绑并清空不再可信的 active 集合，再由下一轮重建，不会把混代状态报告为成功。`unbind()` / `dispose()` 会使当前 lifecycle generation 失效；项目不应依赖递归同步或回调的未声明顺序。

同步结果不会保存或回显条目载荷和稳定 ID。`STATUS_INVALID_IDENTITY`、`STATUS_DUPLICATE_IDENTITY`、`STATUS_FACTORY_FAILED` 等失败会通过 `get_status()`、`get_error_index()` 和有界错误说明报告；bind 拒绝会记录首个失败索引并使用固定错误说明。identity 预检与 factory staging 失败不会修改已经提交的 active materialization。`STATUS_DEFERRED` 的 `is_successful()` 固定为 `false`，revision/range 描述本次尝试的入口快照，materialized indices 与 release count 描述回滚后的当前诊断状态；调用方不得把它当作 `UNCHANGED`，应继续等待已排队的下一轮。

需要把同步诊断交给日志、测试工件或外部工具时，使用 `GFVirtualListSyncResult.to_dict()`。该摘要可直接经过 `JSON.stringify()` / `JSON.parse_string()` 往返：`status` 输出为 `String`，`viewport_range` 与 `requested_range` 输出为 `{ "start": int, "end_exclusive": int }`，`materialized_indices` 输出为 `Array[int]`；它不会退回到 `Vector2i`、PackedArray 或项目载荷。所有 revision 与 count 必须位于 `0..9007199254740991`，`error_index` 必须位于 `-1..9007199254740991`，因此成功配置的结果不会越过 JSON 可精确表达的整数域；越界输入会在结果冻结前被拒绝，同一个新结果对象仍可用合法数据重试。类型化 getter 仍返回 `StringName`、`Vector2i` 与 `PackedInt32Array`，供运行时调用方使用。

## 预算与回收

`max_materialized_items` 和 `max_pooled_items` 是调用方预算，但不能突破 `ABSOLUTE_MAX_MATERIALIZED_ITEMS` 与 `ABSOLUTE_MAX_POOLED_ITEMS` 的框架硬上限。超大赋值会被钳制；活动预算至少为 1，pool 可以设为 0。同步轮次外缩小 pool 预算会立即释放超额 parentless Control；项目 callback 在同步事务内收紧预算时，Binder 会先完成候选提交或回滚，再按新上限统一裁剪并让同步结果报告最终 pool 数量，避免释放仍被事务引用的 Control。

稳定 identity 经过编码后的 UTF-8 token 也受 `ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH` 限制。String、StringName 与 NodePath 会先做廉价文本长度 admission，再进行稳定编码、token 字符数和 UTF-8 字节数校验，避免用超大 key 在硬上限之前制造无界编码工作。超限 identity 会 fail-closed，诊断只说明违反边界，不包含 identity 值。节点上限小于 overscan 请求量时，`GFVirtualListSyncResult.STATUS_TRUNCATED` 表示 Binder 已优先覆盖真实视口；调用方可据此降低 overscan、增大合理预算或调整交互设计，而不应关闭硬上限。

Binder 会先复用仍在目标范围内的稳定 identity，再复用离开范围的 active Control，然后使用 pool，最后才调用 factory。Control 不在 active 范围时保持 parentless，但所有权仍属于 Binder；active 必须直属 content root，pool 必须 parentless，内部 ID 集合必须与两者精确一致。项目释放、排队释放或重挂载任一 active/pool Control 都会 fail-closed，Binder 不会在后续同步中把它静默抢回或替换。事务内的合法 release 会先保持 parentless，候选 map 完整交换后再统一收敛 pool 预算，避免把短暂状态误判为破坏。`unbind()` 会释放当前绑定但允许实例重新绑定，`dispose()` 则进入不可复用终态。owner、ScrollContainer 或 content root 退出 SceneTree 也会确定性 dispose，因此不要让 owner 比承载 UI 的生命周期更长。

## 测量与滚动锚点

默认情况下，新绑定或条目失效会自动测量活动行；`auto_measure = false` 只关闭这些自动触发，不会屏蔽显式 `request_measurement()`。每轮会冻结自动测量配置与请求 revision；已经排队的显式请求不会被后续 `invalidate_items()` 清除，callback 中提出的重测只归入下一轮。项目可提供 `measure_callback`，否则 Binder 使用 Control 的组合最小尺寸或当前尺寸。Binder 在测量前固定与 ScrollContainer 相同的整数滚动锚点快照，因此多个位于原始视口上方的条目同时变化时，会累计全部尺寸差，并只在该轮末尾应用一次滚动修正。若项目 callback 已把布局模型推进到本轮预期 revision 之外，Binder 不会把旧轮测量写入新模型，而是保留重测请求到下一轮。修正量通过 `get_anchor_adjustment()` 报告。

`ScrollContainer` 的滚动条范围由 Godot 布局阶段更新。Binder 的范围、锚点和 reveal 都以滚动条实际接受的同一整数偏移收敛。`scroll_to_item()` 会冻结模型 revision、主轴、视口、当前偏移和精确 Control 所有权；若同步信号回调、Godot 钳制或项目重挂载使快照漂移，则返回 `false`、保留项目意图并请求下一轮，而不会把部分滚动报告为成功。常规用法应使用 `request_sync()` 的 deferred 合并路径；测试或工具若在同一帧修改 content 最小尺寸后直接写滚动值，应先等待一次布局帧，再调用 `sync_now()`，避免让尚未结算的滚动条把值钳制为零。

Binder 只拥有 content root 当前布局主轴的 `custom_minimum_size` 分量。`layout_axis` 只接受 `VERTICAL` 与 `HORIZONTAL`，非法动态整数会保持上一值，且有效修改仍需显式请求同步。切换主轴时，Binder 先恢复旧主轴在该段所有权开始前的分量，再以新主轴的当前分量建立独立 baseline；unbind/dispose 也只恢复最后实际拥有的分量。项目在任一轴未被 Binder 拥有期间写入的新值，会成为后续接管该轴时的恢复基线。`sync_completed` 监听器内再次调用 `sync_now()` 不会同步递归，而会合并到下一轮。

## 虚拟焦点

回收式列表中，当前可见行 `Control` 会不断复用，因此焦点状态应保存在数据索引上，再由渲染层把焦点表现同步到当前物化的行控件。

```gdscript
var focus := GFVirtualListFocusModel.new()
focus.item_count = entries.size()
focus.focusable_callback = func(index: int) -> bool:
	return not entries[index].get("disabled", false)

focus.focus_first()
focus.focus_next()

var focused_index := focus.focused_index
if focused_index != GFVirtualListFocusModel.NO_FOCUS:
	# 项目在这里滚动到 focused_index，并刷新当前可见行的焦点表现。
```

`wrap_navigation` 控制首尾是否环绕。条目数量或 `focusable_callback` 变化后，当前焦点会优先保留；如果越界或不再可聚焦，会修正到附近可聚焦索引。默认不会在没有焦点时自动选择第一项；需要进入列表后自动聚焦时，启用 `auto_focus_on_count_change` 或显式调用 `focus_first()`。

`GFVirtualListFocusModel` 表达的是“导航焦点”，不等于业务选中。需要保留多选、范围选择或排序/过滤后的稳定选择时，应继续使用 `GFTableSelectionModel` 或项目自己的选择状态。

Binder 连接焦点模型后，会接纳 bind 前已经存在的虚拟焦点，并把远端虚拟焦点按 nearest 规则滚入视口；滚入与物理 handoff 是两个独立待办，因此 bind 前已有的外部物理焦点不会阻断 reveal，也不会被 Binder 抢走。只有当前没有其他 Viewport focus owner 时，Binder 才会在对应行物化后把 Godot 焦点交给该行或项目提供的行内目标。行离开 active 范围，或虚拟焦点清除、转移时，Binder 会先释放旧行拥有的 Godot 焦点；仍指向未物化行的虚拟焦点会保留，待目标再次物化后交接。只有可见目标实际成为 Viewport focus owner 后，handoff 才算完成；目标在 `focus_entered` 中立即释放也被视为项目显式取消，不会在连续同步中重抢。焦点目标或 `focus_exited` 回调中产生的新虚拟焦点优先于旧交接，项目把焦点交给另一活动行或外部 Control 也会取消尚未完成的旧 handoff，但不会取消本次 auto-reveal。项目仍负责决定哪些索引可聚焦以及虚拟焦点何时变化。

## 注意事项

- `get_viewport_range()` 与 `get_visible_range()` 都返回 `Vector2i(start, end)`，其中 `end` 是不包含的结束索引。
- `overscan_items` 只扩大计算范围，不代表必须同时创建所有条目；项目仍可按帧分批物化。
- `trailing_padding` 只影响 `get_content_extent()` 的默认返回值，不改变条目自身偏移。
- estimate、实测 extent、padding 和 offset 必须是有限数值；`NaN` / `Inf` 会被拒绝或回退，条目尺寸还会被限制到 `MIN_ITEM_EXTENT` 以上，维持二分查找所需的有限单调累计偏移。
- 模型不感知横向或纵向；参数名使用 `extent`，项目可把它解释为高度或宽度。
- `focusable_callback` 应保持轻量、可重复调用，不应在判断过程中修改列表数据或创建节点。
