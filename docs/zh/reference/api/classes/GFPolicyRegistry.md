# GFPolicyRegistry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/policy/gf_policy_registry.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

通用策略 Provider 注册表。 管理 GFPolicyProvider 集合，并按 artifact kind 对输入 artifact 执行匹配策略。 注册表只负责协议分发和结果汇总，不解释具体业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`providers`](#member-gfpolicyregistry-properties-providers) | `var providers: Array[GFPolicyProvider] = []` |
| 方法 | [`register_provider`](#member-gfpolicyregistry-methods-register_provider) | `func register_provider(provider: GFPolicyProvider) -> bool:` |
| 方法 | [`unregister_provider`](#member-gfpolicyregistry-methods-unregister_provider) | `func unregister_provider(provider_id: StringName) -> bool:` |
| 方法 | [`clear`](#member-gfpolicyregistry-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_provider`](#member-gfpolicyregistry-methods-get_provider) | `func get_provider(provider_id: StringName) -> GFPolicyProvider:` |
| 方法 | [`get_providers_for_artifact`](#member-gfpolicyregistry-methods-get_providers_for_artifact) | `func get_providers_for_artifact(artifact: Dictionary) -> Array[GFPolicyProvider]:` |
| 方法 | [`evaluate_artifact`](#member-gfpolicyregistry-methods-evaluate_artifact) | `func evaluate_artifact(artifact: Dictionary, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfpolicyregistry-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfpolicyregistry-properties-providers"></a>

### `providers`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var providers: Array[GFPolicyProvider] = []
```

已注册 Provider 列表。

结构：

- `providers`: Array[GFPolicyProvider] policy providers.

## 方法

<a id="member-gfpolicyregistry-methods-register_provider"></a>

### `register_provider`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func register_provider(provider: GFPolicyProvider) -> bool:
```

注册或替换 Provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 策略 Provider。 |

返回：注册成功返回 true。

<a id="member-gfpolicyregistry-methods-unregister_provider"></a>

### `unregister_provider`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func unregister_provider(provider_id: StringName) -> bool:
```

注销 Provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider_id` | Provider 稳定标识。 |

返回：注销成功返回 true。

<a id="member-gfpolicyregistry-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear() -> void:
```

清空 Provider。

<a id="member-gfpolicyregistry-methods-get_provider"></a>

### `get_provider`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_provider(provider_id: StringName) -> GFPolicyProvider:
```

获取 Provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider_id` | Provider 稳定标识。 |

返回：Provider；不存在时返回 null。

<a id="member-gfpolicyregistry-methods-get_providers_for_artifact"></a>

### `get_providers_for_artifact`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_providers_for_artifact(artifact: Dictionary) -> Array[GFPolicyProvider]:
```

获取支持 artifact 的 Provider 列表。

参数：

| 名称 | 说明 |
|---|---|
| `artifact` | artifact 字典。 |

返回：Provider 列表。

结构：

- `artifact`: Dictionary with optional kind or artifact_kind.

<a id="member-gfpolicyregistry-methods-evaluate_artifact"></a>

### `evaluate_artifact`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func evaluate_artifact(artifact: Dictionary, context: Dictionary = {}) -> Dictionary:
```

对 artifact 执行匹配策略。

参数：

| 名称 | 说明 |
|---|---|
| `artifact` | artifact 字典。 |
| `context` | 调用方上下文。 |

返回：汇总结果。

结构：

- `artifact`: Dictionary policy input artifact.
- `context`: Dictionary caller-defined policy context.
- `return`: Dictionary with ok, provider_count, result_count, results, issues, and artifact.

<a id="member-gfpolicyregistry-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary containing provider_count and provider_ids.
