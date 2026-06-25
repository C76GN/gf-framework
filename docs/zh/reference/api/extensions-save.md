# Save API

模块：`extensions/save`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 2 | 26 | 22 |
| [协议与扩展点](#category-protocol) | 7 | 79 | 45 |
| [资源定义](#category-resource_definition) | 10 | 49 | 39 |
| [值对象](#category-value_object) | 3 | 49 | 20 |
| [领域模型](#category-domain_model) | 1 | 6 | 3 |
| [事件契约](#category-event_contract) | 1 | 11 | 3 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNodeSerializerRegistry`](classes/GFNodeSerializerRegistry.md#gfnodeserializerregistry) | `RefCounted` | `addons/gf/extensions/save/serializers/gf_node_serializer_registry.gd` |
| [`GFSaveGraphUtility`](classes/GFSaveGraphUtility.md#gfsavegraphutility) | `GFUtility` | `addons/gf/extensions/save/graph/gf_save_graph_utility.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFNodeSerializer`](classes/GFNodeSerializer.md#gfnodeserializer) | `Resource` | `addons/gf/extensions/save/serializers/gf_node_serializer.gd` |
| [`GFPersistPropertiesSource`](classes/GFPersistPropertiesSource.md#gfpersistpropertiessource) | `GFSaveSource` | `addons/gf/extensions/save/core/gf_persist_properties_source.gd` |
| [`GFSaveDataSource`](classes/GFSaveDataSource.md#gfsavedatasource) | `GFSaveSource` | `addons/gf/extensions/save/core/gf_save_data_source.gd` |
| [`GFSaveEntityFactory`](classes/GFSaveEntityFactory.md#gfsaveentityfactory) | `Resource` | `addons/gf/extensions/save/core/gf_save_entity_factory.gd` |
| [`GFSavePipelineStep`](classes/GFSavePipelineStep.md#gfsavepipelinestep) | `Resource` | `addons/gf/extensions/save/pipeline/gf_save_pipeline_step.gd` |
| [`GFSaveScope`](classes/GFSaveScope.md#gfsavescope) | `Node` | `addons/gf/extensions/save/core/gf_save_scope.gd` |
| [`GFSaveSource`](classes/GFSaveSource.md#gfsavesource) | `Node` | `addons/gf/extensions/save/core/gf_save_source.gd` |

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
| [`GFSaveSlotWorkflow`](classes/GFSaveSlotWorkflow.md#gfsaveslotworkflow) | `Resource` | `addons/gf/extensions/save/slots/gf_save_slot_workflow.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFSavePipelineContext`](classes/GFSavePipelineContext.md#gfsavepipelinecontext) | `RefCounted` | `addons/gf/extensions/save/pipeline/gf_save_pipeline_context.gd` |
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
