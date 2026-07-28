# GFStorageFailoverBackend

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_failover_backend.gd`
- 模块：`Standard`
- 继承：`GFStorageBackend`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`10.0.0`

有序存储故障转移后端。 该组合后端按稳定 ID 管理一组调用方持有的 `GFStorageBackend`。读取总是按序 尝试，写入和删除可选择只访问主后端或在失败后访问下一后端。它不会复制、 同步或关闭子后端，也不宣称跨后端原子性；需要镜像和冲突处理时应使用 `GFStorageSyncUtility`。每次操作都会保留一个不含业务数据的有界尝试报告。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`MutationPolicy`](#member-gfstoragefailoverbackend-enums-mutationpolicy) | `enum MutationPolicy` |
| 方法 | [`configure_backends`](#member-gfstoragefailoverbackend-methods-configure_backends) | `func configure_backends( backends: Array[GFStorageBackend], backend_ids: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> bool:` |
| 方法 | [`set_clock`](#member-gfstoragefailoverbackend-methods-set_clock) | `func set_clock(clock: GFClock) -> bool:` |
| 方法 | [`get_backend_count`](#member-gfstoragefailoverbackend-methods-get_backend_count) | `func get_backend_count() -> int:` |
| 方法 | [`get_backend_ids`](#member-gfstoragefailoverbackend-methods-get_backend_ids) | `func get_backend_ids() -> PackedStringArray:` |
| 方法 | [`get_last_operation_report`](#member-gfstoragefailoverbackend-methods-get_last_operation_report) | `func get_last_operation_report() -> Dictionary:` |
| 方法 | [`get_health_snapshot`](#member-gfstoragefailoverbackend-methods-get_health_snapshot) | `func get_health_snapshot() -> Dictionary:` |
| 方法 | [`reset_backend_health`](#member-gfstoragefailoverbackend-methods-reset_backend_health) | `func reset_backend_health(backend_id: StringName = &"") -> bool:` |
| 方法 | [`_initialize`](#member-gfstoragefailoverbackend-methods-_initialize) | `func _initialize(config: Dictionary) -> Error:` |
| 方法 | [`_shutdown`](#member-gfstoragefailoverbackend-methods-_shutdown) | `func _shutdown() -> void:` |
| 方法 | [`_save_data`](#member-gfstoragefailoverbackend-methods-_save_data) | `func _save_data(file_name: String, data: Dictionary, metadata: Dictionary) -> Error:` |
| 方法 | [`_load_data`](#member-gfstoragefailoverbackend-methods-_load_data) | `func _load_data(file_name: String) -> Dictionary:` |
| 方法 | [`_delete_data`](#member-gfstoragefailoverbackend-methods-_delete_data) | `func _delete_data(file_name: String) -> Error:` |
| 方法 | [`_has_data`](#member-gfstoragefailoverbackend-methods-_has_data) | `func _has_data(file_name: String) -> bool:` |
| 方法 | [`_list_data`](#member-gfstoragefailoverbackend-methods-_list_data) | `func _list_data() -> Array[Dictionary]:` |
| 方法 | [`_get_capabilities`](#member-gfstoragefailoverbackend-methods-_get_capabilities) | `func _get_capabilities() -> Dictionary:` |

## 枚举

<a id="member-gfstoragefailoverbackend-enums-mutationpolicy"></a>

### `MutationPolicy`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
enum MutationPolicy {
	## 只访问第一个配置后端，错误原样返回。
	PRIMARY_ONLY,
	## 按顺序尝试，首次成功后立即停止。
	FIRST_SUCCESS,
}
```

写入和删除的后端选择策略。

## 方法

<a id="member-gfstoragefailoverbackend-methods-configure_backends"></a>

### `configure_backends`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure_backends( backends: Array[GFStorageBackend], backend_ids: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> bool:
```

原子替换有序子后端及其稳定 ID。 子后端由调用方持有和管理生命周期；同一实例或同一 ID 不能重复注册。 配置失败时保留原配置。健康熔断只统计明确的暂时性 Godot Error。 `failure_threshold` 或 `cooldown_msec` 为 0 时关闭冷却跳过。

参数：

| 名称 | 说明 |
|---|---|
| `backends` | 按优先级从高到低排列的子后端，数量限制为 1 至 32。 |
| `backend_ids` | 与子后端一一对应的稳定 ID；为空时生成 backend_0 等 ID。 |
| `options` | mutation_policy、failure_threshold（0 至 1000）和 cooldown_msec（0 至 86400000）；非法类型或范围会使配置整体失败。 |

返回：配置合法并完成替换时返回 true。

结构：

- `options`: Dictionary，包含 mutation_policy: MutationPolicy、failure_threshold: int 和 cooldown_msec: int。

<a id="member-gfstoragefailoverbackend-methods-set_clock"></a>

### `set_clock`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_clock(clock: GFClock) -> bool:
```

注入用于冷却窗口的单调时钟。 时钟域变化时会清空既有失败计数和冷却截止时间，避免用新时钟解释旧时间戳。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 系统、测试或模拟时钟。 |

返回：非空时钟设置成功返回 true。

<a id="member-gfstoragefailoverbackend-methods-get_backend_count"></a>

### `get_backend_count`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_backend_count() -> int:
```

返回当前子后端数量。

返回：已配置子后端数量。

<a id="member-gfstoragefailoverbackend-methods-get_backend_ids"></a>

### `get_backend_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_backend_ids() -> PackedStringArray:
```

返回有序稳定后端 ID 副本。

返回：与子后端顺序一致的稳定 ID。

<a id="member-gfstoragefailoverbackend-methods-get_last_operation_report"></a>

### `get_last_operation_report`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_last_operation_report() -> Dictionary:
```

返回最近一次操作的结构化尝试报告。 报告最多包含 32 个尝试项，不包含读写业务载荷或后端私有元数据。

返回：报告深拷贝；尚未执行操作时返回空字典。

结构：

- `return`: Dictionary，包含 schema_version、operation、file_name、ok、selected_backend_id、error_code、error、attempt_count、skipped_count、attempts 和 timestamp_msec；每个 attempt 包含 backend_id、backend_index、capability、status、reason、error_code、error、consecutive_failures 和 cooldown_until_msec。

<a id="member-gfstoragefailoverbackend-methods-get_health_snapshot"></a>

### `get_health_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_health_snapshot() -> Dictionary:
```

返回后端健康与冷却状态快照。

返回：配置和逐后端健康状态，不包含业务数据。

结构：

- `return`: Dictionary，包含 mutation_policy、failure_threshold、cooldown_msec、backend_count 和 backends；每个 backend 包含 backend_id、backend_index、consecutive_failures、cooldown_until_msec 和 cooling_down。

<a id="member-gfstoragefailoverbackend-methods-reset_backend_health"></a>

### `reset_backend_health`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func reset_backend_health(backend_id: StringName = &"") -> bool:
```

重置一个或全部后端的失败计数与冷却窗口。

参数：

| 名称 | 说明 |
|---|---|
| `backend_id` | 目标稳定 ID；为空时重置全部后端。 |

返回：至少重置一个已配置后端时返回 true。

<a id="member-gfstoragefailoverbackend-methods-_initialize"></a>

### `_initialize`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _initialize(config: Dictionary) -> Error:
```

校验组合后端已配置，并应用故障转移选项；不初始化子后端。

参数：

| 名称 | 说明 |
|---|---|
| `config` | mutation_policy、failure_threshold（0 至 1000）和 cooldown_msec（0 至 86400000）。 |

返回：已配置且选项合法时返回 OK；未配置返回 ERR_UNCONFIGURED，非法选项返回 ERR_INVALID_PARAMETER。

结构：

- `config`: Dictionary，包含 mutation_policy: MutationPolicy、failure_threshold: int 和 cooldown_msec: int。

<a id="member-gfstoragefailoverbackend-methods-_shutdown"></a>

### `_shutdown`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _shutdown() -> void:
```

清空运行期报告和健康状态；不关闭调用方持有的子后端。

<a id="member-gfstoragefailoverbackend-methods-_save_data"></a>

### `_save_data`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _save_data(file_name: String, data: Dictionary, metadata: Dictionary) -> Error:
```

按当前 mutation_policy 保存数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `data` | 业务数据副本。 |
| `metadata` | 元数据副本。 |

返回：首次成功时返回 OK，否则返回最后一个可观察错误。

结构：

- `data`: Dictionary，调用方业务数据。
- `metadata`: Dictionary，后端特定元数据。

<a id="member-gfstoragefailoverbackend-methods-_load_data"></a>

### `_load_data`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _load_data(file_name: String) -> Dictionary:
```

按顺序读取首个成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |

返回：首个成功子后端结果或聚合失败结果。

结构：

- `return`: Dictionary，包含 ok、data、metadata、error 和 error_code。

<a id="member-gfstoragefailoverbackend-methods-_delete_data"></a>

### `_delete_data`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _delete_data(file_name: String) -> Error:
```

按当前 mutation_policy 删除数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |

返回：首次成功时返回 OK，否则返回最后一个可观察错误。

<a id="member-gfstoragefailoverbackend-methods-_has_data"></a>

### `_has_data`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _has_data(file_name: String) -> bool:
```

按顺序检查任一可读后端是否包含数据。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |

返回：任一可读后端存在数据时返回 true。

<a id="member-gfstoragefailoverbackend-methods-_list_data"></a>

### `_list_data`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _list_data() -> Array[Dictionary]:
```

从首个支持枚举且未冷却的后端读取文件摘要。

返回：首个可用后端的文件摘要。

结构：

- `return`: Array，包含 file_name 和可选 metadata 的 Dictionary 条目。

<a id="member-gfstoragefailoverbackend-methods-_get_capabilities"></a>

### `_get_capabilities`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _get_capabilities() -> Dictionary:
```

汇总组合后端能力。

返回：read、write、delete、list 和 sync 能力。

结构：

- `return`: Dictionary，包含 read、write、delete、list 和 sync 布尔能力标记。
