# GFResourceServiceDomain

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_service_domain.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

GFResourceServiceDomain：一个 Broker 及其消费者的稳定资源服务入口。 模式在 configure 时固定；主线程上请求、切换与 pump 串行执行。 受控切换暂停时明确拒绝新请求；在途热切换最多保留两代且不会重放已接纳工作。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`generation_changed`](#member-gfresourceservicedomain-signals-generation_changed) | `signal generation_changed(previous_generation: int, current_generation: int)` |
| 枚举 | [`Mode`](#member-gfresourceservicedomain-enums-mode) | `enum Mode` |
| 常量 | [`MAX_GENERATION_REFERENCES`](#member-gfresourceservicedomain-constants-max_generation_references) | `const MAX_GENERATION_REFERENCES: int = 8192` |
| 方法 | [`init`](#member-gfresourceservicedomain-methods-init) | `func init() -> void:` |
| 方法 | [`tick`](#member-gfresourceservicedomain-methods-tick) | `func tick(_delta: float = 0.0) -> void:` |
| 方法 | [`begin_quiesce`](#member-gfresourceservicedomain-methods-begin_quiesce) | `func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`dispose`](#member-gfresourceservicedomain-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`configure`](#member-gfresourceservicedomain-methods-configure) | `func configure(broker: GFResourceBroker, mode: Mode = Mode.STABLE) -> Error:` |
| 方法 | [`get_mode`](#member-gfresourceservicedomain-methods-get_mode) | `func get_mode() -> Mode:` |
| 方法 | [`get_current_generation`](#member-gfresourceservicedomain-methods-get_current_generation) | `func get_current_generation() -> int:` |
| 方法 | [`is_accepting_requests`](#member-gfresourceservicedomain-methods-is_accepting_requests) | `func is_accepting_requests() -> bool:` |
| 方法 | [`request`](#member-gfresourceservicedomain-methods-request) | `func request( path: String, type_hint: String = "", options: Dictionary = {} ) -> GFResourceLease:` |
| 方法 | [`begin_switch`](#member-gfresourceservicedomain-methods-begin_switch) | `func begin_switch(broker: GFResourceBroker, timeout_msec: int = 30000) -> GFAsyncCompletion:` |
| 方法 | [`pump`](#member-gfresourceservicedomain-methods-pump) | `func pump() -> void:` |
| 方法 | [`can_remove_from_active_lifecycle`](#member-gfresourceservicedomain-methods-can_remove_from_active_lifecycle) | `func can_remove_from_active_lifecycle() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfresourceservicedomain-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfresourceservicedomain-signals-generation_changed"></a>

### `generation_changed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal generation_changed(previous_generation: int, current_generation: int)
```

新请求入口完成统一换代；旧代结果仍按原请求交付。

参数：

| 名称 | 说明 |
|---|---|
| `previous_generation` | 原入口代次。 |
| `current_generation` | 新入口代次。 |

## 枚举

<a id="member-gfresourceservicedomain-enums-mode"></a>

### `Mode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Mode {
	## 稳定绑定：生命周期内固定 Broker。
	STABLE,
	## 受控切换：拒绝新请求，等待原代工作和所有权引用收尾后换代。
	CONTROLLED,
	## 在途热切换：新请求立即换代，旧代保留推进到全部所有权引用释放。
	IN_FLIGHT,
}
```

服务域初始化时固定的切换合同。

## 常量

<a id="member-gfresourceservicedomain-constants-max_generation_references"></a>

### `MAX_GENERATION_REFERENCES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const MAX_GENERATION_REFERENCES: int = 8192
```

每代请求票据、句柄保留票据和租约的总预算。

## 方法

<a id="member-gfresourceservicedomain-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func init() -> void:
```

开启生命周期 tick；不会重置已经配置的域或模式。

<a id="member-gfresourceservicedomain-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func tick(_delta: float = 0.0) -> void:
```

推进当前、旧代和切换等待。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 不用于期限计算。 |

<a id="member-gfresourceservicedomain-methods-begin_quiesce"></a>

### `begin_quiesce`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
```

停止新接纳，继续完成已经接纳的本地队列、租约和引用释放。 scope 取消只结束等待；未收尾实例仍需继续 pump，不能强杀加载器。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 调用方的关闭期限与取消作用域。 |

返回：全部代次收尾后成功；取消不表示已物理退出。

<a id="member-gfresourceservicedomain-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

请求关闭并推进一次；尚未收尾且存在 SceneTree 时托管局部退出推进器。 没有 SceneTree 时，租约/句柄仍保留域，调用者须显式 pump。

<a id="member-gfresourceservicedomain-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure(broker: GFResourceBroker, mode: Mode = Mode.STABLE) -> Error:
```

初始化域并接管一个全新 Broker。模式不能在运行中修改。 受控切换仅支持框架原生或快照后端；在途热切换仅支持框架快照后端，原生 threaded 后端拒绝。

参数：

| 名称 | 说明 |
|---|---|
| `broker` | 已初始化、未被固定消费者使用且尚未注册进架构的实例。 |
| `mode` | 域唯一模式，默认为 STABLE。 |

返回：已配置为 ERR_ALREADY_IN_USE，能力不满足为 ERR_UNAVAILABLE。

<a id="member-gfresourceservicedomain-methods-get_mode"></a>

### `get_mode`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_mode() -> Mode:
```

读取固定模式。

返回：初始化选择的模式。

<a id="member-gfresourceservicedomain-methods-get_current_generation"></a>

### `get_current_generation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_current_generation() -> int:
```

读取新请求使用的代次。

返回：未配置时为 0。

<a id="member-gfresourceservicedomain-methods-is_accepting_requests"></a>

### `is_accepting_requests`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_accepting_requests() -> bool:
```

判断当前入口是否接纳新工作；暂停期间不会无限排队。

返回：已配置且未暂停、未关闭时为 true。

<a id="member-gfresourceservicedomain-methods-request"></a>

### `request`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func request( path: String, type_hint: String = "", options: Dictionary = {} ) -> GFResourceLease:
```

立即发起绑定当前代次的请求；旧结果仍通过返回租约读取。 已完成租约也需 release；只取 Resource 后释放租约表示资源已脱离服务所有权。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 逻辑资源路径。 |
| `type_hint` | 冻结类型提示。 |
| `options` | Broker 准入选项。 |

返回：拒绝返回 failed Lease，绝不静默降级。

结构：

- `options`: Dictionary with optional exclusive: bool, require_idle: bool, consumer_id: StringName.

<a id="member-gfresourceservicedomain-methods-begin_switch"></a>

### `begin_switch`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_switch(broker: GFResourceBroker, timeout_msec: int = 30000) -> GFAsyncCompletion:
```

准备并接管新代。受控切换等待旧代所有工作及引用释放后提交；在途热切换立即换入口后继续收尾旧代。 超时失败不会撤销已接纳工作，受控切换保持暂停，在途热切换保留新入口和旧代推进。

参数：

| 名称 | 说明 |
|---|---|
| `broker` | 全新且满足当前模式能力的已初始化实例。 |
| `timeout_msec` | 收尾等待期限，范围 1–600000 毫秒。 |

返回：旧代安全退出后成功；拒绝或期限失败提供稳定错误文本。非主线程错误调用返回 null。

<a id="member-gfresourceservicedomain-methods-pump"></a>

### `pump`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func pump() -> void:
```

推进全部存活代次并尝试收尾；关闭或超时后仍可调用，不强制销毁被引用对象。

<a id="member-gfresourceservicedomain-methods-can_remove_from_active_lifecycle"></a>

### `can_remove_from_active_lifecycle`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func can_remove_from_active_lifecycle() -> bool:
```

域稳定入口不能通过架构移除后重新注册来绕过模式合同。

返回：始终 false；架构整体关闭仍允许。

<a id="member-gfresourceservicedomain-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

读取有界代次与等待诊断，不暴露可变 Broker 实例。

返回：当前入口与收尾状态。

结构：

- `return`: Dictionary with mode: int, current_generation: int, retiring_generation: int, live_generations: int, paused: bool, closing: bool, accepting: bool, retirement_pump: String, retirement_reason: String, generations: Array[Dictionary] containing generation: int, references: int, idle: bool.
