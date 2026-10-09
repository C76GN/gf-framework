# 表单控件绑定

设置界面可以使用 `GFControlValueAdapter` 和 `GFFormBinder` 读写常见 `Control` 值，避免每个设置页重复判断 `LineEdit`、`CheckBox`、`Slider`、`OptionButton` 等控件类型。

```gdscript
var binder := GFFormBinder.new()
binder.bind_field(&"player_name", %NameEdit)
binder.bind_field(&"fullscreen", %FullscreenCheck)
binder.bind_field(&"master_volume", %MasterVolumeSlider)

binder.write_values(settings.to_dict(false))
binder.field_changed.connect(func(key: StringName, value: Variant) -> void:
	settings.set_value(key, value)
)
```

`GFFormBinder.bind_field()` 会在重复绑定同一字段前清理旧连接，`unbind_field()` / `clear()` 也会断开由 `GFControlValueAdapter` 创建的值变化监听。

需要自己管理连接生命周期时，可使用 `connect_value_changed_with_handles()` 和 `disconnect_value_changed_handles()`。

## 输入会话与提交边界

需要保留非法中间输入、取消回到编辑开始值，或防止延期回调跨字段/文档提交时，使用 `GFControlEditSession`。每个活动字段持有自己的实例，宿主在焦点进入时调用 `begin_edit(control)`，并把返回的正数令牌交给对应提交或取消回调。重复开始同一个活动字段不会覆盖最初基线；另一控件不能替换活动会话。

`get_baseline(token)` 和 `capture_draft(token)` 返回独立快照。`value` 是原生控件值；文本控件及 `SpinBox` 另有 `raw_text`。例如 `SpinBox` 显示 `-` 时，它的数值仍可能是先前的 `42`；业务验证应读取原文，而不是把旧数值当作新输入。快照不保存光标、选择区、滚动位置或自定义控件对象。

```gdscript
var session := GFControlEditSession.new()
var token := session.begin_edit(%Amount)
var draft := session.capture_draft(token)
# 项目先解析/验证 draft；非法输入保留当前会话，允许继续输入或取消。
if accepts_amount(draft):
	var result := session.commit_edit(token)
	# changed 比较控件快照；项目仍需比较解析后的业务值，跳过等价值命令。
	if not result.is_empty() and result["changed"] and amount_value_changed(result["before"], result["after"]):
		apply_amount_command(result["before"], result["after"])
```

`commit_edit(token)` 只结束输入边界并返回 `before`、`after`、`changed`，不解析数字或生成撤销命令。值与原文均回到基线时返回 `changed=false`；仅把 `0042` 改成 `42` 仍是控件快照变化。项目应再比较解析后的业务值，跳过等价值命令并保留现有重做分支。

`cancel_edit(token)` 尝试恢复开始时的值与原文并结束会话，只有读回的控件快照确实等于基线才返回 `true`。编辑期间范围、步长或选项改变，原生控件可能截断或拒绝旧值；此时返回 `false`，仍结束本次取消边界，保留原生控件的实际状态，不把旧原文回写成与实际值不一致的文本。宿主需检查结果，不能据此推断模型已恢复。原生值变化信号可能发出，宿主应在取消恢复期间阻止这些信号触发模型写入。恢复过程中拒绝新会话，宿主仍可用 `clear()` 立即失效恢复。

`SpinBox` 的原生延期格式化后会再校正原文；新会话或 `clear()` 会撤销旧校正，校正执行时当前数值不等于基线也会跳过。数值检查不记录变化历史；宿主接管原文、格式设置或字段上下文时仍应调用 `clear()`。宿主应等待原生格式化完成后再接收新的文本输入，会话不接管原生焦点格式化或重放输入事件。

`has_ime_composition(token)` 检查 `LineEdit`（包括 `SpinBox` 内置输入框）和 `TextEdit` 的原生输入法组合。组合未结束时提交与取消均拒绝，先交给原生输入框完成或取消组合。会话不监听或重放键盘事件。

延期回调携带捕获的令牌，用 `is_current(token)` 检查或直接调用提交/取消；过期操作不会结束新会话。令牌只在原实例内有效。字段解绑、文档切换、退树时调用 `clear()`，它放弃会话，不恢复控件。会话使用弱引用，控件释放后旧令牌失效。焦点、拖动、提交与取消事件的连接由宿主管理；保存基线、业务错误展示和单位转换也由项目管理。

如果需要把控件长期同步到一棵运行时状态树，而不是一次性批量 read/write 表单值，使用 [响应式状态与控件绑定](../../reactive-state.md) 中的 `GFReactiveStateStore` 和 `GFReactiveStateControlBinder`。`GFFormBinder` 负责表单字段读写，`GFReactiveStateControlBinder` 负责 store path 与单个控件的双向同步。

需要把数组写入 `ItemList`、`OptionButton`、`PopupMenu` 或用模板节点重复生成列表行时，使用 [列表与模板绑定](list-repeat-binding.md)。
