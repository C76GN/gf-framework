# 惰性诊断 Provider

`GFDiagnosticSnapshotProvider` 用于采集无法长期缓存、但只应在故障点或支持报告请求时读取的短暂状态。它不是轮询器：注册 Provider、读取目录、普通 `collect_snapshot()` 和 EditorDebugger 刷新都不会执行项目代码。只有调用方显式提交稳定 Provider ID 时才求值。

## 定义与注册

项目为每类状态实现独立 Provider，并返回 `GFDiagnosticProviderResult`。Provider 应同步、只读、快速、有界，不应启动网络请求、修改游戏状态或等待下一帧：

```gdscript
## 显式请求时才读取的路由诊断；采集须同步、只读且有界。
class RouteStateProvider extends GFDiagnosticSnapshotProvider:
	## 由项目导航流程更新的最小诊断状态，不保存面板或账号对象。
	var current_route_id: StringName = &""
	## 当前等待数量，由项目维护；采集回调不主动启动路由查询。
	var pending_route_count: int = 0

	## 投影白名单字段；不在故障采集路径里发起 IO 或修改路由。
	func _collect_snapshot(request: Dictionary = {}) -> GFDiagnosticProviderResult:
		return GFDiagnosticProviderResult.succeeded(
			{
				"route_id": current_route_id,
				"pending_count": pending_route_count,
			},
			{ "reason": GFVariantData.get_option_string_name(request, "reason") }
		)


# 注册表弱持有 Provider；项目须将此引用保留到希望停止提供诊断时。
var provider: RouteStateProvider = RouteStateProvider.new()
var _configured_provider: GFDiagnosticSnapshotProvider = provider.configure(
	&"ui.route_state",
	{
		# 返回后才验收耗时；预算无法抢占正在执行的同步项目代码。
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

总快照把内置批次写入顶层 `diagnostic_providers`。为兼容历史项目，普通快照仍允许同名的已发布自定义分区；只有显式提交非空 `diagnostic_provider_ids` 时，内置批次才在当次结果中确定性优先，且不会注销自定义缓存。

结果按 Provider ID 隔离。不存在、重入、owner 释放、注册表变化、超时或非法输出只会让对应项失败，后续 Provider 仍会执行。批次会分别报告 `requested_count`、`unique_request_count`、`duplicate_count`、`invalid_count` 和真正因上限未执行的 `omitted_count`；重复 ID 只执行一次但不算容量丢失，非法 ID 和超过 `max_diagnostic_providers` 的唯一 ID 则使批次 fail closed。为限制去重本身的工作量，原始 ID 列表最多 1024 项；超限返回 `provider_request_size_exceeded`，且不会执行任何 Provider。

共享 request 会在深复制和任何项目回调执行前，以原始引用通过同一套循环、深度、节点数、集合项数和估算字节预算。预检失败时批次返回 `provider_request_rejected`、`executed_count = 0`，避免递归复制或为每个 Provider 重复复制一个无界输入。

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

## 可复现的数值与性能诊断

项目可以沿用这一注册机制提供调优证据，不必另建通用 GM 服务。Provider 只读取已记录的有界样本，采集时不重新发奖、推进随机数、修改配置、加载资源或执行一次被测业务。

每类样本先明确稳定结构：

| 字段 | 用途 |
|---|---|
| `metric`、`unit` | 稳定指标名及单位，例如 `ui.open.commit` 与 `usec`；单位随记录保存 |
| `source`、`measurement_boundary` | 采样位置、开始/结束事件及是否包含 IO、动画、内容就绪或持久化等待 |
| `config_digest`、`content_version` | 绑定真正参与计算的配置快照，不能填采集报告时恰好最新的一版 |
| `seed`、`random_stream`、`sample_index` | 绑定可重现的随机输入；不要为了获取这些值再消费随机流 |
| `clock_source`、`start`、`end` | 同一时间来源的采样边界；单调耗时与服务器时间估计分开记录 |
| `inputs`、`contributions`、`result` | 白名单输入、各计算步骤及最终数值，保留公式/规则版本与舍入位置 |
| `sample_count`、`omitted_count` | 有限环形样本的覆盖情况；丢弃和未采到的样本不能算作零值 |

这些是项目诊断数据约定，不是 GF 新增的固定报告封套。精确整数与定点值应按现有编码能力保留精度；若导出 JSON 给其他系统，可使用带类型说明的十进制文本，避免大整数被当作浮点数。显示格式和计算值分开，不能把已经缩写成 `1.2K` 的文本作为复算输入。

例如离线收益诊断可以记录：上次已确认的周期 ID、服务器时间估计及不确定度、接受的离线秒数、项目上限、每段产率、倍率、舍入政策和候选结果。是否结算以及何时持久化属于业务事务；诊断 Provider 只能解释已经采用的输入，不能在“查看报告”时推进结算检查点。

测量启动或页面打开时，明确区分资源准备、路由提交、内容就绪与目标定位。保留原始有限样本、冷/热缓存条件、设备/引擎版本和样本数量，再计算中位数与分位数；跨条件均值不能证明优化。配置准备同时记录表数、行数、字段规模、校验/索引/摘要阶段，以及旧快照与候选同时驻留时的内存。同步至少区分持久化意图、远端往返与 checkpoint 确认的耗时和写入次数。

静态资源依赖图可解释已知加载关系，但源文件大小不代表启动时长。真实关键路径需要各步骤的运行时间及等待关系。样本不足、时钟估计过期或计数超预算时输出明确的 unavailable/partial 状态，不用默认值制造完整结论。
