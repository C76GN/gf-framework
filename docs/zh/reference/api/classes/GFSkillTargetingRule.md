# GFSkillTargetingRule

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/skills/gf_skill_targeting_rule.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

技能索敌规则资源。 使用纯数据结构描述目标筛选时的空间范围、 朝向约束、排序规则与标签过滤条件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Shape`](#member-gfskilltargetingrule-enums-shape) | `enum Shape` |
| 枚举 | [`SortRule`](#member-gfskilltargetingrule-enums-sortrule) | `enum SortRule` |
| 属性 | [`shape`](#member-gfskilltargetingrule-properties-shape) | `var shape: Shape = Shape.CIRCLE` |
| 属性 | [`radius`](#member-gfskilltargetingrule-properties-radius) | `var radius: float = 100.0` |
| 属性 | [`rectangle_size`](#member-gfskilltargetingrule-properties-rectangle_size) | `var rectangle_size: Vector2 = Vector2(200.0, 200.0)` |
| 属性 | [`max_count`](#member-gfskilltargetingrule-properties-max_count) | `var max_count: int = 1` |
| 属性 | [`forward_direction`](#member-gfskilltargetingrule-properties-forward_direction) | `var forward_direction: Vector2 = Vector2.RIGHT` |
| 属性 | [`sector_angle_degrees`](#member-gfskilltargetingrule-properties-sector_angle_degrees) | `var sector_angle_degrees: float = 90.0` |
| 属性 | [`sort_rule`](#member-gfskilltargetingrule-properties-sort_rule) | `var sort_rule: SortRule = SortRule.DISTANCE_CLOSEST` |
| 属性 | [`sort_attribute_name`](#member-gfskilltargetingrule-properties-sort_attribute_name) | `var sort_attribute_name: StringName = &"HP"` |
| 属性 | [`random_seed`](#member-gfskilltargetingrule-properties-random_seed) | `var random_seed: int = 0` |
| 属性 | [`require_tags`](#member-gfskilltargetingrule-properties-require_tags) | `var require_tags: Array[StringName] = []` |
| 属性 | [`ignore_tags`](#member-gfskilltargetingrule-properties-ignore_tags) | `var ignore_tags: Array[StringName] = []` |

## 枚举

<a id="member-gfskilltargetingrule-enums-shape"></a>

### `Shape`

- API：`public`

```gdscript
enum Shape {
	## 轴对齐矩形范围。
	RECTANGLE,
	## 圆形范围。
	CIRCLE,
	## 扇形范围。
	SECTOR,
	## 单体目标。
	SINGLE,
}
```

索敌形状。

<a id="member-gfskilltargetingrule-enums-sortrule"></a>

### `SortRule`

- API：`public`

```gdscript
enum SortRule {
	## 距离最近优先。
	DISTANCE_CLOSEST,
	## 距离最远优先。
	DISTANCE_FURTHEST,
	## 属性值最低优先。
	ATTRIBUTE_LOWEST,
	## 属性值最高优先。
	ATTRIBUTE_HIGHEST,
	## 随机顺序。
	RANDOM,
}
```

排序规则。

## 属性

<a id="member-gfskilltargetingrule-properties-shape"></a>

### `shape`

- API：`public`

```gdscript
var shape: Shape = Shape.CIRCLE
```

索敌形状。

<a id="member-gfskilltargetingrule-properties-radius"></a>

### `radius`

- API：`public`

```gdscript
var radius: float = 100.0
```

圆形、扇形与单体规则使用的最大半径。

<a id="member-gfskilltargetingrule-properties-rectangle_size"></a>

### `rectangle_size`

- API：`public`

```gdscript
var rectangle_size: Vector2 = Vector2(200.0, 200.0)
```

矩形范围尺寸，使用轴对齐包围盒判断。

<a id="member-gfskilltargetingrule-properties-max_count"></a>

### `max_count`

- API：`public`

```gdscript
var max_count: int = 1
```

最多选中的目标数量。

<a id="member-gfskilltargetingrule-properties-forward_direction"></a>

### `forward_direction`

- API：`public`

```gdscript
var forward_direction: Vector2 = Vector2.RIGHT
```

扇形朝向；为零向量时回退到 `Vector2.RIGHT`。

<a id="member-gfskilltargetingrule-properties-sector_angle_degrees"></a>

### `sector_angle_degrees`

- API：`public`

```gdscript
var sector_angle_degrees: float = 90.0
```

扇形夹角，单位为角度。

<a id="member-gfskilltargetingrule-properties-sort_rule"></a>

### `sort_rule`

- API：`public`

```gdscript
var sort_rule: SortRule = SortRule.DISTANCE_CLOSEST
```

目标排序逻辑。

<a id="member-gfskilltargetingrule-properties-sort_attribute_name"></a>

### `sort_attribute_name`

- API：`public`

```gdscript
var sort_attribute_name: StringName = &"HP"
```

按属性排序时使用的属性名。

<a id="member-gfskilltargetingrule-properties-random_seed"></a>

### `random_seed`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var random_seed: int = 0
```

RANDOM 排序使用的确定性种子。相同候选集合、相同实例顺序与相同种子会得到相同顺序。

<a id="member-gfskilltargetingrule-properties-require_tags"></a>

### `require_tags`

- API：`public`

```gdscript
var require_tags: Array[StringName] = []
```

目标必须拥有的标签列表。

<a id="member-gfskilltargetingrule-properties-ignore_tags"></a>

### `ignore_tags`

- API：`public`

```gdscript
var ignore_tags: Array[StringName] = []
```

目标禁止拥有的标签列表。
