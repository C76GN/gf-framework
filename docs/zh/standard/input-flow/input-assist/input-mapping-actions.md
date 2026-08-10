# 输入动作、上下文与消费时机

这一页说明如何用 `GFInputMappingUtility` 把真实或虚拟输入转换成抽象动作状态，以及一次性动作应该在什么位置读取。

## 输入映射与手感辅助 (`GFInputMappingUtility` / `GFInputAssistUtility`)

`GFInputMappingUtility` 是推荐的输入主入口，负责把真实或虚拟输入转换成抽象动作状态。`GFInputAssistUtility` 是可选的手感辅助层，只负责动作意图缓冲和通用宽容窗口，不读取 `InputEvent`，也不处理重绑定或设备归属。

当项目需要把输入从具体按键抽象成可切换上下文和可重绑动作时，可以注册 `GFInputMappingUtility`。动作、绑定和上下文都由资源描述，框架只负责事件转动作状态，不规定移动、战斗、UI 导航或任何业务规则。

```gdscript
var jump_action := GFInputAction.new()
jump_action.action_id = &"jump"
jump_action.display_name = "Jump"

var jump_binding := GFInputBinding.new()
jump_binding.input_event = InputEventKey.new()
(jump_binding.input_event as InputEventKey).keycode = KEY_SPACE
(jump_binding.input_event as InputEventKey).physical_keycode = KEY_SPACE

var jump_mapping := GFInputMapping.new()
jump_mapping.action = jump_action
jump_mapping.bindings = [jump_binding]

var gameplay_context := GFInputContext.new()
gameplay_context.context_id = &"gameplay"
gameplay_context.mappings = [jump_mapping]

var input_map := Gf.get_utility(GFInputMappingUtility) as GFInputMappingUtility
input_map.enable_context(gameplay_context, 10)

# 在 GFSystem.tick() 或状态 update() 中消费一次性动作。
if input_map.consume_action(&"jump"):
	print("jump requested")
```

运行时用代码组装 `GFInputAction` / `GFInputMapping` / `GFInputContext` 是合法的，适合原型、自动生成配置或测试；正式项目若希望策划可调、可复用和便于改键界面展示，通常把它们保存成 `.tres` 资源再由 Installer、System `ready()` 或场景入口启用。不要在 `GFSystem._init()` 里获取 Model/Utility 或启用上下文：构造阶段还没有完成架构注入，跨模块依赖应放在 `ready()`，纯内部默认值才放在 `init()` / `_init()`。

连续轴输入可以监听 `action_value_changed` 后写入项目自己的输入 Model，也可以在 System `tick()` 中调用 `get_action_vector()` / `get_action_value()` 轮询；两种方式都符合框架边界。跳跃、攻击、确认这类一次性意图更推荐使用 `consume_action()`、`action_started` 或触发器语义，避免把按下、按住和释放都混成普通 value change。二维移动可用一个 `AXIS_2D` 动作配四个方向绑定，再通过 `get_action_vector(&"move")` 读取；拆成 `move_x` / `move_y` 也可以，但后续死区、归一化和重绑展示通常会更分散。

运行时按“绑定 × 物理来源”保存贡献：不同手柄和不同 touch index 即使命中同一 binding，也会独立保持按下状态，只有最后一个来源释放后聚合动作才结束。虚拟输入同样先拒绝 `NaN` / Infinity，再把有限轴值限制到动作值域；无效写入返回 `false`，不会把坏数据解释成 release 或覆盖上一次合法贡献。

`consume_action(action_id)` 消费的是 `GFInputMappingUtility` 已经处理出的 just-started 状态，不会读取任意节点 `_input(event)` 正在收到的当前 `InputEvent`。Utility 初始化后会创建内部 `GFInputMappingRouter` 节点并在它自己的 `_input()` 中调用 `handle_input_event(event)`；Godot 对不同节点 `_input()` 的调用顺序不应该作为项目逻辑依赖。如果项目节点先于内部 router 收到同一个事件，直接在该节点 `_input()` 中调用 `consume_action()` 可能返回 `false`，因为当前事件还没有被 GF 输入映射转换成抽象动作。

因此，一次性动作的推荐读取位置是 `GFSystem.tick()`、状态机 `update()`，或监听 `action_started(action_id, value)` / `player_action_started(player_index, action_id, value)`。如果项目只想在 `_input(event)` 中判断 Godot 原生 InputMap 的当前事件，应直接使用 `event.is_action_pressed("jump")` 等 Godot API；如果确实要在项目自己的 `_input(event)` 中接管 GF 输入桥接，需要先调用 `input_map.handle_input_event(event)` 再查询或消费动作，并确保同一个事件不会又被内部 router 重复处理。

动作信号是同步信号，监听器可以在回调内清空、替换上下文或释放 utility。运行时会把这类变更视为新的派发代际，当前事件不会继续遍历新代际 entry，也不会在 `action_value_changed` 之后补发旧代际的 `action_started`。项目若希望同一个物理事件进入新上下文，应在回调返回后的下一次显式派发中完成，而不是依赖重入迭代顺序。
