# GFCombatHitContext

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/hit_detection/gf_combat_hit_context.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

一次通用命中交互的上下文。 只保存 source、target、hit_id、payload、位置和元数据。 它不解释伤害、阵营、生命值、命中结果或任何业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`source`](#member-gfcombathitcontext-properties-source) | `var source: Object = null` |
| 属性 | [`target`](#member-gfcombathitcontext-properties-target) | `var target: Object = null` |
| 属性 | [`hit_id`](#member-gfcombathitcontext-properties-hit_id) | `var hit_id: StringName = &""` |
| 属性 | [`payload`](#member-gfcombathitcontext-properties-payload) | `var payload: Variant = null` |
| 属性 | [`magnitude`](#member-gfcombathitcontext-properties-magnitude) | `var magnitude: float = 0.0` |
| 属性 | [`tags`](#member-gfcombathitcontext-properties-tags) | `var tags: Array[StringName] = []` |
| 属性 | [`position_2d`](#member-gfcombathitcontext-properties-position_2d) | `var position_2d: Vector2 = Vector2.ZERO` |
| 属性 | [`normal_2d`](#member-gfcombathitcontext-properties-normal_2d) | `var normal_2d: Vector2 = Vector2.ZERO` |
| 属性 | [`position_3d`](#member-gfcombathitcontext-properties-position_3d) | `var position_3d: Vector3 = Vector3.ZERO` |
| 属性 | [`normal_3d`](#member-gfcombathitcontext-properties-normal_3d) | `var normal_3d: Vector3 = Vector3.ZERO` |
| 属性 | [`metadata`](#member-gfcombathitcontext-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`with_source`](#member-gfcombathitcontext-methods-with_source) | `func with_source(value: Object) -> GFCombatHitContext:` |
| 方法 | [`with_target`](#member-gfcombathitcontext-methods-with_target) | `func with_target(value: Object) -> GFCombatHitContext:` |
| 方法 | [`with_hit_id`](#member-gfcombathitcontext-methods-with_hit_id) | `func with_hit_id(value: StringName) -> GFCombatHitContext:` |
| 方法 | [`with_payload`](#member-gfcombathitcontext-methods-with_payload) | `func with_payload(value: Variant) -> GFCombatHitContext:` |
| 方法 | [`with_magnitude`](#member-gfcombathitcontext-methods-with_magnitude) | `func with_magnitude(value: float) -> GFCombatHitContext:` |
| 方法 | [`with_tags`](#member-gfcombathitcontext-methods-with_tags) | `func with_tags(value: Array[StringName]) -> GFCombatHitContext:` |
| 方法 | [`with_metadata`](#member-gfcombathitcontext-methods-with_metadata) | `func with_metadata(value: Dictionary) -> GFCombatHitContext:` |
| 方法 | [`to_dict`](#member-gfcombathitcontext-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 属性

<a id="member-gfcombathitcontext-properties-source"></a>

### `source`

- API：`public`

```gdscript
var source: Object = null
```

命中发起者。

<a id="member-gfcombathitcontext-properties-target"></a>

### `target`

- API：`public`

```gdscript
var target: Object = null
```

命中目标。

<a id="member-gfcombathitcontext-properties-hit_id"></a>

### `hit_id`

- API：`public`

```gdscript
var hit_id: StringName = &""
```

命中 ID。

<a id="member-gfcombathitcontext-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Variant = null
```

命中携带的数据。框架不解释该字段。

结构：

- `payload`: Variant，项目自定义命中载荷；框架只复制并透传。

<a id="member-gfcombathitcontext-properties-magnitude"></a>

### `magnitude`

- API：`public`

```gdscript
var magnitude: float = 0.0
```

通用强度值。框架不解释该字段。

<a id="member-gfcombathitcontext-properties-tags"></a>

### `tags`

- API：`public`

```gdscript
var tags: Array[StringName] = []
```

命中标签。框架不解释该字段。

<a id="member-gfcombathitcontext-properties-position_2d"></a>

### `position_2d`

- API：`public`

```gdscript
var position_2d: Vector2 = Vector2.ZERO
```

2D 命中位置。

<a id="member-gfcombathitcontext-properties-normal_2d"></a>

### `normal_2d`

- API：`public`

```gdscript
var normal_2d: Vector2 = Vector2.ZERO
```

2D 命中法线。

<a id="member-gfcombathitcontext-properties-position_3d"></a>

### `position_3d`

- API：`public`

```gdscript
var position_3d: Vector3 = Vector3.ZERO
```

3D 命中位置。

<a id="member-gfcombathitcontext-properties-normal_3d"></a>

### `normal_3d`

- API：`public`

```gdscript
var normal_3d: Vector3 = Vector3.ZERO
```

3D 命中法线。

<a id="member-gfcombathitcontext-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，项目自定义命中元数据；框架只复制并透传。

## 方法

<a id="member-gfcombathitcontext-methods-with_source"></a>

### `with_source`

- API：`public`

```gdscript
func with_source(value: Object) -> GFCombatHitContext:
```

设置 source 并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | source 对象。 |

返回：当前上下文。

<a id="member-gfcombathitcontext-methods-with_target"></a>

### `with_target`

- API：`public`

```gdscript
func with_target(value: Object) -> GFCombatHitContext:
```

设置 target 并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | target 对象。 |

返回：当前上下文。

<a id="member-gfcombathitcontext-methods-with_hit_id"></a>

### `with_hit_id`

- API：`public`

```gdscript
func with_hit_id(value: StringName) -> GFCombatHitContext:
```

设置 hit_id 并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 命中 ID。 |

返回：当前上下文。

<a id="member-gfcombathitcontext-methods-with_payload"></a>

### `with_payload`

- API：`public`

```gdscript
func with_payload(value: Variant) -> GFCombatHitContext:
```

设置 payload 并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | payload 数据。 |

返回：当前上下文。

结构：

- `value`: Variant，项目自定义命中载荷；框架只复制并透传。

<a id="member-gfcombathitcontext-methods-with_magnitude"></a>

### `with_magnitude`

- API：`public`

```gdscript
func with_magnitude(value: float) -> GFCombatHitContext:
```

设置通用强度值并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 通用强度值。 |

返回：当前上下文。

<a id="member-gfcombathitcontext-methods-with_tags"></a>

### `with_tags`

- API：`public`

```gdscript
func with_tags(value: Array[StringName]) -> GFCombatHitContext:
```

设置标签并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 标签数组。 |

返回：当前上下文。

<a id="member-gfcombathitcontext-methods-with_metadata"></a>

### `with_metadata`

- API：`public`

```gdscript
func with_metadata(value: Dictionary) -> GFCombatHitContext:
```

设置元数据并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 元数据。 |

返回：当前上下文。

结构：

- `value`: Dictionary，项目自定义命中元数据；框架只复制并透传。

<a id="member-gfcombathitcontext-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典快照。

返回：字典快照。

结构：

- `return`: Dictionary，包含 source、target、hit_id、payload、magnitude、tags、position_2d、normal_2d、position_3d、normal_3d 和 metadata。
