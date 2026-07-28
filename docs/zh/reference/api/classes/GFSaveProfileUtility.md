# GFSaveProfileUtility

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_utility.gd`
- 模块：`Save`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`10.0.0`

多 section 存档的异步协调器。 每个 profile 只串行推进一个当前 IO；超时后无法取消的写入会 detached 保留路径所有权。 连续保存通过 generation 合并为最新后续写入；读取在保存屏障后执行，并在主线程完成迁移、校验和 provider 事务化应用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`profile_operation_completed`](#member-gfsaveprofileutility-signals-profile_operation_completed) | `signal profile_operation_completed(result: GFSaveProfileResult)` |
| 信号 | [`profile_state_changed`](#member-gfsaveprofileutility-signals-profile_state_changed) | `signal profile_state_changed(profile_id: StringName, previous_state: StringName, current_state: StringName)` |
| 常量 | [`STATE_IDLE`](#member-gfsaveprofileutility-constants-state_idle) | `const STATE_IDLE: StringName = &"idle"` |
| 常量 | [`STATE_GATHERING`](#member-gfsaveprofileutility-constants-state_gathering) | `const STATE_GATHERING: StringName = &"gathering"` |
| 常量 | [`STATE_SAVING`](#member-gfsaveprofileutility-constants-state_saving) | `const STATE_SAVING: StringName = &"saving"` |
| 常量 | [`STATE_LOADING`](#member-gfsaveprofileutility-constants-state_loading) | `const STATE_LOADING: StringName = &"loading"` |
| 常量 | [`STATE_RETRY_WAIT`](#member-gfsaveprofileutility-constants-state_retry_wait) | `const STATE_RETRY_WAIT: StringName = &"retry_wait"` |
| 常量 | [`STATE_APPLYING`](#member-gfsaveprofileutility-constants-state_applying) | `const STATE_APPLYING: StringName = &"applying"` |
| 常量 | [`STATE_DISPOSED`](#member-gfsaveprofileutility-constants-state_disposed) | `const STATE_DISPOSED: StringName = &"disposed"` |
| 方法 | [`ready`](#member-gfsaveprofileutility-methods-ready) | `func ready() -> void:` |
| 方法 | [`tick`](#member-gfsaveprofileutility-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfsaveprofileutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`setup`](#member-gfsaveprofileutility-methods-setup) | `func setup(storage: GFStorageUtility, clock: GFClock = null) -> GFSaveProfileUtility:` |
| 方法 | [`register_profile`](#member-gfsaveprofileutility-methods-register_profile) | `func register_profile( profile: GFSaveProfile, migrations: GFSaveMigrationRegistry = null ) -> Dictionary:` |
| 方法 | [`unregister_profile`](#member-gfsaveprofileutility-methods-unregister_profile) | `func unregister_profile(profile_id: StringName) -> bool:` |
| 方法 | [`save_profile`](#member-gfsaveprofileutility-methods-save_profile) | `func save_profile( profile_id: StringName, metadata: Dictionary = {}, context: Dictionary = {} ) -> GFSaveProfileOperation:` |
| 方法 | [`load_profile`](#member-gfsaveprofileutility-methods-load_profile) | `func load_profile( profile_id: StringName, context: Dictionary = {}, metadata: Dictionary = {} ) -> GFSaveProfileOperation:` |
| 方法 | [`flush_profile`](#member-gfsaveprofileutility-methods-flush_profile) | `func flush_profile( profile_id: StringName, metadata: Dictionary = {} ) -> GFSaveProfileOperation:` |
| 方法 | [`get_persisted_generation`](#member-gfsaveprofileutility-methods-get_persisted_generation) | `func get_persisted_generation(profile_id: StringName) -> int:` |
| 方法 | [`get_profile_state_snapshot`](#member-gfsaveprofileutility-methods-get_profile_state_snapshot) | `func get_profile_state_snapshot(profile_id: StringName) -> Dictionary:` |

## 信号

<a id="member-gfsaveprofileutility-signals-profile_operation_completed"></a>

### `profile_operation_completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal profile_operation_completed(result: GFSaveProfileResult)
```

任一 profile 操作进入终态时发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 隔离终态结果。 |

<a id="member-gfsaveprofileutility-signals-profile_state_changed"></a>

### `profile_state_changed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal profile_state_changed(profile_id: StringName, previous_state: StringName, current_state: StringName)
```

profile 状态机发生变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | profile ID。 |
| `previous_state` | 变化前状态。 |
| `current_state` | 变化后状态。 |

## 常量

<a id="member-gfsaveprofileutility-constants-state_idle"></a>

### `STATE_IDLE`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATE_IDLE: StringName = &"idle"
```

Profile 空闲。

<a id="member-gfsaveprofileutility-constants-state_gathering"></a>

### `STATE_GATHERING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATE_GATHERING: StringName = &"gathering"
```

正在同步采集 section。

<a id="member-gfsaveprofileutility-constants-state_saving"></a>

### `STATE_SAVING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATE_SAVING: StringName = &"saving"
```

正在等待保存 IO。

<a id="member-gfsaveprofileutility-constants-state_loading"></a>

### `STATE_LOADING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATE_LOADING: StringName = &"loading"
```

正在等待读取 IO。

<a id="member-gfsaveprofileutility-constants-state_retry_wait"></a>

### `STATE_RETRY_WAIT`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATE_RETRY_WAIT: StringName = &"retry_wait"
```

正在等待有界重试截止时间。

<a id="member-gfsaveprofileutility-constants-state_applying"></a>

### `STATE_APPLYING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATE_APPLYING: StringName = &"applying"
```

正在迁移、校验或事务化应用 section。

<a id="member-gfsaveprofileutility-constants-state_disposed"></a>

### `STATE_DISPOSED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATE_DISPOSED: StringName = &"disposed"
```

Utility 已释放。

## 方法

<a id="member-gfsaveprofileutility-methods-ready"></a>

### `ready`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func ready() -> void:
```

在架构 ready 阶段采用已注册的 Storage 和 Time 服务。 `setup()` 显式注入的依赖不会被覆盖。

<a id="member-gfsaveprofileutility-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func tick(_delta: float) -> void:
```

推进到期重试。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 未使用；重试只读取注入时钟的单调时间。 |

<a id="member-gfsaveprofileutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func dispose() -> void:
```

终止所有未完成操作并释放底层信号连接。

<a id="member-gfsaveprofileutility-methods-setup"></a>

### `setup`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func setup(storage: GFStorageUtility, clock: GFClock = null) -> GFSaveProfileUtility:
```

显式注入底层存储和可选时钟。

参数：

| 名称 | 说明 |
|---|---|
| `storage` | 底层事务存储工具。 |
| `clock` | 可选单调时钟；为空时保留当前时钟。 |

返回：当前 Utility；参数无效、已释放或已有注册 profile 时返回 null。

<a id="member-gfsaveprofileutility-methods-register_profile"></a>

### `register_profile`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func register_profile( profile: GFSaveProfile, migrations: GFSaveMigrationRegistry = null ) -> Dictionary:
```

注册一个 profile 及其可选迁移注册表。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | profile 声明和 section providers。 |
| `migrations` | 该 profile 的迁移注册表。 |

返回：包含 registered、规范文件名和全部校验问题的结构化报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with registered, profile_id, schema_id, canonical_file_name, issues, counts, summary, and next_actions.

<a id="member-gfsaveprofileutility-methods-unregister_profile"></a>

### `unregister_profile`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func unregister_profile(profile_id: StringName) -> bool:
```

注销空闲 profile。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | profile ID。 |

返回：profile 存在且没有未完成操作时返回 true。

<a id="member-gfsaveprofileutility-methods-save_profile"></a>

### `save_profile`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func save_profile( profile_id: StringName, metadata: Dictionary = {}, context: Dictionary = {} ) -> GFSaveProfileOperation:
```

请求异步保存 profile。 在途写入期间的新请求只保留最新 generation；每个句柄在覆盖自身 generation 的写入成功或失败后完成。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | profile ID。 |
| `metadata` | 写入文档的持久化元数据。 |
| `context` | provider 采集使用的临时上下文。 |

返回：保存操作句柄；无效请求返回已失败句柄。

结构：

- `metadata`: Dictionary with caller-defined persisted document metadata.
- `context`: Dictionary with caller-defined ephemeral operation data.

<a id="member-gfsaveprofileutility-methods-load_profile"></a>

### `load_profile`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func load_profile( profile_id: StringName, context: Dictionary = {}, metadata: Dictionary = {} ) -> GFSaveProfileOperation:
```

请求异步读取、迁移、校验并应用 profile。 调用时捕获当前 generation 作为写入屏障；相关保存失败时读取不会静默读取旧文件。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | profile ID。 |
| `context` | 迁移和 provider 应用使用的临时上下文。 |
| `metadata` | 仅写入终态结果的调用方元数据。 |

返回：读取操作句柄；无效请求返回已失败句柄。

结构：

- `context`: Dictionary with caller-defined ephemeral operation data.
- `metadata`: Dictionary with caller-defined result metadata.

<a id="member-gfsaveprofileutility-methods-flush_profile"></a>

### `flush_profile`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func flush_profile( profile_id: StringName, metadata: Dictionary = {} ) -> GFSaveProfileOperation:
```

等待调用时可见的最新 generation 持久化。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | profile ID。 |
| `metadata` | 仅写入终态结果的调用方元数据。 |

返回：flush 操作句柄；没有待保存 generation 时立即成功。

结构：

- `metadata`: Dictionary with caller-defined result metadata.

<a id="member-gfsaveprofileutility-methods-get_persisted_generation"></a>

### `get_persisted_generation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_persisted_generation(profile_id: StringName) -> int:
```

获取已成功持久化的 generation。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | profile ID。 |

返回：未注册或从未保存时返回 0。

<a id="member-gfsaveprofileutility-methods-get_profile_state_snapshot"></a>

### `get_profile_state_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_profile_state_snapshot(profile_id: StringName) -> Dictionary:
```

获取稳定状态机快照。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | profile ID。 |

返回：profile 状态摘要；未注册时为空字典。

结构：

- `return`: Dictionary with profile identity, generation evidence, detached writes, and queue counts.
