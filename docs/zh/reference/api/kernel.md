# Kernel API

模块：`kernel`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 9 | 237 | 196 |
| [协议与扩展点](#category-protocol) | 17 | 178 | 156 |
| [资源定义](#category-resource_definition) | 2 | 44 | 14 |
| [值对象](#category-value_object) | 1 | 1 | 0 |
| [编辑器 API](#category-editor_api) | 24 | 319 | 198 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFArchitecture`](classes/GFArchitecture.md#gfarchitecture) | `Object` | `addons/gf/kernel/core/gf_architecture.gd` |
| [`GFDependencyGraphTools`](classes/GFDependencyGraphTools.md#gfdependencygraphtools) | `RefCounted` | `addons/gf/kernel/core/gf_dependency_graph_tools.gd` |
| [`GFExtensionCatalog`](classes/GFExtensionCatalog.md#gfextensioncatalog) | `RefCounted` | `addons/gf/kernel/extension/gf_extension_catalog.gd` |
| [`GFExtensionSettings`](classes/GFExtensionSettings.md#gfextensionsettings) | `RefCounted` | `addons/gf/kernel/extension/gf_extension_settings.gd` |
| [`GFNodeContext`](classes/GFNodeContext.md#gfnodecontext) | `Node` | `addons/gf/kernel/core/gf_node_context.gd` |
| [`GFObjectPropertyTools`](classes/GFObjectPropertyTools.md#gfobjectpropertytools) | `RefCounted` | `addons/gf/kernel/core/gf_object_property_tools.gd` |
| [`GFPathTools`](classes/GFPathTools.md#gfpathtools) | `RefCounted` | `addons/gf/kernel/core/gf_path_tools.gd` |
| [`GFProjectSettingsTools`](classes/GFProjectSettingsTools.md#gfprojectsettingstools) | `RefCounted` | `addons/gf/kernel/core/gf_project_settings_tools.gd` |
| [`GFTypeEventSystem`](classes/GFTypeEventSystem.md#gftypeeventsystem) | `Object` | `addons/gf/kernel/core/gf_type_event_system.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFBindBuilder`](classes/GFBindBuilder.md#gfbindbuilder) | `RefCounted` | `addons/gf/kernel/core/gf_bind_builder.gd` |
| [`GFBindableProperty`](classes/GFBindableProperty.md#gfbindableproperty) | `RefCounted` | `addons/gf/kernel/core/gf_bindable_property.gd` |
| [`GFBinder`](classes/GFBinder.md#gfbinder) | `RefCounted` | `addons/gf/kernel/core/gf_binder.gd` |
| [`GFCommand`](classes/GFCommand.md#gfcommand) | `Object` | `addons/gf/kernel/base/gf_command.gd` |
| [`GFComputedProperty`](classes/GFComputedProperty.md#gfcomputedproperty) | `GFBindableProperty` | `addons/gf/kernel/core/gf_computed_property.gd` |
| [`GFConfig`](classes/GFConfig.md#gfconfig) | `Resource` | `addons/gf/kernel/base/gf_config.gd` |
| [`GFController`](classes/GFController.md#gfcontroller) | `Node` | `addons/gf/kernel/base/gf_controller.gd` |
| [`GFInstaller`](classes/GFInstaller.md#gfinstaller) | `RefCounted` | `addons/gf/kernel/core/gf_installer.gd` |
| [`GFModel`](classes/GFModel.md#gfmodel) | `Object` | `addons/gf/kernel/base/gf_model.gd` |
| [`GFPayload`](classes/GFPayload.md#gfpayload) | `RefCounted` | `addons/gf/kernel/base/gf_payload.gd` |
| [`GFQuery`](classes/GFQuery.md#gfquery) | `Object` | `addons/gf/kernel/base/gf_query.gd` |
| [`GFReactiveEffect`](classes/GFReactiveEffect.md#gfreactiveeffect) | `RefCounted` | `addons/gf/kernel/core/gf_reactive_effect.gd` |
| [`GFReadOnlyBindableProperty`](classes/GFReadOnlyBindableProperty.md#gfreadonlybindableproperty) | `GFBindableProperty` | `addons/gf/kernel/core/gf_read_only_bindable_property.gd` |
| [`GFRule`](classes/GFRule.md#gfrule) | `Resource` | `addons/gf/kernel/base/gf_rule.gd` |
| [`GFSystem`](classes/GFSystem.md#gfsystem) | `Object` | `addons/gf/kernel/base/gf_system.gd` |
| [`GFTimeProvider`](classes/GFTimeProvider.md#gftimeprovider) | `GFUtility` | `addons/gf/kernel/base/gf_time_provider.gd` |
| [`GFUtility`](classes/GFUtility.md#gfutility) | `Object` | `addons/gf/kernel/base/gf_utility.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFExtensionManifest`](classes/GFExtensionManifest.md#gfextensionmanifest) | `RefCounted` | `addons/gf/kernel/extension/gf_extension_manifest.gd` |
| [`GFExtensionPreset`](classes/GFExtensionPreset.md#gfextensionpreset) | `RefCounted` | `addons/gf/kernel/extension/gf_extension_preset.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFBindingLifetimes`](classes/GFBindingLifetimes.md#gfbindinglifetimes) | `RefCounted` | `addons/gf/kernel/core/gf_binding_lifetimes.gd` |

<a id="category-editor_api"></a>

### 编辑器 API

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAccessGenerator`](classes/GFAccessGenerator.md#gfaccessgenerator) | `RefCounted` | `addons/gf/kernel/editor/gf_access_generator.gd` |
| [`GFBakeDependencyReport`](classes/GFBakeDependencyReport.md#gfbakedependencyreport) | `RefCounted` | `addons/gf/kernel/editor/gf_bake_dependency_report.gd` |
| [`GFConfigAccessGenerator`](classes/GFConfigAccessGenerator.md#gfconfigaccessgenerator) | `RefCounted` | `addons/gf/kernel/editor/gf_config_access_generator.gd` |
| [`GFEditorActionDefinition`](classes/GFEditorActionDefinition.md#gfeditoractiondefinition) | `RefCounted` | `addons/gf/kernel/editor/gf_editor_action_definition.gd` |
| [`GFEditorCommand`](classes/GFEditorCommand.md#gfeditorcommand) | `RefCounted` | `addons/gf/kernel/editor/gf_editor_command.gd` |
| [`GFEditorCommandRegistry`](classes/GFEditorCommandRegistry.md#gfeditorcommandregistry) | `RefCounted` | `addons/gf/kernel/editor/gf_editor_command_registry.gd` |
| [`GFEditorCommandSession`](classes/GFEditorCommandSession.md#gfeditorcommandsession) | `RefCounted` | `addons/gf/kernel/editor/gf_editor_command_session.gd` |
| [`GFEditorOperationPlan`](classes/GFEditorOperationPlan.md#gfeditoroperationplan) | `RefCounted` | `addons/gf/kernel/editor/gf_editor_operation_plan.gd` |
| [`GFEditorPickOperation`](classes/GFEditorPickOperation.md#gfeditorpickoperation) | `RefCounted` | `addons/gf/kernel/editor/gf_editor_pick_operation.gd` |
| [`GFEditorSceneMetadataPatch`](classes/GFEditorSceneMetadataPatch.md#gfeditorscenemetadatapatch) | `GFEditorCommand` | `addons/gf/kernel/editor/gf_editor_scene_metadata_patch.gd` |
| [`GFEditorTool`](classes/GFEditorTool.md#gfeditortool) | `RefCounted` | `addons/gf/kernel/editor/gf_editor_tool.gd` |
| [`GFEditorToolContext`](classes/GFEditorToolContext.md#gfeditortoolcontext) | `RefCounted` | `addons/gf/kernel/editor/gf_editor_tool_context.gd` |
| [`GFEditorToolOption`](classes/GFEditorToolOption.md#gfeditortooloption) | `Resource` | `addons/gf/kernel/editor/gf_editor_tool_option.gd` |
| [`GFEditorToolOptionSchema`](classes/GFEditorToolOptionSchema.md#gfeditortooloptionschema) | `Resource` | `addons/gf/kernel/editor/gf_editor_tool_option_schema.gd` |
| [`GFEditorTypeIndex`](classes/GFEditorTypeIndex.md#gfeditortypeindex) | `RefCounted` | `addons/gf/kernel/editor/gf_editor_type_index.gd` |
| [`GFEditorValueField`](classes/GFEditorValueField.md#gfeditorvaluefield) | `HBoxContainer` | `addons/gf/kernel/editor/gf_editor_value_field.gd` |
| [`GFExtensionUsageAudit`](classes/GFExtensionUsageAudit.md#gfextensionusageaudit) | `RefCounted` | `addons/gf/kernel/extension/gf_extension_usage_audit.gd` |
| [`GFGeneratedArtifactReport`](classes/GFGeneratedArtifactReport.md#gfgeneratedartifactreport) | `RefCounted` | `addons/gf/kernel/editor/gf_generated_artifact_report.gd` |
| [`GFResourcePathHint`](classes/GFResourcePathHint.md#gfresourcepathhint) | `Object` | `addons/gf/kernel/editor/gf_resource_path_hint.gd` |
| [`GFResourceTableEditor`](classes/GFResourceTableEditor.md#gfresourcetableeditor) | `VBoxContainer` | `addons/gf/kernel/editor/gf_resource_table_editor.gd` |
| [`GFSceneSignalAudit`](classes/GFSceneSignalAudit.md#gfscenesignalaudit) | `RefCounted` | `addons/gf/kernel/editor/gf_scene_signal_audit.gd` |
| [`GFSourceBuilder`](classes/GFSourceBuilder.md#gfsourcebuilder) | `RefCounted` | `addons/gf/kernel/editor/gf_source_builder.gd` |
| [`GFTemplateGenerationManifest`](classes/GFTemplateGenerationManifest.md#gftemplategenerationmanifest) | `RefCounted` | `addons/gf/kernel/editor/gf_template_generation_manifest.gd` |
| [`GFThumbnailRenderer`](classes/GFThumbnailRenderer.md#gfthumbnailrenderer) | `Node` | `addons/gf/kernel/editor/gf_thumbnail_renderer.gd` |
