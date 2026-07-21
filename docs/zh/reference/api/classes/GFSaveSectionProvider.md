# GFSaveSectionProvider

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_section_provider.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

Save Profile section 所有权协议。 一个 provider 只拥有一个稳定 section。实现必须能够采集当前状态、应用已校验 section，并在后续 provider 失败时恢复此前采集的 section。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`section_id`](#member-gfsavesectionprovider-properties-section_id) | `var section_id: StringName = &"":` |
| 属性 | [`schema_version`](#member-gfsavesectionprovider-properties-schema_version) | `var schema_version: int = 1:` |
| 属性 | [`save_enabled`](#member-gfsavesectionprovider-properties-save_enabled) | `var save_enabled: bool = true:` |
| 属性 | [`load_enabled`](#member-gfsavesectionprovider-properties-load_enabled) | `var load_enabled: bool = true:` |
| 属性 | [`required_on_load`](#member-gfsavesectionprovider-properties-required_on_load) | `var required_on_load: bool = true:` |
| 方法 | [`validate_provider`](#member-gfsavesectionprovider-methods-validate_provider) | `func validate_provider() -> Dictionary:` |
| 方法 | [`gather_section`](#member-gfsavesectionprovider-methods-gather_section) | `func gather_section(context: Dictionary = {}) -> GFSaveSection:` |
| 方法 | [`capture_section`](#member-gfsavesectionprovider-methods-capture_section) | `func capture_section(context: Dictionary = {}) -> GFSaveSection:` |
| 方法 | [`apply_section`](#member-gfsavesectionprovider-methods-apply_section) | `func apply_section(section: GFSaveSection, context: Dictionary = {}) -> Error:` |
| 方法 | [`rollback_section`](#member-gfsavesectionprovider-methods-rollback_section) | `func rollback_section(previous_section: GFSaveSection, context: Dictionary = {}) -> Error:` |
| 方法 | [`make_section`](#member-gfsavesectionprovider-methods-make_section) | `func make_section(payload: Variant, metadata: Dictionary = {}) -> GFSaveSection:` |
| 方法 | [`_gather_section`](#member-gfsavesectionprovider-methods-_gather_section) | `func _gather_section(_context: Dictionary = {}) -> GFSaveSection:` |
| 方法 | [`_capture_section`](#member-gfsavesectionprovider-methods-_capture_section) | `func _capture_section(context: Dictionary = {}) -> GFSaveSection:` |
| 方法 | [`_apply_section`](#member-gfsavesectionprovider-methods-_apply_section) | `func _apply_section(_section: GFSaveSection, _context: Dictionary = {}) -> Error:` |
| 方法 | [`_rollback_section`](#member-gfsavesectionprovider-methods-_rollback_section) | `func _rollback_section(previous_section: GFSaveSection, context: Dictionary = {}) -> Error:` |

## 属性

<a id="member-gfsavesectionprovider-properties-section_id"></a>

### `section_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var section_id: StringName = &"":
```

稳定且在 profile 内唯一的 section ID。

<a id="member-gfsavesectionprovider-properties-schema_version"></a>

### `schema_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var schema_version: int = 1:
```

当前 section schema 版本。

<a id="member-gfsavesectionprovider-properties-save_enabled"></a>

### `save_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var save_enabled: bool = true:
```

是否参与保存采集。

<a id="member-gfsavesectionprovider-properties-load_enabled"></a>

### `load_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var load_enabled: bool = true:
```

是否参与读取应用。

<a id="member-gfsavesectionprovider-properties-required_on_load"></a>

### `required_on_load`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var required_on_load: bool = true:
```

读取时该 section 是否必须存在。

## 方法

<a id="member-gfsavesectionprovider-methods-validate_provider"></a>

### `validate_provider`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_provider() -> Dictionary:
```

校验 provider 身份和能力配置。

返回：结构化校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.

<a id="member-gfsavesectionprovider-methods-gather_section"></a>

### `gather_section`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func gather_section(context: Dictionary = {}) -> GFSaveSection:
```

采集当前状态为隔离 section。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 本次操作的临时上下文。 |

返回：合法且身份匹配的 section；失败时返回 null。

结构：

- `context`: Dictionary with caller-defined ephemeral operation data.

<a id="member-gfsavesectionprovider-methods-capture_section"></a>

### `capture_section`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func capture_section(context: Dictionary = {}) -> GFSaveSection:
```

采集应用前回滚快照。 该能力独立于 `save_enabled`，允许只读取 provider 提供可回滚的内存快照。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 本次操作的临时上下文。 |

返回：合法且身份匹配的当前 section；失败时返回 null。

结构：

- `context`: Dictionary with caller-defined ephemeral operation data.

<a id="member-gfsavesectionprovider-methods-apply_section"></a>

### `apply_section`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func apply_section(section: GFSaveSection, context: Dictionary = {}) -> Error:
```

应用属于当前 provider 的 section。

参数：

| 名称 | 说明 |
|---|---|
| `section` | 已迁移并校验的当前版本 section。 |
| `context` | 本次操作的临时上下文。 |

返回：Godot Error 结果码。

结构：

- `context`: Dictionary with caller-defined ephemeral operation data.

<a id="member-gfsavesectionprovider-methods-rollback_section"></a>

### `rollback_section`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func rollback_section(previous_section: GFSaveSection, context: Dictionary = {}) -> Error:
```

使用应用前快照恢复当前 provider。

参数：

| 名称 | 说明 |
|---|---|
| `previous_section` | 应用前采集的当前版本 section。 |
| `context` | 本次操作的临时上下文。 |

返回：Godot Error 结果码。

结构：

- `context`: Dictionary with caller-defined ephemeral operation data.

<a id="member-gfsavesectionprovider-methods-make_section"></a>

### `make_section`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func make_section(payload: Variant, metadata: Dictionary = {}) -> GFSaveSection:
```

创建带当前 provider 身份的 section。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | 可持久化 section 载荷。 |
| `metadata` | 可持久化 section 元数据。 |

返回：新 section。

结构：

- `payload`: Variant accepted by GFSavePersistedValueValidator.
- `metadata`: Dictionary with provider-defined persisted metadata.

<a id="member-gfsavesectionprovider-methods-_gather_section"></a>

### `_gather_section`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _gather_section(_context: Dictionary = {}) -> GFSaveSection:
```

采集当前 section。返回 null 表示失败。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 本次操作的临时上下文。 |

返回：通过 `make_section()` 创建的当前版本 section。

结构：

- `_context`: Dictionary with caller-defined ephemeral operation data.

<a id="member-gfsavesectionprovider-methods-_capture_section"></a>

### `_capture_section`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _capture_section(context: Dictionary = {}) -> GFSaveSection:
```

采集应用前回滚快照。默认复用 `_gather_section()`。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 本次操作的临时上下文。 |

返回：通过 `make_section()` 创建的当前版本 section。

结构：

- `context`: Dictionary with caller-defined ephemeral operation data.

<a id="member-gfsavesectionprovider-methods-_apply_section"></a>

### `_apply_section`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _apply_section(_section: GFSaveSection, _context: Dictionary = {}) -> Error:
```

应用当前版本 section。

参数：

| 名称 | 说明 |
|---|---|
| `_section` | 已校验的 section 副本。 |
| `_context` | 本次操作的临时上下文。 |

返回：Godot Error 结果码。

结构：

- `_context`: Dictionary with caller-defined ephemeral operation data.

<a id="member-gfsavesectionprovider-methods-_rollback_section"></a>

### `_rollback_section`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _rollback_section(previous_section: GFSaveSection, context: Dictionary = {}) -> Error:
```

恢复应用前 section。默认复用 `_apply_section()`。

参数：

| 名称 | 说明 |
|---|---|
| `previous_section` | 应用前 section 副本。 |
| `context` | 本次操作的临时上下文。 |

返回：Godot Error 结果码。

结构：

- `context`: Dictionary with caller-defined ephemeral operation data.
