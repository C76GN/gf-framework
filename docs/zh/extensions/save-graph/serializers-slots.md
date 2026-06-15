# 节点序列化器与槽位

SaveGraph 的默认节点序列化器按节点类型拆分，覆盖常见场景状态片段。复杂迁移、旧字段别名、业务范围钳制、内嵌资源快照和节点引用恢复应放在项目自己的 Serializer 或 Pipeline Step 中处理。

## 默认节点序列化器

- `GFNodeTransform2DSerializer` / `GFNodeTransform3DSerializer`：保存空间变换。
- `GFNodeCanvasItemSerializer`：保存可见性与调制等 2D 表现状态。
- `GFNodeControlSerializer`：保存常见 UI Control 状态。
- `GFNodeRangeSerializer`：保存 Slider/ProgressBar 等 Range 值。
- `GFNodeTimerSerializer`：保存 Timer 运行状态。
- `GFNodeAnimationPlayerSerializer`：保存动画播放器状态。
- `GFNodeAudioStreamPlayerSerializer`：保存音频播放器状态。
- `GFNodePropertySerializer`：保存项目显式声明的属性列表。

属性序列化器采集时会把常见 Godot 值类型转成可 JSON 落盘的类型化值，并用 `GFVariantReferenceCodec` 保存显式引用。Resource 引用会记录路径、可用时的 `ResourceUID` 和类型提示；同一 SaveGraph Scope 内的 Node 引用会记录相对 Scope 的 `NodePath`。没有路径的内嵌资源、Scope 外节点引用或其他裸 `Object` 会被跳过并输出 warning。应用数据时会先恢复类型化值或引用，再检查属性存在、可写性和基础 Variant 类型兼容性。

如果只需要在场景树里声明属性白名单，可以直接使用 `GFPersistPropertiesSource`。它是 `GFSaveSource` 的薄封装，内部仍使用 `GFNodePropertySerializer`，默认目标是父节点，也可以通过继承的 `target_node_path` 指向其他节点。

```gdscript
var source := GFPersistPropertiesSource.new()
source.source_key = &"player_view"
source.properties = PackedStringArray(["position", "rotation"])
%Player.add_child(source)
```

这个 Source 不引入独立存储格式；它生成的载荷仍然是 SaveGraph 的 `serializers` 片段，因此可以继续和注册表默认序列化器、自定义 Serializer、Pipeline Step 组合。

启用 Save 扩展后，Inspector 会在 `GFPersistPropertiesSource.properties` 上显示目标节点属性选择器。选择器只辅助填写白名单，不改变运行时保存协议；需要保存计算属性、跨节点聚合状态或业务校验时，仍应编写自定义 Serializer、`GFSaveDataSource` 或 `GFSaveSource`。

需要给动态实体稳定身份时，可在节点上挂 `GFSaveIdentity`。它只描述 `persistent_id`、`type_key` 和扩展描述，不负责实例化。

## 槽位工作流

项目可使用 `GFSaveSlotWorkflow` 构建通用槽位元数据和槽位摘要 DTO；它只处理槽位索引、逻辑标识、可选显示名、标签和自定义字典，不规定 UI 布局、默认文案或存档内容。

SaveGraph 负责场景树范围内的 Source、Serializer、Pipeline Step 和实体身份恢复，不是项目全局存档模块注册表。项目需要把背包、任务、关卡、设置、统计或远端资料与场景快照合并时，应在项目层定义聚合载荷，然后交给 `GFStorageUtility` 的槽位或文件 API 落盘。

```gdscript
var storage := Gf.get_utility(GFStorageUtility) as GFStorageUtility
var workflow := GFSaveSlotWorkflow.new()
workflow.active_slot_index = 1

var metadata := workflow.build_active_metadata("手动槽位 1", {
	"chapter": 3,
})
storage.save_slot(workflow.get_active_storage_slot_id(), payload, metadata.to_dict())

var cards := workflow.build_cards_from_storage(storage, [1, 2, 3])
```

槽位工作流内部使用 `GFSaveSlotMetadata` 描述槽位 ID、展示名、schema、版本、标签、耗时和自定义元数据；`validate_metadata()` 返回标准校验报告字典，用 `kind`、统计、摘要和下一步建议描述元数据结构问题。空槽不会默认生成 `Slot N` 这类展示名；如果项目需要统一占位名，可以显式设置 `empty_display_name_template`，或在 UI 渲染层自行映射。

`GFSaveSlotCard` 是给项目读档 UI 消费的轻量 DTO，包含空槽、当前选中、兼容性、非本地化 `status_id`、修改时间和原始 metadata 副本。卡片会从整数 `slot_index`、整数/字符串 `slot_id`、metadata 里的 `slot_id` 或兜底逻辑 ID 中反推整数索引，兼容默认 `slot_3` 这类逻辑标识。它们都不绑定具体 UI 卡片布局，也不定义项目的存档字段、状态文案或按钮行为。
