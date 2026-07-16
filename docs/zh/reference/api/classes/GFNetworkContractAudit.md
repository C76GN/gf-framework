# GFNetworkContractAudit

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/editor/gf_network_contract_audit.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`8.0.0`

网络契约编辑器审计器。 对 GFNetworkContract 执行 fail-closed 倾向的结构审计，帮助项目在运行前发现 松散 payload、未知通道、缺少版本和过宽 Variant 字段等风险。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`audit_contract`](#member-gfnetworkcontractaudit-methods-audit_contract) | `func audit_contract(contract: GFNetworkContract, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`audit_paths`](#member-gfnetworkcontractaudit-methods-audit_paths) | `func audit_paths(contract_paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfnetworkcontractaudit-methods-audit_contract"></a>

### `audit_contract`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func audit_contract(contract: GFNetworkContract, options: Dictionary = {}) -> Dictionary:
```

审计网络契约。

参数：

| 名称 | 说明 |
|---|---|
| `contract` | 网络契约。 |
| `options` | 审计选项，支持 known_channel_ids、require_contract_id、require_version、require_channel_ids、warn_variant_fields、warn_unbounded_collections、max_messages 和 max_fields_per_message。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary audit options.
- `return`: Dictionary with ok, issues, issue_count, summary, and next_action.

<a id="member-gfnetworkcontractaudit-methods-audit_paths"></a>

### `audit_paths`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func audit_paths(contract_paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:
```

审计多个网络契约资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `contract_paths` | 契约资源路径列表。 |
| `options` | 审计选项。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary audit options.
- `return`: Dictionary with ok, issues, issue_count, contract_count, summary, and next_action.
