# Network API

模块：`extensions/network`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 4 | 89 | 52 |
| [协议与扩展点](#category-protocol) | 5 | 78 | 43 |
| [资源定义](#category-resource_definition) | 6 | 80 | 46 |
| [运行时句柄](#category-runtime_handle) | 8 | 108 | 66 |
| [值对象](#category-value_object) | 8 | 110 | 58 |
| [事件契约](#category-event_contract) | 1 | 11 | 4 |
| [编辑器 API](#category-editor_api) | 2 | 9 | 8 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkDirtyStateTracker`](classes/GFNetworkDirtyStateTracker.md#gfnetworkdirtystatetracker) | `RefCounted` | `addons/gf/extensions/network/session/gf_network_dirty_state_tracker.gd` |
| [`GFNetworkLobbyService`](classes/GFNetworkLobbyService.md#gfnetworklobbyservice) | `GFUtility` | `addons/gf/extensions/network/session/gf_network_lobby_service.gd` |
| [`GFNetworkSyncCoordinator`](classes/GFNetworkSyncCoordinator.md#gfnetworksynccoordinator) | `RefCounted` | `addons/gf/extensions/network/simulation/gf_network_sync_coordinator.gd` |
| [`GFNetworkUtility`](classes/GFNetworkUtility.md#gfnetworkutility) | `GFUtility` | `addons/gf/extensions/network/runtime/gf_network_utility.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkBackend`](classes/GFNetworkBackend.md#gfnetworkbackend) | `RefCounted` | `addons/gf/extensions/network/backends/gf_network_backend.gd` |
| [`GFNetworkLobbyBackend`](classes/GFNetworkLobbyBackend.md#gfnetworklobbybackend) | `RefCounted` | `addons/gf/extensions/network/session/gf_network_lobby_backend.gd` |
| [`GFNetworkMessageValidator`](classes/GFNetworkMessageValidator.md#gfnetworkmessagevalidator) | `RefCounted` | `addons/gf/extensions/network/messages/gf_network_message_validator.gd` |
| [`GFNetworkSerializer`](classes/GFNetworkSerializer.md#gfnetworkserializer) | `RefCounted` | `addons/gf/extensions/network/serialization/gf_network_serializer.gd` |
| [`GFNetworkSimulationAdapter`](classes/GFNetworkSimulationAdapter.md#gfnetworksimulationadapter) | `RefCounted` | `addons/gf/extensions/network/simulation/gf_network_simulation_adapter.gd` |

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
| [`GFNetworkServiceDiscovery`](classes/GFNetworkServiceDiscovery.md#gfnetworkservicediscovery) | `RefCounted` | `addons/gf/extensions/network/session/gf_network_service_discovery.gd` |
| [`GFNetworkSession`](classes/GFNetworkSession.md#gfnetworksession) | `RefCounted` | `addons/gf/extensions/network/session/gf_network_session.gd` |
| [`GFWebSocketNetworkBackend`](classes/GFWebSocketNetworkBackend.md#gfwebsocketnetworkbackend) | `GFNetworkBackend` | `addons/gf/extensions/network/backends/gf_websocket_network_backend.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkInputFrame`](classes/GFNetworkInputFrame.md#gfnetworkinputframe) | `RefCounted` | `addons/gf/extensions/network/simulation/gf_network_input_frame.gd` |
| [`GFNetworkLobbyDescriptor`](classes/GFNetworkLobbyDescriptor.md#gfnetworklobbydescriptor) | `Resource` | `addons/gf/extensions/network/session/gf_network_lobby_descriptor.gd` |
| [`GFNetworkLobbyJoinResult`](classes/GFNetworkLobbyJoinResult.md#gfnetworklobbyjoinresult) | `RefCounted` | `addons/gf/extensions/network/session/gf_network_lobby_join_result.gd` |
| [`GFNetworkLobbyMember`](classes/GFNetworkLobbyMember.md#gfnetworklobbymember) | `Resource` | `addons/gf/extensions/network/session/gf_network_lobby_member.gd` |
| [`GFNetworkLobbyQuery`](classes/GFNetworkLobbyQuery.md#gfnetworklobbyquery) | `Resource` | `addons/gf/extensions/network/session/gf_network_lobby_query.gd` |
| [`GFNetworkMessage`](classes/GFNetworkMessage.md#gfnetworkmessage) | `RefCounted` | `addons/gf/extensions/network/messages/gf_network_message.gd` |
| [`GFNetworkPeerIdentity`](classes/GFNetworkPeerIdentity.md#gfnetworkpeeridentity) | `Resource` | `addons/gf/extensions/network/session/gf_network_peer_identity.gd` |
| [`GFNetworkSnapshot`](classes/GFNetworkSnapshot.md#gfnetworksnapshot) | `RefCounted` | `addons/gf/extensions/network/snapshot/gf_network_snapshot.gd` |

<a id="category-event_contract"></a>

### 事件契约

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkLobbyInvite`](classes/GFNetworkLobbyInvite.md#gfnetworklobbyinvite) | `Resource` | `addons/gf/extensions/network/session/gf_network_lobby_invite.gd` |

<a id="category-editor_api"></a>

### 编辑器 API

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNetworkContractAudit`](classes/GFNetworkContractAudit.md#gfnetworkcontractaudit) | `RefCounted` | `addons/gf/extensions/network/editor/gf_network_contract_audit.gd` |
| [`GFNetworkContractGenerator`](classes/GFNetworkContractGenerator.md#gfnetworkcontractgenerator) | `RefCounted` | `addons/gf/extensions/network/editor/gf_network_contract_generator.gd` |
