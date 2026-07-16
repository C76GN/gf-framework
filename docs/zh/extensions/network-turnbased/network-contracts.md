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

网络契约只接受 transport-safe 值类型。`GFNetworkContractField.ValueType.OBJECT` 会被定义校验拒绝；需要传输对象关系时，应先转换成稳定 ID、资源键、网络实体 ID 或项目自定义 DTO，再在接收端解析。

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
generator.generate(contract, "res://gf/generated/network/lobby_network_messages.gd", true, {
	"class_name": "LobbyNetworkMessages",
})

var report := generator.generate_with_report(contract, "res://gf/generated/network/lobby_network_messages.gd", {
	"class_name": "LobbyNetworkMessages",
	"overwrite_existing": false,
})

var typed_message := LobbyNetworkMessages.make_player_ready(1)
LobbyNetworkMessages.send_player_ready(network, -1, 1)
```

生成脚本只是项目侧便捷层；底层仍然发送普通 `GFNetworkMessage`，也仍然遵守项目注册的 `GFNetworkChannel`、serializer、validator 和 backend。生成脚本会携带 `CONTRACT_ID`、`CONTRACT_VERSION_MAJOR`、`CONTRACT_VERSION_MINOR`、`CONTRACT_SCHEMA_DIGEST` 和同形状的 `get_contract_version()` / `validate_peer_contract_version()`，因此运行时可以不加载原始契约资源也能做轻量预检。没有默认值的可选字段会把 `null` 视为“未提供”，默认不写入 payload；如果确实需要显式发送 null，可在 options 中传入 `{ "include_null_optional_fields": true }`。

需要批量生成、dry-run 或编辑器诊断时，优先使用 `generate_with_report()`、`save_source_with_report()` 或 `generate_many()` 返回的产物报告。`overwrite_existing=false` 且目标文件已有不同内容时会得到 `skipped` 状态；这不是生成器失败，但报告仍保留 `ERR_ALREADY_EXISTS`，调用方可按项目策略决定是否阻断流水线。`generate_many()` 会额外返回 `artifact_summary` 和 `artifact_reports`，用于统计实际写入、跳过、失败和路径列表。

## 契约审计

`GFNetworkContractAudit` 是 Network 编辑器工具包中的只读审计器。它不会修改契约资源或生成源码，只返回标准校验报告。审计会提示缺少 contract ID、版本缺失、消息过多、未知通道、无字段消息、过宽 `Variant` 字段和未约束集合字段等风险。

```gdscript
var audit := GFNetworkContractAudit.new()
var report := audit.audit_contract(contract, {
	"known_channel_ids": PackedStringArray(["reliable", "state"]),
	"require_channel_ids": true,
	"max_fields_per_message": 16,
})
```

编辑器菜单中的 Network Contract 审计会读取 `gf/network/contract_paths`，对配置的契约资源生成诊断报告。CI 或项目工具也可以直接调用审计器，把 High-risk 网络契约问题提前挡在运行前。

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
