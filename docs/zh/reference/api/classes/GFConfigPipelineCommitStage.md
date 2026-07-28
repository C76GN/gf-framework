# GFConfigPipelineCommitStage

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_commit_stage.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`9.0.0`

Config Pipeline 的文件提交事务阶段。 将 Config Pipeline 的 ResourceSaver 等专用写入器接到框架级 GFArtifactWriteTransaction。该阶段不复制事务实现、不解释产物内容， 也不决定输出路径策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STAGE_ID`](#member-gfconfigpipelinecommitstage-constants-stage_id) | `const STAGE_ID: String = "gf.config.commit.filesystem"` |
| 常量 | [`IMPLEMENTATION_VERSION`](#member-gfconfigpipelinecommitstage-constants-implementation_version) | `const IMPLEMENTATION_VERSION: int = 3` |
| 方法 | [`begin`](#member-gfconfigpipelinecommitstage-methods-begin) | `func begin( paths: PackedStringArray, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`rollback`](#member-gfconfigpipelinecommitstage-methods-rollback) | `func rollback(transaction: Dictionary) -> Dictionary:` |
| 方法 | [`complete`](#member-gfconfigpipelinecommitstage-methods-complete) | `func complete(transaction: Dictionary) -> Dictionary:` |
| 方法 | [`get_stage_descriptor`](#member-gfconfigpipelinecommitstage-methods-get_stage_descriptor) | `func get_stage_descriptor() -> Dictionary:` |

## 常量

<a id="member-gfconfigpipelinecommitstage-constants-stage_id"></a>

### `STAGE_ID`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const STAGE_ID: String = "gf.config.commit.filesystem"
```

Commit 阶段的稳定实现标识。

<a id="member-gfconfigpipelinecommitstage-constants-implementation_version"></a>

### `IMPLEMENTATION_VERSION`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const IMPLEMENTATION_VERSION: int = 3
```

Commit 阶段的实现版本；改变事务或回滚语义时递增。

## 方法

<a id="member-gfconfigpipelinecommitstage-methods-begin"></a>

### `begin`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func begin( paths: PackedStringArray, options: Dictionary = {} ) -> Dictionary:
```

捕获待写入路径的事务前状态。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 本次事务可能创建或覆盖的完整路径集合。 |
| `options` | 框架级事务预算与允许根选项。 |

返回：只能原样交给 complete() 或 rollback() 的 GFArtifactWriteTransaction 事务。

结构：

- `options`: Dictionary，必须包含非空 allowed_roots；可包含 max_file_count、max_backup_bytes 和 metadata。
- `return`: Dictionary，符合 gf.artifact_write.transaction@1，包含 ok、format、format_version、state、entries、backup_bytes、issues 和 metadata。

<a id="member-gfconfigpipelinecommitstage-methods-rollback"></a>

### `rollback`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func rollback(transaction: Dictionary) -> Dictionary:
```

逆序恢复事务前状态；已存在文件恢复快照，事务中新建文件被删除。

参数：

| 名称 | 说明 |
|---|---|
| `transaction` | begin() 返回且仍处于 open 状态的原始事务字典。 |

返回：回滚结果。

结构：

- `transaction`: Dictionary，符合 gf.artifact_write.transaction@1。
- `return`: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction。

<a id="member-gfconfigpipelinecommitstage-methods-complete"></a>

### `complete`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func complete(transaction: Dictionary) -> Dictionary:
```

完成事务并删除全部回滚快照。

参数：

| 名称 | 说明 |
|---|---|
| `transaction` | begin() 返回且仍处于 open 状态的原始事务字典。 |

返回：提交完成结果。

结构：

- `transaction`: Dictionary，符合 gf.artifact_write.transaction@1。
- `return`: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction。

<a id="member-gfconfigpipelinecommitstage-methods-get_stage_descriptor"></a>

### `get_stage_descriptor`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_stage_descriptor() -> Dictionary:
```

返回阶段实现的稳定描述，用于流水线诊断和编译指纹。

返回：阶段描述。

结构：

- `return`: Dictionary，包含 stage_id、implementation_version、input_contract 和 output_contract。
