# API 类索引

公开 API 的单类页面索引。顶层类拥有独立页面；内部类归入所属顶层类页面。

## 模块概览

| 模块 | 类 | 成员 | 页面内索引 |
|---|---:|---:|---|
| Kernel | 43 | 603 | [Kernel](#module-kernel) |
| Standard | 256 | 3798 | [Standard](#module-standard) |
| Action Queue | 16 | 206 | [Action Queue](#module-extensions-action_queue) |
| Asset Metadata | 3 | 23 | [Asset Metadata](#module-extensions-asset_metadata) |
| Behavior Tree | 22 | 86 | [Behavior Tree](#module-extensions-behavior_tree) |
| Camera | 7 | 115 | [Camera](#module-extensions-camera) |
| Capability | 10 | 131 | [Capability](#module-extensions-capability) |
| Combat | 45 | 498 | [Combat](#module-extensions-combat) |
| Extensions / Content Package | 3 | 45 | [Extensions / Content Package](#module-extensions-content_package) |
| Decision | 7 | 88 | [Decision](#module-extensions-decision) |
| Dialogue | 5 | 72 | [Dialogue](#module-extensions-dialogue) |
| Domain | 18 | 295 | [Domain](#module-extensions-domain) |
| Feedback | 5 | 86 | [Feedback](#module-extensions-feedback) |
| Flow | 7 | 130 | [Flow](#module-extensions-flow) |
| Interaction | 6 | 72 | [Interaction](#module-extensions-interaction) |
| Network | 20 | 243 | [Network](#module-extensions-network) |
| Physics | 2 | 27 | [Physics](#module-extensions-physics) |
| Save | 24 | 216 | [Save](#module-extensions-save) |
| Turn Based | 4 | 47 | [Turn Based](#module-extensions-turn_based) |

## 模块索引

<a id="module-kernel"></a>

### Kernel

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFArchitecture`](GFArchitecture.md#gfarchitecture) | 运行时服务 (`runtime_service`) | `Object` | 89 | `addons/gf/kernel/core/gf_architecture.gd` |
| [`GFDependencyGraphTools`](GFDependencyGraphTools.md#gfdependencygraphtools) | 运行时服务 (`runtime_service`) | `RefCounted` | 1 | `addons/gf/kernel/core/gf_dependency_graph_tools.gd` |
| [`GFExtensionCatalog`](GFExtensionCatalog.md#gfextensioncatalog) | 运行时服务 (`runtime_service`) | `RefCounted` | 5 | `addons/gf/kernel/extension/gf_extension_catalog.gd` |
| [`GFExtensionSettings`](GFExtensionSettings.md#gfextensionsettings) | 运行时服务 (`runtime_service`) | `RefCounted` | 43 | `addons/gf/kernel/extension/gf_extension_settings.gd` |
| [`GFNodeContext`](GFNodeContext.md#gfnodecontext) | 运行时服务 (`runtime_service`) | `Node` | 24 | `addons/gf/kernel/core/gf_node_context.gd` |
| [`GFObjectPropertyTools`](GFObjectPropertyTools.md#gfobjectpropertytools) | 运行时服务 (`runtime_service`) | `RefCounted` | 13 | `addons/gf/kernel/core/gf_object_property_tools.gd` |
| [`GFPathTools`](GFPathTools.md#gfpathtools) | 运行时服务 (`runtime_service`) | `RefCounted` | 7 | `addons/gf/kernel/core/gf_path_tools.gd` |
| [`GFTypeEventSystem`](GFTypeEventSystem.md#gftypeeventsystem) | 运行时服务 (`runtime_service`) | `Object` | 17 | `addons/gf/kernel/core/gf_type_event_system.gd` |
| [`GFBindBuilder`](GFBindBuilder.md#gfbindbuilder) | 协议与扩展点 (`protocol`) | `RefCounted` | 5 | `addons/gf/kernel/core/gf_bind_builder.gd` |
| [`GFBindableProperty`](GFBindableProperty.md#gfbindableproperty) | 协议与扩展点 (`protocol`) | `RefCounted` | 19 | `addons/gf/kernel/core/gf_bindable_property.gd` |
| [`GFBinder`](GFBinder.md#gfbinder) | 协议与扩展点 (`protocol`) | `RefCounted` | 4 | `addons/gf/kernel/core/gf_binder.gd` |
| [`GFCommand`](GFCommand.md#gfcommand) | 协议与扩展点 (`protocol`) | `Object` | 8 | `addons/gf/kernel/base/gf_command.gd` |
| [`GFComputedProperty`](GFComputedProperty.md#gfcomputedproperty) | 协议与扩展点 (`protocol`) | `GFBindableProperty` | 13 | `addons/gf/kernel/core/gf_computed_property.gd` |
| [`GFConfig`](GFConfig.md#gfconfig) | 协议与扩展点 (`protocol`) | `Resource` | 2 | `addons/gf/kernel/base/gf_config.gd` |
| [`GFController`](GFController.md#gfcontroller) | 协议与扩展点 (`protocol`) | `Node` | 24 | `addons/gf/kernel/base/gf_controller.gd` |
| [`GFInstaller`](GFInstaller.md#gfinstaller) | 协议与扩展点 (`protocol`) | `RefCounted` | 2 | `addons/gf/kernel/core/gf_installer.gd` |
| [`GFModel`](GFModel.md#gfmodel) | 协议与扩展点 (`protocol`) | `Object` | 14 | `addons/gf/kernel/base/gf_model.gd` |
| [`GFPayload`](GFPayload.md#gfpayload) | 协议与扩展点 (`protocol`) | `RefCounted` | 4 | `addons/gf/kernel/base/gf_payload.gd` |
| [`GFQuery`](GFQuery.md#gfquery) | 协议与扩展点 (`protocol`) | `Object` | 5 | `addons/gf/kernel/base/gf_query.gd` |
| [`GFReactiveEffect`](GFReactiveEffect.md#gfreactiveeffect) | 协议与扩展点 (`protocol`) | `RefCounted` | 9 | `addons/gf/kernel/core/gf_reactive_effect.gd` |
| [`GFReadOnlyBindableProperty`](GFReadOnlyBindableProperty.md#gfreadonlybindableproperty) | 协议与扩展点 (`protocol`) | `GFBindableProperty` | 9 | `addons/gf/kernel/core/gf_read_only_bindable_property.gd` |
| [`GFRule`](GFRule.md#gfrule) | 协议与扩展点 (`protocol`) | `Resource` | 2 | `addons/gf/kernel/base/gf_rule.gd` |
| [`GFSystem`](GFSystem.md#gfsystem) | 协议与扩展点 (`protocol`) | `Object` | 27 | `addons/gf/kernel/base/gf_system.gd` |
| [`GFTimeProvider`](GFTimeProvider.md#gftimeprovider) | 协议与扩展点 (`protocol`) | `GFUtility` | 4 | `addons/gf/kernel/base/gf_time_provider.gd` |
| [`GFUtility`](GFUtility.md#gfutility) | 协议与扩展点 (`protocol`) | `Object` | 25 | `addons/gf/kernel/base/gf_utility.gd` |
| [`GFExtensionManifest`](GFExtensionManifest.md#gfextensionmanifest) | 资源定义 (`resource_definition`) | `RefCounted` | 29 | `addons/gf/kernel/extension/gf_extension_manifest.gd` |
| [`GFBindingLifetimes`](GFBindingLifetimes.md#gfbindinglifetimes) | 值对象 (`value_object`) | `RefCounted` | 1 | `addons/gf/kernel/core/gf_binding_lifetimes.gd` |
| [`GFAccessGenerator`](GFAccessGenerator.md#gfaccessgenerator) | 编辑器 API (`editor_api`) | `RefCounted` | 10 | `addons/gf/kernel/editor/gf_access_generator.gd` |
| [`GFConfigAccessGenerator`](GFConfigAccessGenerator.md#gfconfigaccessgenerator) | 编辑器 API (`editor_api`) | `RefCounted` | 6 | `addons/gf/kernel/editor/gf_config_access_generator.gd` |
| [`GFEditorActionDefinition`](GFEditorActionDefinition.md#gfeditoractiondefinition) | 编辑器 API (`editor_api`) | `RefCounted` | 10 | `addons/gf/kernel/editor/gf_editor_action_definition.gd` |
| [`GFEditorCommand`](GFEditorCommand.md#gfeditorcommand) | 编辑器 API (`editor_api`) | `RefCounted` | 11 | `addons/gf/kernel/editor/gf_editor_command.gd` |
| [`GFEditorPickOperation`](GFEditorPickOperation.md#gfeditorpickoperation) | 编辑器 API (`editor_api`) | `RefCounted` | 18 | `addons/gf/kernel/editor/gf_editor_pick_operation.gd` |
| [`GFEditorTool`](GFEditorTool.md#gfeditortool) | 编辑器 API (`editor_api`) | `RefCounted` | 28 | `addons/gf/kernel/editor/gf_editor_tool.gd` |
| [`GFEditorToolContext`](GFEditorToolContext.md#gfeditortoolcontext) | 编辑器 API (`editor_api`) | `RefCounted` | 9 | `addons/gf/kernel/editor/gf_editor_tool_context.gd` |
| [`GFEditorToolOption`](GFEditorToolOption.md#gfeditortooloption) | 编辑器 API (`editor_api`) | `Resource` | 17 | `addons/gf/kernel/editor/gf_editor_tool_option.gd` |
| [`GFEditorToolOptionSchema`](GFEditorToolOptionSchema.md#gfeditortooloptionschema) | 编辑器 API (`editor_api`) | `Resource` | 13 | `addons/gf/kernel/editor/gf_editor_tool_option_schema.gd` |
| [`GFEditorTypeIndex`](GFEditorTypeIndex.md#gfeditortypeindex) | 编辑器 API (`editor_api`) | `RefCounted` | 6 | `addons/gf/kernel/editor/gf_editor_type_index.gd` |
| [`GFEditorValueField`](GFEditorValueField.md#gfeditorvaluefield) | 编辑器 API (`editor_api`) | `HBoxContainer` | 7 | `addons/gf/kernel/editor/gf_editor_value_field.gd` |
| [`GFExtensionUsageAudit`](GFExtensionUsageAudit.md#gfextensionusageaudit) | 编辑器 API (`editor_api`) | `RefCounted` | 7 | `addons/gf/kernel/extension/gf_extension_usage_audit.gd` |
| [`GFResourceTableEditor`](GFResourceTableEditor.md#gfresourcetableeditor) | 编辑器 API (`editor_api`) | `VBoxContainer` | 31 | `addons/gf/kernel/editor/gf_resource_table_editor.gd` |
| [`GFSceneSignalAudit`](GFSceneSignalAudit.md#gfscenesignalaudit) | 编辑器 API (`editor_api`) | `RefCounted` | 11 | `addons/gf/kernel/editor/gf_scene_signal_audit.gd` |
| [`GFSourceBuilder`](GFSourceBuilder.md#gfsourcebuilder) | 编辑器 API (`editor_api`) | `RefCounted` | 8 | `addons/gf/kernel/editor/gf_source_builder.gd` |
| [`GFThumbnailRenderer`](GFThumbnailRenderer.md#gfthumbnailrenderer) | 编辑器 API (`editor_api`) | `Node` | 6 | `addons/gf/kernel/editor/gf_thumbnail_renderer.gd` |

<a id="module-standard"></a>

### Standard

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFAnalyticsUtility`](GFAnalyticsUtility.md#gfanalyticsutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 21 | `addons/gf/standard/utilities/analytics/gf_analytics_utility.gd` |
| [`GFAssetUtility`](GFAssetUtility.md#gfassetutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 29 | `addons/gf/standard/utilities/assets/gf_asset_utility.gd` |
| [`GFAudioBankTools`](GFAudioBankTools.md#gfaudiobanktools) | 运行时服务 (`runtime_service`) | `RefCounted` | 13 | `addons/gf/standard/utilities/audio/gf_audio_bank_tools.gd` |
| [`GFAudioCatalogProvider`](GFAudioCatalogProvider.md#gfaudiocatalogprovider) | 运行时服务 (`runtime_service`) | `RefCounted` | 9 | `addons/gf/standard/utilities/audio/gf_audio_catalog_provider.gd` |
| [`GFAudioUtility`](GFAudioUtility.md#gfaudioutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 74 | `addons/gf/standard/utilities/audio/gf_audio_utility.gd` |
| [`GFBackgroundWorkUtility`](GFBackgroundWorkUtility.md#gfbackgroundworkutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 28 | `addons/gf/standard/utilities/jobs/gf_background_work_utility.gd` |
| [`GFBatchedLogSink`](GFBatchedLogSink.md#gfbatchedlogsink) | 运行时服务 (`runtime_service`) | `GFLogSink` | 14 | `addons/gf/standard/utilities/logging/gf_batched_log_sink.gd` |
| [`GFBudgetLedger`](GFBudgetLedger.md#gfbudgetledger) | 运行时服务 (`runtime_service`) | `RefCounted` | 13 | `addons/gf/standard/foundation/budget/gf_budget_ledger.gd` |
| [`GFBuildInfoUtility`](GFBuildInfoUtility.md#gfbuildinfoutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 8 | `addons/gf/standard/utilities/debug/gf_build_info_utility.gd` |
| [`GFCommandHistoryUtility`](GFCommandHistoryUtility.md#gfcommandhistoryutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 22 | `addons/gf/standard/utilities/history/gf_command_history_utility.gd` |
| [`GFCommandSequence`](GFCommandSequence.md#gfcommandsequence) | 运行时服务 (`runtime_service`) | `RefCounted` | 20 | `addons/gf/standard/sequence/gf_command_sequence.gd` |
| [`GFConfigReferenceResolver`](GFConfigReferenceResolver.md#gfconfigreferenceresolver) | 运行时服务 (`runtime_service`) | `RefCounted` | 3 | `addons/gf/standard/utilities/config/gf_config_reference_resolver.gd` |
| [`GFConfigTableImporter`](GFConfigTableImporter.md#gfconfigtableimporter) | 运行时服务 (`runtime_service`) | `RefCounted` | 6 | `addons/gf/standard/utilities/config/gf_config_table_importer.gd` |
| [`GFConfigTableMergeTools`](GFConfigTableMergeTools.md#gfconfigtablemergetools) | 运行时服务 (`runtime_service`) | `RefCounted` | 1 | `addons/gf/standard/utilities/config/gf_config_table_merge_tools.gd` |
| [`GFConsoleUtility`](GFConsoleUtility.md#gfconsoleutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 30 | `addons/gf/standard/utilities/debug/gf_console_utility.gd` |
| [`GFControlValueAdapter`](GFControlValueAdapter.md#gfcontrolvalueadapter) | 运行时服务 (`runtime_service`) | `RefCounted` | 5 | `addons/gf/standard/utilities/ui/gf_control_value_adapter.gd` |
| [`GFCurve2DMath`](GFCurve2DMath.md#gfcurve2dmath) | 运行时服务 (`runtime_service`) | `RefCounted` | 11 | `addons/gf/standard/foundation/math/gf_curve_2d_math.gd` |
| [`GFDebugDrawUtility`](GFDebugDrawUtility.md#gfdebugdrawutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 24 | `addons/gf/standard/utilities/debug/gf_debug_draw_utility.gd` |
| [`GFDebugOverlayUtility`](GFDebugOverlayUtility.md#gfdebugoverlayutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 37 | `addons/gf/standard/utilities/debug/gf_debug_overlay_utility.gd` |
| [`GFDiagnosticsUtility`](GFDiagnosticsUtility.md#gfdiagnosticsutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 52 | `addons/gf/standard/utilities/debug/gf_diagnostics_utility.gd` |
| [`GFDirectoryWatchUtility`](GFDirectoryWatchUtility.md#gfdirectorywatchutility) | 运行时服务 (`runtime_service`) | `RefCounted` | 19 | `addons/gf/standard/utilities/io/gf_directory_watch_utility.gd` |
| [`GFDisplaySettingsUtility`](GFDisplaySettingsUtility.md#gfdisplaysettingsutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 34 | `addons/gf/standard/utilities/display/gf_display_settings_utility.gd` |
| [`GFDownloadUtility`](GFDownloadUtility.md#gfdownloadutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 28 | `addons/gf/standard/utilities/io/gf_download_utility.gd` |
| [`GFDragDropUtility`](GFDragDropUtility.md#gfdragdroputility) | 运行时服务 (`runtime_service`) | `GFUtility` | 24 | `addons/gf/standard/input/drag_drop/gf_drag_drop_utility.gd` |
| [`GFGraphLayoutUtility`](GFGraphLayoutUtility.md#gfgraphlayoututility) | 运行时服务 (`runtime_service`) | `RefCounted` | 2 | `addons/gf/standard/foundation/math/gf_graph_layout_utility.gd` |
| [`GFGraphMath`](GFGraphMath.md#gfgraphmath) | 运行时服务 (`runtime_service`) | `RefCounted` | 4 | `addons/gf/standard/foundation/math/gf_graph_math.gd` |
| [`GFGrid3DMath`](GFGrid3DMath.md#gfgrid3dmath) | 运行时服务 (`runtime_service`) | `RefCounted` | 6 | `addons/gf/standard/foundation/math/gf_grid_3d_math.gd` |
| [`GFGridKey3D`](GFGridKey3D.md#gfgridkey3d) | 运行时服务 (`runtime_service`) | `RefCounted` | 15 | `addons/gf/standard/foundation/math/gf_grid_key_3d.gd` |
| [`GFGridMath`](GFGridMath.md#gfgridmath) | 运行时服务 (`runtime_service`) | `RefCounted` | 14 | `addons/gf/standard/foundation/math/gf_grid_math.gd` |
| [`GFGridOccupancy`](GFGridOccupancy.md#gfgridoccupancy) | 运行时服务 (`runtime_service`) | `RefCounted` | 22 | `addons/gf/standard/foundation/math/gf_grid_occupancy.gd` |
| [`GFGridPlaneMapper3D`](GFGridPlaneMapper3D.md#gfgridplanemapper3d) | 运行时服务 (`runtime_service`) | `RefCounted` | 9 | `addons/gf/standard/foundation/math/gf_grid_plane_mapper_3d.gd` |
| [`GFGridTransform2D`](GFGridTransform2D.md#gfgridtransform2d) | 运行时服务 (`runtime_service`) | `RefCounted` | 11 | `addons/gf/standard/foundation/math/gf_grid_transform_2d.gd` |
| [`GFHexGridMath`](GFHexGridMath.md#gfhexgridmath) | 运行时服务 (`runtime_service`) | `RefCounted` | 23 | `addons/gf/standard/foundation/math/gf_hex_grid_math.gd` |
| [`GFInputAssistUtility`](GFInputAssistUtility.md#gfinputassistutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 13 | `addons/gf/standard/input/runtime/gf_input_assist_utility.gd` |
| [`GFInputConflictAnalyzer`](GFInputConflictAnalyzer.md#gfinputconflictanalyzer) | 运行时服务 (`runtime_service`) | `RefCounted` | 6 | `addons/gf/standard/input/rebinding/gf_input_conflict_analyzer.gd` |
| [`GFInputDetector`](GFInputDetector.md#gfinputdetector) | 运行时服务 (`runtime_service`) | `Node` | 23 | `addons/gf/standard/input/rebinding/gf_input_detector.gd` |
| [`GFInputDeviceUtility`](GFInputDeviceUtility.md#gfinputdeviceutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 38 | `addons/gf/standard/input/runtime/gf_input_device_utility.gd` |
| [`GFInputFormatter`](GFInputFormatter.md#gfinputformatter) | 运行时服务 (`runtime_service`) | `RefCounted` | 15 | `addons/gf/standard/input/formatting/gf_input_formatter.gd` |
| [`GFInputMappingUtility`](GFInputMappingUtility.md#gfinputmappingutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 49 | `addons/gf/standard/input/runtime/gf_input_mapping_utility.gd` |
| [`GFInputPlayback`](GFInputPlayback.md#gfinputplayback) | 运行时服务 (`runtime_service`) | `RefCounted` | 18 | `addons/gf/standard/input/recording/gf_input_playback.gd` |
| [`GFJobQueueUtility`](GFJobQueueUtility.md#gfjobqueueutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 25 | `addons/gf/standard/utilities/jobs/gf_job_queue_utility.gd` |
| [`GFJobWorker`](GFJobWorker.md#gfjobworker) | 运行时服务 (`runtime_service`) | `Node` | 21 | `addons/gf/standard/utilities/jobs/gf_job_worker.gd` |
| [`GFJsonLineLogSink`](GFJsonLineLogSink.md#gfjsonlinelogsink) | 运行时服务 (`runtime_service`) | `GFLogSink` | 10 | `addons/gf/standard/utilities/logging/gf_json_line_log_sink.gd` |
| [`GFLayerMaskUtility`](GFLayerMaskUtility.md#gflayermaskutility) | 运行时服务 (`runtime_service`) | `RefCounted` | 9 | `addons/gf/standard/foundation/math/gf_layer_mask_utility.gd` |
| [`GFLogUtility`](GFLogUtility.md#gflogutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 46 | `addons/gf/standard/utilities/logging/gf_log_utility.gd` |
| [`GFMutationBatch`](GFMutationBatch.md#gfmutationbatch) | 运行时服务 (`runtime_service`) | `RefCounted` | 14 | `addons/gf/standard/foundation/collections/gf_mutation_batch.gd` |
| [`GFNodeStateMachine`](GFNodeStateMachine.md#gfnodestatemachine) | 运行时服务 (`runtime_service`) | `Node` | 51 | `addons/gf/standard/state_machine/node/gf_node_state_machine.gd` |
| [`GFNodeStateMachineValidator`](GFNodeStateMachineValidator.md#gfnodestatemachinevalidator) | 运行时服务 (`runtime_service`) | `RefCounted` | 3 | `addons/gf/standard/state_machine/node/gf_node_state_machine_validator.gd` |
| [`GFNodeTreeOps`](GFNodeTreeOps.md#gfnodetreeops) | 运行时服务 (`runtime_service`) | `RefCounted` | 8 | `addons/gf/standard/utilities/nodes/gf_node_tree_ops.gd` |
| [`GFNotificationUtility`](GFNotificationUtility.md#gfnotificationutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 21 | `addons/gf/standard/utilities/ui/gf_notification_utility.gd` |
| [`GFNumberFormatter`](GFNumberFormatter.md#gfnumberformatter) | 运行时服务 (`runtime_service`) | `RefCounted` | 7 | `addons/gf/standard/foundation/formatting/gf_number_formatter.gd` |
| [`GFObjectPoolUtility`](GFObjectPoolUtility.md#gfobjectpoolutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 17 | `addons/gf/standard/utilities/nodes/gf_object_pool_utility.gd` |
| [`GFPhysicsQueryUtility`](GFPhysicsQueryUtility.md#gfphysicsqueryutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 3 | `addons/gf/standard/utilities/spatial/gf_physics_query_utility.gd` |
| [`GFPointerActivityUtility`](GFPointerActivityUtility.md#gfpointeractivityutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 25 | `addons/gf/standard/input/runtime/gf_pointer_activity_utility.gd` |
| [`GFPolynomialMath`](GFPolynomialMath.md#gfpolynomialmath) | 运行时服务 (`runtime_service`) | `RefCounted` | 9 | `addons/gf/standard/foundation/math/gf_polynomial_math.gd` |
| [`GFProgressionMath`](GFProgressionMath.md#gfprogressionmath) | 运行时服务 (`runtime_service`) | `RefCounted` | 5 | `addons/gf/standard/foundation/math/gf_progression_math.gd` |
| [`GFQuadTreeUtility`](GFQuadTreeUtility.md#gfquadtreeutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 23 | `addons/gf/standard/utilities/spatial/gf_quad_tree_utility.gd` |
| [`GFRefCountedPool`](GFRefCountedPool.md#gfrefcountedpool) | 运行时服务 (`runtime_service`) | `RefCounted` | 17 | `addons/gf/standard/utilities/pooling/gf_ref_counted_pool.gd` |
| [`GFRegionMap2D`](GFRegionMap2D.md#gfregionmap2d) | 运行时服务 (`runtime_service`) | `RefCounted` | 14 | `addons/gf/standard/foundation/math/gf_region_map_2d.gd` |
| [`GFRegionMap3D`](GFRegionMap3D.md#gfregionmap3d) | 运行时服务 (`runtime_service`) | `RefCounted` | 15 | `addons/gf/standard/foundation/math/gf_region_map_3d.gd` |
| [`GFRemoteCacheUtility`](GFRemoteCacheUtility.md#gfremotecacheutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 21 | `addons/gf/standard/utilities/io/gf_remote_cache_utility.gd` |
| [`GFRenderWarmupUtility`](GFRenderWarmupUtility.md#gfrenderwarmuputility) | 运行时服务 (`runtime_service`) | `GFUtility` | 23 | `addons/gf/standard/utilities/display/gf_render_warmup_utility.gd` |
| [`GFRequestOutboxUtility`](GFRequestOutboxUtility.md#gfrequestoutboxutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 30 | `addons/gf/standard/utilities/io/gf_request_outbox_utility.gd` |
| [`GFResourceRegistryTools`](GFResourceRegistryTools.md#gfresourceregistrytools) | 运行时服务 (`runtime_service`) | `RefCounted` | 22 | `addons/gf/standard/utilities/assets/gf_resource_registry_tools.gd` |
| [`GFResourceResolverUtility`](GFResourceResolverUtility.md#gfresourceresolverutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 17 | `addons/gf/standard/utilities/assets/gf_resource_resolver_utility.gd` |
| [`GFRichTextFormatter`](GFRichTextFormatter.md#gfrichtextformatter) | 运行时服务 (`runtime_service`) | `RefCounted` | 9 | `addons/gf/standard/utilities/ui/gf_rich_text_formatter.gd` |
| [`GFRuntimeInspectorUtility`](GFRuntimeInspectorUtility.md#gfruntimeinspectorutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 19 | `addons/gf/standard/utilities/debug/gf_runtime_inspector_utility.gd` |
| [`GFSceneUtility`](GFSceneUtility.md#gfsceneutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 73 | `addons/gf/standard/utilities/scene/gf_scene_utility.gd` |
| [`GFScreenTransitionUtility`](GFScreenTransitionUtility.md#gfscreentransitionutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 17 | `addons/gf/standard/utilities/scene/gf_screen_transition_utility.gd` |
| [`GFSeedUtility`](GFSeedUtility.md#gfseedutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 9 | `addons/gf/standard/utilities/random/gf_seed_utility.gd` |
| [`GFSettingsUtility`](GFSettingsUtility.md#gfsettingsutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 31 | `addons/gf/standard/utilities/settings/gf_settings_utility.gd` |
| [`GFShaderParameterUtility`](GFShaderParameterUtility.md#gfshaderparameterutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 6 | `addons/gf/standard/utilities/display/gf_shader_parameter_utility.gd` |
| [`GFSignalRuntimeProbe`](GFSignalRuntimeProbe.md#gfsignalruntimeprobe) | 运行时服务 (`runtime_service`) | `RefCounted` | 17 | `addons/gf/standard/utilities/debug/gf_signal_runtime_probe.gd` |
| [`GFSignalUtility`](GFSignalUtility.md#gfsignalutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 10 | `addons/gf/standard/utilities/signals/gf_signal_utility.gd` |
| [`GFSnapshotHistoryUtility`](GFSnapshotHistoryUtility.md#gfsnapshothistoryutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 21 | `addons/gf/standard/utilities/history/gf_snapshot_history_utility.gd` |
| [`GFSpatialHash3D`](GFSpatialHash3D.md#gfspatialhash3d) | 运行时服务 (`runtime_service`) | `RefCounted` | 11 | `addons/gf/standard/foundation/math/gf_spatial_hash_3d.gd` |
| [`GFSpringMath`](GFSpringMath.md#gfspringmath) | 运行时服务 (`runtime_service`) | `RefCounted` | 4 | `addons/gf/standard/foundation/math/gf_spring_math.gd` |
| [`GFStateMachine`](GFStateMachine.md#gfstatemachine) | 运行时服务 (`runtime_service`) | `RefCounted` | 37 | `addons/gf/standard/state_machine/pure/gf_state_machine.gd` |
| [`GFSteeringMath`](GFSteeringMath.md#gfsteeringmath) | 运行时服务 (`runtime_service`) | `RefCounted` | 16 | `addons/gf/standard/foundation/math/gf_steering_math.gd` |
| [`GFStorageSyncUtility`](GFStorageSyncUtility.md#gfstoragesyncutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 11 | `addons/gf/standard/utilities/storage/gf_storage_sync_utility.gd` |
| [`GFStorageUtility`](GFStorageUtility.md#gfstorageutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 52 | `addons/gf/standard/utilities/storage/gf_storage_utility.gd` |
| [`GFSupportReportUtility`](GFSupportReportUtility.md#gfsupportreportutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 27 | `addons/gf/standard/utilities/debug/gf_support_report_utility.gd` |
| [`GFSurfaceUtility`](GFSurfaceUtility.md#gfsurfaceutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 14 | `addons/gf/standard/utilities/display/gf_surface_utility.gd` |
| [`GFTagSourceAdapter`](GFTagSourceAdapter.md#gftagsourceadapter) | 运行时服务 (`runtime_service`) | `RefCounted` | 9 | `addons/gf/standard/foundation/tags/gf_tag_source_adapter.gd` |
| [`GFTextAutoFit`](GFTextAutoFit.md#gftextautofit) | 运行时服务 (`runtime_service`) | `Node` | 14 | `addons/gf/standard/utilities/ui/gf_text_auto_fit.gd` |
| [`GFTextFitter`](GFTextFitter.md#gftextfitter) | 运行时服务 (`runtime_service`) | `RefCounted` | 7 | `addons/gf/standard/utilities/ui/gf_text_fitter.gd` |
| [`GFTimeUtility`](GFTimeUtility.md#gftimeutility) | 运行时服务 (`runtime_service`) | `GFTimeProvider` | 15 | `addons/gf/standard/utilities/time/gf_time_utility.gd` |
| [`GFTimedTextImporter`](GFTimedTextImporter.md#gftimedtextimporter) | 运行时服务 (`runtime_service`) | `RefCounted` | 3 | `addons/gf/standard/foundation/timeline/gf_timed_text_importer.gd` |
| [`GFTimerUtility`](GFTimerUtility.md#gftimerutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 10 | `addons/gf/standard/utilities/time/gf_timer_utility.gd` |
| [`GFTouchButton`](GFTouchButton.md#gftouchbutton) | 运行时服务 (`runtime_service`) | `Node2D` | 12 | `addons/gf/standard/input/touch/gf_touch_button.gd` |
| [`GFTouchJoystick`](GFTouchJoystick.md#gftouchjoystick) | 运行时服务 (`runtime_service`) | `Node2D` | 21 | `addons/gf/standard/input/touch/gf_touch_joystick.gd` |
| [`GFUIRouterUtility`](GFUIRouterUtility.md#gfuirouterutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 26 | `addons/gf/standard/utilities/ui/gf_ui_router_utility.gd` |
| [`GFUIUtility`](GFUIUtility.md#gfuiutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 43 | `addons/gf/standard/utilities/ui/gf_ui_utility.gd` |
| [`GFValidationDiagnosticAdapter`](GFValidationDiagnosticAdapter.md#gfvalidationdiagnosticadapter) | 运行时服务 (`runtime_service`) | `RefCounted` | 6 | `addons/gf/standard/foundation/validation/gf_validation_diagnostic_adapter.gd` |
| [`GFValidationJUnitExporter`](GFValidationJUnitExporter.md#gfvalidationjunitexporter) | 运行时服务 (`runtime_service`) | `RefCounted` | 2 | `addons/gf/standard/foundation/validation/gf_validation_junit_exporter.gd` |
| [`GFValidationReportDictionary`](GFValidationReportDictionary.md#gfvalidationreportdictionary) | 运行时服务 (`runtime_service`) | `RefCounted` | 12 | `addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd` |
| [`GFValidationRunner`](GFValidationRunner.md#gfvalidationrunner) | 运行时服务 (`runtime_service`) | `RefCounted` | 10 | `addons/gf/standard/foundation/validation/gf_validation_runner.gd` |
| [`GFValueIndex`](GFValueIndex.md#gfvalueindex) | 运行时服务 (`runtime_service`) | `RefCounted` | 15 | `addons/gf/standard/foundation/collections/gf_value_index.gd` |
| [`GFVariantData`](GFVariantData.md#gfvariantdata) | 运行时服务 (`runtime_service`) | `RefCounted` | 35 | `addons/gf/standard/foundation/variant/gf_variant_data.gd` |
| [`GFVariantJsonCodec`](GFVariantJsonCodec.md#gfvariantjsoncodec) | 运行时服务 (`runtime_service`) | `RefCounted` | 11 | `addons/gf/standard/foundation/variant/gf_variant_json_codec.gd` |
| [`GFVariantReferenceCodec`](GFVariantReferenceCodec.md#gfvariantreferencecodec) | 运行时服务 (`runtime_service`) | `RefCounted` | 19 | `addons/gf/standard/foundation/variant/gf_variant_reference_codec.gd` |
| [`GFViewportUtility`](GFViewportUtility.md#gfviewportutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 20 | `addons/gf/standard/utilities/display/gf_viewport_utility.gd` |
| [`GFVirtualListModel`](GFVirtualListModel.md#gfvirtuallistmodel) | 运行时服务 (`runtime_service`) | `RefCounted` | 19 | `addons/gf/standard/utilities/ui/gf_virtual_list_model.gd` |
| [`GFAudioBackend`](GFAudioBackend.md#gfaudiobackend) | 协议与扩展点 (`protocol`) | `RefCounted` | 36 | `addons/gf/standard/utilities/audio/gf_audio_backend.gd` |
| [`GFConfigProvider`](GFConfigProvider.md#gfconfigprovider) | 协议与扩展点 (`protocol`) | `GFUtility` | 10 | `addons/gf/standard/utilities/config/gf_config_provider.gd` |
| [`GFConfigValidationRule`](GFConfigValidationRule.md#gfconfigvalidationrule) | 协议与扩展点 (`protocol`) | `Resource` | 18 | `addons/gf/standard/utilities/config/validation/gf_config_validation_rule.gd` |
| [`GFFormula`](GFFormula.md#gfformula) | 协议与扩展点 (`protocol`) | `Resource` | 5 | `addons/gf/standard/foundation/formula/gf_formula.gd` |
| [`GFGridSelection2D`](GFGridSelection2D.md#gfgridselection2d) | 协议与扩展点 (`protocol`) | `Resource` | 10 | `addons/gf/standard/foundation/math/gf_grid_selection_2d.gd` |
| [`GFInputIconProvider`](GFInputIconProvider.md#gfinputiconprovider) | 协议与扩展点 (`protocol`) | `Resource` | 6 | `addons/gf/standard/input/formatting/gf_input_icon_provider.gd` |
| [`GFInputModifier`](GFInputModifier.md#gfinputmodifier) | 协议与扩展点 (`protocol`) | `Resource` | 3 | `addons/gf/standard/input/modifiers/gf_input_modifier.gd` |
| [`GFInputTextProvider`](GFInputTextProvider.md#gfinputtextprovider) | 协议与扩展点 (`protocol`) | `Resource` | 4 | `addons/gf/standard/input/formatting/gf_input_text_provider.gd` |
| [`GFInputTrigger`](GFInputTrigger.md#gfinputtrigger) | 协议与扩展点 (`protocol`) | `Resource` | 5 | `addons/gf/standard/input/triggers/gf_input_trigger.gd` |
| [`GFLogSink`](GFLogSink.md#gflogsink) | 协议与扩展点 (`protocol`) | `RefCounted` | 4 | `addons/gf/standard/utilities/logging/gf_log_sink.gd` |
| [`GFNodeState`](GFNodeState.md#gfnodestate) | 协议与扩展点 (`protocol`) | `Node` | 46 | `addons/gf/standard/state_machine/node/gf_node_state.gd` |
| [`GFNodeStateBehavior`](GFNodeStateBehavior.md#gfnodestatebehavior) | 协议与扩展点 (`protocol`) | `Resource` | 15 | `addons/gf/standard/state_machine/node/gf_node_state_behavior.gd` |
| [`GFNodeStateCondition`](GFNodeStateCondition.md#gfnodestatecondition) | 协议与扩展点 (`protocol`) | `Resource` | 5 | `addons/gf/standard/state_machine/node/gf_node_state_condition.gd` |
| [`GFSequenceStep`](GFSequenceStep.md#gfsequencestep) | 协议与扩展点 (`protocol`) | `Resource` | 4 | `addons/gf/standard/sequence/gf_sequence_step.gd` |
| [`GFState`](GFState.md#gfstate) | 协议与扩展点 (`protocol`) | `RefCounted` | 26 | `addons/gf/standard/state_machine/pure/gf_state.gd` |
| [`GFStorageBackend`](GFStorageBackend.md#gfstoragebackend) | 协议与扩展点 (`protocol`) | `RefCounted` | 16 | `addons/gf/standard/utilities/storage/gf_storage_backend.gd` |
| [`GFUndoableCommand`](GFUndoableCommand.md#gfundoablecommand) | 协议与扩展点 (`protocol`) | `GFCommand` | 6 | `addons/gf/standard/command/gf_undoable_command.gd` |
| [`GFValidationRule`](GFValidationRule.md#gfvalidationrule) | 协议与扩展点 (`protocol`) | `Resource` | 13 | `addons/gf/standard/foundation/validation/gf_validation_rule.gd` |
| [`GFAnalyticsConfig`](GFAnalyticsConfig.md#gfanalyticsconfig) | 资源定义 (`resource_definition`) | `Resource` | 13 | `addons/gf/standard/utilities/analytics/gf_analytics_config.gd` |
| [`GFAudioBank`](GFAudioBank.md#gfaudiobank) | 资源定义 (`resource_definition`) | `Resource` | 17 | `addons/gf/standard/utilities/audio/gf_audio_bank.gd` |
| [`GFAudioClip`](GFAudioClip.md#gfaudioclip) | 资源定义 (`resource_definition`) | `Resource` | 12 | `addons/gf/standard/utilities/audio/gf_audio_clip.gd` |
| [`GFAudioSpatialSettings`](GFAudioSpatialSettings.md#gfaudiospatialsettings) | 资源定义 (`resource_definition`) | `Resource` | 19 | `addons/gf/standard/utilities/audio/gf_audio_spatial_settings.gd` |
| [`GFBlackboardEntry`](GFBlackboardEntry.md#gfblackboardentry) | 资源定义 (`resource_definition`) | `Resource` | 14 | `addons/gf/standard/foundation/blackboard/gf_blackboard_entry.gd` |
| [`GFBlackboardSchema`](GFBlackboardSchema.md#gfblackboardschema) | 资源定义 (`resource_definition`) | `Resource` | 16 | `addons/gf/standard/foundation/blackboard/gf_blackboard_schema.gd` |
| [`GFCallableTargetRef`](GFCallableTargetRef.md#gfcallabletargetref) | 资源定义 (`resource_definition`) | `Resource` | 9 | `addons/gf/standard/utilities/signals/bridge/gf_callable_target_ref.gd` |
| [`GFConfigBuildProfile`](GFConfigBuildProfile.md#gfconfigbuildprofile) | 资源定义 (`resource_definition`) | `Resource` | 15 | `addons/gf/standard/utilities/config/gf_config_build_profile.gd` |
| [`GFConfigLocalizationKeyValidationRule`](GFConfigLocalizationKeyValidationRule.md#gfconfiglocalizationkeyvalidationrule) | 资源定义 (`resource_definition`) | `GFConfigValidationRule` | 7 | `addons/gf/standard/utilities/config/validation/gf_config_localization_key_validation_rule.gd` |
| [`GFConfigNotDefaultValidationRule`](GFConfigNotDefaultValidationRule.md#gfconfignotdefaultvalidationrule) | 资源定义 (`resource_definition`) | `GFConfigValidationRule` | 5 | `addons/gf/standard/utilities/config/validation/gf_config_not_default_validation_rule.gd` |
| [`GFConfigRangeValidationRule`](GFConfigRangeValidationRule.md#gfconfigrangevalidationrule) | 资源定义 (`resource_definition`) | `GFConfigValidationRule` | 9 | `addons/gf/standard/utilities/config/validation/gf_config_range_validation_rule.gd` |
| [`GFConfigRegexValidationRule`](GFConfigRegexValidationRule.md#gfconfigregexvalidationrule) | 资源定义 (`resource_definition`) | `GFConfigValidationRule` | 6 | `addons/gf/standard/utilities/config/validation/gf_config_regex_validation_rule.gd` |
| [`GFConfigResourcePathValidationRule`](GFConfigResourcePathValidationRule.md#gfconfigresourcepathvalidationrule) | 资源定义 (`resource_definition`) | `GFConfigValidationRule` | 8 | `addons/gf/standard/utilities/config/validation/gf_config_resource_path_validation_rule.gd` |
| [`GFConfigSetValidationRule`](GFConfigSetValidationRule.md#gfconfigsetvalidationrule) | 资源定义 (`resource_definition`) | `GFConfigValidationRule` | 5 | `addons/gf/standard/utilities/config/validation/gf_config_set_validation_rule.gd` |
| [`GFConfigSizeValidationRule`](GFConfigSizeValidationRule.md#gfconfigsizevalidationrule) | 资源定义 (`resource_definition`) | `GFConfigValidationRule` | 8 | `addons/gf/standard/utilities/config/validation/gf_config_size_validation_rule.gd` |
| [`GFConfigTableColumn`](GFConfigTableColumn.md#gfconfigtablecolumn) | 资源定义 (`resource_definition`) | `Resource` | 14 | `addons/gf/standard/utilities/config/gf_config_table_column.gd` |
| [`GFConfigTableIndexDefinition`](GFConfigTableIndexDefinition.md#gfconfigtableindexdefinition) | 资源定义 (`resource_definition`) | `Resource` | 10 | `addons/gf/standard/utilities/config/gf_config_table_index_definition.gd` |
| [`GFConfigTableMergePolicy`](GFConfigTableMergePolicy.md#gfconfigtablemergepolicy) | 资源定义 (`resource_definition`) | `Resource` | 15 | `addons/gf/standard/utilities/config/gf_config_table_merge_policy.gd` |
| [`GFConfigTableReference`](GFConfigTableReference.md#gfconfigtablereference) | 资源定义 (`resource_definition`) | `Resource` | 14 | `addons/gf/standard/utilities/config/gf_config_table_reference.gd` |
| [`GFConfigTableSchema`](GFConfigTableSchema.md#gfconfigtableschema) | 资源定义 (`resource_definition`) | `Resource` | 28 | `addons/gf/standard/utilities/config/gf_config_table_schema.gd` |
| [`GFConsoleCommandDefinition`](GFConsoleCommandDefinition.md#gfconsolecommanddefinition) | 资源定义 (`resource_definition`) | `Resource` | 5 | `addons/gf/standard/utilities/debug/gf_console_command_definition.gd` |
| [`GFDictionarySchema`](GFDictionarySchema.md#gfdictionaryschema) | 资源定义 (`resource_definition`) | `Resource` | 18 | `addons/gf/standard/foundation/schema/gf_dictionary_schema.gd` |
| [`GFFormulaSet`](GFFormulaSet.md#gfformulaset) | 资源定义 (`resource_definition`) | `Resource` | 5 | `addons/gf/standard/foundation/formula/gf_formula_set.gd` |
| [`GFGridGenerationPipeline2D`](GFGridGenerationPipeline2D.md#gfgridgenerationpipeline2d) | 资源定义 (`resource_definition`) | `Resource` | 12 | `addons/gf/standard/foundation/math/gf_grid_generation_pipeline_2d.gd` |
| [`GFGridGenerationStep2D`](GFGridGenerationStep2D.md#gfgridgenerationstep2d) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/standard/foundation/math/gf_grid_generation_step_2d.gd` |
| [`GFInputAction`](GFInputAction.md#gfinputaction) | 资源定义 (`resource_definition`) | `Resource` | 10 | `addons/gf/standard/input/mapping/gf_input_action.gd` |
| [`GFInputBinding`](GFInputBinding.md#gfinputbinding) | 资源定义 (`resource_definition`) | `Resource` | 14 | `addons/gf/standard/input/mapping/gf_input_binding.gd` |
| [`GFInputChordTrigger`](GFInputChordTrigger.md#gfinputchordtrigger) | 资源定义 (`resource_definition`) | `GFInputTrigger` | 4 | `addons/gf/standard/input/triggers/gf_input_chord_trigger.gd` |
| [`GFInputContext`](GFInputContext.md#gfinputcontext) | 资源定义 (`resource_definition`) | `Resource` | 5 | `addons/gf/standard/input/mapping/gf_input_context.gd` |
| [`GFInputCurveModifier`](GFInputCurveModifier.md#gfinputcurvemodifier) | 资源定义 (`resource_definition`) | `GFInputModifier` | 7 | `addons/gf/standard/input/modifiers/gf_input_curve_modifier.gd` |
| [`GFInputDeadzoneModifier`](GFInputDeadzoneModifier.md#gfinputdeadzonemodifier) | 资源定义 (`resource_definition`) | `GFInputModifier` | 5 | `addons/gf/standard/input/modifiers/gf_input_deadzone_modifier.gd` |
| [`GFInputDeviceAssignment`](GFInputDeviceAssignment.md#gfinputdeviceassignment) | 资源定义 (`resource_definition`) | `Resource` | 6 | `addons/gf/standard/input/runtime/gf_input_device_assignment.gd` |
| [`GFInputDeviceTextProvider`](GFInputDeviceTextProvider.md#gfinputdevicetextprovider) | 资源定义 (`resource_definition`) | `GFInputTextProvider` | 9 | `addons/gf/standard/input/formatting/gf_input_device_text_provider.gd` |
| [`GFInputHoldTrigger`](GFInputHoldTrigger.md#gfinputholdtrigger) | 资源定义 (`resource_definition`) | `GFInputTrigger` | 3 | `addons/gf/standard/input/triggers/gf_input_hold_trigger.gd` |
| [`GFInputIconAtlasProvider`](GFInputIconAtlasProvider.md#gfinputiconatlasprovider) | 资源定义 (`resource_definition`) | `GFInputIconProvider` | 18 | `addons/gf/standard/input/formatting/gf_input_icon_atlas_provider.gd` |
| [`GFInputMagnitudeModifier`](GFInputMagnitudeModifier.md#gfinputmagnitudemodifier) | 资源定义 (`resource_definition`) | `GFInputModifier` | 7 | `addons/gf/standard/input/modifiers/gf_input_magnitude_modifier.gd` |
| [`GFInputMapRangeModifier`](GFInputMapRangeModifier.md#gfinputmaprangemodifier) | 资源定义 (`resource_definition`) | `GFInputModifier` | 7 | `addons/gf/standard/input/modifiers/gf_input_map_range_modifier.gd` |
| [`GFInputMapping`](GFInputMapping.md#gfinputmapping) | 资源定义 (`resource_definition`) | `Resource` | 9 | `addons/gf/standard/input/mapping/gf_input_mapping.gd` |
| [`GFInputNormalizeModifier`](GFInputNormalizeModifier.md#gfinputnormalizemodifier) | 资源定义 (`resource_definition`) | `GFInputModifier` | 3 | `addons/gf/standard/input/modifiers/gf_input_normalize_modifier.gd` |
| [`GFInputPressedTrigger`](GFInputPressedTrigger.md#gfinputpressedtrigger) | 资源定义 (`resource_definition`) | `GFInputTrigger` | 2 | `addons/gf/standard/input/triggers/gf_input_pressed_trigger.gd` |
| [`GFInputProfileBank`](GFInputProfileBank.md#gfinputprofilebank) | 资源定义 (`resource_definition`) | `Resource` | 13 | `addons/gf/standard/input/mapping/gf_input_profile_bank.gd` |
| [`GFInputPulseTrigger`](GFInputPulseTrigger.md#gfinputpulsetrigger) | 资源定义 (`resource_definition`) | `GFInputTrigger` | 4 | `addons/gf/standard/input/triggers/gf_input_pulse_trigger.gd` |
| [`GFInputReleasedTrigger`](GFInputReleasedTrigger.md#gfinputreleasedtrigger) | 资源定义 (`resource_definition`) | `GFInputTrigger` | 2 | `addons/gf/standard/input/triggers/gf_input_released_trigger.gd` |
| [`GFInputRemapConfig`](GFInputRemapConfig.md#gfinputremapconfig) | 资源定义 (`resource_definition`) | `Resource` | 13 | `addons/gf/standard/input/rebinding/gf_input_remap_config.gd` |
| [`GFInputScaleModifier`](GFInputScaleModifier.md#gfinputscalemodifier) | 资源定义 (`resource_definition`) | `GFInputModifier` | 5 | `addons/gf/standard/input/modifiers/gf_input_scale_modifier.gd` |
| [`GFInputSequenceBranch`](GFInputSequenceBranch.md#gfinputsequencebranch) | 资源定义 (`resource_definition`) | `Resource` | 5 | `addons/gf/standard/input/sequences/gf_input_sequence_branch.gd` |
| [`GFInputSequenceStep`](GFInputSequenceStep.md#gfinputsequencestep) | 资源定义 (`resource_definition`) | `Resource` | 6 | `addons/gf/standard/input/sequences/gf_input_sequence_step.gd` |
| [`GFInputSequenceTrigger`](GFInputSequenceTrigger.md#gfinputsequencetrigger) | 资源定义 (`resource_definition`) | `GFInputTrigger` | 7 | `addons/gf/standard/input/sequences/gf_input_sequence_trigger.gd` |
| [`GFInputSignClampModifier`](GFInputSignClampModifier.md#gfinputsignclampmodifier) | 资源定义 (`resource_definition`) | `GFInputModifier` | 8 | `addons/gf/standard/input/modifiers/gf_input_sign_clamp_modifier.gd` |
| [`GFInputSwizzleModifier`](GFInputSwizzleModifier.md#gfinputswizzlemodifier) | 资源定义 (`resource_definition`) | `GFInputModifier` | 4 | `addons/gf/standard/input/modifiers/gf_input_swizzle_modifier.gd` |
| [`GFInputTapTrigger`](GFInputTapTrigger.md#gfinputtaptrigger) | 资源定义 (`resource_definition`) | `GFInputTrigger` | 4 | `addons/gf/standard/input/triggers/gf_input_tap_trigger.gd` |
| [`GFInputVirtualCursorModifier`](GFInputVirtualCursorModifier.md#gfinputvirtualcursormodifier) | 资源定义 (`resource_definition`) | `GFInputModifier` | 12 | `addons/gf/standard/input/modifiers/gf_input_virtual_cursor_modifier.gd` |
| [`GFModalAction`](GFModalAction.md#gfmodalaction) | 资源定义 (`resource_definition`) | `Resource` | 9 | `addons/gf/standard/utilities/ui/gf_modal_action.gd` |
| [`GFModalConfig`](GFModalConfig.md#gfmodalconfig) | 资源定义 (`resource_definition`) | `Resource` | 11 | `addons/gf/standard/utilities/ui/gf_modal_config.gd` |
| [`GFNodeStateMachineConfig`](GFNodeStateMachineConfig.md#gfnodestatemachineconfig) | 资源定义 (`resource_definition`) | `Resource` | 4 | `addons/gf/standard/state_machine/node/gf_node_state_machine_config.gd` |
| [`GFPattern2D`](GFPattern2D.md#gfpattern2d) | 资源定义 (`resource_definition`) | `Resource` | 11 | `addons/gf/standard/foundation/math/gf_pattern_2d.gd` |
| [`GFRenderWarmupManifest`](GFRenderWarmupManifest.md#gfrenderwarmupmanifest) | 资源定义 (`resource_definition`) | `Resource` | 12 | `addons/gf/standard/utilities/display/gf_render_warmup_manifest.gd` |
| [`GFResourceRegistry`](GFResourceRegistry.md#gfresourceregistry) | 资源定义 (`resource_definition`) | `Resource` | 23 | `addons/gf/standard/utilities/assets/gf_resource_registry.gd` |
| [`GFResourceRegistryEntry`](GFResourceRegistryEntry.md#gfresourceregistryentry) | 资源定义 (`resource_definition`) | `Resource` | 9 | `addons/gf/standard/utilities/assets/gf_resource_registry_entry.gd` |
| [`GFRuntimeTunableProperty`](GFRuntimeTunableProperty.md#gfruntimetunableproperty) | 资源定义 (`resource_definition`) | `Resource` | 25 | `addons/gf/standard/utilities/debug/gf_runtime_tunable_property.gd` |
| [`GFScenePreloadEntry`](GFScenePreloadEntry.md#gfscenepreloadentry) | 资源定义 (`resource_definition`) | `Resource` | 7 | `addons/gf/standard/utilities/scene/gf_scene_preload_entry.gd` |
| [`GFScenePreloadMap`](GFScenePreloadMap.md#gfscenepreloadmap) | 资源定义 (`resource_definition`) | `Resource` | 10 | `addons/gf/standard/utilities/scene/gf_scene_preload_map.gd` |
| [`GFSceneTransitionConfig`](GFSceneTransitionConfig.md#gfscenetransitionconfig) | 资源定义 (`resource_definition`) | `Resource` | 11 | `addons/gf/standard/utilities/scene/gf_scene_transition_config.gd` |
| [`GFSchemaField`](GFSchemaField.md#gfschemafield) | 资源定义 (`resource_definition`) | `Resource` | 18 | `addons/gf/standard/foundation/schema/gf_schema_field.gd` |
| [`GFScreenTransitionEffect`](GFScreenTransitionEffect.md#gfscreentransitioneffect) | 资源定义 (`resource_definition`) | `Resource` | 16 | `addons/gf/standard/utilities/scene/gf_screen_transition_effect.gd` |
| [`GFSettingDefinition`](GFSettingDefinition.md#gfsettingdefinition) | 资源定义 (`resource_definition`) | `Resource` | 10 | `addons/gf/standard/utilities/settings/gf_setting_definition.gd` |
| [`GFShaderParameterProfile`](GFShaderParameterProfile.md#gfshaderparameterprofile) | 资源定义 (`resource_definition`) | `Resource` | 14 | `addons/gf/standard/utilities/display/gf_shader_parameter_profile.gd` |
| [`GFSignalBridge`](GFSignalBridge.md#gfsignalbridge) | 资源定义 (`resource_definition`) | `Resource` | 15 | `addons/gf/standard/utilities/signals/bridge/gf_signal_bridge.gd` |
| [`GFSignalSourceRef`](GFSignalSourceRef.md#gfsignalsourceref) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/standard/utilities/signals/bridge/gf_signal_source_ref.gd` |
| [`GFSteeringBehaviorResource`](GFSteeringBehaviorResource.md#gfsteeringbehaviorresource) | 资源定义 (`resource_definition`) | `Resource` | 20 | `addons/gf/standard/foundation/math/gf_steering_behavior_resource.gd` |
| [`GFSteeringBehaviorStack`](GFSteeringBehaviorStack.md#gfsteeringbehaviorstack) | 资源定义 (`resource_definition`) | `Resource` | 10 | `addons/gf/standard/foundation/math/gf_steering_behavior_stack.gd` |
| [`GFStorageCodec`](GFStorageCodec.md#gfstoragecodec) | 资源定义 (`resource_definition`) | `Resource` | 28 | `addons/gf/standard/utilities/storage/gf_storage_codec.gd` |
| [`GFTagExpression`](GFTagExpression.md#gftagexpression) | 资源定义 (`resource_definition`) | `Resource` | 15 | `addons/gf/standard/foundation/tags/gf_tag_expression.gd` |
| [`GFTagQuery`](GFTagQuery.md#gftagquery) | 资源定义 (`resource_definition`) | `Resource` | 11 | `addons/gf/standard/foundation/tags/gf_tag_query.gd` |
| [`GFTagSet`](GFTagSet.md#gftagset) | 资源定义 (`resource_definition`) | `Resource` | 12 | `addons/gf/standard/foundation/tags/gf_tag_set.gd` |
| [`GFTileMapCache`](GFTileMapCache.md#gftilemapcache) | 资源定义 (`resource_definition`) | `Resource` | 11 | `addons/gf/standard/foundation/math/gf_tile_map_cache.gd` |
| [`GFTileMetadataLayer`](GFTileMetadataLayer.md#gftilemetadatalayer) | 资源定义 (`resource_definition`) | `GFTileMapCache` | 15 | `addons/gf/standard/foundation/math/gf_tile_metadata_layer.gd` |
| [`GFTileRuleSet`](GFTileRuleSet.md#gftileruleset) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/standard/foundation/math/gf_tile_rule_set.gd` |
| [`GFTimedTextEntry`](GFTimedTextEntry.md#gftimedtextentry) | 资源定义 (`resource_definition`) | `Resource` | 9 | `addons/gf/standard/foundation/timeline/gf_timed_text_entry.gd` |
| [`GFTimedTextTrack`](GFTimedTextTrack.md#gftimedtexttrack) | 资源定义 (`resource_definition`) | `Resource` | 13 | `addons/gf/standard/foundation/timeline/gf_timed_text_track.gd` |
| [`GFUIRoute`](GFUIRoute.md#gfuiroute) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/standard/utilities/ui/gf_ui_route.gd` |
| [`GFValidationSuite`](GFValidationSuite.md#gfvalidationsuite) | 资源定义 (`resource_definition`) | `Resource` | 23 | `addons/gf/standard/foundation/validation/gf_validation_suite.gd` |
| [`GFWaitSequenceStep`](GFWaitSequenceStep.md#gfwaitsequencestep) | 资源定义 (`resource_definition`) | `GFSequenceStep` | 3 | `addons/gf/standard/sequence/gf_wait_sequence_step.gd` |
| [`GFWeightedEntry`](GFWeightedEntry.md#gfweightedentry) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/standard/foundation/math/gf_weighted_entry.gd` |
| [`GFWeightedTable`](GFWeightedTable.md#gfweightedtable) | 资源定义 (`resource_definition`) | `Resource` | 17 | `addons/gf/standard/foundation/math/gf_weighted_table.gd` |
| [`GFAssetHandle`](GFAssetHandle.md#gfassethandle) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 9 | `addons/gf/standard/utilities/assets/gf_asset_handle.gd` |
| [`GFAsyncBatch`](GFAsyncBatch.md#gfasyncbatch) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 11 | `addons/gf/standard/utilities/io/gf_async_batch.gd` |
| [`GFAudioBankMounter`](GFAudioBankMounter.md#gfaudiobankmounter) | 运行时句柄 (`runtime_handle`) | `Node` | 12 | `addons/gf/standard/utilities/audio/gf_audio_bank_mounter.gd` |
| [`GFAudioBeatClock`](GFAudioBeatClock.md#gfaudiobeatclock) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 33 | `addons/gf/standard/utilities/audio/gf_audio_beat_clock.gd` |
| [`GFAudioEmitterHandle`](GFAudioEmitterHandle.md#gfaudioemitterhandle) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 19 | `addons/gf/standard/utilities/audio/gf_audio_emitter_handle.gd` |
| [`GFBackgroundWorkTask`](GFBackgroundWorkTask.md#gfbackgroundworktask) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 22 | `addons/gf/standard/utilities/jobs/gf_background_work_task.gd` |
| [`GFDownloadTask`](GFDownloadTask.md#gfdownloadtask) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 23 | `addons/gf/standard/utilities/io/gf_download_task.gd` |
| [`GFDragSession`](GFDragSession.md#gfdragsession) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 12 | `addons/gf/standard/input/drag_drop/gf_drag_session.gd` |
| [`GFFormBinder`](GFFormBinder.md#gfformbinder) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 9 | `addons/gf/standard/utilities/ui/gf_form_binder.gd` |
| [`GFHttpRequestBuilder`](GFHttpRequestBuilder.md#gfhttprequestbuilder) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 21 | `addons/gf/standard/utilities/io/gf_http_request_builder.gd` |
| [`GFHttpResponse`](GFHttpResponse.md#gfhttpresponse) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 23 | `addons/gf/standard/utilities/io/gf_http_response.gd` |
| [`GFJob`](GFJob.md#gfjob) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 15 | `addons/gf/standard/utilities/jobs/gf_job.gd` |
| [`GFNodeStateGroup`](GFNodeStateGroup.md#gfnodestategroup) | 运行时句柄 (`runtime_handle`) | `Node` | 35 | `addons/gf/standard/state_machine/node/gf_node_state_group.gd` |
| [`GFShaderParameterBinder`](GFShaderParameterBinder.md#gfshaderparameterbinder) | 运行时句柄 (`runtime_handle`) | `Node` | 14 | `addons/gf/standard/utilities/display/gf_shader_parameter_binder.gd` |
| [`GFSignalBridgeBinding`](GFSignalBridgeBinding.md#gfsignalbridgebinding) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 5 | `addons/gf/standard/utilities/signals/bridge/gf_signal_bridge_binding.gd` |
| [`GFSignalConnection`](GFSignalConnection.md#gfsignalconnection) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 18 | `addons/gf/standard/utilities/signals/gf_signal_connection.gd` |
| [`GFVirtualInputSource`](GFVirtualInputSource.md#gfvirtualinputsource) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 14 | `addons/gf/standard/input/sources/gf_virtual_input_source.gd` |
| [`GFAudioBackendCapability`](GFAudioBackendCapability.md#gfaudiobackendcapability) | 值对象 (`value_object`) | `Resource` | 14 | `addons/gf/standard/utilities/audio/gf_audio_backend_capability.gd` |
| [`GFBigNumber`](GFBigNumber.md#gfbignumber) | 值对象 (`value_object`) | `RefCounted` | 23 | `addons/gf/standard/foundation/numeric/gf_big_number.gd` |
| [`GFBuildInfo`](GFBuildInfo.md#gfbuildinfo) | 值对象 (`value_object`) | `Resource` | 31 | `addons/gf/standard/utilities/debug/gf_build_info.gd` |
| [`GFConfigValidationReport`](GFConfigValidationReport.md#gfconfigvalidationreport) | 值对象 (`value_object`) | `RefCounted` | 6 | `addons/gf/standard/utilities/config/gf_config_validation_report.gd` |
| [`GFDirectoryChangeSet`](GFDirectoryChangeSet.md#gfdirectorychangeset) | 值对象 (`value_object`) | `RefCounted` | 13 | `addons/gf/standard/utilities/io/gf_directory_change_set.gd` |
| [`GFFixedDecimal`](GFFixedDecimal.md#gffixeddecimal) | 值对象 (`value_object`) | `RefCounted` | 20 | `addons/gf/standard/foundation/numeric/gf_fixed_decimal.gd` |
| [`GFFormulaParameter`](GFFormulaParameter.md#gfformulaparameter) | 值对象 (`value_object`) | `RefCounted` | 8 | `addons/gf/standard/foundation/formula/gf_formula_parameter.gd` |
| [`GFMetricSeries`](GFMetricSeries.md#gfmetricseries) | 值对象 (`value_object`) | `RefCounted` | 20 | `addons/gf/standard/utilities/debug/gf_metric_series.gd` |
| [`GFModalResult`](GFModalResult.md#gfmodalresult) | 值对象 (`value_object`) | `RefCounted` | 10 | `addons/gf/standard/utilities/ui/gf_modal_result.gd` |
| [`GFResultDictionary`](GFResultDictionary.md#gfresultdictionary) | 值对象 (`value_object`) | `RefCounted` | 21 | `addons/gf/standard/foundation/validation/gf_result_dictionary.gd` |
| [`GFSequenceContext`](GFSequenceContext.md#gfsequencecontext) | 值对象 (`value_object`) | `RefCounted` | 6 | `addons/gf/standard/sequence/gf_sequence_context.gd` |
| [`GFSourceSpan`](GFSourceSpan.md#gfsourcespan) | 值对象 (`value_object`) | `RefCounted` | 23 | `addons/gf/standard/foundation/validation/gf_source_span.gd` |
| [`GFSteeringAcceleration`](GFSteeringAcceleration.md#gfsteeringacceleration) | 值对象 (`value_object`) | `RefCounted` | 8 | `addons/gf/standard/foundation/math/gf_steering_acceleration.gd` |
| [`GFSteeringAgent`](GFSteeringAgent.md#gfsteeringagent) | 值对象 (`value_object`) | `RefCounted` | 12 | `addons/gf/standard/foundation/math/gf_steering_agent.gd` |
| [`GFStorageConflictReport`](GFStorageConflictReport.md#gfstorageconflictreport) | 值对象 (`value_object`) | `Resource` | 13 | `addons/gf/standard/utilities/storage/gf_storage_conflict_report.gd` |
| [`GFUuid`](GFUuid.md#gfuuid) | 值对象 (`value_object`) | `RefCounted` | 5 | `addons/gf/standard/foundation/identity/gf_uuid.gd` |
| [`GFValidationIssue`](GFValidationIssue.md#gfvalidationissue) | 值对象 (`value_object`) | `RefCounted` | 32 | `addons/gf/standard/foundation/validation/gf_validation_issue.gd` |
| [`GFValidationReport`](GFValidationReport.md#gfvalidationreport) | 值对象 (`value_object`) | `RefCounted` | 28 | `addons/gf/standard/foundation/validation/gf_validation_report.gd` |
| [`GFDropZone`](GFDropZone.md#gfdropzone) | 领域模型 (`domain_model`) | `RefCounted` | 14 | `addons/gf/standard/input/drag_drop/gf_drop_zone.gd` |
| [`GFInputDirectionHistory`](GFInputDirectionHistory.md#gfinputdirectionhistory) | 领域模型 (`domain_model`) | `RefCounted` | 9 | `addons/gf/standard/input/history/gf_input_direction_history.gd` |
| [`GFInputRecording`](GFInputRecording.md#gfinputrecording) | 领域模型 (`domain_model`) | `RefCounted` | 14 | `addons/gf/standard/input/recording/gf_input_recording.gd` |
| [`GFReplayTimeline`](GFReplayTimeline.md#gfreplaytimeline) | 领域模型 (`domain_model`) | `RefCounted` | 23 | `addons/gf/standard/foundation/timeline/gf_replay_timeline.gd` |
| [`GFAudioEvent`](GFAudioEvent.md#gfaudioevent) | 事件契约 (`event_contract`) | `Resource` | 9 | `addons/gf/standard/utilities/audio/gf_audio_event.gd` |
| [`GFAudioParameter`](GFAudioParameter.md#gfaudioparameter) | 事件契约 (`event_contract`) | `Resource` | 5 | `addons/gf/standard/utilities/audio/gf_audio_parameter.gd` |
| [`GFAudioState`](GFAudioState.md#gfaudiostate) | 事件契约 (`event_contract`) | `Resource` | 4 | `addons/gf/standard/utilities/audio/gf_audio_state.gd` |
| [`GFAudioSwitch`](GFAudioSwitch.md#gfaudioswitch) | 事件契约 (`event_contract`) | `Resource` | 5 | `addons/gf/standard/utilities/audio/gf_audio_switch.gd` |
| [`GFRequestEnvelope`](GFRequestEnvelope.md#gfrequestenvelope) | 事件契约 (`event_contract`) | `RefCounted` | 24 | `addons/gf/standard/utilities/io/gf_request_envelope.gd` |
| [`GFBuildInfoExportPlugin`](GFBuildInfoExportPlugin.md#gfbuildinfoexportplugin) | 编辑器 API (`editor_api`) | `EditorExportPlugin` | 4 | `addons/gf/standard/utilities/debug/editor/gf_build_info_export_plugin.gd` |
| [`GFDiagnosticsDock`](GFDiagnosticsDock.md#gfdiagnosticsdock) | 编辑器 API (`editor_api`) | `Control` | 3 | `addons/gf/standard/utilities/debug/editor/gf_diagnostics_dock.gd` |
| [`GFInputMappingDock`](GFInputMappingDock.md#gfinputmappingdock) | 编辑器 API (`editor_api`) | `Control` | 4 | `addons/gf/standard/input/editor/gf_input_mapping_dock.gd` |
| [`GFNodeStateMachineDock`](GFNodeStateMachineDock.md#gfnodestatemachinedock) | 编辑器 API (`editor_api`) | `Control` | 4 | `addons/gf/standard/state_machine/node/editor/gf_node_state_machine_dock.gd` |
| [`GFSignalGraphDock`](GFSignalGraphDock.md#gfsignalgraphdock) | 编辑器 API (`editor_api`) | `Control` | 6 | `addons/gf/standard/utilities/debug/editor/gf_signal_graph_dock.gd` |
| [`GFStorageViewerDock`](GFStorageViewerDock.md#gfstorageviewerdock) | 编辑器 API (`editor_api`) | `VBoxContainer` | 0 | `addons/gf/standard/utilities/storage/editor/gf_storage_viewer_dock.gd` |

<a id="module-extensions-action_queue"></a>

### Action Queue

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFAction`](GFAction.md#gfaction) | 运行时服务 (`runtime_service`) | `RefCounted` | 24 | `addons/gf/extensions/action_queue/core/gf_action.gd` |
| [`GFActionQueueSystem`](GFActionQueueSystem.md#gfactionqueuesystem) | 运行时服务 (`runtime_service`) | `GFSystem` | 33 | `addons/gf/extensions/action_queue/core/gf_action_queue_system.gd` |
| [`GFActionInterceptor`](GFActionInterceptor.md#gfactioninterceptor) | 协议与扩展点 (`protocol`) | `RefCounted` | 4 | `addons/gf/extensions/action_queue/core/gf_action_interceptor.gd` |
| [`GFVisualAction`](GFVisualAction.md#gfvisualaction) | 协议与扩展点 (`protocol`) | `RefCounted` | 17 | `addons/gf/extensions/action_queue/actions/gf_visual_action.gd` |
| [`GFTweenActionConfig`](GFTweenActionConfig.md#gftweenactionconfig) | 资源定义 (`resource_definition`) | `Resource` | 17 | `addons/gf/extensions/action_queue/tween/gf_tween_action_config.gd` |
| [`GFTweenActionStep`](GFTweenActionStep.md#gftweenactionstep) | 资源定义 (`resource_definition`) | `Resource` | 15 | `addons/gf/extensions/action_queue/tween/gf_tween_action_step.gd` |
| [`GFAudioAction`](GFAudioAction.md#gfaudioaction) | 运行时句柄 (`runtime_handle`) | `GFVisualAction` | 5 | `addons/gf/extensions/action_queue/actions/gf_audio_action.gd` |
| [`GFCallableAction`](GFCallableAction.md#gfcallableaction) | 运行时句柄 (`runtime_handle`) | `GFVisualAction` | 3 | `addons/gf/extensions/action_queue/actions/gf_callable_action.gd` |
| [`GFConfiguredTweenAction`](GFConfiguredTweenAction.md#gfconfiguredtweenaction) | 运行时句柄 (`runtime_handle`) | `GFVisualAction` | 10 | `addons/gf/extensions/action_queue/actions/gf_configured_tween_action.gd` |
| [`GFFlashAction`](GFFlashAction.md#gfflashaction) | 运行时句柄 (`runtime_handle`) | `GFVisualAction` | 7 | `addons/gf/extensions/action_queue/actions/gf_flash_action.gd` |
| [`GFMoveTweenAction`](GFMoveTweenAction.md#gfmovetweenaction) | 运行时句柄 (`runtime_handle`) | `GFVisualAction` | 12 | `addons/gf/extensions/action_queue/actions/gf_move_tween_action.gd` |
| [`GFRepeatAction`](GFRepeatAction.md#gfrepeataction) | 运行时句柄 (`runtime_handle`) | `GFVisualAction` | 10 | `addons/gf/extensions/action_queue/actions/gf_repeat_action.gd` |
| [`GFShaderParameterAction`](GFShaderParameterAction.md#gfshaderparameteraction) | 运行时句柄 (`runtime_handle`) | `GFVisualAction` | 17 | `addons/gf/extensions/action_queue/actions/gf_shader_parameter_action.gd` |
| [`GFVisualActionGroup`](GFVisualActionGroup.md#gfvisualactiongroup) | 运行时句柄 (`runtime_handle`) | `GFVisualAction` | 11 | `addons/gf/extensions/action_queue/actions/gf_visual_action_group.gd` |
| [`GFWaitAction`](GFWaitAction.md#gfwaitaction) | 运行时句柄 (`runtime_handle`) | `GFVisualAction` | 9 | `addons/gf/extensions/action_queue/actions/gf_wait_action.gd` |
| [`GFActionInterceptionResult`](GFActionInterceptionResult.md#gfactioninterceptionresult) | 值对象 (`value_object`) | `RefCounted` | 12 | `addons/gf/extensions/action_queue/core/gf_action_interception_result.gd` |

<a id="module-extensions-asset_metadata"></a>

### Asset Metadata

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFAssetMetadataUtility`](GFAssetMetadataUtility.md#gfassetmetadatautility) | 运行时服务 (`runtime_service`) | `GFUtility` | 10 | `addons/gf/extensions/asset_metadata/runtime/gf_asset_metadata_utility.gd` |
| [`GFAssetMetadataRecord`](GFAssetMetadataRecord.md#gfassetmetadatarecord) | 资源定义 (`resource_definition`) | `Resource` | 12 | `addons/gf/extensions/asset_metadata/resources/gf_asset_metadata_record.gd` |
| [`GFAssetMetadataGltfDocumentExtension`](GFAssetMetadataGltfDocumentExtension.md#gfassetmetadatagltfdocumentextension) | 编辑器 API (`editor_api`) | `GLTFDocumentExtension` | 1 | `addons/gf/extensions/asset_metadata/editor/gf_asset_metadata_gltf_document_extension.gd` |

<a id="module-extensions-behavior_tree"></a>

### Behavior Tree

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFBehaviorTree`](GFBehaviorTree.md#gfbehaviortree) | 协议与扩展点 (`protocol`) | `Object` | 4 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.BTNode`](GFBehaviorTree.md#gfbehaviortreebtnode) | 协议与扩展点 (`protocol`) | `RefCounted` | 13 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Decorator`](GFBehaviorTree.md#gfbehaviortreedecorator) | 协议与扩展点 (`protocol`) | `BTNode` | 3 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Runner`](GFBehaviorTree.md#gfbehaviortreerunner) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 6 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Action`](GFBehaviorTree.md#gfbehaviortreeaction) | 领域模型 (`domain_model`) | `BTNode` | 2 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.AlwaysFail`](GFBehaviorTree.md#gfbehaviortreealwaysfail) | 领域模型 (`domain_model`) | `Decorator` | 2 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.AlwaysSucceed`](GFBehaviorTree.md#gfbehaviortreealwayssucceed) | 领域模型 (`domain_model`) | `Decorator` | 2 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.BlackboardScope`](GFBehaviorTree.md#gfbehaviortreeblackboardscope) | 领域模型 (`domain_model`) | `RefCounted` | 6 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Condition`](GFBehaviorTree.md#gfbehaviortreecondition) | 领域模型 (`domain_model`) | `BTNode` | 2 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Cooldown`](GFBehaviorTree.md#gfbehaviortreecooldown) | 领域模型 (`domain_model`) | `Decorator` | 5 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Inverter`](GFBehaviorTree.md#gfbehaviortreeinverter) | 领域模型 (`domain_model`) | `Decorator` | 2 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Limit`](GFBehaviorTree.md#gfbehaviortreelimit) | 领域模型 (`domain_model`) | `Decorator` | 4 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Parallel`](GFBehaviorTree.md#gfbehaviortreeparallel) | 领域模型 (`domain_model`) | `BTNode` | 4 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Probability`](GFBehaviorTree.md#gfbehaviortreeprobability) | 领域模型 (`domain_model`) | `Decorator` | 5 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.RandomSelector`](GFBehaviorTree.md#gfbehaviortreerandomselector) | 领域模型 (`domain_model`) | `BTNode` | 4 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.RandomSequence`](GFBehaviorTree.md#gfbehaviortreerandomsequence) | 领域模型 (`domain_model`) | `BTNode` | 4 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Repeat`](GFBehaviorTree.md#gfbehaviortreerepeat) | 领域模型 (`domain_model`) | `Decorator` | 4 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Selector`](GFBehaviorTree.md#gfbehaviortreeselector) | 领域模型 (`domain_model`) | `BTNode` | 3 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Sequence`](GFBehaviorTree.md#gfbehaviortreesequence) | 领域模型 (`domain_model`) | `BTNode` | 3 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.TimeLimit`](GFBehaviorTree.md#gfbehaviortreetimelimit) | 领域模型 (`domain_model`) | `Decorator` | 4 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.UntilFail`](GFBehaviorTree.md#gfbehaviortreeuntilfail) | 领域模型 (`domain_model`) | `Decorator` | 2 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.UntilSuccess`](GFBehaviorTree.md#gfbehaviortreeuntilsuccess) | 领域模型 (`domain_model`) | `Decorator` | 2 | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |

<a id="module-extensions-camera"></a>

### Camera

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFCameraDirector2D`](GFCameraDirector2D.md#gfcameradirector2d) | 运行时服务 (`runtime_service`) | `Node` | 16 | `addons/gf/extensions/camera/nodes/gf_camera_director_2d.gd` |
| [`GFCameraDirector3D`](GFCameraDirector3D.md#gfcameradirector3d) | 运行时服务 (`runtime_service`) | `Node` | 16 | `addons/gf/extensions/camera/nodes/gf_camera_director_3d.gd` |
| [`GFCameraOrbitInput3D`](GFCameraOrbitInput3D.md#gfcameraorbitinput3d) | 运行时服务 (`runtime_service`) | `Node` | 24 | `addons/gf/extensions/camera/nodes/gf_camera_orbit_input_3d.gd` |
| [`GFCameraBlend`](GFCameraBlend.md#gfcamerablend) | 资源定义 (`resource_definition`) | `Resource` | 6 | `addons/gf/extensions/camera/resources/gf_camera_blend.gd` |
| [`GFCameraOrbitRig3D`](GFCameraOrbitRig3D.md#gfcameraorbitrig3d) | 运行时句柄 (`runtime_handle`) | `GFCameraRig3D` | 18 | `addons/gf/extensions/camera/nodes/gf_camera_orbit_rig_3d.gd` |
| [`GFCameraRig2D`](GFCameraRig2D.md#gfcamerarig2d) | 运行时句柄 (`runtime_handle`) | `Node2D` | 16 | `addons/gf/extensions/camera/nodes/gf_camera_rig_2d.gd` |
| [`GFCameraRig3D`](GFCameraRig3D.md#gfcamerarig3d) | 运行时句柄 (`runtime_handle`) | `Node3D` | 19 | `addons/gf/extensions/camera/nodes/gf_camera_rig_3d.gd` |

<a id="module-extensions-capability"></a>

### Capability

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFCapabilityUtility`](GFCapabilityUtility.md#gfcapabilityutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 38 | `addons/gf/extensions/capability/core/gf_capability_utility.gd` |
| [`GFCapability`](GFCapability.md#gfcapability) | 协议与扩展点 (`protocol`) | `RefCounted` | 12 | `addons/gf/extensions/capability/core/gf_capability.gd` |
| [`GFControlCapability`](GFControlCapability.md#gfcontrolcapability) | 协议与扩展点 (`protocol`) | `Control` | 12 | `addons/gf/extensions/capability/nodes/gf_control_capability.gd` |
| [`GFNode2DCapability`](GFNode2DCapability.md#gfnode2dcapability) | 协议与扩展点 (`protocol`) | `Node2D` | 12 | `addons/gf/extensions/capability/nodes/gf_node_2d_capability.gd` |
| [`GFNode3DCapability`](GFNode3DCapability.md#gfnode3dcapability) | 协议与扩展点 (`protocol`) | `Node3D` | 12 | `addons/gf/extensions/capability/nodes/gf_node_3d_capability.gd` |
| [`GFNodeCapability`](GFNodeCapability.md#gfnodecapability) | 协议与扩展点 (`protocol`) | `Node` | 12 | `addons/gf/extensions/capability/nodes/gf_node_capability.gd` |
| [`GFCapabilityRecipe`](GFCapabilityRecipe.md#gfcapabilityrecipe) | 资源定义 (`resource_definition`) | `Resource` | 9 | `addons/gf/extensions/capability/recipes/gf_capability_recipe.gd` |
| [`GFCapabilityRecipeEntry`](GFCapabilityRecipeEntry.md#gfcapabilityrecipeentry) | 资源定义 (`resource_definition`) | `Resource` | 6 | `addons/gf/extensions/capability/recipes/gf_capability_recipe_entry.gd` |
| [`GFCapabilityContainer`](GFCapabilityContainer.md#gfcapabilitycontainer) | 运行时句柄 (`runtime_handle`) | `Node` | 4 | `addons/gf/extensions/capability/nodes/gf_capability_container.gd` |
| [`GFPropertyBagCapability`](GFPropertyBagCapability.md#gfpropertybagcapability) | 运行时句柄 (`runtime_handle`) | `GFCapability` | 14 | `addons/gf/extensions/capability/core/gf_property_bag_capability.gd` |

<a id="module-extensions-combat"></a>

### Combat

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFCombatSystem`](GFCombatSystem.md#gfcombatsystem) | 运行时服务 (`runtime_service`) | `GFSystem` | 13 | `addons/gf/extensions/combat/core/gf_combat_system.gd` |
| [`GFSkillTargetingUtility`](GFSkillTargetingUtility.md#gfskilltargetingutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 1 | `addons/gf/extensions/combat/skills/gf_skill_targeting_utility.gd` |
| [`GFBuff`](GFBuff.md#gfbuff) | 协议与扩展点 (`protocol`) | `RefCounted` | 22 | `addons/gf/extensions/combat/attributes/gf_buff.gd` |
| [`GFProjectileLifetimePolicy`](GFProjectileLifetimePolicy.md#gfprojectilelifetimepolicy) | 协议与扩展点 (`protocol`) | `Resource` | 7 | `addons/gf/extensions/combat/projectiles/gf_projectile_lifetime_policy.gd` |
| [`GFProjectileMotion`](GFProjectileMotion.md#gfprojectilemotion) | 协议与扩展点 (`protocol`) | `Resource` | 4 | `addons/gf/extensions/combat/projectiles/gf_projectile_motion.gd` |
| [`GFProjectileSpawnPattern2D`](GFProjectileSpawnPattern2D.md#gfprojectilespawnpattern2d) | 协议与扩展点 (`protocol`) | `Resource` | 2 | `addons/gf/extensions/combat/projectiles/gf_projectile_spawn_pattern_2d.gd` |
| [`GFProjectileSpawnPattern3D`](GFProjectileSpawnPattern3D.md#gfprojectilespawnpattern3d) | 协议与扩展点 (`protocol`) | `Resource` | 2 | `addons/gf/extensions/combat/projectiles/gf_projectile_spawn_pattern_3d.gd` |
| [`GFSkill`](GFSkill.md#gfskill) | 协议与扩展点 (`protocol`) | `RefCounted` | 22 | `addons/gf/extensions/combat/skills/gf_skill.gd` |
| [`GFCombatAction`](GFCombatAction.md#gfcombataction) | 资源定义 (`resource_definition`) | `Resource` | 17 | `addons/gf/extensions/combat/actions/gf_combat_action.gd` |
| [`GFCombatActionModifier`](GFCombatActionModifier.md#gfcombatactionmodifier) | 资源定义 (`resource_definition`) | `Resource` | 14 | `addons/gf/extensions/combat/actions/gf_combat_action_modifier.gd` |
| [`GFHitCollisionShapeConfig2D`](GFHitCollisionShapeConfig2D.md#gfhitcollisionshapeconfig2d) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/extensions/combat/hit_detection/gf_hit_collision_shape_config_2d.gd` |
| [`GFHitCollisionShapeConfig3D`](GFHitCollisionShapeConfig3D.md#gfhitcollisionshapeconfig3d) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/extensions/combat/hit_detection/gf_hit_collision_shape_config_3d.gd` |
| [`GFHomingProjectileMotion`](GFHomingProjectileMotion.md#gfhomingprojectilemotion) | 资源定义 (`resource_definition`) | `GFProjectileMotion` | 9 | `addons/gf/extensions/combat/projectiles/gf_homing_projectile_motion.gd` |
| [`GFLinearProjectileMotion`](GFLinearProjectileMotion.md#gflinearprojectilemotion) | 资源定义 (`resource_definition`) | `GFProjectileMotion` | 6 | `addons/gf/extensions/combat/projectiles/gf_linear_projectile_motion.gd` |
| [`GFProjectileBurstPattern2D`](GFProjectileBurstPattern2D.md#gfprojectileburstpattern2d) | 资源定义 (`resource_definition`) | `GFProjectileSpawnPattern2D` | 7 | `addons/gf/extensions/combat/projectiles/gf_projectile_burst_pattern_2d.gd` |
| [`GFProjectileCatalog`](GFProjectileCatalog.md#gfprojectilecatalog) | 资源定义 (`resource_definition`) | `Resource` | 7 | `addons/gf/extensions/combat/projectiles/gf_projectile_catalog.gd` |
| [`GFProjectileCatalogEntry`](GFProjectileCatalogEntry.md#gfprojectilecatalogentry) | 资源定义 (`resource_definition`) | `Resource` | 3 | `addons/gf/extensions/combat/projectiles/gf_projectile_catalog_entry.gd` |
| [`GFProjectileConePattern3D`](GFProjectileConePattern3D.md#gfprojectileconepattern3d) | 资源定义 (`resource_definition`) | `GFProjectileSpawnPattern3D` | 5 | `addons/gf/extensions/combat/projectiles/gf_projectile_cone_pattern_3d.gd` |
| [`GFProjectileLineSpawnPattern2D`](GFProjectileLineSpawnPattern2D.md#gfprojectilelinespawnpattern2d) | 资源定义 (`resource_definition`) | `GFProjectileSpawnPattern2D` | 5 | `addons/gf/extensions/combat/projectiles/gf_projectile_line_spawn_pattern_2d.gd` |
| [`GFProjectileLineSpawnPattern3D`](GFProjectileLineSpawnPattern3D.md#gfprojectilelinespawnpattern3d) | 资源定义 (`resource_definition`) | `GFProjectileSpawnPattern3D` | 5 | `addons/gf/extensions/combat/projectiles/gf_projectile_line_spawn_pattern_3d.gd` |
| [`GFSkillTargetingRule`](GFSkillTargetingRule.md#gfskilltargetingrule) | 资源定义 (`resource_definition`) | `Resource` | 12 | `addons/gf/extensions/combat/skills/gf_skill_targeting_rule.gd` |
| [`GFCombatGauge`](GFCombatGauge.md#gfcombatgauge) | 运行时句柄 (`runtime_handle`) | `Node` | 23 | `addons/gf/extensions/combat/attributes/gf_combat_gauge.gd` |
| [`GFHitBox2D`](GFHitBox2D.md#gfhitbox2d) | 运行时句柄 (`runtime_handle`) | `Area2D` | 24 | `addons/gf/extensions/combat/hit_detection/gf_hit_box_2d.gd` |
| [`GFHitBox3D`](GFHitBox3D.md#gfhitbox3d) | 运行时句柄 (`runtime_handle`) | `Area3D` | 24 | `addons/gf/extensions/combat/hit_detection/gf_hit_box_3d.gd` |
| [`GFHitBoxState2D`](GFHitBoxState2D.md#gfhitboxstate2d) | 运行时句柄 (`runtime_handle`) | `Node2D` | 12 | `addons/gf/extensions/combat/hit_detection/gf_hit_box_state_2d.gd` |
| [`GFHitBoxState3D`](GFHitBoxState3D.md#gfhitboxstate3d) | 运行时句柄 (`runtime_handle`) | `Node3D` | 12 | `addons/gf/extensions/combat/hit_detection/gf_hit_box_state_3d.gd` |
| [`GFHitScan2D`](GFHitScan2D.md#gfhitscan2d) | 运行时句柄 (`runtime_handle`) | `RayCast2D` | 14 | `addons/gf/extensions/combat/hit_detection/gf_hit_scan_2d.gd` |
| [`GFHitScan3D`](GFHitScan3D.md#gfhitscan3d) | 运行时句柄 (`runtime_handle`) | `RayCast3D` | 14 | `addons/gf/extensions/combat/hit_detection/gf_hit_scan_3d.gd` |
| [`GFHurtBox2D`](GFHurtBox2D.md#gfhurtbox2d) | 运行时句柄 (`runtime_handle`) | `Area2D` | 21 | `addons/gf/extensions/combat/hit_detection/gf_hurt_box_2d.gd` |
| [`GFHurtBox3D`](GFHurtBox3D.md#gfhurtbox3d) | 运行时句柄 (`runtime_handle`) | `Area3D` | 21 | `addons/gf/extensions/combat/hit_detection/gf_hurt_box_3d.gd` |
| [`GFModifiedAttribute`](GFModifiedAttribute.md#gfmodifiedattribute) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 7 | `addons/gf/extensions/combat/attributes/gf_modified_attribute.gd` |
| [`GFModifiedAttributeSet`](GFModifiedAttributeSet.md#gfmodifiedattributeset) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 22 | `addons/gf/extensions/combat/attributes/gf_modified_attribute_set.gd` |
| [`GFProjectile2D`](GFProjectile2D.md#gfprojectile2d) | 运行时句柄 (`runtime_handle`) | `GFHitBox2D` | 13 | `addons/gf/extensions/combat/projectiles/gf_projectile_2d.gd` |
| [`GFProjectile3D`](GFProjectile3D.md#gfprojectile3d) | 运行时句柄 (`runtime_handle`) | `GFHitBox3D` | 13 | `addons/gf/extensions/combat/projectiles/gf_projectile_3d.gd` |
| [`GFProjectileEmitter2D`](GFProjectileEmitter2D.md#gfprojectileemitter2d) | 运行时句柄 (`runtime_handle`) | `Node2D` | 18 | `addons/gf/extensions/combat/projectiles/gf_projectile_emitter_2d.gd` |
| [`GFProjectileEmitter3D`](GFProjectileEmitter3D.md#gfprojectileemitter3d) | 运行时句柄 (`runtime_handle`) | `Node3D` | 18 | `addons/gf/extensions/combat/projectiles/gf_projectile_emitter_3d.gd` |
| [`GFTagComponent`](GFTagComponent.md#gftagcomponent) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 8 | `addons/gf/extensions/combat/tags/gf_tag_component.gd` |
| [`GFCombatActionResult`](GFCombatActionResult.md#gfcombatactionresult) | 值对象 (`value_object`) | `RefCounted` | 10 | `addons/gf/extensions/combat/actions/gf_combat_action_result.gd` |
| [`GFCombatHitContext`](GFCombatHitContext.md#gfcombathitcontext) | 值对象 (`value_object`) | `RefCounted` | 19 | `addons/gf/extensions/combat/hit_detection/gf_combat_hit_context.gd` |
| [`GFModifier`](GFModifier.md#gfmodifier) | 值对象 (`value_object`) | `RefCounted` | 8 | `addons/gf/extensions/combat/attributes/gf_modifier.gd` |
| [`GFSkillActivationContext`](GFSkillActivationContext.md#gfskillactivationcontext) | 值对象 (`value_object`) | `RefCounted` | 12 | `addons/gf/extensions/combat/skills/gf_skill_activation_context.gd` |
| [`GFCombatPayloads`](GFCombatPayloads.md#gfcombatpayloads) | 事件契约 (`event_contract`) | `Node` | 0 | `addons/gf/extensions/combat/core/gf_combat_payloads.gd` |
| [`GFCombatPayloads.GFBuffAppliedPayload`](GFCombatPayloads.md#gfcombatpayloadsgfbuffappliedpayload) | 事件契约 (`event_contract`) | `GFPayload` | 2 | `addons/gf/extensions/combat/core/gf_combat_payloads.gd` |
| [`GFCombatPayloads.GFBuffRefreshedPayload`](GFCombatPayloads.md#gfcombatpayloadsgfbuffrefreshedpayload) | 事件契约 (`event_contract`) | `GFPayload` | 2 | `addons/gf/extensions/combat/core/gf_combat_payloads.gd` |
| [`GFCombatPayloads.GFBuffRemovedPayload`](GFCombatPayloads.md#gfcombatpayloadsgfbuffremovedpayload) | 事件契约 (`event_contract`) | `GFPayload` | 2 | `addons/gf/extensions/combat/core/gf_combat_payloads.gd` |

<a id="module-extensions-content_package"></a>

### Extensions / Content Package

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFContentPackageCatalog`](GFContentPackageCatalog.md#gfcontentpackagecatalog) | 运行时服务 (`runtime_service`) | `RefCounted` | 11 | `addons/gf/extensions/content_package/runtime/gf_content_package_catalog.gd` |
| [`GFContentPackageUtility`](GFContentPackageUtility.md#gfcontentpackageutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 12 | `addons/gf/extensions/content_package/runtime/gf_content_package_utility.gd` |
| [`GFContentPackageManifest`](GFContentPackageManifest.md#gfcontentpackagemanifest) | 资源定义 (`resource_definition`) | `Resource` | 22 | `addons/gf/extensions/content_package/resources/gf_content_package_manifest.gd` |

<a id="module-extensions-decision"></a>

### Decision

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFDecisionUtility`](GFDecisionUtility.md#gfdecisionutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 12 | `addons/gf/extensions/decision/runtime/gf_decision_utility.gd` |
| [`GFDecisionConsideration`](GFDecisionConsideration.md#gfdecisionconsideration) | 协议与扩展点 (`protocol`) | `Resource` | 15 | `addons/gf/extensions/decision/resources/gf_decision_consideration.gd` |
| [`GFDecisionOption`](GFDecisionOption.md#gfdecisionoption) | 资源定义 (`resource_definition`) | `Resource` | 15 | `addons/gf/extensions/decision/resources/gf_decision_option.gd` |
| [`GFDecisionSet`](GFDecisionSet.md#gfdecisionset) | 资源定义 (`resource_definition`) | `Resource` | 13 | `addons/gf/extensions/decision/resources/gf_decision_set.gd` |
| [`GFDecisionScore`](GFDecisionScore.md#gfdecisionscore) | 值对象 (`value_object`) | `RefCounted` | 8 | `addons/gf/extensions/decision/runtime/gf_decision_score.gd` |
| [`GFDecisionBlackboard`](GFDecisionBlackboard.md#gfdecisionblackboard) | 领域模型 (`domain_model`) | `RefCounted` | 12 | `addons/gf/extensions/decision/runtime/gf_decision_blackboard.gd` |
| [`GFDecisionContext`](GFDecisionContext.md#gfdecisioncontext) | 领域模型 (`domain_model`) | `RefCounted` | 13 | `addons/gf/extensions/decision/runtime/gf_decision_context.gd` |

<a id="module-extensions-dialogue"></a>

### Dialogue

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFDialogueRunner`](GFDialogueRunner.md#gfdialoguerunner) | 运行时服务 (`runtime_service`) | `RefCounted` | 15 | `addons/gf/extensions/dialogue/runtime/gf_dialogue_runner.gd` |
| [`GFDialogueLine`](GFDialogueLine.md#gfdialogueline) | 资源定义 (`resource_definition`) | `Resource` | 22 | `addons/gf/extensions/dialogue/resources/gf_dialogue_line.gd` |
| [`GFDialogueResource`](GFDialogueResource.md#gfdialogueresource) | 资源定义 (`resource_definition`) | `Resource` | 10 | `addons/gf/extensions/dialogue/resources/gf_dialogue_resource.gd` |
| [`GFDialogueResponse`](GFDialogueResponse.md#gfdialogueresponse) | 资源定义 (`resource_definition`) | `Resource` | 12 | `addons/gf/extensions/dialogue/resources/gf_dialogue_response.gd` |
| [`GFDialogueContext`](GFDialogueContext.md#gfdialoguecontext) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 13 | `addons/gf/extensions/dialogue/runtime/gf_dialogue_context.gd` |

<a id="module-extensions-domain"></a>

### Domain

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFLevelUtility`](GFLevelUtility.md#gflevelutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 29 | `addons/gf/extensions/domain/level/gf_level_utility.gd` |
| [`GFQuestUtility`](GFQuestUtility.md#gfquestutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 35 | `addons/gf/extensions/domain/quest/gf_quest_utility.gd` |
| [`GFDerivedAttributeRule`](GFDerivedAttributeRule.md#gfderivedattributerule) | 资源定义 (`resource_definition`) | `Resource` | 15 | `addons/gf/extensions/domain/attributes/gf_derived_attribute_rule.gd` |
| [`GFEquipmentSlot`](GFEquipmentSlot.md#gfequipmentslot) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/extensions/domain/equipment/gf_equipment_slot.gd` |
| [`GFInventoryItemDefinition`](GFInventoryItemDefinition.md#gfinventoryitemdefinition) | 资源定义 (`resource_definition`) | `Resource` | 20 | `addons/gf/extensions/domain/inventory/gf_inventory_item_definition.gd` |
| [`GFInventoryItemRegistry`](GFInventoryItemRegistry.md#gfinventoryitemregistry) | 资源定义 (`resource_definition`) | `Resource` | 17 | `addons/gf/extensions/domain/inventory/gf_inventory_item_registry.gd` |
| [`GFInventorySlotDefinition`](GFInventorySlotDefinition.md#gfinventoryslotdefinition) | 资源定义 (`resource_definition`) | `Resource` | 11 | `addons/gf/extensions/domain/inventory/gf_inventory_slot_definition.gd` |
| [`GFLevelCatalog`](GFLevelCatalog.md#gflevelcatalog) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/extensions/domain/level/gf_level_catalog.gd` |
| [`GFLevelEntry`](GFLevelEntry.md#gflevelentry) | 资源定义 (`resource_definition`) | `Resource` | 8 | `addons/gf/extensions/domain/level/gf_level_entry.gd` |
| [`GFTrait`](GFTrait.md#gftrait) | 资源定义 (`resource_definition`) | `Resource` | 9 | `addons/gf/extensions/domain/traits/gf_trait.gd` |
| [`GFInventoryOperationResult`](GFInventoryOperationResult.md#gfinventoryoperationresult) | 值对象 (`value_object`) | `RefCounted` | 13 | `addons/gf/extensions/domain/inventory/gf_inventory_operation_result.gd` |
| [`GFAttributeSet`](GFAttributeSet.md#gfattributeset) | 领域模型 (`domain_model`) | `Resource` | 27 | `addons/gf/extensions/domain/attributes/gf_attribute_set.gd` |
| [`GFEquipmentSet`](GFEquipmentSet.md#gfequipmentset) | 领域模型 (`domain_model`) | `Resource` | 6 | `addons/gf/extensions/domain/equipment/gf_equipment_set.gd` |
| [`GFInventoryModel`](GFInventoryModel.md#gfinventorymodel) | 领域模型 (`domain_model`) | `GFModel` | 10 | `addons/gf/extensions/domain/inventory/gf_inventory_model.gd` |
| [`GFInventoryStack`](GFInventoryStack.md#gfinventorystack) | 领域模型 (`domain_model`) | `Resource` | 14 | `addons/gf/extensions/domain/inventory/gf_inventory_stack.gd` |
| [`GFLevelProgressModel`](GFLevelProgressModel.md#gflevelprogressmodel) | 领域模型 (`domain_model`) | `GFModel` | 14 | `addons/gf/extensions/domain/level/gf_level_progress_model.gd` |
| [`GFSlotInventoryModel`](GFSlotInventoryModel.md#gfslotinventorymodel) | 领域模型 (`domain_model`) | `GFModel` | 45 | `addons/gf/extensions/domain/inventory/gf_slot_inventory_model.gd` |
| [`GFTraitSet`](GFTraitSet.md#gftraitset) | 领域模型 (`domain_model`) | `Resource` | 6 | `addons/gf/extensions/domain/traits/gf_trait_set.gd` |

<a id="module-extensions-feedback"></a>

### Feedback

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFShakeUtility`](GFShakeUtility.md#gfshakeutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 21 | `addons/gf/extensions/feedback/runtime/gf_shake_utility.gd` |
| [`GFShakePreset`](GFShakePreset.md#gfshakepreset) | 资源定义 (`resource_definition`) | `Resource` | 20 | `addons/gf/extensions/feedback/resources/gf_shake_preset.gd` |
| [`GFShakeTrack`](GFShakeTrack.md#gfshaketrack) | 资源定义 (`resource_definition`) | `Resource` | 19 | `addons/gf/extensions/feedback/resources/gf_shake_track.gd` |
| [`GFShakeReceiver2D`](GFShakeReceiver2D.md#gfshakereceiver2d) | 运行时句柄 (`runtime_handle`) | `Node` | 13 | `addons/gf/extensions/feedback/nodes/gf_shake_receiver_2d.gd` |
| [`GFShakeReceiver3D`](GFShakeReceiver3D.md#gfshakereceiver3d) | 运行时句柄 (`runtime_handle`) | `Node` | 13 | `addons/gf/extensions/feedback/nodes/gf_shake_receiver_3d.gd` |

<a id="module-extensions-flow"></a>

### Flow

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFFlowRunner`](GFFlowRunner.md#gfflowrunner) | 运行时服务 (`runtime_service`) | `RefCounted` | 13 | `addons/gf/extensions/flow/runtime/gf_flow_runner.gd` |
| [`GFFlowGraph`](GFFlowGraph.md#gfflowgraph) | 资源定义 (`resource_definition`) | `Resource` | 35 | `addons/gf/extensions/flow/resources/gf_flow_graph.gd` |
| [`GFFlowNode`](GFFlowNode.md#gfflownode) | 资源定义 (`resource_definition`) | `Resource` | 27 | `addons/gf/extensions/flow/resources/gf_flow_node.gd` |
| [`GFFlowPort`](GFFlowPort.md#gfflowport) | 资源定义 (`resource_definition`) | `Resource` | 18 | `addons/gf/extensions/flow/resources/gf_flow_port.gd` |
| [`GFFlowContext`](GFFlowContext.md#gfflowcontext) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 20 | `addons/gf/extensions/flow/runtime/gf_flow_context.gd` |
| [`GFFlowGraphDock`](GFFlowGraphDock.md#gfflowgraphdock) | 编辑器 API (`editor_api`) | `Control` | 4 | `addons/gf/extensions/flow/editor/gf_flow_graph_dock.gd` |
| [`GFFlowGraphEditorModel`](GFFlowGraphEditorModel.md#gfflowgrapheditormodel) | 编辑器 API (`editor_api`) | `RefCounted` | 13 | `addons/gf/extensions/flow/editor/gf_flow_graph_editor_model.gd` |

<a id="module-extensions-interaction"></a>

### Interaction

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFInteractions`](GFInteractions.md#gfinteractions) | 运行时服务 (`runtime_service`) | `RefCounted` | 2 | `addons/gf/extensions/interaction/runtime/gf_interactions.gd` |
| [`GFInteractionContext`](GFInteractionContext.md#gfinteractioncontext) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 8 | `addons/gf/extensions/interaction/runtime/gf_interaction_context.gd` |
| [`GFInteractionFlow`](GFInteractionFlow.md#gfinteractionflow) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 6 | `addons/gf/extensions/interaction/runtime/gf_interaction_flow.gd` |
| [`GFInteractionReceiver`](GFInteractionReceiver.md#gfinteractionreceiver) | 运行时句柄 (`runtime_handle`) | `Node` | 11 | `addons/gf/extensions/interaction/nodes/gf_interaction_receiver.gd` |
| [`GFInteractionSensor`](GFInteractionSensor.md#gfinteractionsensor) | 运行时句柄 (`runtime_handle`) | `Node` | 17 | `addons/gf/extensions/interaction/nodes/gf_interaction_sensor.gd` |
| [`GFPointerInteraction3D`](GFPointerInteraction3D.md#gfpointerinteraction3d) | 运行时句柄 (`runtime_handle`) | `Node` | 28 | `addons/gf/extensions/interaction/nodes/gf_pointer_interaction_3d.gd` |

<a id="module-extensions-network"></a>

### Network

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFNetworkUtility`](GFNetworkUtility.md#gfnetworkutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 25 | `addons/gf/extensions/network/runtime/gf_network_utility.gd` |
| [`GFNetworkBackend`](GFNetworkBackend.md#gfnetworkbackend) | 协议与扩展点 (`protocol`) | `RefCounted` | 11 | `addons/gf/extensions/network/backends/gf_network_backend.gd` |
| [`GFNetworkMessageValidator`](GFNetworkMessageValidator.md#gfnetworkmessagevalidator) | 协议与扩展点 (`protocol`) | `RefCounted` | 8 | `addons/gf/extensions/network/messages/gf_network_message_validator.gd` |
| [`GFNetworkSerializer`](GFNetworkSerializer.md#gfnetworkserializer) | 协议与扩展点 (`protocol`) | `RefCounted` | 9 | `addons/gf/extensions/network/serialization/gf_network_serializer.gd` |
| [`GFNetworkChannel`](GFNetworkChannel.md#gfnetworkchannel) | 资源定义 (`resource_definition`) | `Resource` | 9 | `addons/gf/extensions/network/session/gf_network_channel.gd` |
| [`GFNetworkContract`](GFNetworkContract.md#gfnetworkcontract) | 资源定义 (`resource_definition`) | `Resource` | 12 | `addons/gf/extensions/network/contracts/gf_network_contract.gd` |
| [`GFNetworkContractField`](GFNetworkContractField.md#gfnetworkcontractfield) | 资源定义 (`resource_definition`) | `Resource` | 16 | `addons/gf/extensions/network/contracts/gf_network_contract_field.gd` |
| [`GFNetworkContractMessage`](GFNetworkContractMessage.md#gfnetworkcontractmessage) | 资源定义 (`resource_definition`) | `Resource` | 14 | `addons/gf/extensions/network/contracts/gf_network_contract_message.gd` |
| [`GFNetworkFieldSerializer`](GFNetworkFieldSerializer.md#gfnetworkfieldserializer) | 资源定义 (`resource_definition`) | `Resource` | 9 | `addons/gf/extensions/network/serialization/gf_network_field_serializer.gd` |
| [`GFNetworkSnapshotSchema`](GFNetworkSnapshotSchema.md#gfnetworksnapshotschema) | 资源定义 (`resource_definition`) | `Resource` | 14 | `addons/gf/extensions/network/snapshot/gf_network_snapshot_schema.gd` |
| [`GFENetNetworkBackend`](GFENetNetworkBackend.md#gfenetnetworkbackend) | 运行时句柄 (`runtime_handle`) | `GFNetworkBackend` | 8 | `addons/gf/extensions/network/backends/gf_enet_network_backend.gd` |
| [`GFFixedTickClock`](GFFixedTickClock.md#gffixedtickclock) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 22 | `addons/gf/extensions/network/simulation/gf_fixed_tick_clock.gd` |
| [`GFNetworkHistoryBuffer`](GFNetworkHistoryBuffer.md#gfnetworkhistorybuffer) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 15 | `addons/gf/extensions/network/snapshot/gf_network_history_buffer.gd` |
| [`GFNetworkRateLimiter`](GFNetworkRateLimiter.md#gfnetworkratelimiter) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 6 | `addons/gf/extensions/network/session/gf_network_rate_limiter.gd` |
| [`GFNetworkReconnectPolicy`](GFNetworkReconnectPolicy.md#gfnetworkreconnectpolicy) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 8 | `addons/gf/extensions/network/session/gf_network_reconnect_policy.gd` |
| [`GFNetworkSession`](GFNetworkSession.md#gfnetworksession) | 运行时句柄 (`runtime_handle`) | `RefCounted` | 17 | `addons/gf/extensions/network/session/gf_network_session.gd` |
| [`GFWebSocketNetworkBackend`](GFWebSocketNetworkBackend.md#gfwebsocketnetworkbackend) | 运行时句柄 (`runtime_handle`) | `GFNetworkBackend` | 11 | `addons/gf/extensions/network/backends/gf_websocket_network_backend.gd` |
| [`GFNetworkMessage`](GFNetworkMessage.md#gfnetworkmessage) | 值对象 (`value_object`) | `RefCounted` | 8 | `addons/gf/extensions/network/messages/gf_network_message.gd` |
| [`GFNetworkSnapshot`](GFNetworkSnapshot.md#gfnetworksnapshot) | 值对象 (`value_object`) | `RefCounted` | 16 | `addons/gf/extensions/network/snapshot/gf_network_snapshot.gd` |
| [`GFNetworkContractGenerator`](GFNetworkContractGenerator.md#gfnetworkcontractgenerator) | 编辑器 API (`editor_api`) | `RefCounted` | 5 | `addons/gf/extensions/network/editor/gf_network_contract_generator.gd` |

<a id="module-extensions-physics"></a>

### Physics

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFGravityField3D`](GFGravityField3D.md#gfgravityfield3d) | 运行时句柄 (`runtime_handle`) | `Node3D` | 16 | `addons/gf/extensions/physics/nodes/gf_gravity_field_3d.gd` |
| [`GFGravityProbe3D`](GFGravityProbe3D.md#gfgravityprobe3d) | 运行时句柄 (`runtime_handle`) | `Node3D` | 11 | `addons/gf/extensions/physics/nodes/gf_gravity_probe_3d.gd` |

<a id="module-extensions-save"></a>

### Save

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFNodeSerializerRegistry`](GFNodeSerializerRegistry.md#gfnodeserializerregistry) | 运行时服务 (`runtime_service`) | `RefCounted` | 7 | `addons/gf/extensions/save/serializers/gf_node_serializer_registry.gd` |
| [`GFSaveGraphUtility`](GFSaveGraphUtility.md#gfsavegraphutility) | 运行时服务 (`runtime_service`) | `GFUtility` | 19 | `addons/gf/extensions/save/graph/gf_save_graph_utility.gd` |
| [`GFNodeSerializer`](GFNodeSerializer.md#gfnodeserializer) | 协议与扩展点 (`protocol`) | `Resource` | 15 | `addons/gf/extensions/save/serializers/gf_node_serializer.gd` |
| [`GFPersistPropertiesSource`](GFPersistPropertiesSource.md#gfpersistpropertiessource) | 协议与扩展点 (`protocol`) | `GFSaveSource` | 4 | `addons/gf/extensions/save/core/gf_persist_properties_source.gd` |
| [`GFSaveDataSource`](GFSaveDataSource.md#gfsavedatasource) | 协议与扩展点 (`protocol`) | `GFSaveSource` | 10 | `addons/gf/extensions/save/core/gf_save_data_source.gd` |
| [`GFSaveEntityFactory`](GFSaveEntityFactory.md#gfsaveentityfactory) | 协议与扩展点 (`protocol`) | `Resource` | 5 | `addons/gf/extensions/save/core/gf_save_entity_factory.gd` |
| [`GFSavePipelineStep`](GFSavePipelineStep.md#gfsavepipelinestep) | 协议与扩展点 (`protocol`) | `Resource` | 6 | `addons/gf/extensions/save/pipeline/gf_save_pipeline_step.gd` |
| [`GFSaveScope`](GFSaveScope.md#gfsavescope) | 协议与扩展点 (`protocol`) | `Node` | 18 | `addons/gf/extensions/save/core/gf_save_scope.gd` |
| [`GFSaveSource`](GFSaveSource.md#gfsavesource) | 协议与扩展点 (`protocol`) | `Node` | 19 | `addons/gf/extensions/save/core/gf_save_source.gd` |
| [`GFNodeAnimationPlayerSerializer`](GFNodeAnimationPlayerSerializer.md#gfnodeanimationplayerserializer) | 资源定义 (`resource_definition`) | `GFNodeSerializer` | 3 | `addons/gf/extensions/save/serializers/gf_node_animation_player_serializer.gd` |
| [`GFNodeAudioStreamPlayerSerializer`](GFNodeAudioStreamPlayerSerializer.md#gfnodeaudiostreamplayerserializer) | 资源定义 (`resource_definition`) | `GFNodeSerializer` | 3 | `addons/gf/extensions/save/serializers/gf_node_audio_stream_player_serializer.gd` |
| [`GFNodeCanvasItemSerializer`](GFNodeCanvasItemSerializer.md#gfnodecanvasitemserializer) | 资源定义 (`resource_definition`) | `GFNodeSerializer` | 3 | `addons/gf/extensions/save/serializers/gf_node_canvas_item_serializer.gd` |
| [`GFNodeControlSerializer`](GFNodeControlSerializer.md#gfnodecontrolserializer) | 资源定义 (`resource_definition`) | `GFNodeSerializer` | 3 | `addons/gf/extensions/save/serializers/gf_node_control_serializer.gd` |
| [`GFNodePropertySerializer`](GFNodePropertySerializer.md#gfnodepropertyserializer) | 资源定义 (`resource_definition`) | `GFNodeSerializer` | 4 | `addons/gf/extensions/save/serializers/gf_node_property_serializer.gd` |
| [`GFNodeRangeSerializer`](GFNodeRangeSerializer.md#gfnoderangeserializer) | 资源定义 (`resource_definition`) | `GFNodeSerializer` | 3 | `addons/gf/extensions/save/serializers/gf_node_range_serializer.gd` |
| [`GFNodeTimerSerializer`](GFNodeTimerSerializer.md#gfnodetimerserializer) | 资源定义 (`resource_definition`) | `GFNodeSerializer` | 3 | `addons/gf/extensions/save/serializers/gf_node_timer_serializer.gd` |
| [`GFNodeTransform2DSerializer`](GFNodeTransform2DSerializer.md#gfnodetransform2dserializer) | 资源定义 (`resource_definition`) | `GFNodeSerializer` | 3 | `addons/gf/extensions/save/serializers/gf_node_transform_2d_serializer.gd` |
| [`GFNodeTransform3DSerializer`](GFNodeTransform3DSerializer.md#gfnodetransform3dserializer) | 资源定义 (`resource_definition`) | `GFNodeSerializer` | 3 | `addons/gf/extensions/save/serializers/gf_node_transform_3d_serializer.gd` |
| [`GFSaveSlotWorkflow`](GFSaveSlotWorkflow.md#gfsaveslotworkflow) | 资源定义 (`resource_definition`) | `Resource` | 19 | `addons/gf/extensions/save/slots/gf_save_slot_workflow.gd` |
| [`GFSavePipelineContext`](GFSavePipelineContext.md#gfsavepipelinecontext) | 值对象 (`value_object`) | `RefCounted` | 16 | `addons/gf/extensions/save/pipeline/gf_save_pipeline_context.gd` |
| [`GFSaveSlotCard`](GFSaveSlotCard.md#gfsaveslotcard) | 值对象 (`value_object`) | `Resource` | 14 | `addons/gf/extensions/save/slots/gf_save_slot_card.gd` |
| [`GFSaveSlotMetadata`](GFSaveSlotMetadata.md#gfsaveslotmetadata) | 值对象 (`value_object`) | `Resource` | 19 | `addons/gf/extensions/save/slots/gf_save_slot_metadata.gd` |
| [`GFSaveIdentity`](GFSaveIdentity.md#gfsaveidentity) | 领域模型 (`domain_model`) | `Node` | 6 | `addons/gf/extensions/save/core/gf_save_identity.gd` |
| [`GFSavePipelineEvent`](GFSavePipelineEvent.md#gfsavepipelineevent) | 事件契约 (`event_contract`) | `RefCounted` | 11 | `addons/gf/extensions/save/pipeline/gf_save_pipeline_event.gd` |

<a id="module-extensions-turn_based"></a>

### Turn Based

| 类 | 类别 | 继承 | 成员 | 源文件 |
|---|---|---|---:|---|
| [`GFTurnFlowSystem`](GFTurnFlowSystem.md#gfturnflowsystem) | 运行时服务 (`runtime_service`) | `GFSystem` | 19 | `addons/gf/extensions/turn_based/runtime/gf_turn_flow_system.gd` |
| [`GFTurnAction`](GFTurnAction.md#gfturnaction) | 协议与扩展点 (`protocol`) | `RefCounted` | 9 | `addons/gf/extensions/turn_based/runtime/gf_turn_action.gd` |
| [`GFTurnPhase`](GFTurnPhase.md#gfturnphase) | 协议与扩展点 (`protocol`) | `Resource` | 9 | `addons/gf/extensions/turn_based/resources/gf_turn_phase.gd` |
| [`GFTurnContext`](GFTurnContext.md#gfturncontext) | 领域模型 (`domain_model`) | `RefCounted` | 10 | `addons/gf/extensions/turn_based/runtime/gf_turn_context.gd` |
