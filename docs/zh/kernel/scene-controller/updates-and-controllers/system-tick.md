# System 与 Utility 心跳

在 GF 架构下，核心系统不需要继承 `Node`，也不存在于场景树中。核心业务逻辑更新由架构集中管理，可统一处理暂停、时间缩放和调试诊断。

全局 AutoLoad `Gf` 持有对 Godot `_process` 和 `_physics_process` 的监听。收到帧调用后，它会转发给 `GFArchitecture`，再由架构遍历参与 `tick()` / `physics_tick()` 的 `GFSystem` 与 `GFUtility`。

`Gf` 会把自身 `process_mode` 设置为 `PROCESS_MODE_ALWAYS`，因此即使项目临时使用 Godot 原生 `SceneTree.paused`，框架层的时间工具、暂停逻辑和明确声明忽略暂停的模块仍有机会继续收敛状态。

```gdscript
class_name CooldownSystem extends GFSystem

var _combat_model: CombatModel

func ready() -> void:
	_combat_model = get_model(CombatModel) as CombatModel

func tick(delta: float) -> void:
	if _combat_model != null and not _combat_model.is_combat_paused:
		_combat_model.decrease_cooldown_timers(delta)
```

架构只调度已注册的 `GFSystem` 与 `GFUtility`，不支持普通 `Object` 依靠同名方法参与框架 tick。刷新 tick 缓存时，架构会一次性验证 `tick()` / `physics_tick()` 能力并缓存 `Callable`、优先级和时间策略；每帧只遍历这些记录，不再通过字符串方法名反射调用模块。

`GFSystem` 基类提供空的 `tick()` / `physics_tick()` 模板，但架构不会把未重写模板的 System 自动加入热路径。需要使用基类模板入口时，应显式设置 `tick_enabled = true` 或 `physics_tick_enabled = true`。`GFUtility` 没有基类 tick 模板，需要声明对应方法才会被驱动；显式标记只负责让能力声明和缓存刷新更直接。这些标记在注册前或注册后设置都可以，已注入架构的模块会自动刷新 tick 缓存。

内部调度由 `GFArchitectureTickScheduler` 维护，单条缓存记录由 `GFArchitectureTickRecord` 表示。它们都是框架内部类型，项目通常不需要直接创建；项目只需要继承 `GFSystem` / `GFUtility` 并声明 tick 能力。

在 `tick()` / `physics_tick()` 这类热路径里，推荐在 `ready()` 或初始化阶段缓存长期依赖的 Model、System、Utility 引用。`get_model()` / `get_system()` / `get_utility()` 适合表达依赖入口，但每帧重复查找没有必要；只有当项目会动态替换某个模块实例时，才需要在替换完成后刷新缓存。

## Tick 与 Physics Tick

- `tick(delta)`：对应渲染帧，适合视觉队列、UI 数据动态演算、不涉及物理碰撞引擎参与的高频逻辑。
- `physics_tick(delta)`：对应固定逻辑帧，适合移动插值前置、碰撞检测参数传递和状态机物理更新。
