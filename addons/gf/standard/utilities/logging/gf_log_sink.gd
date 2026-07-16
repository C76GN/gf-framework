## GFLogSink: 日志输出 sink 基类。
##
## 项目可以继承该类，把 GFLogUtility 的结构化日志条目写入 JSONL、
## 远端采集、编辑器面板或其他自定义目标。Sink 不拥有日志工具生命周期，
## 只响应 init/write/flush/shutdown 钩子。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFLogSink
extends RefCounted


# --- 公共方法 ---

## 获取该输出边界使用的报告脱敏 profile。
## 未知 sink 默认采用 public；仅本地、受控的诊断 sink 应显式覆盖为 debug。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return GFReportValueCodec REDACTION_PROFILE_* 常量之一。
## [br]
## @schema return: String naming one GFReportValueCodec redaction profile.
func get_report_redaction_profile() -> String:
	return GFReportValueCodec.REDACTION_PROFILE_PUBLIC


## 初始化 sink。
## [br]
## @api public
## [br]
## @param _owner: 持有该 sink 的日志工具。
func init(_owner: Object) -> void:
	pass


## 写入一条结构化日志。
## [br]
## @api public
## [br]
## @param _entry: 日志条目字典。
## [br]
## @schema _entry: Dictionary log entry produced by GFLogUtility.
func write(_entry: Dictionary) -> void:
	pass


## 刷新尚未写出的缓冲。
## [br]
## @api public
func flush() -> void:
	pass


## 关闭 sink 并释放内部资源。
## [br]
## @api public
func shutdown() -> void:
	pass
