# GFProjectile2D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_2d.gd`
- 模块：`Combat`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

2D projectile scene 内的 dimension-neutral runtime 节点。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`projectile_started`](#member-gfprojectile2d-signals-projectile_started) | `signal projectile_started(session: GFProjectileSession)` |
| 信号 | [`projectile_finished`](#member-gfprojectile2d-signals-projectile_finished) | `signal projectile_finished(session: GFProjectileSession, reason: int)` |
| 方法 | [`launch`](#member-gfprojectile2d-methods-launch) | `func launch( binding: GFProjectileBinding2D, launch_input: GFProjectileLaunchInput2D = null ) -> GFProjectileSession:` |
| 方法 | [`get_active_session`](#member-gfprojectile2d-methods-get_active_session) | `func get_active_session() -> GFProjectileSession:` |
| 方法 | [`is_active`](#member-gfprojectile2d-methods-is_active) | `func is_active() -> bool:` |

## 信号

<a id="member-gfprojectile2d-signals-projectile_started"></a>

### `projectile_started`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal projectile_started(session: GFProjectileSession)
```

session 已 ACTIVE 且允许发布 started 时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session` | 本 runtime 的当前 session。 |

<a id="member-gfprojectile2d-signals-projectile_finished"></a>

### `projectile_finished`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal projectile_finished(session: GFProjectileSession, reason: int)
```

当前 session 首次结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `session` | 已结算 session。 |
| `reason` | \`GFProjectileSession.EndReason\` 枚举值。 |

## 方法

<a id="member-gfprojectile2d-methods-launch"></a>

### `launch`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func launch( binding: GFProjectileBinding2D, launch_input: GFProjectileLaunchInput2D = null ) -> GFProjectileSession:
```

直接激活一个已验证 binding。

参数：

| 名称 | 说明 |
|---|---|
| `binding` | 指向本 runtime 的 current 2D topology snapshot。 |
| `launch_input` | 可选 typed 输入；runtime 会在用户 callback 前冻结副本。 |

返回：ACTIVE session；准入、预检或重入失败时返回 null。

<a id="member-gfprojectile2d-methods-get_active_session"></a>

### `get_active_session`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_active_session() -> GFProjectileSession:
```

返回当前 ACTIVE session。

返回：ACTIVE session；未激活或已结束时返回 null。

<a id="member-gfprojectile2d-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_active() -> bool:
```

判断 runtime 是否持有 ACTIVE session。

返回：当前 session ACTIVE 时为 true。
