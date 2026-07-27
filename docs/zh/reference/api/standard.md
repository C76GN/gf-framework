# Standard API

模块：`standard`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 187 | 3342 | 2259 |
| [协议与扩展点](#category-protocol) | 24 | 337 | 266 |
| [资源定义](#category-resource_definition) | 117 | 1505 | 771 |
| [运行时句柄](#category-runtime_handle) | 45 | 757 | 495 |
| [值对象](#category-value_object) | 38 | 698 | 442 |
| [领域模型](#category-domain_model) | 4 | 61 | 42 |
| [事件契约](#category-event_contract) | 6 | 61 | 23 |
| [编辑器 API](#category-editor_api) | 11 | 68 | 46 |
| [工具 API](#category-tool_api) | 3 | 45 | 25 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFActivationTransaction`](classes/GFActivationTransaction.md#gfactivationtransaction) | `RefCounted` | `addons/gf/standard/foundation/policy/gf_activation_transaction.gd` |
| [`GFAnalyticsOutboxAdapter`](classes/GFAnalyticsOutboxAdapter.md#gfanalyticsoutboxadapter) | `RefCounted` | `addons/gf/standard/utilities/io/gf_analytics_outbox_adapter.gd` |
| [`GFAnalyticsSchemaRegistry`](classes/GFAnalyticsSchemaRegistry.md#gfanalyticsschemaregistry) | `Resource` | `addons/gf/standard/utilities/analytics/gf_analytics_schema_registry.gd` |
| [`GFAnalyticsUtility`](classes/GFAnalyticsUtility.md#gfanalyticsutility) | `GFUtility` | `addons/gf/standard/utilities/analytics/gf_analytics_utility.gd` |
| [`GFArtifactFreshnessReport`](classes/GFArtifactFreshnessReport.md#gfartifactfreshnessreport) | `RefCounted` | `addons/gf/standard/foundation/policy/gf_artifact_freshness_report.gd` |
| [`GFAssetCatalogRuntime`](classes/GFAssetCatalogRuntime.md#gfassetcatalogruntime) | `GFUtility` | `addons/gf/standard/utilities/assets/gf_asset_catalog_runtime.gd` |
| [`GFAssetCatalogSourceRegistry`](classes/GFAssetCatalogSourceRegistry.md#gfassetcatalogsourceregistry) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_asset_catalog_source_registry.gd` |
| [`GFAssetUtility`](classes/GFAssetUtility.md#gfassetutility) | `GFUtility` | `addons/gf/standard/utilities/assets/gf_asset_utility.gd` |
| [`GFAsyncFlowTools`](classes/GFAsyncFlowTools.md#gfasyncflowtools) | `RefCounted` | `addons/gf/standard/common/gf_async_flow_tools.gd` |
| [`GFAsyncTrackerUtility`](classes/GFAsyncTrackerUtility.md#gfasynctrackerutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_async_tracker_utility.gd` |
| [`GFAsyncWaitUtility`](classes/GFAsyncWaitUtility.md#gfasyncwaitutility) | `RefCounted` | `addons/gf/standard/common/gf_async_wait_utility.gd` |
| [`GFAudioCatalogProvider`](classes/GFAudioCatalogProvider.md#gfaudiocatalogprovider) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_catalog_provider.gd` |
| [`GFAudioMetadataTools`](classes/GFAudioMetadataTools.md#gfaudiometadatatools) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_metadata_tools.gd` |
| [`GFAudioPitchAnalysisTools`](classes/GFAudioPitchAnalysisTools.md#gfaudiopitchanalysistools) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_pitch_analysis_tools.gd` |
| [`GFAudioUtility`](classes/GFAudioUtility.md#gfaudioutility) | `GFUtility` | `addons/gf/standard/utilities/audio/gf_audio_utility.gd` |
| [`GFBackgroundWorkUtility`](classes/GFBackgroundWorkUtility.md#gfbackgroundworkutility) | `GFUtility` | `addons/gf/standard/utilities/jobs/gf_background_work_utility.gd` |
| [`GFBatchedLogSink`](classes/GFBatchedLogSink.md#gfbatchedlogsink) | `GFLogSink` | `addons/gf/standard/utilities/logging/gf_batched_log_sink.gd` |
| [`GFBridgeContractReport`](classes/GFBridgeContractReport.md#gfbridgecontractreport) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_bridge_contract_report.gd` |
| [`GFBudgetLedger`](classes/GFBudgetLedger.md#gfbudgetledger) | `RefCounted` | `addons/gf/standard/foundation/budget/gf_budget_ledger.gd` |
| [`GFBuildInfoUtility`](classes/GFBuildInfoUtility.md#gfbuildinfoutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_build_info_utility.gd` |
| [`GFCacheDiagnostics`](classes/GFCacheDiagnostics.md#gfcachediagnostics) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_cache_diagnostics.gd` |
| [`GFCollisionBroadphase2D`](classes/GFCollisionBroadphase2D.md#gfcollisionbroadphase2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_collision_broadphase_2d.gd` |
| [`GFCollisionBroadphase3D`](classes/GFCollisionBroadphase3D.md#gfcollisionbroadphase3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_collision_broadphase_3d.gd` |
| [`GFCollisionNarrowphase2D`](classes/GFCollisionNarrowphase2D.md#gfcollisionnarrowphase2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_collision_narrowphase_2d.gd` |
| [`GFCommandHistoryUtility`](classes/GFCommandHistoryUtility.md#gfcommandhistoryutility) | `GFUtility` | `addons/gf/standard/utilities/history/gf_command_history_utility.gd` |
| [`GFCommandSequence`](classes/GFCommandSequence.md#gfcommandsequence) | `RefCounted` | `addons/gf/standard/sequence/gf_command_sequence.gd` |
| [`GFCompatibilityPreflight`](classes/GFCompatibilityPreflight.md#gfcompatibilitypreflight) | `RefCounted` | `addons/gf/standard/foundation/policy/gf_compatibility_preflight.gd` |
| [`GFConfigProviderAdapter`](classes/GFConfigProviderAdapter.md#gfconfigprovideradapter) | `GFConfigProvider` | `addons/gf/standard/utilities/config/gf_config_provider_adapter.gd` |
| [`GFConfigReferenceResolver`](classes/GFConfigReferenceResolver.md#gfconfigreferenceresolver) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_reference_resolver.gd` |
| [`GFConfigTableImporter`](classes/GFConfigTableImporter.md#gfconfigtableimporter) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_table_importer.gd` |
| [`GFConfigTableMergeTools`](classes/GFConfigTableMergeTools.md#gfconfigtablemergetools) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_table_merge_tools.gd` |
| [`GFConsoleUtility`](classes/GFConsoleUtility.md#gfconsoleutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_console_utility.gd` |
| [`GFControlFocusUtility`](classes/GFControlFocusUtility.md#gfcontrolfocusutility) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_control_focus_utility.gd` |
| [`GFControlValueAdapter`](classes/GFControlValueAdapter.md#gfcontrolvalueadapter) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_control_value_adapter.gd` |
| [`GFCurve2DMath`](classes/GFCurve2DMath.md#gfcurve2dmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_curve_2d_math.gd` |
| [`GFCurve3DMath`](classes/GFCurve3DMath.md#gfcurve3dmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_curve_3d_math.gd` |
| [`GFDataProjection`](classes/GFDataProjection.md#gfdataprojection) | `RefCounted` | `addons/gf/standard/foundation/variant/gf_data_projection.gd` |
| [`GFDebugDrawUtility`](classes/GFDebugDrawUtility.md#gfdebugdrawutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_debug_draw_utility.gd` |
| [`GFDebugOverlayUtility`](classes/GFDebugOverlayUtility.md#gfdebugoverlayutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_debug_overlay_utility.gd` |
| [`GFDeferredMutationQueue`](classes/GFDeferredMutationQueue.md#gfdeferredmutationqueue) | `GFUtility` | `addons/gf/standard/common/gf_deferred_mutation_queue.gd` |
| [`GFDelimitedTextTools`](classes/GFDelimitedTextTools.md#gfdelimitedtexttools) | `RefCounted` | `addons/gf/standard/foundation/text/gf_delimited_text_tools.gd` |
| [`GFDeterministicVariantSerializer`](classes/GFDeterministicVariantSerializer.md#gfdeterministicvariantserializer) | `RefCounted` | `addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd` |
| [`GFDiagnosticsUtility`](classes/GFDiagnosticsUtility.md#gfdiagnosticsutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_diagnostics_utility.gd` |
| [`GFDirectoryWatchUtility`](classes/GFDirectoryWatchUtility.md#gfdirectorywatchutility) | `RefCounted` | `addons/gf/standard/utilities/io/gf_directory_watch_utility.gd` |
| [`GFDisplaySettingsUtility`](classes/GFDisplaySettingsUtility.md#gfdisplaysettingsutility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_display_settings_utility.gd` |
| [`GFDownloadUtility`](classes/GFDownloadUtility.md#gfdownloadutility) | `GFUtility` | `addons/gf/standard/utilities/io/gf_download_utility.gd` |
| [`GFDragDropController`](classes/GFDragDropController.md#gfdragdropcontroller) | `Node` | `addons/gf/standard/input/drag_drop/gf_drag_drop_controller.gd` |
| [`GFDragDropUtility`](classes/GFDragDropUtility.md#gfdragdroputility) | `GFUtility` | `addons/gf/standard/input/drag_drop/gf_drag_drop_utility.gd` |
| [`GFDualMeshTopology2D`](classes/GFDualMeshTopology2D.md#gfdualmeshtopology2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_dual_mesh_topology_2d.gd` |
| [`GFExecutionLaneDiagnostics`](classes/GFExecutionLaneDiagnostics.md#gfexecutionlanediagnostics) | `RefCounted` | `addons/gf/standard/common/gf_execution_lane_diagnostics.gd` |
| [`GFGraphLayoutUtility`](classes/GFGraphLayoutUtility.md#gfgraphlayoututility) | `RefCounted` | `addons/gf/standard/foundation/math/gf_graph_layout_utility.gd` |
| [`GFGraphMath`](classes/GFGraphMath.md#gfgraphmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_graph_math.gd` |
| [`GFGrid3DMath`](classes/GFGrid3DMath.md#gfgrid3dmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_3d_math.gd` |
| [`GFGridConnectionMath2D`](classes/GFGridConnectionMath2D.md#gfgridconnectionmath2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_connection_math_2d.gd` |
| [`GFGridCoordinateMath2D`](classes/GFGridCoordinateMath2D.md#gfgridcoordinatemath2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_coordinate_math_2d.gd` |
| [`GFGridGenerationMath2D`](classes/GFGridGenerationMath2D.md#gfgridgenerationmath2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_generation_math_2d.gd` |
| [`GFGridKey3D`](classes/GFGridKey3D.md#gfgridkey3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_key_3d.gd` |
| [`GFGridMath`](classes/GFGridMath.md#gfgridmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_math.gd` |
| [`GFGridOccupancy`](classes/GFGridOccupancy.md#gfgridoccupancy) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_occupancy.gd` |
| [`GFGridPathMath2D`](classes/GFGridPathMath2D.md#gfgridpathmath2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_path_math_2d.gd` |
| [`GFGridPlaneMapper3D`](classes/GFGridPlaneMapper3D.md#gfgridplanemapper3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_plane_mapper_3d.gd` |
| [`GFGridTransform2D`](classes/GFGridTransform2D.md#gfgridtransform2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_grid_transform_2d.gd` |
| [`GFHeightfield3D`](classes/GFHeightfield3D.md#gfheightfield3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_heightfield_3d.gd` |
| [`GFHexGridMath`](classes/GFHexGridMath.md#gfhexgridmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_hex_grid_math.gd` |
| [`GFHttpClientUtility`](classes/GFHttpClientUtility.md#gfhttpclientutility) | `GFUtility` | `addons/gf/standard/utilities/io/gf_http_client_utility.gd` |
| [`GFInputAssistUtility`](classes/GFInputAssistUtility.md#gfinputassistutility) | `GFUtility` | `addons/gf/standard/input/runtime/gf_input_assist_utility.gd` |
| [`GFInputConflictAnalyzer`](classes/GFInputConflictAnalyzer.md#gfinputconflictanalyzer) | `RefCounted` | `addons/gf/standard/input/rebinding/gf_input_conflict_analyzer.gd` |
| [`GFInputContextDiagnostics`](classes/GFInputContextDiagnostics.md#gfinputcontextdiagnostics) | `RefCounted` | `addons/gf/standard/input/mapping/gf_input_context_diagnostics.gd` |
| [`GFInputDetector`](classes/GFInputDetector.md#gfinputdetector) | `Node` | `addons/gf/standard/input/rebinding/gf_input_detector.gd` |
| [`GFInputDeviceUtility`](classes/GFInputDeviceUtility.md#gfinputdeviceutility) | `GFUtility` | `addons/gf/standard/input/runtime/gf_input_device_utility.gd` |
| [`GFInputDirectionTools`](classes/GFInputDirectionTools.md#gfinputdirectiontools) | `RefCounted` | `addons/gf/standard/input/common/gf_input_direction_tools.gd` |
| [`GFInputFormatter`](classes/GFInputFormatter.md#gfinputformatter) | `RefCounted` | `addons/gf/standard/input/formatting/gf_input_formatter.gd` |
| [`GFInputFormatterRegistry`](classes/GFInputFormatterRegistry.md#gfinputformatterregistry) | `RefCounted` | `addons/gf/standard/input/formatting/gf_input_formatter_registry.gd` |
| [`GFInputMapPresetTools`](classes/GFInputMapPresetTools.md#gfinputmappresettools) | `RefCounted` | `addons/gf/standard/input/mapping/gf_input_map_preset_tools.gd` |
| [`GFInputMappingUtility`](classes/GFInputMappingUtility.md#gfinputmappingutility) | `GFUtility` | `addons/gf/standard/input/runtime/gf_input_mapping_utility.gd` |
| [`GFInputPlayback`](classes/GFInputPlayback.md#gfinputplayback) | `RefCounted` | `addons/gf/standard/input/recording/gf_input_playback.gd` |
| [`GFJobQueueUtility`](classes/GFJobQueueUtility.md#gfjobqueueutility) | `GFUtility` | `addons/gf/standard/utilities/jobs/gf_job_queue_utility.gd` |
| [`GFJobWorker`](classes/GFJobWorker.md#gfjobworker) | `Node` | `addons/gf/standard/utilities/jobs/gf_job_worker.gd` |
| [`GFJsonLineLogSink`](classes/GFJsonLineLogSink.md#gfjsonlinelogsink) | `GFLogSink` | `addons/gf/standard/utilities/logging/gf_json_line_log_sink.gd` |
| [`GFLayerMaskUtility`](classes/GFLayerMaskUtility.md#gflayermaskutility) | `RefCounted` | `addons/gf/standard/foundation/math/gf_layer_mask_utility.gd` |
| [`GFLogUtility`](classes/GFLogUtility.md#gflogutility) | `GFUtility` | `addons/gf/standard/utilities/logging/gf_log_utility.gd` |
| [`GFMainThreadDispatchQueue`](classes/GFMainThreadDispatchQueue.md#gfmainthreaddispatchqueue) | `GFUtility` | `addons/gf/standard/common/gf_main_thread_dispatch_queue.gd` |
| [`GFManualClock`](classes/GFManualClock.md#gfmanualclock) | `GFClock` | `addons/gf/standard/utilities/time/gf_manual_clock.gd` |
| [`GFMutationBatch`](classes/GFMutationBatch.md#gfmutationbatch) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_mutation_batch.gd` |
| [`GFNodeGroupCache`](classes/GFNodeGroupCache.md#gfnodegroupcache) | `RefCounted` | `addons/gf/standard/utilities/nodes/gf_node_group_cache.gd` |
| [`GFNodeStateMachine`](classes/GFNodeStateMachine.md#gfnodestatemachine) | `Node` | `addons/gf/standard/state_machine/node/gf_node_state_machine.gd` |
| [`GFNodeStateMachineValidator`](classes/GFNodeStateMachineValidator.md#gfnodestatemachinevalidator) | `RefCounted` | `addons/gf/standard/state_machine/node/gf_node_state_machine_validator.gd` |
| [`GFNodeTreeOps`](classes/GFNodeTreeOps.md#gfnodetreeops) | `RefCounted` | `addons/gf/standard/utilities/nodes/gf_node_tree_ops.gd` |
| [`GFNoiseFieldTools`](classes/GFNoiseFieldTools.md#gfnoisefieldtools) | `RefCounted` | `addons/gf/standard/foundation/math/gf_noise_field_tools.gd` |
| [`GFNotificationUtility`](classes/GFNotificationUtility.md#gfnotificationutility) | `GFUtility` | `addons/gf/standard/utilities/ui/gf_notification_utility.gd` |
| [`GFNumberFormatter`](classes/GFNumberFormatter.md#gfnumberformatter) | `RefCounted` | `addons/gf/standard/foundation/formatting/gf_number_formatter.gd` |
| [`GFNumericModifierMath`](classes/GFNumericModifierMath.md#gfnumericmodifiermath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_numeric_modifier_math.gd` |
| [`GFObjectCandidateRegistry`](classes/GFObjectCandidateRegistry.md#gfobjectcandidateregistry) | `RefCounted` | `addons/gf/standard/common/gf_object_candidate_registry.gd` |
| [`GFObjectPoolUtility`](classes/GFObjectPoolUtility.md#gfobjectpoolutility) | `GFUtility` | `addons/gf/standard/utilities/nodes/gf_object_pool_utility.gd` |
| [`GFOperationDiagnosticsUtility`](classes/GFOperationDiagnosticsUtility.md#gfoperationdiagnosticsutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_operation_diagnostics_utility.gd` |
| [`GFPathEnumerationTools`](classes/GFPathEnumerationTools.md#gfpathenumerationtools) | `RefCounted` | `addons/gf/standard/utilities/io/gf_path_enumeration_tools.gd` |
| [`GFPhysicsQueryUtility`](classes/GFPhysicsQueryUtility.md#gfphysicsqueryutility) | `GFUtility` | `addons/gf/standard/utilities/spatial/gf_physics_query_utility.gd` |
| [`GFPlacementSequenceMath`](classes/GFPlacementSequenceMath.md#gfplacementsequencemath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_placement_sequence_math.gd` |
| [`GFPlatformRuntime`](classes/GFPlatformRuntime.md#gfplatformruntime) | `GFUtility` | `addons/gf/standard/platform/gf_platform_runtime.gd` |
| [`GFPointerActivityUtility`](classes/GFPointerActivityUtility.md#gfpointeractivityutility) | `GFUtility` | `addons/gf/standard/input/runtime/gf_pointer_activity_utility.gd` |
| [`GFPointerGestureUtility`](classes/GFPointerGestureUtility.md#gfpointergestureutility) | `GFUtility` | `addons/gf/standard/input/runtime/gf_pointer_gesture_utility.gd` |
| [`GFPoissonDisc2D`](classes/GFPoissonDisc2D.md#gfpoissondisc2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_poisson_disc_2d.gd` |
| [`GFPolicyRegistry`](classes/GFPolicyRegistry.md#gfpolicyregistry) | `Resource` | `addons/gf/standard/foundation/policy/gf_policy_registry.gd` |
| [`GFPolynomialMath`](classes/GFPolynomialMath.md#gfpolynomialmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_polynomial_math.gd` |
| [`GFProgressionMath`](classes/GFProgressionMath.md#gfprogressionmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_progression_math.gd` |
| [`GFQuadTreeUtility`](classes/GFQuadTreeUtility.md#gfquadtreeutility) | `GFUtility` | `addons/gf/standard/utilities/spatial/gf_quad_tree_utility.gd` |
| [`GFQuietWindowCoalescer`](classes/GFQuietWindowCoalescer.md#gfquietwindowcoalescer) | `RefCounted` | `addons/gf/standard/common/gf_quiet_window_coalescer.gd` |
| [`GFRectPacking2D`](classes/GFRectPacking2D.md#gfrectpacking2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_rect_packing_2d.gd` |
| [`GFRefCountedPool`](classes/GFRefCountedPool.md#gfrefcountedpool) | `RefCounted` | `addons/gf/standard/utilities/pooling/gf_ref_counted_pool.gd` |
| [`GFRegionMap2D`](classes/GFRegionMap2D.md#gfregionmap2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_region_map_2d.gd` |
| [`GFRegionMap3D`](classes/GFRegionMap3D.md#gfregionmap3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_region_map_3d.gd` |
| [`GFRemoteCacheUtility`](classes/GFRemoteCacheUtility.md#gfremotecacheutility) | `GFUtility` | `addons/gf/standard/utilities/io/gf_remote_cache_utility.gd` |
| [`GFRenderWarmupUtility`](classes/GFRenderWarmupUtility.md#gfrenderwarmuputility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_render_warmup_utility.gd` |
| [`GFRequestHandlerRegistry`](classes/GFRequestHandlerRegistry.md#gfrequesthandlerregistry) | `RefCounted` | `addons/gf/standard/common/gf_request_handler_registry.gd` |
| [`GFRequestOutboxUtility`](classes/GFRequestOutboxUtility.md#gfrequestoutboxutility) | `GFUtility` | `addons/gf/standard/utilities/io/gf_request_outbox_utility.gd` |
| [`GFResourceConfigProvider`](classes/GFResourceConfigProvider.md#gfresourceconfigprovider) | `GFConfigProvider` | `addons/gf/standard/utilities/config/gf_resource_config_provider.gd` |
| [`GFResourceFeatureRemapTools`](classes/GFResourceFeatureRemapTools.md#gfresourcefeatureremaptools) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_resource_feature_remap_tools.gd` |
| [`GFResourceGraphScanner`](classes/GFResourceGraphScanner.md#gfresourcegraphscanner) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_resource_graph_scanner.gd` |
| [`GFResourceRegistryAssetSourceProvider`](classes/GFResourceRegistryAssetSourceProvider.md#gfresourceregistryassetsourceprovider) | `GFAssetCatalogSourceProvider` | `addons/gf/standard/utilities/assets/gf_resource_registry_asset_source_provider.gd` |
| [`GFResourceResolverUtility`](classes/GFResourceResolverUtility.md#gfresourceresolverutility) | `GFUtility` | `addons/gf/standard/utilities/assets/gf_resource_resolver_utility.gd` |
| [`GFResourceVariantProvider`](classes/GFResourceVariantProvider.md#gfresourcevariantprovider) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_resource_variant_provider.gd` |
| [`GFRichTextFormatter`](classes/GFRichTextFormatter.md#gfrichtextformatter) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_rich_text_formatter.gd` |
| [`GFRuntimeAgentEnvironment`](classes/GFRuntimeAgentEnvironment.md#gfruntimeagentenvironment) | `GFUtility` | `addons/gf/standard/utilities/agent/gf_runtime_agent_environment.gd` |
| [`GFRuntimeCleanupScope`](classes/GFRuntimeCleanupScope.md#gfruntimecleanupscope) | `RefCounted` | `addons/gf/standard/common/gf_runtime_cleanup_scope.gd` |
| [`GFRuntimeInspectorUtility`](classes/GFRuntimeInspectorUtility.md#gfruntimeinspectorutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_runtime_inspector_utility.gd` |
| [`GFRuntimeTaskScheduler`](classes/GFRuntimeTaskScheduler.md#gfruntimetaskscheduler) | `GFUtility` | `addons/gf/standard/sequence/gf_runtime_task_scheduler.gd` |
| [`GFSafeResourceCodec`](classes/GFSafeResourceCodec.md#gfsaferesourcecodec) | `RefCounted` | `addons/gf/standard/utilities/storage/gf_safe_resource_codec.gd` |
| [`GFSceneContractTools`](classes/GFSceneContractTools.md#gfscenecontracttools) | `RefCounted` | `addons/gf/standard/utilities/scene/gf_scene_contract_tools.gd` |
| [`GFSceneUtility`](classes/GFSceneUtility.md#gfsceneutility) | `GFUtility` | `addons/gf/standard/utilities/scene/gf_scene_utility.gd` |
| [`GFScreenTransitionUtility`](classes/GFScreenTransitionUtility.md#gfscreentransitionutility) | `GFUtility` | `addons/gf/standard/utilities/scene/gf_screen_transition_utility.gd` |
| [`GFScreenshotUtility`](classes/GFScreenshotUtility.md#gfscreenshotutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_screenshot_utility.gd` |
| [`GFScriptStructureTools`](classes/GFScriptStructureTools.md#gfscriptstructuretools) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_script_structure_tools.gd` |
| [`GFSeedUtility`](classes/GFSeedUtility.md#gfseedutility) | `GFUtility` | `addons/gf/standard/utilities/random/gf_seed_utility.gd` |
| [`GFSessionTraceUtility`](classes/GFSessionTraceUtility.md#gfsessiontraceutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_session_trace_utility.gd` |
| [`GFSettingsUtility`](classes/GFSettingsUtility.md#gfsettingsutility) | `GFUtility` | `addons/gf/standard/utilities/settings/gf_settings_utility.gd` |
| [`GFShaderParameterUtility`](classes/GFShaderParameterUtility.md#gfshaderparameterutility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_shader_parameter_utility.gd` |
| [`GFSignalRuntimeProbe`](classes/GFSignalRuntimeProbe.md#gfsignalruntimeprobe) | `RefCounted` | `addons/gf/standard/utilities/debug/gf_signal_runtime_probe.gd` |
| [`GFSignalUtility`](classes/GFSignalUtility.md#gfsignalutility) | `GFUtility` | `addons/gf/standard/utilities/signals/gf_signal_utility.gd` |
| [`GFSnapshotHistoryUtility`](classes/GFSnapshotHistoryUtility.md#gfsnapshothistoryutility) | `GFUtility` | `addons/gf/standard/utilities/history/gf_snapshot_history_utility.gd` |
| [`GFSourceTextLoader`](classes/GFSourceTextLoader.md#gfsourcetextloader) | `RefCounted` | `addons/gf/standard/utilities/io/gf_source_text_loader.gd` |
| [`GFSourceTextPatchTools`](classes/GFSourceTextPatchTools.md#gfsourcetextpatchtools) | `RefCounted` | `addons/gf/standard/foundation/text/gf_source_text_patch_tools.gd` |
| [`GFSpatialCanvas2D`](classes/GFSpatialCanvas2D.md#gfspatialcanvas2d) | `Control` | `addons/gf/standard/utilities/spatial_canvas/gf_spatial_canvas_2d.gd` |
| [`GFSpatialHash3D`](classes/GFSpatialHash3D.md#gfspatialhash3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_spatial_hash_3d.gd` |
| [`GFSpatialQueryIndex2D`](classes/GFSpatialQueryIndex2D.md#gfspatialqueryindex2d) | `RefCounted` | `addons/gf/standard/utilities/spatial/gf_spatial_query_index_2d.gd` |
| [`GFSpatialQueryIndex3D`](classes/GFSpatialQueryIndex3D.md#gfspatialqueryindex3d) | `RefCounted` | `addons/gf/standard/utilities/spatial/gf_spatial_query_index_3d.gd` |
| [`GFSpringMath`](classes/GFSpringMath.md#gfspringmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_spring_math.gd` |
| [`GFStateMachine`](classes/GFStateMachine.md#gfstatemachine) | `RefCounted` | `addons/gf/standard/state_machine/pure/gf_state_machine.gd` |
| [`GFSteeringMath`](classes/GFSteeringMath.md#gfsteeringmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_steering_math.gd` |
| [`GFStorageFailoverBackend`](classes/GFStorageFailoverBackend.md#gfstoragefailoverbackend) | `GFStorageBackend` | `addons/gf/standard/utilities/storage/gf_storage_failover_backend.gd` |
| [`GFStorageSyncUtility`](classes/GFStorageSyncUtility.md#gfstoragesyncutility) | `GFUtility` | `addons/gf/standard/utilities/storage/gf_storage_sync_utility.gd` |
| [`GFStorageUtility`](classes/GFStorageUtility.md#gfstorageutility) | `GFUtility` | `addons/gf/standard/utilities/storage/gf_storage_utility.gd` |
| [`GFSupportReportUtility`](classes/GFSupportReportUtility.md#gfsupportreportutility) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_support_report_utility.gd` |
| [`GFSupportReportWorkflow`](classes/GFSupportReportWorkflow.md#gfsupportreportworkflow) | `GFUtility` | `addons/gf/standard/utilities/debug/gf_support_report_workflow.gd` |
| [`GFSurfaceScatterSampler3D`](classes/GFSurfaceScatterSampler3D.md#gfsurfacescattersampler3d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_surface_scatter_sampler_3d.gd` |
| [`GFSurfaceUtility`](classes/GFSurfaceUtility.md#gfsurfaceutility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_surface_utility.gd` |
| [`GFTableDataView`](classes/GFTableDataView.md#gftabledataview) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_table_data_view.gd` |
| [`GFTableSelectionModel`](classes/GFTableSelectionModel.md#gftableselectionmodel) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_table_selection_model.gd` |
| [`GFTagSourceAdapter`](classes/GFTagSourceAdapter.md#gftagsourceadapter) | `RefCounted` | `addons/gf/standard/foundation/tags/gf_tag_source_adapter.gd` |
| [`GFTextAutoFit`](classes/GFTextAutoFit.md#gftextautofit) | `Node` | `addons/gf/standard/utilities/ui/gf_text_auto_fit.gd` |
| [`GFTextFitter`](classes/GFTextFitter.md#gftextfitter) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_text_fitter.gd` |
| [`GFTextSearchScorer`](classes/GFTextSearchScorer.md#gftextsearchscorer) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_text_search_scorer.gd` |
| [`GFTextureSetClassifier`](classes/GFTextureSetClassifier.md#gftexturesetclassifier) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_texture_set_classifier.gd` |
| [`GFTimeUtility`](classes/GFTimeUtility.md#gftimeutility) | `GFTimeProvider` | `addons/gf/standard/utilities/time/gf_time_utility.gd` |
| [`GFTimedTextImporter`](classes/GFTimedTextImporter.md#gftimedtextimporter) | `RefCounted` | `addons/gf/standard/foundation/timeline/gf_timed_text_importer.gd` |
| [`GFTimerUtility`](classes/GFTimerUtility.md#gftimerutility) | `GFUtility` | `addons/gf/standard/utilities/time/gf_timer_utility.gd` |
| [`GFTouchButton`](classes/GFTouchButton.md#gftouchbutton) | `GFTouchControl2D` | `addons/gf/standard/input/touch/gf_touch_button.gd` |
| [`GFTouchJoystick`](classes/GFTouchJoystick.md#gftouchjoystick) | `GFTouchControl2D` | `addons/gf/standard/input/touch/gf_touch_joystick.gd` |
| [`GFTrajectoryMath`](classes/GFTrajectoryMath.md#gftrajectorymath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_trajectory_math.gd` |
| [`GFTransform3DMath`](classes/GFTransform3DMath.md#gftransform3dmath) | `RefCounted` | `addons/gf/standard/foundation/math/gf_transform_3d_math.gd` |
| [`GFUIRoutePreloadUtility`](classes/GFUIRoutePreloadUtility.md#gfuiroutepreloadutility) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_ui_route_preload_utility.gd` |
| [`GFUIRouterUtility`](classes/GFUIRouterUtility.md#gfuirouterutility) | `GFUtility` | `addons/gf/standard/utilities/ui/gf_ui_router_utility.gd` |
| [`GFUIUtility`](classes/GFUIUtility.md#gfuiutility) | `GFUtility` | `addons/gf/standard/utilities/ui/gf_ui_utility.gd` |
| [`GFValidationDiagnosticAdapter`](classes/GFValidationDiagnosticAdapter.md#gfvalidationdiagnosticadapter) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_diagnostic_adapter.gd` |
| [`GFValidationJUnitExporter`](classes/GFValidationJUnitExporter.md#gfvalidationjunitexporter) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_junit_exporter.gd` |
| [`GFValidationReportDictionary`](classes/GFValidationReportDictionary.md#gfvalidationreportdictionary) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd` |
| [`GFValidationRunner`](classes/GFValidationRunner.md#gfvalidationrunner) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_validation_runner.gd` |
| [`GFValueIndex`](classes/GFValueIndex.md#gfvalueindex) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_value_index.gd` |
| [`GFVariantData`](classes/GFVariantData.md#gfvariantdata) | `RefCounted` | `addons/gf/standard/foundation/variant/gf_variant_data.gd` |
| [`GFVariantJsonCodec`](classes/GFVariantJsonCodec.md#gfvariantjsoncodec) | `RefCounted` | `addons/gf/standard/foundation/variant/gf_variant_json_codec.gd` |
| [`GFVariantKeyCodec`](classes/GFVariantKeyCodec.md#gfvariantkeycodec) | `RefCounted` | `addons/gf/standard/foundation/variant/gf_variant_key_codec.gd` |
| [`GFVariantReferenceCodec`](classes/GFVariantReferenceCodec.md#gfvariantreferencecodec) | `RefCounted` | `addons/gf/standard/foundation/variant/gf_variant_reference_codec.gd` |
| [`GFViewportUtility`](classes/GFViewportUtility.md#gfviewportutility) | `GFUtility` | `addons/gf/standard/utilities/display/gf_viewport_utility.gd` |
| [`GFVirtualInputBridge`](classes/GFVirtualInputBridge.md#gfvirtualinputbridge) | `RefCounted` | `addons/gf/standard/input/common/gf_virtual_input_bridge.gd` |
| [`GFVirtualListFocusModel`](classes/GFVirtualListFocusModel.md#gfvirtuallistfocusmodel) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_virtual_list_focus_model.gd` |
| [`GFVirtualListModel`](classes/GFVirtualListModel.md#gfvirtuallistmodel) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_virtual_list_model.gd` |
| [`GFVoronoi2D`](classes/GFVoronoi2D.md#gfvoronoi2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_voronoi_2d.gd` |
| [`GFWaveFunctionCollapse2D`](classes/GFWaveFunctionCollapse2D.md#gfwavefunctioncollapse2d) | `RefCounted` | `addons/gf/standard/foundation/math/gf_wave_function_collapse_2d.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAssetCatalogSourceProvider`](classes/GFAssetCatalogSourceProvider.md#gfassetcatalogsourceprovider) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_asset_catalog_source_provider.gd` |
| [`GFAudioBackend`](classes/GFAudioBackend.md#gfaudiobackend) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_backend.gd` |
| [`GFConfigProvider`](classes/GFConfigProvider.md#gfconfigprovider) | `GFUtility` | `addons/gf/standard/utilities/config/gf_config_provider.gd` |
| [`GFConfigValidationRule`](classes/GFConfigValidationRule.md#gfconfigvalidationrule) | `Resource` | `addons/gf/standard/utilities/config/validation/gf_config_validation_rule.gd` |
| [`GFDiagnosticSnapshotProvider`](classes/GFDiagnosticSnapshotProvider.md#gfdiagnosticsnapshotprovider) | `RefCounted` | `addons/gf/standard/utilities/debug/gf_diagnostic_snapshot_provider.gd` |
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
| [`GFPlatformAdapter`](classes/GFPlatformAdapter.md#gfplatformadapter) | `RefCounted` | `addons/gf/standard/platform/gf_platform_adapter.gd` |
| [`GFPlatformAdapterConformance`](classes/GFPlatformAdapterConformance.md#gfplatformadapterconformance) | `RefCounted` | `addons/gf/standard/platform/gf_platform_adapter_conformance.gd` |
| [`GFPolicyProvider`](classes/GFPolicyProvider.md#gfpolicyprovider) | `Resource` | `addons/gf/standard/foundation/policy/gf_policy_provider.gd` |
| [`GFRuntimeTask`](classes/GFRuntimeTask.md#gfruntimetask) | `RefCounted` | `addons/gf/standard/sequence/gf_runtime_task.gd` |
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
| [`GFAnalyticsEventSchema`](classes/GFAnalyticsEventSchema.md#gfanalyticseventschema) | `Resource` | `addons/gf/standard/utilities/analytics/gf_analytics_event_schema.gd` |
| [`GFAssetCatalog`](classes/GFAssetCatalog.md#gfassetcatalog) | `Resource` | `addons/gf/standard/utilities/assets/gf_asset_catalog.gd` |
| [`GFAssetCatalogEntry`](classes/GFAssetCatalogEntry.md#gfassetcatalogentry) | `Resource` | `addons/gf/standard/utilities/assets/gf_asset_catalog_entry.gd` |
| [`GFAssetCollection`](classes/GFAssetCollection.md#gfassetcollection) | `Resource` | `addons/gf/standard/utilities/assets/gf_asset_collection.gd` |
| [`GFAssetPreloadPlan`](classes/GFAssetPreloadPlan.md#gfassetpreloadplan) | `Resource` | `addons/gf/standard/utilities/assets/gf_asset_preload_plan.gd` |
| [`GFAudioBank`](classes/GFAudioBank.md#gfaudiobank) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_bank.gd` |
| [`GFAudioClip`](classes/GFAudioClip.md#gfaudioclip) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_clip.gd` |
| [`GFAudioSpatialSettings`](classes/GFAudioSpatialSettings.md#gfaudiospatialsettings) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_spatial_settings.gd` |
| [`GFBlackboardEntry`](classes/GFBlackboardEntry.md#gfblackboardentry) | `Resource` | `addons/gf/standard/foundation/blackboard/gf_blackboard_entry.gd` |
| [`GFBlackboardSchema`](classes/GFBlackboardSchema.md#gfblackboardschema) | `Resource` | `addons/gf/standard/foundation/blackboard/gf_blackboard_schema.gd` |
| [`GFCallableTargetRef`](classes/GFCallableTargetRef.md#gfcallabletargetref) | `Resource` | `addons/gf/standard/utilities/signals/bridge/gf_callable_target_ref.gd` |
| [`GFCompatibilityProfile`](classes/GFCompatibilityProfile.md#gfcompatibilityprofile) | `Resource` | `addons/gf/standard/foundation/policy/gf_compatibility_profile.gd` |
| [`GFConfigBuildProfile`](classes/GFConfigBuildProfile.md#gfconfigbuildprofile) | `Resource` | `addons/gf/standard/utilities/config/gf_config_build_profile.gd` |
| [`GFConfigDatabaseResource`](classes/GFConfigDatabaseResource.md#gfconfigdatabaseresource) | `Resource` | `addons/gf/standard/utilities/config/gf_config_database_resource.gd` |
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
| [`GFConfigTableResource`](classes/GFConfigTableResource.md#gfconfigtableresource) | `Resource` | `addons/gf/standard/utilities/config/gf_config_table_resource.gd` |
| [`GFConfigTableSchema`](classes/GFConfigTableSchema.md#gfconfigtableschema) | `Resource` | `addons/gf/standard/utilities/config/gf_config_table_schema.gd` |
| [`GFConsoleCommandDefinition`](classes/GFConsoleCommandDefinition.md#gfconsolecommanddefinition) | `Resource` | `addons/gf/standard/utilities/debug/gf_console_command_definition.gd` |
| [`GFDictionarySchema`](classes/GFDictionarySchema.md#gfdictionaryschema) | `Resource` | `addons/gf/standard/foundation/schema/gf_dictionary_schema.gd` |
| [`GFFormulaSet`](classes/GFFormulaSet.md#gfformulaset) | `Resource` | `addons/gf/standard/foundation/formula/gf_formula_set.gd` |
| [`GFGridGenerationPipeline2D`](classes/GFGridGenerationPipeline2D.md#gfgridgenerationpipeline2d) | `Resource` | `addons/gf/standard/foundation/math/gf_grid_generation_pipeline_2d.gd` |
| [`GFGridGenerationStep2D`](classes/GFGridGenerationStep2D.md#gfgridgenerationstep2d) | `Resource` | `addons/gf/standard/foundation/math/gf_grid_generation_step_2d.gd` |
| [`GFImportPlan`](classes/GFImportPlan.md#gfimportplan) | `Resource` | `addons/gf/standard/utilities/assets/gf_import_plan.gd` |
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
| [`GFNodeStateActiveCondition`](classes/GFNodeStateActiveCondition.md#gfnodestateactivecondition) | `GFNodeStateCondition` | `addons/gf/standard/state_machine/node/gf_node_state_active_condition.gd` |
| [`GFNodeStateConditionGroup`](classes/GFNodeStateConditionGroup.md#gfnodestateconditiongroup) | `GFNodeStateCondition` | `addons/gf/standard/state_machine/node/gf_node_state_condition_group.gd` |
| [`GFNodeStateMachineConfig`](classes/GFNodeStateMachineConfig.md#gfnodestatemachineconfig) | `Resource` | `addons/gf/standard/state_machine/node/gf_node_state_machine_config.gd` |
| [`GFObservableArrayResource`](classes/GFObservableArrayResource.md#gfobservablearrayresource) | `Resource` | `addons/gf/standard/foundation/collections/gf_observable_array_resource.gd` |
| [`GFObservableDictionaryResource`](classes/GFObservableDictionaryResource.md#gfobservabledictionaryresource) | `Resource` | `addons/gf/standard/foundation/collections/gf_observable_dictionary_resource.gd` |
| [`GFPattern2D`](classes/GFPattern2D.md#gfpattern2d) | `Resource` | `addons/gf/standard/foundation/math/gf_pattern_2d.gd` |
| [`GFPlatformBridgeRequest`](classes/GFPlatformBridgeRequest.md#gfplatformbridgerequest) | `Resource` | `addons/gf/standard/foundation/platform/gf_platform_bridge_request.gd` |
| [`GFPlatformBridgeResult`](classes/GFPlatformBridgeResult.md#gfplatformbridgeresult) | `Resource` | `addons/gf/standard/foundation/platform/gf_platform_bridge_result.gd` |
| [`GFPlatformCapabilitySet`](classes/GFPlatformCapabilitySet.md#gfplatformcapabilityset) | `Resource` | `addons/gf/standard/foundation/platform/gf_platform_capability_set.gd` |
| [`GFPlatformContractDescriptor`](classes/GFPlatformContractDescriptor.md#gfplatformcontractdescriptor) | `Resource` | `addons/gf/standard/foundation/platform/gf_platform_contract_descriptor.gd` |
| [`GFPlatformContractMethodDescriptor`](classes/GFPlatformContractMethodDescriptor.md#gfplatformcontractmethoddescriptor) | `Resource` | `addons/gf/standard/foundation/platform/gf_platform_contract_method_descriptor.gd` |
| [`GFPlatformLifecycleEvent`](classes/GFPlatformLifecycleEvent.md#gfplatformlifecycleevent) | `Resource` | `addons/gf/standard/foundation/platform/gf_platform_lifecycle_event.gd` |
| [`GFPlatformLocaleMap`](classes/GFPlatformLocaleMap.md#gfplatformlocalemap) | `Resource` | `addons/gf/standard/foundation/text/gf_platform_locale_map.gd` |
| [`GFPlatformRuntimeContext`](classes/GFPlatformRuntimeContext.md#gfplatformruntimecontext) | `Resource` | `addons/gf/standard/foundation/platform/gf_platform_runtime_context.gd` |
| [`GFRawResourceArtifact`](classes/GFRawResourceArtifact.md#gfrawresourceartifact) | `Resource` | `addons/gf/standard/utilities/assets/gf_raw_resource_artifact.gd` |
| [`GFRenderWarmupManifest`](classes/GFRenderWarmupManifest.md#gfrenderwarmupmanifest) | `Resource` | `addons/gf/standard/utilities/display/gf_render_warmup_manifest.gd` |
| [`GFResourceOverlay`](classes/GFResourceOverlay.md#gfresourceoverlay) | `Resource` | `addons/gf/standard/utilities/assets/gf_resource_overlay.gd` |
| [`GFResourcePropertyPatch`](classes/GFResourcePropertyPatch.md#gfresourcepropertypatch) | `Resource` | `addons/gf/standard/utilities/assets/gf_resource_property_patch.gd` |
| [`GFResourceRegistry`](classes/GFResourceRegistry.md#gfresourceregistry) | `Resource` | `addons/gf/standard/utilities/assets/gf_resource_registry.gd` |
| [`GFResourceRegistryEntry`](classes/GFResourceRegistryEntry.md#gfresourceregistryentry) | `Resource` | `addons/gf/standard/utilities/assets/gf_resource_registry_entry.gd` |
| [`GFRuntimeTunableProperty`](classes/GFRuntimeTunableProperty.md#gfruntimetunableproperty) | `Resource` | `addons/gf/standard/utilities/debug/gf_runtime_tunable_property.gd` |
| [`GFSafeResourceCodecPolicy`](classes/GFSafeResourceCodecPolicy.md#gfsaferesourcecodecpolicy) | `Resource` | `addons/gf/standard/utilities/storage/gf_safe_resource_codec_policy.gd` |
| [`GFScenePreloadEntry`](classes/GFScenePreloadEntry.md#gfscenepreloadentry) | `Resource` | `addons/gf/standard/utilities/scene/gf_scene_preload_entry.gd` |
| [`GFScenePreloadMap`](classes/GFScenePreloadMap.md#gfscenepreloadmap) | `Resource` | `addons/gf/standard/utilities/scene/gf_scene_preload_map.gd` |
| [`GFSceneTransitionConfig`](classes/GFSceneTransitionConfig.md#gfscenetransitionconfig) | `Resource` | `addons/gf/standard/utilities/scene/gf_scene_transition_config.gd` |
| [`GFSchemaField`](classes/GFSchemaField.md#gfschemafield) | `Resource` | `addons/gf/standard/foundation/schema/gf_schema_field.gd` |
| [`GFScreenTransitionEffect`](classes/GFScreenTransitionEffect.md#gfscreentransitioneffect) | `Resource` | `addons/gf/standard/utilities/scene/gf_screen_transition_effect.gd` |
| [`GFSessionTraceChannelDefinition`](classes/GFSessionTraceChannelDefinition.md#gfsessiontracechanneldefinition) | `Resource` | `addons/gf/standard/utilities/debug/gf_session_trace_channel_definition.gd` |
| [`GFSessionTraceCheckpoint`](classes/GFSessionTraceCheckpoint.md#gfsessiontracecheckpoint) | `Resource` | `addons/gf/standard/utilities/debug/gf_session_trace_checkpoint.gd` |
| [`GFSessionTraceRecipe`](classes/GFSessionTraceRecipe.md#gfsessiontracerecipe) | `Resource` | `addons/gf/standard/utilities/debug/gf_session_trace_recipe.gd` |
| [`GFSettingDefinition`](classes/GFSettingDefinition.md#gfsettingdefinition) | `Resource` | `addons/gf/standard/utilities/settings/gf_setting_definition.gd` |
| [`GFShaderParameterProfile`](classes/GFShaderParameterProfile.md#gfshaderparameterprofile) | `Resource` | `addons/gf/standard/utilities/display/gf_shader_parameter_profile.gd` |
| [`GFSignalBridge`](classes/GFSignalBridge.md#gfsignalbridge) | `Resource` | `addons/gf/standard/utilities/signals/bridge/gf_signal_bridge.gd` |
| [`GFSignalSourceRef`](classes/GFSignalSourceRef.md#gfsignalsourceref) | `Resource` | `addons/gf/standard/utilities/signals/bridge/gf_signal_source_ref.gd` |
| [`GFSteeringBehaviorResource`](classes/GFSteeringBehaviorResource.md#gfsteeringbehaviorresource) | `Resource` | `addons/gf/standard/foundation/math/gf_steering_behavior_resource.gd` |
| [`GFSteeringBehaviorStack`](classes/GFSteeringBehaviorStack.md#gfsteeringbehaviorstack) | `Resource` | `addons/gf/standard/foundation/math/gf_steering_behavior_stack.gd` |
| [`GFStorageCodec`](classes/GFStorageCodec.md#gfstoragecodec) | `Resource` | `addons/gf/standard/utilities/storage/gf_storage_codec.gd` |
| [`GFTableColumnDefinition`](classes/GFTableColumnDefinition.md#gftablecolumndefinition) | `Resource` | `addons/gf/standard/utilities/ui/gf_table_column_definition.gd` |
| [`GFTagCatalog`](classes/GFTagCatalog.md#gftagcatalog) | `Resource` | `addons/gf/standard/foundation/tags/gf_tag_catalog.gd` |
| [`GFTagExpression`](classes/GFTagExpression.md#gftagexpression) | `Resource` | `addons/gf/standard/foundation/tags/gf_tag_expression.gd` |
| [`GFTagQuery`](classes/GFTagQuery.md#gftagquery) | `Resource` | `addons/gf/standard/foundation/tags/gf_tag_query.gd` |
| [`GFTagSet`](classes/GFTagSet.md#gftagset) | `Resource` | `addons/gf/standard/foundation/tags/gf_tag_set.gd` |
| [`GFTileMapCache`](classes/GFTileMapCache.md#gftilemapcache) | `Resource` | `addons/gf/standard/foundation/math/gf_tile_map_cache.gd` |
| [`GFTileMetadataLayer`](classes/GFTileMetadataLayer.md#gftilemetadatalayer) | `GFTileMapCache` | `addons/gf/standard/foundation/math/gf_tile_metadata_layer.gd` |
| [`GFTileRuleSet`](classes/GFTileRuleSet.md#gftileruleset) | `Resource` | `addons/gf/standard/foundation/math/gf_tile_rule_set.gd` |
| [`GFTimedTextEntry`](classes/GFTimedTextEntry.md#gftimedtextentry) | `Resource` | `addons/gf/standard/foundation/timeline/gf_timed_text_entry.gd` |
| [`GFTimedTextTrack`](classes/GFTimedTextTrack.md#gftimedtexttrack) | `Resource` | `addons/gf/standard/foundation/timeline/gf_timed_text_track.gd` |
| [`GFUILayerDefinition`](classes/GFUILayerDefinition.md#gfuilayerdefinition) | `Resource` | `addons/gf/standard/utilities/ui/gf_ui_layer_definition.gd` |
| [`GFUIRoute`](classes/GFUIRoute.md#gfuiroute) | `Resource` | `addons/gf/standard/utilities/ui/gf_ui_route.gd` |
| [`GFValidationConstraintRule`](classes/GFValidationConstraintRule.md#gfvalidationconstraintrule) | `GFValidationRule` | `addons/gf/standard/foundation/validation/gf_validation_constraint_rule.gd` |
| [`GFValidationSuite`](classes/GFValidationSuite.md#gfvalidationsuite) | `Resource` | `addons/gf/standard/foundation/validation/gf_validation_suite.gd` |
| [`GFWaitSequenceStep`](classes/GFWaitSequenceStep.md#gfwaitsequencestep) | `GFSequenceStep` | `addons/gf/standard/sequence/gf_wait_sequence_step.gd` |
| [`GFWeightedEntry`](classes/GFWeightedEntry.md#gfweightedentry) | `Resource` | `addons/gf/standard/foundation/math/gf_weighted_entry.gd` |
| [`GFWeightedTable`](classes/GFWeightedTable.md#gfweightedtable) | `Resource` | `addons/gf/standard/foundation/math/gf_weighted_table.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAssetCatalogMount`](classes/GFAssetCatalogMount.md#gfassetcatalogmount) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_asset_catalog_mount.gd` |
| [`GFAssetHandle`](classes/GFAssetHandle.md#gfassethandle) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_asset_handle.gd` |
| [`GFAssetLoadSession`](classes/GFAssetLoadSession.md#gfassetloadsession) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_asset_load_session.gd` |
| [`GFAssetSlot`](classes/GFAssetSlot.md#gfassetslot) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_asset_slot.gd` |
| [`GFAsyncBatch`](classes/GFAsyncBatch.md#gfasyncbatch) | `RefCounted` | `addons/gf/standard/utilities/io/gf_async_batch.gd` |
| [`GFAsyncChannel`](classes/GFAsyncChannel.md#gfasyncchannel) | `RefCounted` | `addons/gf/standard/common/gf_async_channel.gd` |
| [`GFAsyncGateLease`](classes/GFAsyncGateLease.md#gfasyncgatelease) | `RefCounted` | `addons/gf/standard/common/gf_async_gate_lease.gd` |
| [`GFAsyncKeyedGate`](classes/GFAsyncKeyedGate.md#gfasynckeyedgate) | `RefCounted` | `addons/gf/standard/common/gf_async_keyed_gate.gd` |
| [`GFAsyncProgress`](classes/GFAsyncProgress.md#gfasyncprogress) | `RefCounted` | `addons/gf/standard/common/gf_async_progress.gd` |
| [`GFAsyncProgressAggregator`](classes/GFAsyncProgressAggregator.md#gfasyncprogressaggregator) | `RefCounted` | `addons/gf/standard/common/gf_async_progress_aggregator.gd` |
| [`GFAudioBankMounter`](classes/GFAudioBankMounter.md#gfaudiobankmounter) | `Node` | `addons/gf/standard/utilities/audio/gf_audio_bank_mounter.gd` |
| [`GFAudioBeatClock`](classes/GFAudioBeatClock.md#gfaudiobeatclock) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_beat_clock.gd` |
| [`GFAudioEmitterHandle`](classes/GFAudioEmitterHandle.md#gfaudioemitterhandle) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_emitter_handle.gd` |
| [`GFBackgroundWorkTask`](classes/GFBackgroundWorkTask.md#gfbackgroundworktask) | `RefCounted` | `addons/gf/standard/utilities/jobs/gf_background_work_task.gd` |
| [`GFCallableRuntimeTask`](classes/GFCallableRuntimeTask.md#gfcallableruntimetask) | `GFRuntimeTask` | `addons/gf/standard/sequence/gf_callable_runtime_task.gd` |
| [`GFConfigTableQuery`](classes/GFConfigTableQuery.md#gfconfigtablequery) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_table_query.gd` |
| [`GFDeterministicRandom`](classes/GFDeterministicRandom.md#gfdeterministicrandom) | `RefCounted` | `addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd` |
| [`GFDownloadTask`](classes/GFDownloadTask.md#gfdownloadtask) | `RefCounted` | `addons/gf/standard/utilities/io/gf_download_task.gd` |
| [`GFDragSession`](classes/GFDragSession.md#gfdragsession) | `RefCounted` | `addons/gf/standard/input/drag_drop/gf_drag_session.gd` |
| [`GFExecutionBudget`](classes/GFExecutionBudget.md#gfexecutionbudget) | `RefCounted` | `addons/gf/standard/common/gf_execution_budget.gd` |
| [`GFFormBinder`](classes/GFFormBinder.md#gfformbinder) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_form_binder.gd` |
| [`GFGraphPathSearchState`](classes/GFGraphPathSearchState.md#gfgraphpathsearchstate) | `RefCounted` | `addons/gf/standard/foundation/math/gf_graph_path_search_state.gd` |
| [`GFHttpRequestBuilder`](classes/GFHttpRequestBuilder.md#gfhttprequestbuilder) | `RefCounted` | `addons/gf/standard/utilities/io/gf_http_request_builder.gd` |
| [`GFHttpResponse`](classes/GFHttpResponse.md#gfhttpresponse) | `RefCounted` | `addons/gf/standard/utilities/io/gf_http_response.gd` |
| [`GFInputProviderRegistration`](classes/GFInputProviderRegistration.md#gfinputproviderregistration) | `RefCounted` | `addons/gf/standard/input/formatting/gf_input_provider_registration.gd` |
| [`GFItemListBinder`](classes/GFItemListBinder.md#gfitemlistbinder) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_item_list_binder.gd` |
| [`GFJob`](classes/GFJob.md#gfjob) | `RefCounted` | `addons/gf/standard/utilities/jobs/gf_job.gd` |
| [`GFManualTimerQueue`](classes/GFManualTimerQueue.md#gfmanualtimerqueue) | `RefCounted` | `addons/gf/standard/utilities/time/gf_manual_timer_queue.gd` |
| [`GFNodeStateGroup`](classes/GFNodeStateGroup.md#gfnodestategroup) | `Node` | `addons/gf/standard/state_machine/node/gf_node_state_group.gd` |
| [`GFPlatformRequestHandle`](classes/GFPlatformRequestHandle.md#gfplatformrequesthandle) | `RefCounted` | `addons/gf/standard/platform/gf_platform_request_handle.gd` |
| [`GFPointerCapture`](classes/GFPointerCapture.md#gfpointercapture) | `RefCounted` | `addons/gf/standard/input/common/gf_pointer_capture.gd` |
| [`GFProtocolAckLedger`](classes/GFProtocolAckLedger.md#gfprotocolackledger) | `RefCounted` | `addons/gf/standard/utilities/io/gf_protocol_ack_ledger.gd` |
| [`GFReactiveStateControlBinder`](classes/GFReactiveStateControlBinder.md#gfreactivestatecontrolbinder) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_reactive_state_control_binder.gd` |
| [`GFReactiveStateStore`](classes/GFReactiveStateStore.md#gfreactivestatestore) | `RefCounted` | `addons/gf/standard/utilities/state/gf_reactive_state_store.gd` |
| [`GFRepeaterBinder`](classes/GFRepeaterBinder.md#gfrepeaterbinder) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_repeater_binder.gd` |
| [`GFRuntimeTaskGroup`](classes/GFRuntimeTaskGroup.md#gfruntimetaskgroup) | `GFRuntimeTask` | `addons/gf/standard/sequence/gf_runtime_task_group.gd` |
| [`GFShaderParameterBinder`](classes/GFShaderParameterBinder.md#gfshaderparameterbinder) | `Node` | `addons/gf/standard/utilities/display/gf_shader_parameter_binder.gd` |
| [`GFSignalBridgeBinding`](classes/GFSignalBridgeBinding.md#gfsignalbridgebinding) | `RefCounted` | `addons/gf/standard/utilities/signals/bridge/gf_signal_bridge_binding.gd` |
| [`GFSignalConnection`](classes/GFSignalConnection.md#gfsignalconnection) | `RefCounted` | `addons/gf/standard/utilities/signals/gf_signal_connection.gd` |
| [`GFStorageAsyncOperation`](classes/GFStorageAsyncOperation.md#gfstorageasyncoperation) | `RefCounted` | `addons/gf/standard/utilities/storage/gf_storage_async_operation.gd` |
| [`GFTextGenerationContext`](classes/GFTextGenerationContext.md#gftextgenerationcontext) | `RefCounted` | `addons/gf/standard/foundation/text/gf_text_generation_context.gd` |
| [`GFTimeoutController`](classes/GFTimeoutController.md#gftimeoutcontroller) | `RefCounted` | `addons/gf/standard/common/gf_timeout_controller.gd` |
| [`GFTouchControl2D`](classes/GFTouchControl2D.md#gftouchcontrol2d) | `Node2D` | `addons/gf/standard/input/touch/gf_touch_control_2d.gd` |
| [`GFUIRouteOperation`](classes/GFUIRouteOperation.md#gfuirouteoperation) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_ui_route_operation.gd` |
| [`GFVirtualInputSource`](classes/GFVirtualInputSource.md#gfvirtualinputsource) | `RefCounted` | `addons/gf/standard/input/sources/gf_virtual_input_source.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAssetLoadSessionResult`](classes/GFAssetLoadSessionResult.md#gfassetloadsessionresult) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_asset_load_session_result.gd` |
| [`GFAudioBackendCapability`](classes/GFAudioBackendCapability.md#gfaudiobackendcapability) | `Resource` | `addons/gf/standard/utilities/audio/gf_audio_backend_capability.gd` |
| [`GFBigNumber`](classes/GFBigNumber.md#gfbignumber) | `RefCounted` | `addons/gf/standard/foundation/numeric/gf_big_number.gd` |
| [`GFBuildInfo`](classes/GFBuildInfo.md#gfbuildinfo) | `Resource` | `addons/gf/standard/utilities/debug/gf_build_info.gd` |
| [`GFByteCursor`](classes/GFByteCursor.md#gfbytecursor) | `RefCounted` | `addons/gf/standard/foundation/binary/gf_byte_cursor.gd` |
| [`GFConfigValidationReport`](classes/GFConfigValidationReport.md#gfconfigvalidationreport) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_validation_report.gd` |
| [`GFDeque`](classes/GFDeque.md#gfdeque) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_deque.gd` |
| [`GFDiagnosticProviderResult`](classes/GFDiagnosticProviderResult.md#gfdiagnosticproviderresult) | `RefCounted` | `addons/gf/standard/utilities/debug/gf_diagnostic_provider_result.gd` |
| [`GFDirectoryChangeSet`](classes/GFDirectoryChangeSet.md#gfdirectorychangeset) | `RefCounted` | `addons/gf/standard/utilities/io/gf_directory_change_set.gd` |
| [`GFDriftReport`](classes/GFDriftReport.md#gfdriftreport) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_drift_report.gd` |
| [`GFExecutionRequirement`](classes/GFExecutionRequirement.md#gfexecutionrequirement) | `RefCounted` | `addons/gf/standard/common/gf_execution_requirement.gd` |
| [`GFFixedDecimal`](classes/GFFixedDecimal.md#gffixeddecimal) | `RefCounted` | `addons/gf/standard/foundation/numeric/gf_fixed_decimal.gd` |
| [`GFFixedVector2`](classes/GFFixedVector2.md#gffixedvector2) | `RefCounted` | `addons/gf/standard/foundation/numeric/gf_fixed_vector2.gd` |
| [`GFFixedVector3`](classes/GFFixedVector3.md#gffixedvector3) | `RefCounted` | `addons/gf/standard/foundation/numeric/gf_fixed_vector3.gd` |
| [`GFFormulaParameter`](classes/GFFormulaParameter.md#gfformulaparameter) | `RefCounted` | `addons/gf/standard/foundation/formula/gf_formula_parameter.gd` |
| [`GFInputDetectionResult`](classes/GFInputDetectionResult.md#gfinputdetectionresult) | `RefCounted` | `addons/gf/standard/input/rebinding/gf_input_detection_result.gd` |
| [`GFInputEventIdentity`](classes/GFInputEventIdentity.md#gfinputeventidentity) | `RefCounted` | `addons/gf/standard/input/common/gf_input_event_identity.gd` |
| [`GFMetricSeries`](classes/GFMetricSeries.md#gfmetricseries) | `RefCounted` | `addons/gf/standard/utilities/debug/gf_metric_series.gd` |
| [`GFModalResult`](classes/GFModalResult.md#gfmodalresult) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_modal_result.gd` |
| [`GFPriorityQueue`](classes/GFPriorityQueue.md#gfpriorityqueue) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_priority_queue.gd` |
| [`GFPriorityWorkQueue`](classes/GFPriorityWorkQueue.md#gfpriorityworkqueue) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_priority_work_queue.gd` |
| [`GFQuerySignature`](classes/GFQuerySignature.md#gfquerysignature) | `RefCounted` | `addons/gf/standard/foundation/collections/gf_query_signature.gd` |
| [`GFResourceIdentity`](classes/GFResourceIdentity.md#gfresourceidentity) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_resource_identity.gd` |
| [`GFResourceLoadState`](classes/GFResourceLoadState.md#gfresourceloadstate) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_resource_load_state.gd` |
| [`GFResultDictionary`](classes/GFResultDictionary.md#gfresultdictionary) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_result_dictionary.gd` |
| [`GFSequenceContext`](classes/GFSequenceContext.md#gfsequencecontext) | `RefCounted` | `addons/gf/standard/sequence/gf_sequence_context.gd` |
| [`GFSourceSpan`](classes/GFSourceSpan.md#gfsourcespan) | `RefCounted` | `addons/gf/standard/foundation/validation/gf_source_span.gd` |
| [`GFSpatialQueryIdentity`](classes/GFSpatialQueryIdentity.md#gfspatialqueryidentity) | `RefCounted` | `addons/gf/standard/foundation/math/gf_spatial_query_identity.gd` |
| [`GFSteeringAcceleration`](classes/GFSteeringAcceleration.md#gfsteeringacceleration) | `RefCounted` | `addons/gf/standard/foundation/math/gf_steering_acceleration.gd` |
| [`GFSteeringAgent`](classes/GFSteeringAgent.md#gfsteeringagent) | `RefCounted` | `addons/gf/standard/foundation/math/gf_steering_agent.gd` |
| [`GFStorageAsyncResult`](classes/GFStorageAsyncResult.md#gfstorageasyncresult) | `RefCounted` | `addons/gf/standard/utilities/storage/gf_storage_async_result.gd` |
| [`GFStorageConflictReport`](classes/GFStorageConflictReport.md#gfstorageconflictreport) | `Resource` | `addons/gf/standard/utilities/storage/gf_storage_conflict_report.gd` |
| [`GFStorageReadResult`](classes/GFStorageReadResult.md#gfstoragereadresult) | `RefCounted` | `addons/gf/standard/utilities/storage/gf_storage_read_result.gd` |
| [`GFStorageSectionCache`](classes/GFStorageSectionCache.md#gfstoragesectioncache) | `RefCounted` | `addons/gf/standard/utilities/storage/gf_storage_section_cache.gd` |
| [`GFUIRouteResult`](classes/GFUIRouteResult.md#gfuirouteresult) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_ui_route_result.gd` |
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
| [`GFPlatformActivationIntent`](classes/GFPlatformActivationIntent.md#gfplatformactivationintent) | `Resource` | `addons/gf/standard/foundation/platform/gf_platform_activation_intent.gd` |
| [`GFRequestEnvelope`](classes/GFRequestEnvelope.md#gfrequestenvelope) | `RefCounted` | `addons/gf/standard/utilities/io/gf_request_envelope.gd` |

<a id="category-editor_api"></a>

### 编辑器 API

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFBuildInfoExportPlugin`](classes/GFBuildInfoExportPlugin.md#gfbuildinfoexportplugin) | `EditorExportPlugin` | `addons/gf/standard/utilities/debug/editor/gf_build_info_export_plugin.gd` |
| [`GFConfigTableEditorTools`](classes/GFConfigTableEditorTools.md#gfconfigtableeditortools) | `RefCounted` | `addons/gf/standard/utilities/config/gf_config_table_editor_tools.gd` |
| [`GFDiagnosticsDock`](classes/GFDiagnosticsDock.md#gfdiagnosticsdock) | `Control` | `addons/gf/standard/utilities/debug/editor/gf_diagnostics_dock.gd` |
| [`GFInputMappingDock`](classes/GFInputMappingDock.md#gfinputmappingdock) | `Control` | `addons/gf/standard/input/editor/gf_input_mapping_dock.gd` |
| [`GFNodeStateMachineDock`](classes/GFNodeStateMachineDock.md#gfnodestatemachinedock) | `Control` | `addons/gf/standard/state_machine/node/editor/gf_node_state_machine_dock.gd` |
| [`GFRuntimeDebuggerPlugin`](classes/GFRuntimeDebuggerPlugin.md#gfruntimedebuggerplugin) | `EditorDebuggerPlugin` | `addons/gf/standard/utilities/debug/editor/gf_runtime_debugger_plugin.gd` |
| [`GFRuntimeDebuggerTab`](classes/GFRuntimeDebuggerTab.md#gfruntimedebuggertab) | `Control` | `addons/gf/standard/utilities/debug/editor/gf_runtime_debugger_tab.gd` |
| [`GFSignalGraphDock`](classes/GFSignalGraphDock.md#gfsignalgraphdock) | `Control` | `addons/gf/standard/utilities/debug/editor/gf_signal_graph_dock.gd` |
| [`GFStorageViewerDock`](classes/GFStorageViewerDock.md#gfstorageviewerdock) | `VBoxContainer` | `addons/gf/standard/utilities/storage/editor/gf_storage_viewer_dock.gd` |
| [`GFThemeOverridePropertyList`](classes/GFThemeOverridePropertyList.md#gfthemeoverridepropertylist) | `RefCounted` | `addons/gf/standard/utilities/ui/gf_theme_override_property_list.gd` |
| [`GFTileMetadataPaintTool`](classes/GFTileMetadataPaintTool.md#gftilemetadatapainttool) | `RefCounted` | `addons/gf/standard/foundation/math/editor/gf_tile_metadata_paint_tool.gd` |

<a id="category-tool_api"></a>

### 工具 API

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAudioBankTools`](classes/GFAudioBankTools.md#gfaudiobanktools) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_bank_tools.gd` |
| [`GFAudioLibraryTools`](classes/GFAudioLibraryTools.md#gfaudiolibrarytools) | `RefCounted` | `addons/gf/standard/utilities/audio/gf_audio_library_tools.gd` |
| [`GFResourceRegistryTools`](classes/GFResourceRegistryTools.md#gfresourceregistrytools) | `RefCounted` | `addons/gf/standard/utilities/assets/gf_resource_registry_tools.gd` |
