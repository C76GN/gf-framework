# GFProjectileBinding

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_binding.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

definition 与完整场景实例之间的拓扑快照。 直接 `new()` 得到封闭的 unconfigured invalid value，其原因为 `INTERNAL_FAILURE`； 只有 typed definition 的 `bind_instance()` 才能构造有效 topology。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`FailureReason`](#member-gfprojectilebinding-enums-failurereason) | `enum FailureReason` |
| 方法 | [`is_valid`](#member-gfprojectilebinding-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_failure_reason`](#member-gfprojectilebinding-methods-get_failure_reason) | `func get_failure_reason() -> FailureReason:` |
| 方法 | [`get_definition`](#member-gfprojectilebinding-methods-get_definition) | `func get_definition() -> GFProjectileDefinition:` |
| 方法 | [`get_instance_root`](#member-gfprojectilebinding-methods-get_instance_root) | `func get_instance_root() -> Node:` |
| 方法 | [`get_runtime`](#member-gfprojectilebinding-methods-get_runtime) | `func get_runtime() -> Node:` |
| 方法 | [`get_impact_sources`](#member-gfprojectilebinding-methods-get_impact_sources) | `func get_impact_sources() -> Array[Node]:` |
| 方法 | [`get_body_adapter`](#member-gfprojectilebinding-methods-get_body_adapter) | `func get_body_adapter() -> Resource:` |
| 方法 | [`is_current`](#member-gfprojectilebinding-methods-is_current) | `func is_current() -> bool:` |

## 枚举

<a id="member-gfprojectilebinding-enums-failurereason"></a>

### `FailureReason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum FailureReason {
	## Topology 完整有效。
	NONE = 0,
	## Definition 缺少可用 scene 或声明无效。
	INVALID_DEFINITION = 1,
	## 实例 root 为 null 或已失效。
	INVALID_ROOT = 2,
	## Root 类型与 definition 维度不一致。
	ROOT_DIMENSION_MISMATCH = 3,
	## Root 尚未进入 SceneTree。
	ROOT_NOT_IN_TREE = 4,
	## Definition 未声明 runtime path。
	MISSING_RUNTIME_PATH = 5,
	## 实例树内没有对应维度 runtime。
	MISSING_RUNTIME = 6,
	## 实例树内存在多个对应维度 runtime。
	AMBIGUOUS_RUNTIME = 7,
	## 显式 runtime path 未指向唯一 runtime。
	RUNTIME_PATH_MISMATCH = 8,
	## Runtime path 解析到实例 root 之外。
	RUNTIME_OUTSIDE_ROOT = 9,
	## Runtime 节点维度错误。
	RUNTIME_DIMENSION_MISMATCH = 10,
	## Runtime 已有 ACTIVE session 或 launch claim。
	RUNTIME_BUSY = 11,
	## Definition 未配置 motion。
	MISSING_MOTION = 12,
	## Typed definition 未配置 body adapter。
	MISSING_BODY_ADAPTER = 13,
	## Body adapter 不支持该 root。
	UNSUPPORTED_MOTION_BODY = 14,
	## Impact source 路径或节点类型无效。
	INVALID_IMPACT_SOURCE = 15,
	## 显式 impact source 路径不存在。
	MISSING_IMPACT_SOURCE = 16,
	## Impact source 路径重复。
	DUPLICATE_IMPACT_SOURCE = 17,
	## Impact source 位于实例 root 之外。
	IMPACT_SOURCE_OUTSIDE_ROOT = 18,
	## Impact source 与 definition 维度不一致。
	IMPACT_SOURCE_DIMENSION_MISMATCH = 19,
	## Binding topology 已不再 current。
	STALE_BINDING = 20,
	## Motion 拒绝创建 per-session state。
	MOTION_STATE_CREATION_FAILED = 21,
	## Reservation 在消费前失效。
	RESERVATION_INVALIDATED = 22,
	## 公开默认构造但尚未由 typed definition 初始化的封闭 invalid 状态。
	INTERNAL_FAILURE = 23,
}
```

定义 binding 拒绝或失效的封闭原因。

## 方法

<a id="member-gfprojectilebinding-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

返回 topology 是否已完整绑定。

返回：binding 是否有效。

<a id="member-gfprojectilebinding-methods-get_failure_reason"></a>

### `get_failure_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failure_reason() -> FailureReason:
```

返回首个绑定失败原因。

返回：有效 binding 返回 `NONE`；默认 `new()` 返回 `INTERNAL_FAILURE`；其余返回首个确定失败原因。

<a id="member-gfprojectilebinding-methods-get_definition"></a>

### `get_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_definition() -> GFProjectileDefinition:
```

返回创建本快照的 typed definition。

返回：definition；准入前失败时可能为 null。

<a id="member-gfprojectilebinding-methods-get_instance_root"></a>

### `get_instance_root`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_instance_root() -> Node:
```

返回绑定的完整实例根节点。

返回：live root；已释放时返回 null。

<a id="member-gfprojectilebinding-methods-get_runtime"></a>

### `get_runtime`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_runtime() -> Node:
```

返回唯一 runtime 节点。

返回：live runtime；已释放时返回 null。

<a id="member-gfprojectilebinding-methods-get_impact_sources"></a>

### `get_impact_sources`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_impact_sources() -> Array[Node]:
```

返回 definition 声明顺序的 live impact source 快照。

返回：当前仍存活的 impact source。

结构：

- `return`: Array[Node]，definition 声明顺序的同维 GFHitBox/GFHitScan 显式 union；调用方可修改返回数组。

<a id="member-gfprojectilebinding-methods-get_body_adapter"></a>

### `get_body_adapter`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_body_adapter() -> Resource:
```

返回本次绑定冻结的 dimension-specific body adapter。

返回：`GFProjectileBodyAdapter2D` 或 `GFProjectileBodyAdapter3D`。

<a id="member-gfprojectilebinding-methods-is_current"></a>

### `is_current`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_current() -> bool:
```

检查弱引用 topology 是否仍与实例树一致。

返回：root、runtime 与所有 source 仍存活且位于同一实例树时返回 true。
