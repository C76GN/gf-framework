# GFProjectileLifetimePolicy

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_lifetime_policy.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

基于 session 观测值的生命周期策略。 Runtime 在 launch 时强持有策略快照；Definition 后续替换/清空或外部引用释放 不改变 ACTIVE session，终态清理后 Runtime 释放该快照。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`max_seconds`](#member-gfprojectilelifetimepolicy-properties-max_seconds) | `var max_seconds: float = 0.0` |
| 属性 | [`max_distance`](#member-gfprojectilelifetimepolicy-properties-max_distance) | `var max_distance: float = 0.0` |
| 属性 | [`max_impacts`](#member-gfprojectilelifetimepolicy-properties-max_impacts) | `var max_impacts: int = 0` |
| 方法 | [`get_end_reason`](#member-gfprojectilelifetimepolicy-methods-get_end_reason) | `func get_end_reason(session: GFProjectileSession) -> GFProjectileSession.EndReason:` |
| 方法 | [`_should_finish`](#member-gfprojectilelifetimepolicy-methods-_should_finish) | `func _should_finish(_session: GFProjectileSession) -> bool:` |

## 属性

<a id="member-gfprojectilelifetimepolicy-properties-max_seconds"></a>

### `max_seconds`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_seconds: float = 0.0
```

最大活动时长；不大于零表示不限制。

<a id="member-gfprojectilelifetimepolicy-properties-max_distance"></a>

### `max_distance`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_distance: float = 0.0
```

最大累计实际位移；不大于零表示不限制。

<a id="member-gfprojectilelifetimepolicy-properties-max_impacts"></a>

### `max_impacts`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_impacts: int = 0
```

最大已接受 impact 数；不大于零表示不限制。

## 方法

<a id="member-gfprojectilelifetimepolicy-methods-get_end_reason"></a>

### `get_end_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_end_reason(session: GFProjectileSession) -> GFProjectileSession.EndReason:
```

计算当前 session 是否已触发生命周期终止条件。

参数：

| 名称 | 说明 |
|---|---|
| `session` | 当前 projectile session。 |

返回：尚未结束时为 `NONE`，否则为首个匹配的生命周期原因。

<a id="member-gfprojectilelifetimepolicy-methods-_should_finish"></a>

### `_should_finish`

- API：`protected`
- 首次版本：`3.17.0`

```gdscript
func _should_finish(_session: GFProjectileSession) -> bool:
```

自定义生命周期终止钩子。

参数：

| 名称 | 说明 |
|---|---|
| `_session` | 当前 projectile session。 |

返回：是否以 `LIFETIME_CUSTOM` 结束。
