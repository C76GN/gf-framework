# GFHitScan3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/hit_detection/gf_hit_scan_3d.gd`
- 模块：`Combat`
- 继承：`RayCast3D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

3D 通用射线命中发送器。 基于 RayCast3D 构建 GFCombatHitContext 并发送给具备 receive_hit() 的接收对象。 它不规定伤害、穿透、命中特效或任何业务规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`scan_hit`](#member-gfhitscan3d-signals-scan_hit) | `signal scan_hit(context: GFCombatHitContext, receiver: Object, report: Dictionary)` |
| 信号 | [`scan_missed`](#member-gfhitscan3d-signals-scan_missed) | `signal scan_missed(report: Dictionary)` |
| 信号 | [`hit_accepted`](#member-gfhitscan3d-signals-hit_accepted) | `signal hit_accepted(context: GFCombatHitContext, receiver: Object, report: Dictionary)` |
| 信号 | [`hit_rejected`](#member-gfhitscan3d-signals-hit_rejected) | `signal hit_rejected(context: GFCombatHitContext, receiver: Object, report: Dictionary)` |
| 属性 | [`hit_enabled`](#member-gfhitscan3d-properties-hit_enabled) | `var hit_enabled: bool = true` |
| 属性 | [`force_update_before_scan`](#member-gfhitscan3d-properties-force_update_before_scan) | `var force_update_before_scan: bool = true` |
| 属性 | [`hit_id`](#member-gfhitscan3d-properties-hit_id) | `var hit_id: StringName = &""` |
| 属性 | [`payload`](#member-gfhitscan3d-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`magnitude`](#member-gfhitscan3d-properties-magnitude) | `var magnitude: float = 0.0` |
| 属性 | [`tags`](#member-gfhitscan3d-properties-tags) | `var tags: Array[StringName] = []` |
| 属性 | [`metadata`](#member-gfhitscan3d-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`sender_path`](#member-gfhitscan3d-properties-sender_path) | `var sender_path: NodePath = NodePath("")` |
| 方法 | [`build_hit_context`](#member-gfhitscan3d-methods-build_hit_context) | `func build_hit_context( target: Object = null, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> GFCombatHitContext:` |
| 方法 | [`scan`](#member-gfhitscan3d-methods-scan) | `func scan(payload_override: Variant = null, hit_id_override: StringName = &"") -> Dictionary:` |

## 信号

<a id="member-gfhitscan3d-signals-scan_hit"></a>

### `scan_hit`

- API：`public`

```gdscript
signal scan_hit(context: GFCombatHitContext, receiver: Object, report: Dictionary)
```

扫描命中对象后发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: Dictionary，统一扫描命中结果，包含 ok、hit_id、receiver、reason、message 和 metadata。

<a id="member-gfhitscan3d-signals-scan_missed"></a>

### `scan_missed`

- API：`public`

```gdscript
signal scan_missed(report: Dictionary)
```

扫描没有命中可发送对象时发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 结果报告。 |

结构：

- `report`: Dictionary，扫描未命中报告，包含 ok、reason 和 metadata。

<a id="member-gfhitscan3d-signals-hit_accepted"></a>

### `hit_accepted`

- API：`public`

```gdscript
signal hit_accepted(context: GFCombatHitContext, receiver: Object, report: Dictionary)
```

命中被接收对象接受。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: Dictionary，统一扫描命中结果，包含 ok、hit_id、receiver、reason、message 和 metadata。

<a id="member-gfhitscan3d-signals-hit_rejected"></a>

### `hit_rejected`

- API：`public`

```gdscript
signal hit_rejected(context: GFCombatHitContext, receiver: Object, report: Dictionary)
```

命中被接收对象拒绝或发送失败。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: Dictionary，统一扫描命中结果，包含 ok、hit_id、receiver、reason、message 和 metadata。

## 属性

<a id="member-gfhitscan3d-properties-hit_enabled"></a>

### `hit_enabled`

- API：`public`

```gdscript
var hit_enabled: bool = true
```

是否允许发送命中。

<a id="member-gfhitscan3d-properties-force_update_before_scan"></a>

### `force_update_before_scan`

- API：`public`

```gdscript
var force_update_before_scan: bool = true
```

扫描前是否强制刷新射线。

<a id="member-gfhitscan3d-properties-hit_id"></a>

### `hit_id`

- API：`public`

```gdscript
var hit_id: StringName = &""
```

默认命中 ID。

<a id="member-gfhitscan3d-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Dictionary = {}
```

默认 payload；发送时会深拷贝。

结构：

- `payload`: Dictionary，默认命中载荷；框架只复制并透传。

<a id="member-gfhitscan3d-properties-magnitude"></a>

### `magnitude`

- API：`public`

```gdscript
var magnitude: float = 0.0
```

通用强度值。框架不解释该字段。

<a id="member-gfhitscan3d-properties-tags"></a>

### `tags`

- API：`public`

```gdscript
var tags: Array[StringName] = []
```

命中标签。框架不解释该字段。

<a id="member-gfhitscan3d-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

发送器自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，发送器自定义扫描命中元数据；会进入命中上下文和结果报告。

<a id="member-gfhitscan3d-properties-sender_path"></a>

### `sender_path`

- API：`public`

```gdscript
var sender_path: NodePath = NodePath("")
```

可选发送者路径；为空时使用当前节点。

## 方法

<a id="member-gfhitscan3d-methods-build_hit_context"></a>

### `build_hit_context`

- API：`public`

```gdscript
func build_hit_context( target: Object = null, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> GFCombatHitContext:
```

构建命中上下文。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 命中目标。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `hit_id_override` | 覆盖命中 ID；为空时使用节点默认命中 ID。 |

返回：命中上下文。

结构：

- `payload_override`: Variant，可为 null、Dictionary 或项目自定义命中载荷；为 null 时使用节点默认 payload。

<a id="member-gfhitscan3d-methods-scan"></a>

### `scan`

- API：`public`

```gdscript
func scan(payload_override: Variant = null, hit_id_override: StringName = &"") -> Dictionary:
```

执行一次射线扫描并尝试发送命中。

参数：

| 名称 | 说明 |
|---|---|
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `hit_id_override` | 覆盖命中 ID；为空时使用节点默认命中 ID。 |

返回：统一结果报告。

结构：

- `payload_override`: Variant，可为 null、Dictionary 或项目自定义命中载荷；为 null 时使用节点默认 payload。
- `return`: Dictionary，统一扫描命中或未命中结果，包含 ok、reason、metadata，并在命中时包含 hit_id、receiver 和 message。
