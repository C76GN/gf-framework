## GFConfigPipelineCommitStage: Config Pipeline 的文件提交事务阶段。
##
## 将 Config Pipeline 的 ResourceSaver 等专用写入器接到框架级
## GFArtifactWriteTransaction。该阶段不复制事务实现、不解释产物内容，
## 也不决定输出路径策略。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFConfigPipelineCommitStage
extends RefCounted


# --- 常量 ---

## Commit 阶段的稳定实现标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const STAGE_ID: String = "gf.config.commit.filesystem"

## Commit 阶段的实现版本；改变事务或回滚语义时递增。
## [br]
## @api public
## [br]
## @since 9.0.0
const IMPLEMENTATION_VERSION: int = 3

const _TRANSACTION_FORMAT: String = "gf.artifact_write.transaction"
const _TRANSACTION_VERSION: int = 1
const _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_artifact_write_transaction.gd"
)


# --- 公共方法 ---

## 捕获待写入路径的事务前状态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param paths: 本次事务可能创建或覆盖的完整路径集合。
## [br]
## @param options: 框架级事务预算与允许根选项。
## [br]
## @return: 只能原样交给 complete() 或 rollback() 的 GFArtifactWriteTransaction 事务。
## [br]
## @schema options: Dictionary，必须包含非空 allowed_roots；可包含 max_file_count、max_backup_bytes 和 metadata。
## [br]
## @schema return: Dictionary，符合 gf.artifact_write.transaction@1，包含 ok、format、format_version、state、entries、backup_bytes、issues 和 metadata。
func begin(
	paths: PackedStringArray,
	options: Dictionary = {}
) -> Dictionary:
	return _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.begin(paths, options)


## 逆序恢复事务前状态；已存在文件恢复快照，事务中新建文件被删除。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param transaction: begin() 返回且仍处于 open 状态的原始事务字典。
## [br]
## @schema transaction: Dictionary，符合 gf.artifact_write.transaction@1。
## [br]
## @return: 回滚结果。
## [br]
## @schema return: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction。
func rollback(transaction: Dictionary) -> Dictionary:
	return _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.rollback(transaction)


## 完成事务并删除全部回滚快照。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param transaction: begin() 返回且仍处于 open 状态的原始事务字典。
## [br]
## @schema transaction: Dictionary，符合 gf.artifact_write.transaction@1。
## [br]
## @return: 提交完成结果。
## [br]
## @schema return: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction。
func complete(transaction: Dictionary) -> Dictionary:
	return _GF_ARTIFACT_WRITE_TRANSACTION_SCRIPT.complete(transaction)


## 返回阶段实现的稳定描述，用于流水线诊断和编译指纹。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 阶段描述。
## [br]
## @schema return: Dictionary，包含 stage_id、implementation_version、implementation_dependencies、input_contract 和 output_contract。
func get_stage_descriptor() -> Dictionary:
	return {
		"stage_id": STAGE_ID,
		"implementation_version": IMPLEMENTATION_VERSION,
		"implementation_dependencies": [
			"res://addons/gf/kernel/editor/gf_artifact_write_transaction.gd",
		],
		"input_contract": "PackedStringArray",
		"output_contract": "%s@%d" % [_TRANSACTION_FORMAT, _TRANSACTION_VERSION],
	}
