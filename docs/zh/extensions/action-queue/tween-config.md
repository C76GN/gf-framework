# 配置化 Tween 动作

如果表现动画需要被多个界面、实体或流程复用，可以把属性 Tween 抽成资源配置，再生成动作交给队列。

## 创建配置动作

```gdscript
var config := GFTweenActionConfig.new()
config.add_property_step(^"position", Vector2(400, 300), 0.25)
config.add_property_step(^"modulate", Color.WHITE, 0.12)

q_sys.enqueue(config.create_action(card_node))
```

`GFTweenActionConfig` 只描述属性路径、目标值、时长、缓动和并行关系。每一段属性变化由 `GFTweenActionStep` 保存，支持延迟、相对值、并行、transition、ease、可选 `easing_curve` 和 `marker_id`。

## 自定义缓动曲线

`GFTweenActionStep.easing_curve` 默认为 `null`，继续使用 `transition_type` 和 `ease_type`。设置原生 `Curve` 后，它会替代这两个预设：Godot Tween 先提供线性时间进度，再由 `Curve.sample_baked()` 得到属性插值进度，不叠加第二层预设缓动。

可以在 Inspector 的步骤资源中创建或指定 `Curve`，使用 Godot 自带曲线编辑器调整，也可以用代码创建：

```gdscript
var easing: Curve = Curve.new()
easing.bake_resolution = 128
var _start_index: int = easing.add_point(Vector2.ZERO)
var _middle_index: int = easing.add_point(Vector2(0.35, 0.15))
var _end_index: int = easing.add_point(Vector2.ONE)

var config: GFTweenActionConfig = GFTweenActionConfig.new()
var movement: GFTweenActionStep = config.add_property_step(
    ^"position", Vector2(240, 0), 0.6
)
movement.easing_curve = easing
```

这段配置让属性在前段缓慢变化，再到达目标值。曲线横轴表示 `0..1` 时间进度，纵轴表示插值进度；曲线可以回弹或超调，输出不会被截到 `0..1`。需要超调控制点时，先在原生曲线编辑器中扩大纵轴编辑范围。

| 约束 | 要求 |
| --- | --- |
| 资源 | 原生 `Curve`，不能附带脚本 |
| 横轴 | `min_domain = 0`、`max_domain = 1`；点的 x 严格递增 |
| 控制点 | 2–256 个；首尾必须精确为 `(0, 0)` 和 `(1, 1)` |
| 数值 | 控制点与左右切线有限；纵轴编辑范围有限、覆盖 `0..1`，并包含控制点的 y 值 |
| 烘焙 | `bake_resolution` 为 2–1000；实际使用的烘焙输出有限且绝对值不超过 16 |

输出限制针对 `sample_baked()` 使用的结果，不保证未烘焙曲线在任意位置的极值。每个属性 Tweener 持有独立的原生曲线副本；创建后修改源曲线不会改变该 Tweener 的求值。重新播放会采用修改后的曲线。

`duplicate_step()` 和 `duplicate_config()` 会深复制有效曲线；无效曲线会使复制返回 `null` 并给出警告，调用方应先校验并检查复制结果。`duplicate_config()` 也保留 `enable_playback_control` 和 `ping_pong`。`apply_instant()` 直接应用步骤终点，不沿曲线求中间值；它与正在播放的动作会话的 `finish()` 是不同入口。

## 执行前校验

`GFTweenActionStep.can_apply_to(target)` 和 `get_validation_error(target)` 可在执行前检查目标属性是否存在、目标值类型是否兼容，以及缓动曲线是否有效。absolute 步骤接受相同 Variant 类型或 `int` / `float` 数值互转；relative 步骤当前支持数值、`Vector2`、`Vector3` 和 `Color` 的同类相加。`GFTweenActionConfig.get_validation_report(target)` 将检查结果整理成 `GFValidationReport`；开启播放控制或往返时，也检查组合预算与并行冲突等整组约束。仅通过动作的替换作用域启用受控播放时，整组约束在动作执行入口检查。

默认运行时路径通过原生 Tween 执行步骤，无效步骤会被跳过并给出警告。启用下文的受控播放后，配置会先进行整组校验；无效计划不会部分播放。编辑器预览也会拒绝整组无效配置并显示原因。直接使用 `apply_instant()` 不需要有效的缓动曲线，但目标属性和值仍须有效。

## 标记点与恢复

`create_action(target)` 会生成 `GFConfiguredTweenAction`，由它在执行时创建 Tween、追加步骤，并返回 `GFVisualAction` 的动作完成信号。

步骤设置 `marker_id` 后，动作会在对应步骤结束时发出 `marker_reached(marker_id, step_index, target)`。标记回调与对应属性 Tweener 位于同一调度组，不会让后续 `parallel = true` 步骤退化为串行。项目可以把它用于通用时间点通知，而不需要把动画资源绑定到具体业务回调。

`restore_initial_values_on_cancel` 和 `restore_initial_values_on_finish` 可让动作在取消或完成时恢复播放前捕获的属性值，适合编辑器预览或可回滚表现；它只恢复被步骤引用的属性，不隐藏、释放或重排节点。

取消或强制完成会唤醒动作队列等待。普通有限原生 Tween 的 `finish()` 推进已有 Tween 到实际终点，不把相对偏移重新加到当前中间值；无限循环停在当前位置。为避免强制完成同步执行过量 setter，原生计划超过 4,096 个展开属性步骤，或总时长计算非有限时，`finish()` 会警告并停止在当前位置；随后仍遵守 `restore_initial_values_on_finish`。这不限制普通播放的规模。具体节点含义、动画命名和业务时机仍由项目层决定。

## 运行时时间定位与正反向播放

`enable_playback_control` 默认为 `false`。需要定位或改变方向时，将它设为 `true`；设置 `ping_pong = true`，或为动作赋予 `replacement_scope`，也会自动启用受控播放。已有未启用这些选项的配置继续使用原生 Tween 路径。

受控动作在 `execute()` 时捕获配置、曲线和目标根属性初值。会话中的定位与方向切换使用这份快照，修改来源配置不会改变当前会话。`can_control_playback()` 表示动作是否仍处于可操作的播放或暂停会话。

| 方法 | 行为 |
| --- | --- |
| `seek(seconds)` | 定位到完整时间轴中的秒数并暂停；不完成动作，也不补发经过的 marker |
| `play_forward()` | 从当前时刻向时间轴末端播放 |
| `play_backward()` | 从当前时刻向时间轴起点播放 |
| `pause()` / `resume()` | 暂停，或沿当前方向继续 |
| `finish()` | 应用当前方向的终点并完成，遵守完成恢复策略，不补 marker |
| `get_time_seconds()` / `get_duration_seconds()` | 读取当前时刻与完整时间轴长度；没有捕获过有效会话时为 `0` |

时间轴包含延迟、时长缩放、串并行组、全部循环，以及启用往返时的每次去程和回程。`seek()` 接受 `0..get_duration_seconds()` 内的有限秒数；定位到端点仍是暂停状态。动作自然完成、取消或被替换后，`seek()` 与两个方向方法不再接受操作；最后的时间读数可以保留，重新播放须再次 `execute()` 创建会话。

下面的 Node2D 示例先捕获两轮相对移动，再定位到第二轮并向回播放：

```gdscript
extends Node2D

var _motion: GFConfiguredTweenAction = null

func _ready() -> void:
	_motion = GFAction.tween_by(self, ^"position:x", 120.0, 1.0, {
		"enable_playback_control": true,
		"loop_count": 2,
	})
	if _motion == null:
		return
	var _completion: Variant = _motion.execute()
	if _motion.can_control_playback() and _motion.seek(1.25):
		var _playing_backward: bool = _motion.play_backward()

func _exit_tree() -> void:
	if _motion != null:
		_motion.cancel()
```

反向播放不触发 marker。定位会把不晚于目标时刻的未触发 marker 记为跳过；回拨后再正向播放，也不会重发已经触发或跳过的那一次 marker。不同循环的同名 marker 各自计数。这些通知适合表现时机，不承担业务状态撤销。

### 往返播放

`ping_pong = true` 时，一次 `loop_count` 是完整的“去程 + 回程”。回程沿同一冻结时间轴返回初值，不累计相对偏移；后续周期再次从初值出发。正向去程保留步骤标记，回程不发标记。

```gdscript
var config: GFTweenActionConfig = GFTweenActionConfig.new()
config.ping_pong = true
config.loop_count = 2
var _scale_step: GFTweenActionStep = config.add_property_step(
	^"scale", Vector2(1.08, 1.08), 0.2
)
q_sys.enqueue(config.create_action(card_node))
```

这个配置播放两次缩放往返，总长 `0.8` 秒，最终回到捕获的缩放初值。

### 受控播放的适用范围

受控计划支持有限 `int` / `float`、`Vector2`、`Vector3`、`Color`，以及单层向量和颜色分量路径，例如 `position:x` 或 `modulate:a`。不支持对象值、任意嵌套资源属性、Transform 或 Quaternion 插值。它在每个串行组开始时固定该段起点；相对终点由该起点加偏移计算，延迟结束时不会重新读取外部写入。

每组配置最多 256 步、1–256 次有限循环，步骤数乘循环数最多 4,096，完整总时长必须有限且大于零。曲线累计最多 65,536 个烘焙样本和 4,096 个控制点。同一并行组不能同时写同一根属性，`position:x` 与 `position:y` 也属于同根；需要同时改变二者时，使用一个 `position` 步骤。一个计划不能混用 `position` / `global_position`、`scale` / `global_scale`，也不能混用多个旋转别名，例如 `rotation` 和 `rotation_degrees`。

采样按完整根属性写回，即使步骤只写 `position:x`，其余分量也来自该会话的冻结状态。播放期间应让该会话独占相关根属性；独立脚本、AnimationPlayer 或未加入替换作用域的 Tween 不会自动参与协调。

## 同属性自动替换

为同一组表现动作传入同一个 `GFTweenReplacementScope`，新动作开始执行时会接管相同目标的冲突属性。作用域由页面或实体控制器持有；它只弱引用动作与目标，控制器退出时应显式 `dispose()`。

下面的 Control 示例在悬停进入、离开时立即创建新的缩放动作，让最新意图从当前姿态继续：

```gdscript
extends Control

var _replacement_scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
var _hover_action: GFConfiguredTweenAction = null

func _ready() -> void:
	var _entered: int = mouse_entered.connect(_on_mouse_entered)
	var _exited: int = mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	_animate_scale(Vector2(1.06, 1.06))

func _on_mouse_exited() -> void:
	_animate_scale(Vector2.ONE)

func _animate_scale(next_scale: Vector2) -> void:
	var next_action: GFConfiguredTweenAction = GFAction.scale_to(
		self, next_scale, 0.12, ^"scale", { "replacement_scope": _replacement_scope }
	)
	if next_action != null:
		var _completion: Variant = next_action.execute()
		_hover_action = next_action

func _exit_tree() -> void:
	_replacement_scope.dispose()
	_hover_action = null
```

接管发生在 `execute()`，不是创建或入队时。若新动作排在串行等待队列后，它仍会等待轮到自己；需要即时响应时可直接执行，或采用 fire-and-forget / 并发的命名队列。

冲突按目标身份和顶层属性判定：`position`、`position:x`、`position:y` 相互冲突；`modulate` 与 `modulate:a` 相互冲突。Node2D、Node3D 的 `rotation` 与 `rotation_degrees` 归为同一属性；其他别名不推断，因此作用域不会自动识别不同动作中的 `global_position` 与 `position` 关系。

只要一个属性冲突，就终止旧整条配置动作，并保留当前姿态，不执行旧动作的取消初值恢复。旧动作的等待会结束，其余步骤和标记停止；新配置无效则不接管。作用域先停止全部冲突动作，再发出完成通知；通知回调中更晚开始的动作仍可接管。`dispose()` 也会停止仍登记的动作并保留当前姿态，此后不接受新动作。

只有传入同一个作用域的动作相互替换。不同作用域、未设置作用域的动作，以及裸 Tween 均保持各自行为。已有配置可用 `GFConfiguredTweenAction.new(target, config)` 创建具体动作，再设置其 `replacement_scope`；作用域属于运行时控制器，不存入共享配置资源。

## 在 Inspector 中预览

启用 `gf.action_queue` 扩展后，选中 `GFTweenActionConfig` 资源，Inspector 顶部会出现 **Tween 预览**。选择与配置匹配的 2D、UI 或 3D 样机，即可查看串行、并行、延迟、相对值和缓动的效果。展开 **样机初值** 可以调整本次预览的起点；这些值不会写回配置。

| 操作 | 行为 |
| --- | --- |
| 播放 | 从样机初值开始，读取当前配置的快照 |
| 暂停 / 继续 | 冻结画面，再从暂停的位置继续同一次预览 |
| 时间滑条 / 秒数输入 / 定位 | 定位到已捕获时间轴中的时刻并暂停；定位按钮可重复检查同一时刻 |
| 停止 | 终止播放，保留画面和可定位的快照；再次播放从初值读取最新配置 |
| 复位 | 终止本次预览、丢弃定位快照并恢复样机初值 |

先点击一次播放以捕获配置，时间控件才会启用。定位始终使用该次捕获的步骤、曲线纯值快照和样机初值，不会读取之后修改的配置。要查看最新配置或曲线，请停止后重新播放。定位会暂停画面，点击继续从所选时刻向前播放；时间滑条显示串行组与并行组形成的实际时长，包含延迟、时长缩放和有限循环，而非所有步骤时长简单相加。

定位到时间轴末端时会保留动画终值，方便检查最后姿态；此时点击继续才执行正常完成策略。正常播放完成遵循 `restore_initial_values_on_finish`，完成后仍能定位检查同一快照。全零时长配置仅应用一轮瞬时步骤；点击定位按钮检查其唯一的 `0` 秒位置，可查看这一轮的终值，不累计多次相对偏移。

改变样机初值、切换配置、切换样机、隐藏预览或关闭 Inspector 会丢弃旧定位快照，必须重新播放后才能定位。此处的定位与重放只作用于独立样机；运行时动作使用前述受控播放接口，二者都不提供业务回调回滚。Inspector 暂不支持 `enable_playback_control` 或 `ping_pong` 配置，会在播放前明确显示原因；请在运行时验证受控播放与替换接管效果。普通配置的单向预览保持原有行为。

样机支持以下属性，以及向量的 `x` / `y` / `z`、颜色的 `r` / `g` / `b` / `a` 分量路径，例如 `position:x`、`modulate:a`。

| 样机 | 属性 |
| --- | --- |
| 2D | `position`、`rotation`、`rotation_degrees`、`scale`、`modulate`、`self_modulate` |
| UI | 2D 属性，加上 `size`、`pivot_offset` |
| 3D | `position`、`rotation`、`rotation_degrees`、`scale` |

2D 与 UI 位置以画布中心为原点，3D 使用独立相机。属性读数可以辅助观察移出画面的目标。预览使用工具自己创建的节点，不操作当前场景，不执行项目脚本或步骤标记通知，也不产生撤销记录。它采用独立的编辑器时钟，运行时的 `process_mode`、`pause_mode` 和 `ignore_time_scale` 不参与预览调度。

预览只接受原生 `GFTweenActionConfig` 和 `GFTweenActionStep` 资源，暂不执行自定义子类、对象目标值或任意嵌套资源属性。目标值及样机初值须为类型匹配的有限数值、`Vector2`、`Vector3` 或 `Color`，各数值分量绝对值不超过 1,000,000。单次预览最多 128 个步骤、32 次有限循环；按全部步骤的缩放后时长与延迟之和乘循环次数计算，保守预算上限为 120 秒，时间轴实际时长可以更短。自定义曲线除满足前述单条约束外，整组累计最多 65,536 个烘焙样本和 4,096 个控制点。

Inspector 定位通过从初值与快照重建原生 Tween 并向前求值完成，不逐帧追赶，也不更换插值算法。无限循环、无效曲线与超出预算的配置会在播放前显示原因。上述预算属于编辑器预览；运行时受控播放采用前述独立预算，默认原生 Tween 路径不套用这两套组规模限制。
