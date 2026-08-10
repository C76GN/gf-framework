# Network 契约、生成器与重连策略

这一页说明如何用契约资源声明消息类型、payload 字段、生成辅助类，并用重连策略统一退避间隔。契约只约束消息结构，不定义房间、鉴权、服务器权威或玩法语义。

## 消息契约

当项目希望减少手写 `message_type` 和 payload 字段名时，可以用 `GFNetworkContract` 描述一组消息契约。单条消息由 `GFNetworkContractMessage` 声明 `message_type`、默认 `channel_id` 和字段列表；字段由 `GFNetworkContractField` 声明名称、值类型、必填性、默认值和可选类名提示。

```gdscript
var slot := GFNetworkContractField.new()
slot.field_name = &"slot"
slot.value_type = GFNetworkContractField.ValueType.INT

var ready := GFNetworkContractMessage.new()
ready.message_type = &"player_ready"
ready.channel_id = &"lobby"
ready.fields = [slot]

var contract := GFNetworkContract.new()
contract.contract_id = &"lobby"
contract.messages = [ready]

var message := contract.make_message(&"player_ready", { &"slot": 1 })
var report := contract.validate_message(message)
```

`validate_contract()`、`validate_message()`、`GFNetworkContractMessage.validate_payload()` 和 `GFNetworkContractField.validate_value()` 都返回标准校验报告字典。字段名、消息类型和契约 ID 只作为附加上下文保留，便于生成器、编辑器面板、CI 和项目工具复用同一套诊断展示逻辑。

网络契约只接受 transport-safe 值类型。`GFNetworkContractField.ValueType.OBJECT` 会被定义校验拒绝；非 `null` 的 `default_value` 也必须精确匹配声明的 `value_type`，并通过同一套深度、节点、循环和有限数校验。需要传输对象关系时，应先转换成稳定 ID、资源键、网络实体 ID 或项目自定义 DTO，再在接收端解析。`allow_null=true` 表示显式传入的 `null` 必须保留；它不会再被非空默认值替换，只有真正省略字段时才应用默认值。

`GFNetworkMessageValidator` 可以进入更严格的 fail-closed 模式。项目可用 `configure_from_contract()` 从契约同步允许的 `message_type` 和默认通道，再打开 `require_contract_message`、`require_sender_id` 或 `enforce_sender_id_matches_peer`。入站消息在 `GFNetworkUtility` 中会以 backend 报告的真实 `peer_id` 参与校验，避免信任 payload 自带 sender。

```gdscript
var validator := GFNetworkMessageValidator.new()
validator.configure_from_contract(contract)
validator.require_contract_message = true
validator.require_sender_id = true
validator.enforce_sender_id_matches_peer = true

var report := validator.validate_message_for_peer(message, peer_id)
```

契约资源还可以声明 `contract_version_major` 和 `contract_version_minor`。大版本用于项目在连接、房间加入、热更新切换或工具流水线中判断双方是否仍使用兼容的消息结构；小版本默认只用于日志、排查或构建追踪。`get_schema_descriptor()` 会导出不含展示名和 metadata 的纯结构描述，`get_schema_digest()` 使用确定性 Variant 编码生成稳定 SHA-256，`get_contract_version()` 会把契约 ID、版本号和 schema digest 合并成可传输字典。

```gdscript
contract.contract_version_major = 2
contract.contract_version_minor = 20260308

var local_version := contract.get_contract_version()
var report := contract.validate_peer_contract_version(peer_version, {
	"require_schema_digest": true,
})
```

`validate_peer_contract_version()` 只输出标准校验报告，不负责断开连接、弹窗、重连或限制操作。是否只比较大版本、是否强制 schema digest、失败后如何处理，都应由项目的连接协议或发布策略决定。

## 辅助类生成

`GFNetworkContractGenerator` 可把契约资源生成 GDScript 辅助类，提供强类型构造、发送、匹配和字段读取函数。生成器不会扫描或推断项目业务协议；需要生成哪些契约由项目显式配置。

```gdscript
var generator := GFNetworkContractGenerator.new()
generator.generate(contract, "res://generated/network/lobby_network_messages.gd", true, {
	"class_name": "LobbyNetworkMessages",
})

var report := generator.generate_with_report(contract, "res://generated/network/lobby_network_messages.gd", {
	"class_name": "LobbyNetworkMessages",
	"overwrite_existing": false,
})

var typed_message := LobbyNetworkMessages.make_player_ready(1)
LobbyNetworkMessages.send_player_ready(network, -1, 1)
```

生成脚本只是项目侧便捷层；底层仍然发送普通 `GFNetworkMessage`，也仍然遵守项目注册的 `GFNetworkChannel`、serializer、validator 和 backend。生成脚本会携带 `CONTRACT_ID`、`CONTRACT_VERSION_MAJOR`、`CONTRACT_VERSION_MINOR`、`CONTRACT_SCHEMA_DIGEST` 和同形状的 `get_contract_version()` / `validate_peer_contract_version()`；两条版本预检路径委托同一个纯值校验器，报告字段和 issue 语义不会各自漂移。没有默认值的可选字段会把 `null` 视为“未提供”，默认不写入 payload；如果确实需要显式发送 null，可在 options 中传入 `{ "include_null_optional_fields": true }`。允许 null 且具有非空默认值的具体类型字段会生成 `Variant` 参数：省略参数使用默认值，显式传入 `null` 则保留 null。Dictionary、Array 和其 transport-safe 嵌套值会生成完整、稳定排序且可编译的字面量，不再回落为空容器。

需要批量生成、dry-run 或编辑器诊断时，优先使用 `generate_with_report()`、`save_source_with_report()` 或 `generate_many()` 返回的产物报告。`generate_many()` 会先加载并校验整个输入批次、分配唯一的大小写不敏感 canonical 输出路径、构建全部源码，再进入任何写入；共享 `class_name`、清洗后同名、任一无效契约或生成预算超限都会使批次保持零写入。dry-run 与真实提交共享同一个计划，报告中的 `plan_fingerprint` 可用于确认两次输入、路径和内容一致。调用方可以用 `max_contracts`、`max_messages_per_contract`、`max_fields_per_message`、`max_identifier_length`、`max_source_bytes` 和 `max_total_source_bytes` 收紧默认预算，所有值必须是正整数且不能突破框架硬上限。

`overwrite_existing=false` 且目标文件已有不同内容时仍会得到 `skipped` 状态；这不是生成器失败，但报告保留 `ERR_ALREADY_EXISTS`，调用方可按项目策略决定是否阻断流水线。`generate_many()` 还会返回 `artifact_summary` 和 `artifact_reports`，用于统计实际写入、跳过、失败和路径列表。当前批次只保证“进入写入前的计划完整性”，多个文件的保存仍是逐项原子替换，不承诺整个批次在不可预期 I/O 故障下自动回滚；要求 all-or-nothing 的项目流水线应在外层使用受控事务根并把失败视为需要恢复的终态。

## 契约审计

`GFNetworkContractAudit` 是 Network 编辑器工具包中的只读审计器。它不会修改契约资源或生成源码，只返回标准校验报告。审计会提示缺少 contract ID、版本缺失、消息过多、未知通道、无字段消息、过宽 `Variant` 字段和需要人工核对边界的集合字段等风险。GF 不解释项目自有 `metadata`，因此 `collection_bounds_review_required` 不会声称某个未执行的 bounds schema 已经满足；项目必须在自己的 schema、serializer 或入站 validator 中落实可执行限制，确认已有独立 gate 后才关闭 `warn_collection_bounds_review`。

```gdscript
var audit := GFNetworkContractAudit.new()
var report := audit.audit_contract(contract, {
	"known_channel_ids": PackedStringArray(["reliable", "state"]),
	"require_channel_ids": true,
	"warn_collection_bounds_review": true,
	"max_known_channel_ids": 64,
	"max_fields_per_message": 16,
})
```

编辑器菜单中的 Network Contract 审计会读取 `gf/network/contract_paths`，对配置的契约资源生成诊断报告。`audit_paths()` 会对词法规范路径去重，并为每条聚合 issue 保留 `resource_path`、原始 `phase` 和 `aggregation_phase`，因此相同 `contract_id` 的不同资源仍可定位。`max_contract_paths`、`max_known_channel_ids` 和 `max_channel_id_length` 为同步编辑器入口提供可收紧预算，内部集合去重保持线性复杂度。CI 或项目工具也可以直接调用审计器，把高风险网络契约问题提前挡在运行前。

## 重连策略

需要断线重连时，可以让项目后端使用 `GFNetworkReconnectPolicy` 统一退避间隔和尝试次数。它只返回下一次等待多少毫秒，不负责打开 socket、鉴权、频道恢复或 presence 语义。

```gdscript
var reconnect := GFNetworkReconnectPolicy.new()
reconnect.delays_msec = [500, 1000, 2000, 5000]
reconnect.max_attempts = 0

var delay_msec := reconnect.get_next_delay_msec()
if delay_msec >= 0:
	# 项目后端自行安排 timer 后再次 connect。
	pass
```

## 使用边界

项目层应在后端中处理连接、鉴权、重连、可靠性、频道和平台差异；GF 层只提供稳定的消息载体、序列化、消息大小/结构校验、会话快照和可替换边界。

从 `2.0.0` 起，`GFNetworkMessageValidator.max_packet_size` 默认使用 `64 KiB`。需要传输更大快照或自定义分片协议时应显式调大，或设为 `0` 关闭全局上限；高频通道仍建议配置更小的 `GFNetworkChannel.max_packet_size`。
