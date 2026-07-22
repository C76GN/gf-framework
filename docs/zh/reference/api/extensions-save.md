# Save API

模块：`extensions/save`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 6 | 86 | 63 |
| [协议与扩展点](#category-protocol) | 10 | 112 | 67 |
| [资源定义](#category-resource_definition) | 13 | 92 | 58 |
| [运行时句柄](#category-runtime_handle) | 1 | 11 | 7 |
| [值对象](#category-value_object) | 9 | 150 | 95 |
| [领域模型](#category-domain_model) | 1 | 6 | 3 |
| [事件契约](#category-event_contract) | 1 | 11 | 3 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNodeSerializerRegistry`](classes/GFNodeSerializerRegistry.md#gfnodeserializerregistry) | `RefCounted` | `addons/gf/extensions/save/serializers/gf_node_serializer_registry.gd` |
| [`GFSaveGraphUtility`](classes/GFSaveGraphUtility.md#gfsavegraphutility) | `GFUtility` | `addons/gf/extensions/save/graph/gf_save_graph_utility.gd` |
| [`GFSaveMigrationRegistry`](classes/GFSaveMigrationRegistry.md#gfsavemigrationregistry) | `RefCounted` | `addons/gf/extensions/save/document/gf_save_migration_registry.gd` |
| [`GFSaveProfileUtility`](classes/GFSaveProfileUtility.md#gfsaveprofileutility) | `GFUtility` | `addons/gf/extensions/save/profile/gf_save_profile_utility.gd` |
| [`GFSaveSlotStorageAdapter`](classes/GFSaveSlotStorageAdapter.md#gfsaveslotstorageadapter) | `Resource` | `addons/gf/extensions/save/slots/gf_save_slot_storage_adapter.gd` |
| [`GFSaveSlotSyncBridge`](classes/GFSaveSlotSyncBridge.md#gfsaveslotsyncbridge) | `RefCounted` | `addons/gf/extensions/save/slots/gf_save_slot_sync_bridge.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNodeSerializer`](classes/GFNodeSerializer.md#gfnodeserializer) | `Resource` | `addons/gf/extensions/save/serializers/gf_node_serializer.gd` |
| [`GFPersistPropertiesSource`](classes/GFPersistPropertiesSource.md#gfpersistpropertiessource) | `GFSaveSource` | `addons/gf/extensions/save/core/gf_persist_properties_source.gd` |
| [`GFSaveDataSource`](classes/GFSaveDataSource.md#gfsavedatasource) | `GFSaveSource` | `addons/gf/extensions/save/core/gf_save_data_source.gd` |
| [`GFSaveEntityFactory`](classes/GFSaveEntityFactory.md#gfsaveentityfactory) | `Resource` | `addons/gf/extensions/save/core/gf_save_entity_factory.gd` |
| [`GFSaveMigrationStep`](classes/GFSaveMigrationStep.md#gfsavemigrationstep) | `Resource` | `addons/gf/extensions/save/document/gf_save_migration_step.gd` |
| [`GFSavePipelineStep`](classes/GFSavePipelineStep.md#gfsavepipelinestep) | `Resource` | `addons/gf/extensions/save/pipeline/gf_save_pipeline_step.gd` |
| [`GFSaveScope`](classes/GFSaveScope.md#gfsavescope) | `Node` | `addons/gf/extensions/save/core/gf_save_scope.gd` |
| [`GFSaveSectionProvider`](classes/GFSaveSectionProvider.md#gfsavesectionprovider) | `Resource` | `addons/gf/extensions/save/profile/gf_save_section_provider.gd` |
| [`GFSaveSource`](classes/GFSaveSource.md#gfsavesource) | `Node` | `addons/gf/extensions/save/core/gf_save_source.gd` |
| [`GFSaveTransactionParticipant`](classes/GFSaveTransactionParticipant.md#gfsavetransactionparticipant) | `Resource` | `addons/gf/extensions/save/pipeline/gf_save_transaction_participant.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNodeAnimationPlayerSerializer`](classes/GFNodeAnimationPlayerSerializer.md#gfnodeanimationplayerserializer) | `GFNodeSerializer` | `addons/gf/extensions/save/serializers/gf_node_animation_player_serializer.gd` |
| [`GFNodeAudioStreamPlayerSerializer`](classes/GFNodeAudioStreamPlayerSerializer.md#gfnodeaudiostreamplayerserializer) | `GFNodeSerializer` | `addons/gf/extensions/save/serializers/gf_node_audio_stream_player_serializer.gd` |
| [`GFNodeCanvasItemSerializer`](classes/GFNodeCanvasItemSerializer.md#gfnodecanvasitemserializer) | `GFNodeSerializer` | `addons/gf/extensions/save/serializers/gf_node_canvas_item_serializer.gd` |
| [`GFNodeControlSerializer`](classes/GFNodeControlSerializer.md#gfnodecontrolserializer) | `GFNodeSerializer` | `addons/gf/extensions/save/serializers/gf_node_control_serializer.gd` |
| [`GFNodePropertySerializer`](classes/GFNodePropertySerializer.md#gfnodepropertyserializer) | `GFNodeSerializer` | `addons/gf/extensions/save/serializers/gf_node_property_serializer.gd` |
| [`GFNodeRangeSerializer`](classes/GFNodeRangeSerializer.md#gfnoderangeserializer) | `GFNodeSerializer` | `addons/gf/extensions/save/serializers/gf_node_range_serializer.gd` |
| [`GFNodeTimerSerializer`](classes/GFNodeTimerSerializer.md#gfnodetimerserializer) | `GFNodeSerializer` | `addons/gf/extensions/save/serializers/gf_node_timer_serializer.gd` |
| [`GFNodeTransform2DSerializer`](classes/GFNodeTransform2DSerializer.md#gfnodetransform2dserializer) | `GFNodeSerializer` | `addons/gf/extensions/save/serializers/gf_node_transform_2d_serializer.gd` |
| [`GFNodeTransform3DSerializer`](classes/GFNodeTransform3DSerializer.md#gfnodetransform3dserializer) | `GFNodeSerializer` | `addons/gf/extensions/save/serializers/gf_node_transform_3d_serializer.gd` |
| [`GFSaveDocumentSchema`](classes/GFSaveDocumentSchema.md#gfsavedocumentschema) | `Resource` | `addons/gf/extensions/save/document/gf_save_document_schema.gd` |
| [`GFSaveProfile`](classes/GFSaveProfile.md#gfsaveprofile) | `Resource` | `addons/gf/extensions/save/profile/gf_save_profile.gd` |
| [`GFSaveRecoveryPolicy`](classes/GFSaveRecoveryPolicy.md#gfsaverecoverypolicy) | `Resource` | `addons/gf/extensions/save/profile/gf_save_recovery_policy.gd` |
| [`GFSaveSlotWorkflow`](classes/GFSaveSlotWorkflow.md#gfsaveslotworkflow) | `Resource` | `addons/gf/extensions/save/slots/gf_save_slot_workflow.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFSaveProfileOperation`](classes/GFSaveProfileOperation.md#gfsaveprofileoperation) | `RefCounted` | `addons/gf/extensions/save/profile/gf_save_profile_operation.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFSaveDocument`](classes/GFSaveDocument.md#gfsavedocument) | `RefCounted` | `addons/gf/extensions/save/document/gf_save_document.gd` |
| [`GFSaveDocumentReadResult`](classes/GFSaveDocumentReadResult.md#gfsavedocumentreadresult) | `RefCounted` | `addons/gf/extensions/save/document/gf_save_document_read_result.gd` |
| [`GFSaveMigrationResult`](classes/GFSaveMigrationResult.md#gfsavemigrationresult) | `RefCounted` | `addons/gf/extensions/save/document/gf_save_migration_result.gd` |
| [`GFSavePipelineContext`](classes/GFSavePipelineContext.md#gfsavepipelinecontext) | `RefCounted` | `addons/gf/extensions/save/pipeline/gf_save_pipeline_context.gd` |
| [`GFSaveProfileResult`](classes/GFSaveProfileResult.md#gfsaveprofileresult) | `RefCounted` | `addons/gf/extensions/save/profile/gf_save_profile_result.gd` |
| [`GFSaveRollbackFailure`](classes/GFSaveRollbackFailure.md#gfsaverollbackfailure) | `RefCounted` | `addons/gf/extensions/save/profile/gf_save_rollback_failure.gd` |
| [`GFSaveSection`](classes/GFSaveSection.md#gfsavesection) | `RefCounted` | `addons/gf/extensions/save/document/gf_save_section.gd` |
| [`GFSaveSlotCard`](classes/GFSaveSlotCard.md#gfsaveslotcard) | `Resource` | `addons/gf/extensions/save/slots/gf_save_slot_card.gd` |
| [`GFSaveSlotMetadata`](classes/GFSaveSlotMetadata.md#gfsaveslotmetadata) | `Resource` | `addons/gf/extensions/save/slots/gf_save_slot_metadata.gd` |

<a id="category-domain_model"></a>

### 领域模型

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFSaveIdentity`](classes/GFSaveIdentity.md#gfsaveidentity) | `Node` | `addons/gf/extensions/save/core/gf_save_identity.gd` |

<a id="category-event_contract"></a>

### 事件契约

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFSavePipelineEvent`](classes/GFSavePipelineEvent.md#gfsavepipelineevent) | `RefCounted` | `addons/gf/extensions/save/pipeline/gf_save_pipeline_event.gd` |
