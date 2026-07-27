# GFAssetSlot

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_slot.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

稳定资源身份下的显式可替换资源槽位。 槽位强持有当前 Resource，并在成功配置、替换或终态释放后推进单调 generation。 它不监听文件变化、不接管 GFAssetUtility 缓存，也不改变 GFAssetHandle 的快照语义。 全部公开操作限定在主线程；其他线程上的调用会失败关闭且不改变槽位状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`resource_replaced`](#member-gfassetslot-signals-resource_replaced) | `signal resource_replaced(previous_resource: Resource, current_resource: Resource, generation: int)` |
| 信号 | [`released`](#member-gfassetslot-signals-released) | `signal released(previous_resource: Resource, generation: int)` |
| 方法 | [`configure`](#member-gfassetslot-methods-configure) | `func configure( resource_identity: GFResourceIdentity, initial_resource: Resource = null, owner: Object = null, type_hint_override: String = "" ) -> bool:` |
| 方法 | [`get_resource_identity`](#member-gfassetslot-methods-get_resource_identity) | `func get_resource_identity() -> GFResourceIdentity:` |
| 方法 | [`get_resource`](#member-gfassetslot-methods-get_resource) | `func get_resource() -> Resource:` |
| 方法 | [`get_type_hint`](#member-gfassetslot-methods-get_type_hint) | `func get_type_hint() -> String:` |
| 方法 | [`is_configured`](#member-gfassetslot-methods-is_configured) | `func is_configured() -> bool:` |
| 方法 | [`get_generation`](#member-gfassetslot-methods-get_generation) | `func get_generation() -> int:` |
| 方法 | [`has_resource`](#member-gfassetslot-methods-has_resource) | `func has_resource() -> bool:` |
| 方法 | [`is_released`](#member-gfassetslot-methods-is_released) | `func is_released() -> bool:` |
| 方法 | [`accepts_resource`](#member-gfassetslot-methods-accepts_resource) | `func accepts_resource(candidate_resource: Resource) -> bool:` |
| 方法 | [`replace`](#member-gfassetslot-methods-replace) | `func replace(next_resource: Resource) -> bool:` |
| 方法 | [`release`](#member-gfassetslot-methods-release) | `func release() -> bool:` |

## 信号

<a id="member-gfassetslot-signals-resource_replaced"></a>

### `resource_replaced`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal resource_replaced(previous_resource: Resource, current_resource: Resource, generation: int)
```

当前资源成功替换后发出。 信号发出前资源与 generation 已经提交；通知期间再次替换或释放会失败关闭。

参数：

| 名称 | 说明 |
|---|---|
| `previous_resource` | 替换前的资源；原先为空时为 null。 |
| `current_resource` | 替换后的资源。 |
| `generation` | 本次提交后的槽位 generation。 |

<a id="member-gfassetslot-signals-released"></a>

### `released`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal released(previous_resource: Resource, generation: int)
```

槽位进入不可逆释放终态后发出。 信号发出前资源已经清空、generation 已经推进且 owner 监听已经解除。

参数：

| 名称 | 说明 |
|---|---|
| `previous_resource` | 释放前的资源；原先为空时为 null。 |
| `generation` | 本次提交后的槽位 generation。 |

## 方法

<a id="member-gfassetslot-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure( resource_identity: GFResourceIdentity, initial_resource: Resource = null, owner: Object = null, type_hint_override: String = "" ) -> bool:
```

显式配置 live asset slot。 每个槽位只允许成功配置一次。资源身份会被复制并固定；type_hint_override 非空时覆盖身份中的 type_hint。空类型提示接受任意 Resource，非空类型提示 同时支持 Godot 原生类名、脚本 global class_name 与脚本资源路径。 owner 为 Node 时必须已经位于场景树中，退出场景树会自动释放槽位；其他 Object 通过弱引用在后续读取活动状态或替换时检测生命周期。owner 不会被槽位强持有。

参数：

| 名称 | 说明 |
|---|---|
| `resource_identity` | 具有稳定 cache_key 的资源身份。 |
| `initial_resource` | 可选初始资源。 |
| `owner` | 可选生命周期 owner。 |
| `type_hint_override` | 可选显式类型提示；为空时使用身份中的 type_hint。 |

返回：本次是否成功提交配置。

<a id="member-gfassetslot-methods-get_resource_identity"></a>

### `get_resource_identity`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_resource_identity() -> GFResourceIdentity:
```

获取稳定资源身份副本。 身份不属于活动资源状态，因此槽位释放后仍可读取。

返回：已配置身份的副本；尚未成功配置时返回 null。

<a id="member-gfassetslot-methods-get_resource"></a>

### `get_resource`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_resource() -> Resource:
```

获取当前资源。 若普通 Object owner 已释放，本次访问会先把槽位提交到释放终态。

返回：当前强引用资源；槽位未配置或已释放时返回 null。

<a id="member-gfassetslot-methods-get_type_hint"></a>

### `get_type_hint`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_type_hint() -> String:
```

获取当前生效的资源类型提示。 类型提示不属于活动资源状态，因此槽位释放后仍可读取。

返回：显式覆盖值、身份 type_hint 或空字符串。

<a id="member-gfassetslot-methods-is_configured"></a>

### `is_configured`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_configured() -> bool:
```

检查槽位是否已经成功配置。

返回：主线程上返回是否已经成功配置；其他线程返回 false。

<a id="member-gfassetslot-methods-get_generation"></a>

### `get_generation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_generation() -> int:
```

获取当前单调 generation。 generation 在成功配置、成功替换和首次释放后推进，且只应在同一个槽位内比较。 若普通 Object owner 已释放，本次访问会先提交释放。

返回：当前 generation；新建但未配置的槽位为 0，其他线程返回 -1。

<a id="member-gfassetslot-methods-has_resource"></a>

### `has_resource`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_resource() -> bool:
```

检查槽位当前是否持有资源。

返回：槽位活动且持有资源时返回 true。

<a id="member-gfassetslot-methods-is_released"></a>

### `is_released`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_released() -> bool:
```

检查槽位是否已经进入不可逆释放终态。

返回：成功配置后已进入终态时返回 true；未配置时返回 false，其他线程返回 true。

<a id="member-gfassetslot-methods-accepts_resource"></a>

### `accepts_resource`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func accepts_resource(candidate_resource: Resource) -> bool:
```

检查资源是否满足当前槽位类型契约。

参数：

| 名称 | 说明 |
|---|---|
| `candidate_resource` | 待检查资源。 |

返回：槽位活动且资源非空、类型兼容时返回 true。

<a id="member-gfassetslot-methods-replace"></a>

### `replace`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func replace(next_resource: Resource) -> bool:
```

原子替换当前资源。 成功时先提交资源和 generation，再同步发出 resource_replaced。相同实例、 空资源、类型不兼容、释放终态或通知重入均保持原状态并返回 false。

参数：

| 名称 | 说明 |
|---|---|
| `next_resource` | 新资源实例。 |

返回：本次是否提交了替换。

<a id="member-gfassetslot-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release() -> bool:
```

终态释放槽位持有的资源。 首次成功释放会清空资源、推进 generation、解除 owner 监听，再同步发出 released。 重复释放或通知重入没有副作用。

返回：本次是否首次提交了释放。
