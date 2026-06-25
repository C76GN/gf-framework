# Network API

模块：`extensions/network`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 2 | 36 | 23 |
| [协议与扩展点](#category-protocol) | 3 | 28 | 14 |
| [资源定义](#category-resource_definition) | 6 | 74 | 42 |
| [运行时句柄](#category-runtime_handle) | 7 | 87 | 51 |
| [值对象](#category-value_object) | 2 | 24 | 14 |
| [编辑器 API](#category-editor_api) | 1 | 5 | 4 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkDirtyStateTracker`](classes/GFNetworkDirtyStateTracker.md#gfnetworkdirtystatetracker) | `RefCounted` | `addons/gf/extensions/network/session/gf_network_dirty_state_tracker.gd` |
| [`GFNetworkUtility`](classes/GFNetworkUtility.md#gfnetworkutility) | `GFUtility` | `addons/gf/extensions/network/runtime/gf_network_utility.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkBackend`](classes/GFNetworkBackend.md#gfnetworkbackend) | `RefCounted` | `addons/gf/extensions/network/backends/gf_network_backend.gd` |
| [`GFNetworkMessageValidator`](classes/GFNetworkMessageValidator.md#gfnetworkmessagevalidator) | `RefCounted` | `addons/gf/extensions/network/messages/gf_network_message_validator.gd` |
| [`GFNetworkSerializer`](classes/GFNetworkSerializer.md#gfnetworkserializer) | `RefCounted` | `addons/gf/extensions/network/serialization/gf_network_serializer.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkChannel`](classes/GFNetworkChannel.md#gfnetworkchannel) | `Resource` | `addons/gf/extensions/network/session/gf_network_channel.gd` |
| [`GFNetworkContract`](classes/GFNetworkContract.md#gfnetworkcontract) | `Resource` | `addons/gf/extensions/network/contracts/gf_network_contract.gd` |
| [`GFNetworkContractField`](classes/GFNetworkContractField.md#gfnetworkcontractfield) | `Resource` | `addons/gf/extensions/network/contracts/gf_network_contract_field.gd` |
| [`GFNetworkContractMessage`](classes/GFNetworkContractMessage.md#gfnetworkcontractmessage) | `Resource` | `addons/gf/extensions/network/contracts/gf_network_contract_message.gd` |
| [`GFNetworkFieldSerializer`](classes/GFNetworkFieldSerializer.md#gfnetworkfieldserializer) | `Resource` | `addons/gf/extensions/network/serialization/gf_network_field_serializer.gd` |
| [`GFNetworkSnapshotSchema`](classes/GFNetworkSnapshotSchema.md#gfnetworksnapshotschema) | `Resource` | `addons/gf/extensions/network/snapshot/gf_network_snapshot_schema.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFENetNetworkBackend`](classes/GFENetNetworkBackend.md#gfenetnetworkbackend) | `GFNetworkBackend` | `addons/gf/extensions/network/backends/gf_enet_network_backend.gd` |
| [`GFFixedTickClock`](classes/GFFixedTickClock.md#gffixedtickclock) | `RefCounted` | `addons/gf/extensions/network/simulation/gf_fixed_tick_clock.gd` |
| [`GFNetworkHistoryBuffer`](classes/GFNetworkHistoryBuffer.md#gfnetworkhistorybuffer) | `RefCounted` | `addons/gf/extensions/network/snapshot/gf_network_history_buffer.gd` |
| [`GFNetworkRateLimiter`](classes/GFNetworkRateLimiter.md#gfnetworkratelimiter) | `RefCounted` | `addons/gf/extensions/network/session/gf_network_rate_limiter.gd` |
| [`GFNetworkReconnectPolicy`](classes/GFNetworkReconnectPolicy.md#gfnetworkreconnectpolicy) | `RefCounted` | `addons/gf/extensions/network/session/gf_network_reconnect_policy.gd` |
| [`GFNetworkSession`](classes/GFNetworkSession.md#gfnetworksession) | `RefCounted` | `addons/gf/extensions/network/session/gf_network_session.gd` |
| [`GFWebSocketNetworkBackend`](classes/GFWebSocketNetworkBackend.md#gfwebsocketnetworkbackend) | `GFNetworkBackend` | `addons/gf/extensions/network/backends/gf_websocket_network_backend.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkMessage`](classes/GFNetworkMessage.md#gfnetworkmessage) | `RefCounted` | `addons/gf/extensions/network/messages/gf_network_message.gd` |
| [`GFNetworkSnapshot`](classes/GFNetworkSnapshot.md#gfnetworksnapshot) | `RefCounted` | `addons/gf/extensions/network/snapshot/gf_network_snapshot.gd` |

<a id="category-editor_api"></a>

### 编辑器 API

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkContractGenerator`](classes/GFNetworkContractGenerator.md#gfnetworkcontractgenerator) | `RefCounted` | `addons/gf/extensions/network/editor/gf_network_contract_generator.gd` |
