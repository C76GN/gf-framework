# 惰性诊断 Provider

`GFDiagnosticSnapshotProvider` 用于采集无法长期缓存、但只应在故障点或支持报告请求时读取的短暂状态。它不是轮询器：注册 Provider、读取目录、普通 `collect_snapshot()` 和 EditorDebugger 刷新都不会执行项目代码。只有调用方显式提交稳定 Provider ID 时才求值。

## 定义与注册

项目为每类状态实现独立 Provider，并返回 `GFDiagnosticProviderResult`。Provider 应同步、只读、快速、有界，不应启动网络请求、修改游戏状态或等待下一帧：

```gdscript
class RouteStateProvider extends GFDiagnosticSnapshotProvider:
	var current_route_id: StringName = &""
	var pending_route_count: int = 0

	func _collect_snapshot(request: Dictionary = {}) -> GFDiagnosticProviderResult:
		return GFDiagnosticProviderResult.succeeded(
			{
				"route_id": current_route_id,
				"pending_count": pending_route_count,
			},
			{ "reason": GFVariantData.get_option_string_name(request, "reason") }
		)


var provider: RouteStateProvider = RouteStateProvider.new()
var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(
	&"ui.route_state",
	{
		"max_duration_usec": 20_000,
		"metadata": { "domain": &"ui" },
	}
)

if not diagnostics.register_diagnostic_provider(self, provider):
	push_error("诊断 Provider 注册失败。")
```

注册表只弱引用 owner 和 Provider。owner 或 Provider 释放后，条目会被剪枝；同一 ID 只能由当前 owner 更新。注册后 ID、时长预算和目录 metadata 会锁定，避免目录身份与实际执行定义漂移。

## 显式采集

直接采集可以一次请求多个 Provider，也可以把相同选项交给总快照：

```gdscript
var batch: Dictionary = diagnostics.collect_diagnostic_providers(
	PackedStringArray(["ui.route_state", "save.profile_state"]),
	{ "reason": &"support_report" }
)

var snapshot: Dictionary = diagnostics.collect_snapshot({
	"include_monitors": false,
	"diagnostic_provider_ids": PackedStringArray(["ui.route_state"]),
	"diagnostic_provider_request": { "reason": &"route_failure" },
})
```

结果按 Provider ID 隔离。不存在、重入、owner 释放、注册表变化、超时或非法输出只会让对应项失败，后续 Provider 仍会执行。批次会分别报告 `requested_count`、`unique_request_count`、`duplicate_count`、`invalid_count` 和真正因上限未执行的 `omitted_count`；重复 ID 只执行一次但不算容量丢失，非法 ID 和超过 `max_diagnostic_providers` 的唯一 ID 则使批次 fail closed。为限制去重本身的工作量，原始 ID 列表最多 1024 项；超限返回 `provider_request_size_exceeded`，且不会执行任何 Provider。

共享 request 会在任何项目回调执行前通过同一套深度、节点数、集合项数和估算字节预算。预检失败时批次返回 `provider_request_rejected`、`executed_count = 0`，避免为每个 Provider 重复复制一个无界输入。

`max_duration_usec` 是同步回调返回后的验收预算，不是可抢占 timeout。GDScript 回调一旦开始就无法被 GF 安全中止，因此 Provider 自身仍必须保证最坏执行时间；超时结果会被拒绝并记录 `duration_usec`，但已经消耗的主线程时间无法追回。`0` 只用于显式关闭返回后时长拒绝，负数不会被静默归一为 `0`，而会让 Provider 定义校验与注册失败。

## 输出边界

成功值和 metadata 在进入报告前会经过 `GFReportValueCodec`、深度、集合项数和估算字节预算。循环引用、超大集合或其他不合规值会返回稳定失败码，未验收原始值不会进入结果。Provider 主动失败时应使用项目稳定错误码：

```gdscript
return GFDiagnosticProviderResult.failed(
	&"route_state_unavailable",
	"Route state is not available during shutdown."
)
```

失败错误码必须非空、无首尾空白且不超过 128 个字符，否则归一为 `provider_failed`；错误说明最多保留 1024 个字符。该限制只约束诊断结果，不替代项目自己的错误分类表。

GF 只负责技术脱敏和结构预算，无法识别项目自由文本中的账号、令牌或玩家内容。Provider 仍应采用字段白名单，只返回定位当前问题所需的最小状态；上传、用户同意、保留期和访问控制属于项目策略。
