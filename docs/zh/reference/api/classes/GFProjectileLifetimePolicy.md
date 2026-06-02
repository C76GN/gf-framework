# GFProjectileLifetimePolicy

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_lifetime_policy.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

发射体生命周期策略。 默认支持按时间和距离结束。项目可继承后叠加自定义结束条件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`max_seconds`](#member-gfprojectilelifetimepolicy-properties-max_seconds) | `var max_seconds: float = 0.0` |
| 属性 | [`max_distance`](#member-gfprojectilelifetimepolicy-properties-max_distance) | `var max_distance: float = 0.0` |
| 属性 | [`max_impacts`](#member-gfprojectilelifetimepolicy-properties-max_impacts) | `var max_impacts: int = 0` |
| 方法 | [`setup`](#member-gfprojectilelifetimepolicy-methods-setup) | `func setup(projectile: Node, projectile_context: Dictionary = {}) -> void:` |
| 方法 | [`should_finish`](#member-gfprojectilelifetimepolicy-methods-should_finish) | `func should_finish(projectile: Node, elapsed_seconds: float, projectile_context: Dictionary = {}) -> bool:` |

## 属性

<a id="member-gfprojectilelifetimepolicy-properties-max_seconds"></a>

### `max_seconds`

- API：`public`

```gdscript
var max_seconds: float = 0.0
```

最长存活时间。小于等于 0 表示不按时间结束。

<a id="member-gfprojectilelifetimepolicy-properties-max_distance"></a>

### `max_distance`

- API：`public`

```gdscript
var max_distance: float = 0.0
```

最远移动距离。小于等于 0 表示不按距离结束。

<a id="member-gfprojectilelifetimepolicy-properties-max_impacts"></a>

### `max_impacts`

- API：`public`

```gdscript
var max_impacts: int = 0
```

最大成功命中次数。小于等于 0 表示不按命中次数结束。

## 方法

<a id="member-gfprojectilelifetimepolicy-methods-setup"></a>

### `setup`

- API：`public`

```gdscript
func setup(projectile: Node, projectile_context: Dictionary = {}) -> void:
```

发射体启动时调用。

参数：

| 名称 | 说明 |
|---|---|
| `projectile` | 发射体节点。 |
| `projectile_context` | 本次发射的上下文字典。 |

结构：

- `projectile_context`: Dictionary，本次发射上下文；会写入初始位置和 impact_count。

<a id="member-gfprojectilelifetimepolicy-methods-should_finish"></a>

### `should_finish`

- API：`public`

```gdscript
func should_finish(projectile: Node, elapsed_seconds: float, projectile_context: Dictionary = {}) -> bool:
```

判断发射体是否应结束。

参数：

| 名称 | 说明 |
|---|---|
| `projectile` | 发射体节点。 |
| `elapsed_seconds` | 本次发射已经运行的秒数。 |
| `projectile_context` | 本次发射的上下文字典。 |

返回：应结束时返回 true。

结构：

- `projectile_context`: Dictionary，本次发射上下文；用于读取初始位置和 impact_count。
