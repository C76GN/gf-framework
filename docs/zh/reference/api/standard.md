# Standard API

模块：`standard`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 113 | 2039 | 1398 |
| [协议与扩展点](#category-protocol) | 18 | 232 | 190 |
| [资源定义](#category-resource_definition) | 85 | 914 | 447 |
| [运行时句柄](#category-runtime_handle) | 21 | 355 | 205 |
| [值对象](#category-value_object) | 21 | 371 | 231 |
| [领域模型](#category-domain_model) | 4 | 60 | 41 |
| [事件契约](#category-event_contract) | 5 | 47 | 17 |
| [编辑器 API](#category-editor_api) | 6 | 21 | 17 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAnalyticsUtility`](classes/GFAnalyticsUtility.md#gfanalyticsutility) | `GFUtility` | `addons/gf/standard/utilities/analytics/gf_analytics_utility.gd` |
| [`GFAssetUtility`](classes/GFAssetUtility.md#gfassetutility) | `GFUtility` | `addons/gf/standard/utilities/assets/gf_asset_utility.gd` |
| [`GFAudioBankTools`](classes/GFAudioBankTools.md#gfaudiobanktools) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_bank_tools.gd` |
| [`GFAudioCatalogProvider`](classes/GFAudioCatalogProvider.md#gfaudiocatalogprovider) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_catalog_provider.gd` |
| [`GFAudioLibraryTools`](classes/GFAudioLibraryTools.md#gfaudiolibrarytools) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_library_tools.gd` |
| [`GFAudioUtility`](classes/GFAudioUtility.md#gfaudioutility) | `GFUtility` | `addons/gf/standard/utilities/audio/gf_audio_utility.gd` |
| [`GFBackgroundWorkUtility`](classes/GFBackgroundWorkUtility.md#gfbackgroundworkutility) | `GFUtility` | `addons/gf/standard/utilities/jobs/gf_background_work_utility.gd` |
| [`GFBatchedLogSink`](classes/GFBatchedLogSink.md#gfbatchedlogsink) | `GFLogSink` | `addons/gf/standard/utilities/logging/gf_batched_log_sink.gd` |
| [`GFBudgetLedger`](classes/GFBudgetLedger.md#gfbudgetledger) | `RefCounted` | `addons/gf/standard/foundation/budget/gf_budget_ledger.gd` |
| [`GFBuildInfoUtility`](classes/GFBuildInfoUtility.md#gfbuildinfoutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_build_info_utility.gd` |
| [`GFCollisionBroadphase2D`](classes/GFCollisionBroadphase2D.md#gfcollisionbroadphase2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_collision_broadphase_2d.gd` |
| [`GFCollisionBroadphase3D`](classes/GFCollisionBroadphase3D.md#gfcollisionbroadphase3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_collision_broadphase_3d.gd` |
| [`GFCollisionNarrowphase2D`](classes/GFCollisionNarrowphase2D.md#gfcollisionnarrowphase2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_collision_narrowphase_2d.gd` |
| [`GFCommandHistoryUtility`](classes/GFCommandHistoryUtility.md#gfcommandhistoryutility) | `GFUtility` | `addons/gf/standard/utilities/history/gf_command_history_utility.gd` |
| [`GFCommandSequence`](classes/GFCommandSequence.md#gfcommandsequence) | `RefCounted` | `addons/gf/standard/sequence/gf_command_sequence.gd` |
| [`GFConfigReferenceResolver`](classes/GFConfigReferenceResolver.md#gfconfigreferenceresolver) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_reference_resolver.gd` |
| [`GFConfigTableImporter`](classes/GFConfigTableImporter.md#gfconfigtableimporter) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_table_importer.gd` |
| [`GFConfigTableMergeTools`](classes/GFConfigTableMergeTools.md#gfconfigtablemergetools) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_table_merge_tools.gd` |
| [`GFConsoleUtility`](classes/GFConsoleUtility.md#gfconsoleutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_console_utility.gd` |
| [`GFControlValueAdapter`](classes/GFControlValueAdapter.md#gfcontrolvalueadapter) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_control_value_adapter.gd` |
| [`GFCurve2DMath`](classes/GFCurve2DMath.md#gfcurve2dmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_curve_2d_math.gd` |
| [`GFDebugDrawUtility`](classes/GFDebugDrawUtility.md#gfdebugdrawutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_debug_draw_utility.gd` |
| [`GFDebugOverlayUtility`](classes/GFDebugOverlayUtility.md#gfdebugoverlayutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_debug_overlay_utility.gd` |
| [`GFDeterministicVariantSerializer`](classes/GFDeterministicVariantSerializer.md#gfdeterministicvariantserializer) | `RefCounted` | `addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd` |
| [`GFDiagnosticsUtility`](classes/GFDiagnosticsUtility.md#gfdiagnosticsutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_diagnostics_utility.gd` |
| [`GFDirectoryWatchUtility`](classes/GFDirectoryWatchUtility.md#gfdirectorywatchutility) | `RefCounted` | `addons/gf/standard/utilities/io/gf_directory_watch_utility.gd` |
| [`GFDisplaySettingsUtility`](classes/GFDisplaySettingsUtility.md#gfdisplaysettingsutility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_display_settings_utility.gd` |
| [`GFDownloadUtility`](classes/GFDownloadUtility.md#gfdownloadutility) | `GFUtility` | `addons/gf/standard/utilities/io/gf_download_utility.gd` |
| [`GFDragDropUtility`](classes/GFDragDropUtility.md#gfdragdroputility) | `GFUtility` | `addons/gf/standard/input/drag_drop/gf_drag_drop_utility.gd` |
| [`GFGraphLayoutUtility`](classes/GFGraphLayoutUtility.md#gfgraphlayoututility) | `RefCounted` | `addons/gf/standard/foundation/math/gf_graph_layout_utility.gd` |
| [`GFGraphMath`](classes/GFGraphMath.md#gfgraphmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_graph_math.gd` |
| [`GFGrid3DMath`](classes/GFGrid3DMath.md#gfgrid3dmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_3d_math.gd` |
| [`GFGridKey3D`](classes/GFGridKey3D.md#gfgridkey3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_key_3d.gd` |
| [`GFGridMath`](classes/GFGridMath.md#gfgridmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_math.gd` |
| [`GFGridOccupancy`](classes/GFGridOccupancy.md#gfgridoccupancy) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_occupancy.gd` |
| [`GFGridPlaneMapper3D`](classes/GFGridPlaneMapper3D.md#gfgridplanemapper3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_plane_mapper_3d.gd` |
| [`GFGridTransform2D`](classes/GFGridTransform2D.md#gfgridtransform2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_transform_2d.gd` |
| [`GFHexGridMath`](classes/GFHexGridMath.md#gfhexgridmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_hex_grid_math.gd` |
| [`GFInputAssistUtility`](classes/GFInputAssistUtility.md#gfinputassistutility) | `GFUtility` | `addons/gf/standard/input/runtime/gf_input_assist_utility.gd` |
| [`GFInputConflictAnalyzer`](classes/GFInputConflictAnalyzer.md#gfinputconflictanalyzer) | `RefCounted` | `addons/gf/standard/input/rebinding/gf_input_conflict_analyzer.gd` |
| [`GFInputDetector`](classes/GFInputDetector.md#gfinputdetector) | `Node` | `addons/gf/standard/input/rebinding/gf_input_detector.gd` |
| [`GFInputDeviceUtility`](classes/GFInputDeviceUtility.md#gfinputdeviceutility) | `GFUtility` | `addons/gf/standard/input/runtime/gf_input_device_utility.gd` |
| [`GFInputFormatter`](classes/GFInputFormatter.md#gfinputformatter) | `RefCounted` | `addons/gf/standard/input/formatting/gf_input_formatter.gd` |
| [`GFInputMappingUtility`](classes/GFInputMappingUtility.md#gfinputmappingutility) | `GFUtility` | `addons/gf/standard/input/runtime/gf_input_mapping_utility.gd` |
| [`GFInputPlayback`](classes/GFInputPlayback.md#gfinputplayback) | `RefCounted` | `addons/gf/standard/input/recording/gf_input_playback.gd` |
| [`GFJobQueueUtility`](classes/GFJobQueueUtility.md#gfjobqueueutility) | `GFUtility` | `addons/gf/standard/utilities/jobs/gf_job_queue_utility.gd` |
| [`GFJobWorker`](classes/GFJobWorker.md#gfjobworker) | `Node` | `addons/gf/standard/utilities/jobs/gf_job_worker.gd` |
| [`GFJsonLineLogSink`](classes/GFJsonLineLogSink.md#gfjsonlinelogsink) | `GFLogSink` | `addons/gf/standard/utilities/logging/gf_json_line_log_sink.gd` |
| [`GFLayerMaskUtility`](classes/GFLayerMaskUtility.md#gflayermaskutility) | `RefCounted` | `addons/gf/standard/foundation/math/gf_layer_mask_utility.gd` |
| [`GFLogUtility`](classes/GFLogUtility.md#gflogutility) | `GFUtility` | `addons/gf/standard/utilities/logging/gf_log_utility.gd` |
| [`GFMutationBatch`](classes/GFMutationBatch.md#gfmutationbatch) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_mutation_batch.gd` |
| [`GFNodeStateMachine`](classes/GFNodeStateMachine.md#gfnodestatemachine) | `Node` | `addons/gf/standard/state_machine/node/gf_node_state_machine.gd` |
| [`GFNodeStateMachineValidator`](classes/GFNodeStateMachineValidator.md#gfnodestatemachinevalidator) | `RefCounted` | `addons/gf/standard/state_machine/node/gf_node_state_machine_validator.gd` |
| [`GFNodeTreeOps`](classes/GFNodeTreeOps.md#gfnodetreeops) | `RefCounted` | `addons/gf/standard/utilities/nodes/gf_node_tree_ops.gd` |
| [`GFNotificationUtility`](classes/GFNotificationUtility.md#gfnotificationutility) | `GFUtility` | `addons/gf/standard/utilities/ui/gf_notification_utility.gd` |
| [`GFNumberFormatter`](classes/GFNumberFormatter.md#gfnumberformatter) | `RefCounted` | `addons/gf/standard/foundation/formatting/gf_number_formatter.gd` |
| [`GFObjectPoolUtility`](classes/GFObjectPoolUtility.md#gfobjectpoolutility) | `GFUtility` | `addons/gf/standard/utilities/nodes/gf_object_pool_utility.gd` |
| [`GFPhysicsQueryUtility`](classes/GFPhysicsQueryUtility.md#gfphysicsqueryutility) | `GFUtility` | `addons/gf/standard/utilities/spatial/gf_physics_query_utility.gd` |
| [`GFPointerActivityUtility`](classes/GFPointerActivityUtility.md#gfpointeractivityutility) | `GFUtility` | `addons/gf/standard/input/runtime/gf_pointer_activity_utility.gd` |
| [`GFPoissonDisc2D`](classes/GFPoissonDisc2D.md#gfpoissondisc2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_poisson_disc_2d.gd` |
| [`GFPolynomialMath`](classes/GFPolynomialMath.md#gfpolynomialmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_polynomial_math.gd` |
| [`GFProgressionMath`](classes/GFProgressionMath.md#gfprogressionmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_progression_math.gd` |
| [`GFQuadTreeUtility`](classes/GFQuadTreeUtility.md#gfquadtreeutility) | `GFUtility` | `addons/gf/standard/utilities/spatial/gf_quad_tree_utility.gd` |
| [`GFRectPacking2D`](classes/GFRectPacking2D.md#gfrectpacking2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_rect_packing_2d.gd` |
| [`GFRefCountedPool`](classes/GFRefCountedPool.md#gfrefcountedpool) | `RefCounted` | `addons/gf/standard/utilities/pooling/gf_ref_counted_pool.gd` |
| [`GFRegionMap2D`](classes/GFRegionMap2D.md#gfregionmap2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_region_map_2d.gd` |
| [`GFRegionMap3D`](classes/GFRegionMap3D.md#gfregionmap3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_region_map_3d.gd` |
| [`GFRemoteCacheUtility`](classes/GFRemoteCacheUtility.md#gfremotecacheutility) | `GFUtility` | `addons/gf/standard/utilities/io/gf_remote_cache_utility.gd` |
| [`GFRenderWarmupUtility`](classes/GFRenderWarmupUtility.md#gfrenderwarmuputility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_render_warmup_utility.gd` |
| [`GFRequestOutboxUtility`](classes/GFRequestOutboxUtility.md#gfrequestoutboxutility) | `GFUtility` | `addons/gf/standard/utilities/io/gf_request_outbox_utility.gd` |
| [`GFResourceRegistryTools`](classes/GFResourceRegistryTools.md#gfresourceregistrytools) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_resource_registry_tools.gd` |
| [`GFResourceResolverUtility`](classes/GFResourceResolverUtility.md#gfresourceresolverutility) | `GFUtility` | `addons/gf/standard/utilities/assets/gf_resource_resolver_utility.gd` |
| [`GFRichTextFormatter`](classes/GFRichTextFormatter.md#gfrichtextformatter) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_rich_text_formatter.gd` |
| [`GFRuntimeInspectorUtility`](classes/GFRuntimeInspectorUtility.md#gfruntimeinspectorutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_runtime_inspector_utility.gd` |
| [`GFSceneUtility`](classes/GFSceneUtility.md#gfsceneutility) | `GFUtility` | `addons/gf/standard/utilities/scene/gf_scene_utility.gd` |
| [`GFScreenTransitionUtility`](classes/GFScreenTransitionUtility.md#gfscreentransitionutility) | `GFUtility` | `addons/gf/standard/utilities/scene/gf_screen_transition_utility.gd` |
| [`GFScreenshotUtility`](classes/GFScreenshotUtility.md#gfscreenshotutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_screenshot_utility.gd` |
| [`GFSeedUtility`](classes/GFSeedUtility.md#gfseedutility) | `GFUtility` | `addons/gf/standard/utilities/random/gf_seed_utility.gd` |
| [`GFSettingsUtility`](classes/GFSettingsUtility.md#gfsettingsutility) | `GFUtility` | `addons/gf/standard/utilities/settings/gf_settings_utility.gd` |
| [`GFShaderParameterUtility`](classes/GFShaderParameterUtility.md#gfshaderparameterutility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_shader_parameter_utility.gd` |
| [`GFSignalRuntimeProbe`](classes/GFSignalRuntimeProbe.md#gfsignalruntimeprobe) | `RefCounted` | `addons/gf/standard/utilities/debug/gf_signal_runtime_probe.gd` |
| [`GFSignalUtility`](classes/GFSignalUtility.md#gfsignalutility) | `GFUtility` | `addons/gf/standard/utilities/signals/gf_signal_utility.gd` |
| [`GFSnapshotHistoryUtility`](classes/GFSnapshotHistoryUtility.md#gfsnapshothistoryutility) | `GFUtility` | `addons/gf/standard/utilities/history/gf_snapshot_history_utility.gd` |
| [`GFSpatialHash3D`](classes/GFSpatialHash3D.md#gfspatialhash3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_spatial_hash_3d.gd` |
| [`GFSpringMath`](classes/GFSpringMath.md#gfspringmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_spring_math.gd` |
| [`GFStateMachine`](classes/GFStateMachine.md#gfstatemachine) | `RefCounted` | `addons/gf/standard/state_machine/pure/gf_state_machine.gd` |
| [`GFSteeringMath`](classes/GFSteeringMath.md#gfsteeringmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_steering_math.gd` |
| [`GFStorageSyncUtility`](classes/GFStorageSyncUtility.md#gfstoragesyncutility) | `GFUtility` | `addons/gf/standard/utilities/storage/gf_storage_sync_utility.gd` |
| [`GFStorageUtility`](classes/GFStorageUtility.md#gfstorageutility) | `GFUtility` | `addons/gf/standard/utilities/storage/gf_storage_utility.gd` |
| [`GFSupportReportUtility`](classes/GFSupportReportUtility.md#gfsupportreportutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_support_report_utility.gd` |
| [`GFSurfaceUtility`](classes/GFSurfaceUtility.md#gfsurfaceutility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_surface_utility.gd` |
| [`GFTagSourceAdapter`](classes/GFTagSourceAdapter.md#gftagsourceadapter) | `RefCounted` | `addons/gf/standard/foundation/tags/gf_tag_source_adapter.gd` |
| [`GFTextAutoFit`](classes/GFTextAutoFit.md#gftextautofit) | `Node` | `addons/gf/standard/utilities/ui/gf_text_auto_fit.gd` |
| [`GFTextFitter`](classes/GFTextFitter.md#gftextfitter) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_text_fitter.gd` |
| [`GFTextSearchScorer`](classes/GFTextSearchScorer.md#gftextsearchscorer) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_text_search_scorer.gd` |
| [`GFTimeUtility`](classes/GFTimeUtility.md#gftimeutility) | `GFTimeProvider` | `addons/gf/standard/utilities/time/gf_time_utility.gd` |
| [`GFTimedTextImporter`](classes/GFTimedTextImporter.md#gftimedtextimporter) | `RefCounted` | `addons/gf/standard/foundation/timeline/gf_timed_text_importer.gd` |
| [`GFTimerUtility`](classes/GFTimerUtility.md#gftimerutility) | `GFUtility` | `addons/gf/standard/utilities/time/gf_timer_utility.gd` |
| [`GFTouchButton`](classes/GFTouchButton.md#gftouchbutton) | `Node2D` | `addons/gf/standard/input/touch/gf_touch_button.gd` |
| [`GFTouchJoystick`](classes/GFTouchJoystick.md#gftouchjoystick) | `Node2D` | `addons/gf/standard/input/touch/gf_touch_joystick.gd` |
| [`GFUIRouterUtility`](classes/GFUIRouterUtility.md#gfuirouterutility) | `GFUtility` | `addons/gf/standard/utilities/ui/gf_ui_router_utility.gd` |
| [`GFUIUtility`](classes/GFUIUtility.md#gfuiutility) | `GFUtility` | `addons/gf/standard/utilities/ui/gf_ui_utility.gd` |
| [`GFValidationDiagnosticAdapter`](classes/GFValidationDiagnosticAdapter.md#gfvalidationdiagnosticadapter) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_diagnostic_adapter.gd` |
| [`GFValidationJUnitExporter`](classes/GFValidationJUnitExporter.md#gfvalidationjunitexporter) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_junit_exporter.gd` |
| [`GFValidationReportDictionary`](classes/GFValidationReportDictionary.md#gfvalidationreportdictionary) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd` |
| [`GFValidationRunner`](classes/GFValidationRunner.md#gfvalidationrunner) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_runner.gd` |
| [`GFValueIndex`](classes/GFValueIndex.md#gfvalueindex) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_value_index.gd` |
| [`GFVariantData`](classes/GFVariantData.md#gfvariantdata) | `RefCounted` | `addons/gf/standard/foundation/variant/gf_variant_data.gd` |
| [`GFVariantJsonCodec`](classes/GFVariantJsonCodec.md#gfvariantjsoncodec) | `RefCounted` | `addons/gf/standard/foundation/variant/gf_variant_json_codec.gd` |
| [`GFVariantReferenceCodec`](classes/GFVariantReferenceCodec.md#gfvariantreferencecodec) | `RefCounted` | `addons/gf/standard/foundation/variant/gf_variant_reference_codec.gd` |
| [`GFViewportUtility`](classes/GFViewportUtility.md#gfviewportutility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_viewport_utility.gd` |
| [`GFVirtualListModel`](classes/GFVirtualListModel.md#gfvirtuallistmodel) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_virtual_list_model.gd` |
| [`GFVoronoi2D`](classes/GFVoronoi2D.md#gfvoronoi2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_voronoi_2d.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAudioBackend`](classes/GFAudioBackend.md#gfaudiobackend) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_backend.gd` |
| [`GFConfigProvider`](classes/GFConfigProvider.md#gfconfigprovider) | `GFUtility` | `addons/gf/standard/utilities/config/gf_config_provider.gd` |
| [`GFConfigValidationRule`](classes/GFConfigValidationRule.md#gfconfigvalidationrule) | `Resource` | `addons/gf/standard/utilities/config/validation/gf_config_validation_rule.gd` |
| [`GFFormula`](classes/GFFormula.md#gfformula) | `Resource` | `addons/gf/standard/foundation/formula/gf_formula.gd` |
| [`GFGridSelection2D`](classes/GFGridSelection2D.md#gfgridselection2d) | `Resource` | `addons/gf/standard/foundation/math/gf_grid_selection_2d.gd` |
| [`GFInputIconProvider`](classes/GFInputIconProvider.md#gfinputiconprovider) | `Resource` | `addons/gf/standard/input/formatting/gf_input_icon_provider.gd` |
| [`GFInputModifier`](classes/GFInputModifier.md#gfinputmodifier) | `Resource` | `addons/gf/standard/input/modifiers/gf_input_modifier.gd` |
| [`GFInputTextProvider`](classes/GFInputTextProvider.md#gfinputtextprovider) | `Resource` | `addons/gf/standard/input/formatting/gf_input_text_provider.gd` |
| [`GFInputTrigger`](classes/GFInputTrigger.md#gfinputtrigger) | `Resource` | `addons/gf/standard/input/triggers/gf_input_trigger.gd` |
| [`GFLogSink`](classes/GFLogSink.md#gflogsink) | `RefCounted` | `addons/gf/standard/utilities/logging/gf_log_sink.gd` |
| [`GFNodeState`](classes/GFNodeState.md#gfnodestate) | `Node` | `addons/gf/standard/state_machine/node/gf_node_state.gd` |
| [`GFNodeStateBehavior`](classes/GFNodeStateBehavior.md#gfnodestatebehavior) | `Resource` | `addons/gf/standard/state_machine/node/gf_node_state_behavior.gd` |
| [`GFNodeStateCondition`](classes/GFNodeStateCondition.md#gfnodestatecondition) | `Resource` | `addons/gf/standard/state_machine/node/gf_node_state_condition.gd` |
| [`GFSequenceStep`](classes/GFSequenceStep.md#gfsequencestep) | `Resource` | `addons/gf/standard/sequence/gf_sequence_step.gd` |
| [`GFState`](classes/GFState.md#gfstate) | `RefCounted` | `addons/gf/standard/state_machine/pure/gf_state.gd` |
| [`GFStorageBackend`](classes/GFStorageBackend.md#gfstoragebackend) | `RefCounted` | `addons/gf/standard/utilities/storage/gf_storage_backend.gd` |
| [`GFUndoableCommand`](classes/GFUndoableCommand.md#gfundoablecommand) | `GFCommand` | `addons/gf/standard/command/gf_undoable_command.gd` |
| [`GFValidationRule`](classes/GFValidationRule.md#gfvalidationrule) | `Resource` | `addons/gf/standard/foundation/validation/gf_validation_rule.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAnalyticsConfig`](classes/GFAnalyticsConfig.md#gfanalyticsconfig) | `Resource` | `addons/gf/standard/utilities/analytics/gf_analytics_config.gd` |
| [`GFAudioBank`](classes/GFAudioBank.md#gfaudiobank) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_bank.gd` |
| [`GFAudioClip`](classes/GFAudioClip.md#gfaudioclip) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_clip.gd` |
| [`GFAudioSpatialSettings`](classes/GFAudioSpatialSettings.md#gfaudiospatialsettings) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_spatial_settings.gd` |
| [`GFBlackboardEntry`](classes/GFBlackboardEntry.md#gfblackboardentry) | `Resource` | `addons/gf/standard/foundation/blackboard/gf_blackboard_entry.gd` |
| [`GFBlackboardSchema`](classes/GFBlackboardSchema.md#gfblackboardschema) | `Resource` | `addons/gf/standard/foundation/blackboard/gf_blackboard_schema.gd` |
| [`GFCallableTargetRef`](classes/GFCallableTargetRef.md#gfcallabletargetref) | `Resource` | `addons/gf/standard/utilities/signals/bridge/gf_callable_target_ref.gd` |
| [`GFConfigBuildProfile`](classes/GFConfigBuildProfile.md#gfconfigbuildprofile) | `Resource` | `addons/gf/standard/utilities/config/gf_config_build_profile.gd` |
| [`GFConfigLocalizationKeyValidationRule`](classes/GFConfigLocalizationKeyValidationRule.md#gfconfiglocalizationkeyvalidationrule) | `GFConfigValidationRule` | `addons/gf/standard/utilities/config/validation/gf_config_localization_key_validation_rule.gd` |
| [`GFConfigNotDefaultValidationRule`](classes/GFConfigNotDefaultValidationRule.md#gfconfignotdefaultvalidationrule) | `GFConfigValidationRule` | `addons/gf/standard/utilities/config/validation/gf_config_not_default_validation_rule.gd` |
| [`GFConfigRangeValidationRule`](classes/GFConfigRangeValidationRule.md#gfconfigrangevalidationrule) | `GFConfigValidationRule` | `addons/gf/standard/utilities/config/validation/gf_config_range_validation_rule.gd` |
| [`GFConfigRegexValidationRule`](classes/GFConfigRegexValidationRule.md#gfconfigregexvalidationrule) | `GFConfigValidationRule` | `addons/gf/standard/utilities/config/validation/gf_config_regex_validation_rule.gd` |
| [`GFConfigResourcePathValidationRule`](classes/GFConfigResourcePathValidationRule.md#gfconfigresourcepathvalidationrule) | `GFConfigValidationRule` | `addons/gf/standard/utilities/config/validation/gf_config_resource_path_validation_rule.gd` |
| [`GFConfigSetValidationRule`](classes/GFConfigSetValidationRule.md#gfconfigsetvalidationrule) | `GFConfigValidationRule` | `addons/gf/standard/utilities/config/validation/gf_config_set_validation_rule.gd` |
| [`GFConfigSizeValidationRule`](classes/GFConfigSizeValidationRule.md#gfconfigsizevalidationrule) | `GFConfigValidationRule` | `addons/gf/standard/utilities/config/validation/gf_config_size_validation_rule.gd` |
| [`GFConfigTableColumn`](classes/GFConfigTableColumn.md#gfconfigtablecolumn) | `Resource` | `addons/gf/standard/utilities/config/gf_config_table_column.gd` |
| [`GFConfigTableIndexDefinition`](classes/GFConfigTableIndexDefinition.md#gfconfigtableindexdefinition) | `Resource` | `addons/gf/standard/utilities/config/gf_config_table_index_definition.gd` |
| [`GFConfigTableMergePolicy`](classes/GFConfigTableMergePolicy.md#gfconfigtablemergepolicy) | `Resource` | `addons/gf/standard/utilities/config/gf_config_table_merge_policy.gd` |
| [`GFConfigTableReference`](classes/GFConfigTableReference.md#gfconfigtablereference) | `Resource` | `addons/gf/standard/utilities/config/gf_config_table_reference.gd` |
| [`GFConfigTableSchema`](classes/GFConfigTableSchema.md#gfconfigtableschema) | `Resource` | `addons/gf/standard/utilities/config/gf_config_table_schema.gd` |
| [`GFConsoleCommandDefinition`](classes/GFConsoleCommandDefinition.md#gfconsolecommanddefinition) | `Resource` | `addons/gf/standard/utilities/debug/gf_console_command_definition.gd` |
| [`GFDictionarySchema`](classes/GFDictionarySchema.md#gfdictionaryschema) | `Resource` | `addons/gf/standard/foundation/schema/gf_dictionary_schema.gd` |
| [`GFFormulaSet`](classes/GFFormulaSet.md#gfformulaset) | `Resource` | `addons/gf/standard/foundation/formula/gf_formula_set.gd` |
| [`GFGridGenerationPipeline2D`](classes/GFGridGenerationPipeline2D.md#gfgridgenerationpipeline2d) | `Resource` | `addons/gf/standard/foundation/math/gf_grid_generation_pipeline_2d.gd` |
| [`GFGridGenerationStep2D`](classes/GFGridGenerationStep2D.md#gfgridgenerationstep2d) | `Resource` | `addons/gf/standard/foundation/math/gf_grid_generation_step_2d.gd` |
| [`GFInputAction`](classes/GFInputAction.md#gfinputaction) | `Resource` | `addons/gf/standard/input/mapping/gf_input_action.gd` |
| [`GFInputBinding`](classes/GFInputBinding.md#gfinputbinding) | `Resource` | `addons/gf/standard/input/mapping/gf_input_binding.gd` |
| [`GFInputChordTrigger`](classes/GFInputChordTrigger.md#gfinputchordtrigger) | `GFInputTrigger` | `addons/gf/standard/input/triggers/gf_input_chord_trigger.gd` |
| [`GFInputContext`](classes/GFInputContext.md#gfinputcontext) | `Resource` | `addons/gf/standard/input/mapping/gf_input_context.gd` |
| [`GFInputCurveModifier`](classes/GFInputCurveModifier.md#gfinputcurvemodifier) | `GFInputModifier` | `addons/gf/standard/input/modifiers/gf_input_curve_modifier.gd` |
| [`GFInputDeadzoneModifier`](classes/GFInputDeadzoneModifier.md#gfinputdeadzonemodifier) | `GFInputModifier` | `addons/gf/standard/input/modifiers/gf_input_deadzone_modifier.gd` |
| [`GFInputDeviceAssignment`](classes/GFInputDeviceAssignment.md#gfinputdeviceassignment) | `Resource` | `addons/gf/standard/input/runtime/gf_input_device_assignment.gd` |
| [`GFInputDeviceTextProvider`](classes/GFInputDeviceTextProvider.md#gfinputdevicetextprovider) | `GFInputTextProvider` | `addons/gf/standard/input/formatting/gf_input_device_text_provider.gd` |
| [`GFInputHoldTrigger`](classes/GFInputHoldTrigger.md#gfinputholdtrigger) | `GFInputTrigger` | `addons/gf/standard/input/triggers/gf_input_hold_trigger.gd` |
| [`GFInputIconAtlasProvider`](classes/GFInputIconAtlasProvider.md#gfinputiconatlasprovider) | `GFInputIconProvider` | `addons/gf/standard/input/formatting/gf_input_icon_atlas_provider.gd` |
| [`GFInputMagnitudeModifier`](classes/GFInputMagnitudeModifier.md#gfinputmagnitudemodifier) | `GFInputModifier` | `addons/gf/standard/input/modifiers/gf_input_magnitude_modifier.gd` |
| [`GFInputMapRangeModifier`](classes/GFInputMapRangeModifier.md#gfinputmaprangemodifier) | `GFInputModifier` | `addons/gf/standard/input/modifiers/gf_input_map_range_modifier.gd` |
| [`GFInputMapping`](classes/GFInputMapping.md#gfinputmapping) | `Resource` | `addons/gf/standard/input/mapping/gf_input_mapping.gd` |
| [`GFInputNormalizeModifier`](classes/GFInputNormalizeModifier.md#gfinputnormalizemodifier) | `GFInputModifier` | `addons/gf/standard/input/modifiers/gf_input_normalize_modifier.gd` |
| [`GFInputPressedTrigger`](classes/GFInputPressedTrigger.md#gfinputpressedtrigger) | `GFInputTrigger` | `addons/gf/standard/input/triggers/gf_input_pressed_trigger.gd` |
| [`GFInputProfileBank`](classes/GFInputProfileBank.md#gfinputprofilebank) | `Resource` | `addons/gf/standard/input/mapping/gf_input_profile_bank.gd` |
| [`GFInputPulseTrigger`](classes/GFInputPulseTrigger.md#gfinputpulsetrigger) | `GFInputTrigger` | `addons/gf/standard/input/triggers/gf_input_pulse_trigger.gd` |
| [`GFInputReleasedTrigger`](classes/GFInputReleasedTrigger.md#gfinputreleasedtrigger) | `GFInputTrigger` | `addons/gf/standard/input/triggers/gf_input_released_trigger.gd` |
| [`GFInputRemapConfig`](classes/GFInputRemapConfig.md#gfinputremapconfig) | `Resource` | `addons/gf/standard/input/rebinding/gf_input_remap_config.gd` |
| [`GFInputScaleModifier`](classes/GFInputScaleModifier.md#gfinputscalemodifier) | `GFInputModifier` | `addons/gf/standard/input/modifiers/gf_input_scale_modifier.gd` |
| [`GFInputSequenceBranch`](classes/GFInputSequenceBranch.md#gfinputsequencebranch) | `Resource` | `addons/gf/standard/input/sequences/gf_input_sequence_branch.gd` |
| [`GFInputSequenceStep`](classes/GFInputSequenceStep.md#gfinputsequencestep) | `Resource` | `addons/gf/standard/input/sequences/gf_input_sequence_step.gd` |
| [`GFInputSequenceTrigger`](classes/GFInputSequenceTrigger.md#gfinputsequencetrigger) | `GFInputTrigger` | `addons/gf/standard/input/sequences/gf_input_sequence_trigger.gd` |
| [`GFInputSignClampModifier`](classes/GFInputSignClampModifier.md#gfinputsignclampmodifier) | `GFInputModifier` | `addons/gf/standard/input/modifiers/gf_input_sign_clamp_modifier.gd` |
| [`GFInputSwizzleModifier`](classes/GFInputSwizzleModifier.md#gfinputswizzlemodifier) | `GFInputModifier` | `addons/gf/standard/input/modifiers/gf_input_swizzle_modifier.gd` |
| [`GFInputTapTrigger`](classes/GFInputTapTrigger.md#gfinputtaptrigger) | `GFInputTrigger` | `addons/gf/standard/input/triggers/gf_input_tap_trigger.gd` |
| [`GFInputVirtualCursorModifier`](classes/GFInputVirtualCursorModifier.md#gfinputvirtualcursormodifier) | `GFInputModifier` | `addons/gf/standard/input/modifiers/gf_input_virtual_cursor_modifier.gd` |
| [`GFModalAction`](classes/GFModalAction.md#gfmodalaction) | `Resource` | `addons/gf/standard/utilities/ui/gf_modal_action.gd` |
| [`GFModalConfig`](classes/GFModalConfig.md#gfmodalconfig) | `Resource` | `addons/gf/standard/utilities/ui/gf_modal_config.gd` |
| [`GFNodeStateMachineConfig`](classes/GFNodeStateMachineConfig.md#gfnodestatemachineconfig) | `Resource` | `addons/gf/standard/state_machine/node/gf_node_state_machine_config.gd` |
| [`GFPattern2D`](classes/GFPattern2D.md#gfpattern2d) | `Resource` | `addons/gf/standard/foundation/math/gf_pattern_2d.gd` |
| [`GFRenderWarmupManifest`](classes/GFRenderWarmupManifest.md#gfrenderwarmupmanifest) | `Resource` | `addons/gf/standard/utilities/display/gf_render_warmup_manifest.gd` |
| [`GFResourceRegistry`](classes/GFResourceRegistry.md#gfresourceregistry) | `Resource` | `addons/gf/standard/utilities/assets/gf_resource_registry.gd` |
| [`GFResourceRegistryEntry`](classes/GFResourceRegistryEntry.md#gfresourceregistryentry) | `Resource` | `addons/gf/standard/utilities/assets/gf_resource_registry_entry.gd` |
| [`GFRuntimeTunableProperty`](classes/GFRuntimeTunableProperty.md#gfruntimetunableproperty) | `Resource` | `addons/gf/standard/utilities/debug/gf_runtime_tunable_property.gd` |
| [`GFScenePreloadEntry`](classes/GFScenePreloadEntry.md#gfscenepreloadentry) | `Resource` | `addons/gf/standard/utilities/scene/gf_scene_preload_entry.gd` |
| [`GFScenePreloadMap`](classes/GFScenePreloadMap.md#gfscenepreloadmap) | `Resource` | `addons/gf/standard/utilities/scene/gf_scene_preload_map.gd` |
| [`GFSceneTransitionConfig`](classes/GFSceneTransitionConfig.md#gfscenetransitionconfig) | `Resource` | `addons/gf/standard/utilities/scene/gf_scene_transition_config.gd` |
| [`GFSchemaField`](classes/GFSchemaField.md#gfschemafield) | `Resource` | `addons/gf/standard/foundation/schema/gf_schema_field.gd` |
| [`GFScreenTransitionEffect`](classes/GFScreenTransitionEffect.md#gfscreentransitioneffect) | `Resource` | `addons/gf/standard/utilities/scene/gf_screen_transition_effect.gd` |
| [`GFSettingDefinition`](classes/GFSettingDefinition.md#gfsettingdefinition) | `Resource` | `addons/gf/standard/utilities/settings/gf_setting_definition.gd` |
| [`GFShaderParameterProfile`](classes/GFShaderParameterProfile.md#gfshaderparameterprofile) | `Resource` | `addons/gf/standard/utilities/display/gf_shader_parameter_profile.gd` |
| [`GFSignalBridge`](classes/GFSignalBridge.md#gfsignalbridge) | `Resource` | `addons/gf/standard/utilities/signals/bridge/gf_signal_bridge.gd` |
| [`GFSignalSourceRef`](classes/GFSignalSourceRef.md#gfsignalsourceref) | `Resource` | `addons/gf/standard/utilities/signals/bridge/gf_signal_source_ref.gd` |
| [`GFSteeringBehaviorResource`](classes/GFSteeringBehaviorResource.md#gfsteeringbehaviorresource) | `Resource` | `addons/gf/standard/foundation/math/gf_steering_behavior_resource.gd` |
| [`GFSteeringBehaviorStack`](classes/GFSteeringBehaviorStack.md#gfsteeringbehaviorstack) | `Resource` | `addons/gf/standard/foundation/math/gf_steering_behavior_stack.gd` |
| [`GFStorageCodec`](classes/GFStorageCodec.md#gfstoragecodec) | `Resource` | `addons/gf/standard/utilities/storage/gf_storage_codec.gd` |
| [`GFTagExpression`](classes/GFTagExpression.md#gftagexpression) | `Resource` | `addons/gf/standard/foundation/tags/gf_tag_expression.gd` |
| [`GFTagQuery`](classes/GFTagQuery.md#gftagquery) | `Resource` | `addons/gf/standard/foundation/tags/gf_tag_query.gd` |
| [`GFTagSet`](classes/GFTagSet.md#gftagset) | `Resource` | `addons/gf/standard/foundation/tags/gf_tag_set.gd` |
| [`GFTileMapCache`](classes/GFTileMapCache.md#gftilemapcache) | `Resource` | `addons/gf/standard/foundation/math/gf_tile_map_cache.gd` |
| [`GFTileMetadataLayer`](classes/GFTileMetadataLayer.md#gftilemetadatalayer) | `GFTileMapCache` | `addons/gf/standard/foundation/math/gf_tile_metadata_layer.gd` |
| [`GFTileRuleSet`](classes/GFTileRuleSet.md#gftileruleset) | `Resource` | `addons/gf/standard/foundation/math/gf_tile_rule_set.gd` |
| [`GFTimedTextEntry`](classes/GFTimedTextEntry.md#gftimedtextentry) | `Resource` | `addons/gf/standard/foundation/timeline/gf_timed_text_entry.gd` |
| [`GFTimedTextTrack`](classes/GFTimedTextTrack.md#gftimedtexttrack) | `Resource` | `addons/gf/standard/foundation/timeline/gf_timed_text_track.gd` |
| [`GFUIRoute`](classes/GFUIRoute.md#gfuiroute) | `Resource` | `addons/gf/standard/utilities/ui/gf_ui_route.gd` |
| [`GFValidationSuite`](classes/GFValidationSuite.md#gfvalidationsuite) | `Resource` | `addons/gf/standard/foundation/validation/gf_validation_suite.gd` |
| [`GFWaitSequenceStep`](classes/GFWaitSequenceStep.md#gfwaitsequencestep) | `GFSequenceStep` | `addons/gf/standard/sequence/gf_wait_sequence_step.gd` |
| [`GFWeightedEntry`](classes/GFWeightedEntry.md#gfweightedentry) | `Resource` | `addons/gf/standard/foundation/math/gf_weighted_entry.gd` |
| [`GFWeightedTable`](classes/GFWeightedTable.md#gfweightedtable) | `Resource` | `addons/gf/standard/foundation/math/gf_weighted_table.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAssetHandle`](classes/GFAssetHandle.md#gfassethandle) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_asset_handle.gd` |
| [`GFAsyncBatch`](classes/GFAsyncBatch.md#gfasyncbatch) | `RefCounted` | `addons/gf/standard/utilities/io/gf_async_batch.gd` |
| [`GFAudioBankMounter`](classes/GFAudioBankMounter.md#gfaudiobankmounter) | `Node` | `addons/gf/standard/utilities/audio/gf_audio_bank_mounter.gd` |
| [`GFAudioBeatClock`](classes/GFAudioBeatClock.md#gfaudiobeatclock) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_beat_clock.gd` |
| [`GFAudioEmitterHandle`](classes/GFAudioEmitterHandle.md#gfaudioemitterhandle) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_emitter_handle.gd` |
| [`GFBackgroundWorkTask`](classes/GFBackgroundWorkTask.md#gfbackgroundworktask) | `RefCounted` | `addons/gf/standard/utilities/jobs/gf_background_work_task.gd` |
| [`GFDeterministicRandom`](classes/GFDeterministicRandom.md#gfdeterministicrandom) | `RefCounted` | `addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd` |
| [`GFDownloadTask`](classes/GFDownloadTask.md#gfdownloadtask) | `RefCounted` | `addons/gf/standard/utilities/io/gf_download_task.gd` |
| [`GFDragSession`](classes/GFDragSession.md#gfdragsession) | `RefCounted` | `addons/gf/standard/input/drag_drop/gf_drag_session.gd` |
| [`GFFormBinder`](classes/GFFormBinder.md#gfformbinder) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_form_binder.gd` |
| [`GFGraphPathSearchState`](classes/GFGraphPathSearchState.md#gfgraphpathsearchstate) | `RefCounted` | `addons/gf/standard/foundation/math/gf_graph_path_search_state.gd` |
| [`GFHttpRequestBuilder`](classes/GFHttpRequestBuilder.md#gfhttprequestbuilder) | `RefCounted` | `addons/gf/standard/utilities/io/gf_http_request_builder.gd` |
| [`GFHttpResponse`](classes/GFHttpResponse.md#gfhttpresponse) | `RefCounted` | `addons/gf/standard/utilities/io/gf_http_response.gd` |
| [`GFJob`](classes/GFJob.md#gfjob) | `RefCounted` | `addons/gf/standard/utilities/jobs/gf_job.gd` |
| [`GFNodeStateGroup`](classes/GFNodeStateGroup.md#gfnodestategroup) | `Node` | `addons/gf/standard/state_machine/node/gf_node_state_group.gd` |
| [`GFReactiveStateControlBinder`](classes/GFReactiveStateControlBinder.md#gfreactivestatecontrolbinder) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_reactive_state_control_binder.gd` |
| [`GFReactiveStateStore`](classes/GFReactiveStateStore.md#gfreactivestatestore) | `RefCounted` | `addons/gf/standard/utilities/state/gf_reactive_state_store.gd` |
| [`GFShaderParameterBinder`](classes/GFShaderParameterBinder.md#gfshaderparameterbinder) | `Node` | `addons/gf/standard/utilities/display/gf_shader_parameter_binder.gd` |
| [`GFSignalBridgeBinding`](classes/GFSignalBridgeBinding.md#gfsignalbridgebinding) | `RefCounted` | `addons/gf/standard/utilities/signals/bridge/gf_signal_bridge_binding.gd` |
| [`GFSignalConnection`](classes/GFSignalConnection.md#gfsignalconnection) | `RefCounted` | `addons/gf/standard/utilities/signals/gf_signal_connection.gd` |
| [`GFVirtualInputSource`](classes/GFVirtualInputSource.md#gfvirtualinputsource) | `RefCounted` | `addons/gf/standard/input/sources/gf_virtual_input_source.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAudioBackendCapability`](classes/GFAudioBackendCapability.md#gfaudiobackendcapability) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_backend_capability.gd` |
| [`GFBigNumber`](classes/GFBigNumber.md#gfbignumber) | `RefCounted` | `addons/gf/standard/foundation/numeric/gf_big_number.gd` |
| [`GFBuildInfo`](classes/GFBuildInfo.md#gfbuildinfo) | `Resource` | `addons/gf/standard/utilities/debug/gf_build_info.gd` |
| [`GFConfigValidationReport`](classes/GFConfigValidationReport.md#gfconfigvalidationreport) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_validation_report.gd` |
| [`GFDeque`](classes/GFDeque.md#gfdeque) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_deque.gd` |
| [`GFDirectoryChangeSet`](classes/GFDirectoryChangeSet.md#gfdirectorychangeset) | `RefCounted` | `addons/gf/standard/utilities/io/gf_directory_change_set.gd` |
| [`GFFixedDecimal`](classes/GFFixedDecimal.md#gffixeddecimal) | `RefCounted` | `addons/gf/standard/foundation/numeric/gf_fixed_decimal.gd` |
| [`GFFixedVector2`](classes/GFFixedVector2.md#gffixedvector2) | `RefCounted` | `addons/gf/standard/foundation/numeric/gf_fixed_vector2.gd` |
| [`GFFixedVector3`](classes/GFFixedVector3.md#gffixedvector3) | `RefCounted` | `addons/gf/standard/foundation/numeric/gf_fixed_vector3.gd` |
| [`GFFormulaParameter`](classes/GFFormulaParameter.md#gfformulaparameter) | `RefCounted` | `addons/gf/standard/foundation/formula/gf_formula_parameter.gd` |
| [`GFMetricSeries`](classes/GFMetricSeries.md#gfmetricseries) | `RefCounted` | `addons/gf/standard/utilities/debug/gf_metric_series.gd` |
| [`GFModalResult`](classes/GFModalResult.md#gfmodalresult) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_modal_result.gd` |
| [`GFResultDictionary`](classes/GFResultDictionary.md#gfresultdictionary) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_result_dictionary.gd` |
| [`GFSequenceContext`](classes/GFSequenceContext.md#gfsequencecontext) | `RefCounted` | `addons/gf/standard/sequence/gf_sequence_context.gd` |
| [`GFSourceSpan`](classes/GFSourceSpan.md#gfsourcespan) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_source_span.gd` |
| [`GFSteeringAcceleration`](classes/GFSteeringAcceleration.md#gfsteeringacceleration) | `RefCounted` | `addons/gf/standard/foundation/math/gf_steering_acceleration.gd` |
| [`GFSteeringAgent`](classes/GFSteeringAgent.md#gfsteeringagent) | `RefCounted` | `addons/gf/standard/foundation/math/gf_steering_agent.gd` |
| [`GFStorageConflictReport`](classes/GFStorageConflictReport.md#gfstorageconflictreport) | `Resource` | `addons/gf/standard/utilities/storage/gf_storage_conflict_report.gd` |
| [`GFUuid`](classes/GFUuid.md#gfuuid) | `RefCounted` | `addons/gf/standard/foundation/identity/gf_uuid.gd` |
| [`GFValidationIssue`](classes/GFValidationIssue.md#gfvalidationissue) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_issue.gd` |
| [`GFValidationReport`](classes/GFValidationReport.md#gfvalidationreport) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_report.gd` |

<a id="category-domain_model"></a>

### 领域模型

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFDropZone`](classes/GFDropZone.md#gfdropzone) | `RefCounted` | `addons/gf/standard/input/drag_drop/gf_drop_zone.gd` |
| [`GFInputDirectionHistory`](classes/GFInputDirectionHistory.md#gfinputdirectionhistory) | `RefCounted` | `addons/gf/standard/input/history/gf_input_direction_history.gd` |
| [`GFInputRecording`](classes/GFInputRecording.md#gfinputrecording) | `RefCounted` | `addons/gf/standard/input/recording/gf_input_recording.gd` |
| [`GFReplayTimeline`](classes/GFReplayTimeline.md#gfreplaytimeline) | `RefCounted` | `addons/gf/standard/foundation/timeline/gf_replay_timeline.gd` |

<a id="category-event_contract"></a>

### 事件契约

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAudioEvent`](classes/GFAudioEvent.md#gfaudioevent) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_event.gd` |
| [`GFAudioParameter`](classes/GFAudioParameter.md#gfaudioparameter) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_parameter.gd` |
| [`GFAudioState`](classes/GFAudioState.md#gfaudiostate) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_state.gd` |
| [`GFAudioSwitch`](classes/GFAudioSwitch.md#gfaudioswitch) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_switch.gd` |
| [`GFRequestEnvelope`](classes/GFRequestEnvelope.md#gfrequestenvelope) | `RefCounted` | `addons/gf/standard/utilities/io/gf_request_envelope.gd` |

<a id="category-editor_api"></a>

### 编辑器 API

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFBuildInfoExportPlugin`](classes/GFBuildInfoExportPlugin.md#gfbuildinfoexportplugin) | `EditorExportPlugin` | `addons/gf/standard/utilities/debug/editor/gf_build_info_export_plugin.gd` |
| [`GFDiagnosticsDock`](classes/GFDiagnosticsDock.md#gfdiagnosticsdock) | `Control` | `addons/gf/standard/utilities/debug/editor/gf_diagnostics_dock.gd` |
| [`GFInputMappingDock`](classes/GFInputMappingDock.md#gfinputmappingdock) | `Control` | `addons/gf/standard/input/editor/gf_input_mapping_dock.gd` |
| [`GFNodeStateMachineDock`](classes/GFNodeStateMachineDock.md#gfnodestatemachinedock) | `Control` | `addons/gf/standard/state_machine/node/editor/gf_node_state_machine_dock.gd` |
| [`GFSignalGraphDock`](classes/GFSignalGraphDock.md#gfsignalgraphdock) | `Control` | `addons/gf/standard/utilities/debug/editor/gf_signal_graph_dock.gd` |
| [`GFStorageViewerDock`](classes/GFStorageViewerDock.md#gfstorageviewerdock) | `VBoxContainer` | `addons/gf/standard/utilities/storage/editor/gf_storage_viewer_dock.gd` |
