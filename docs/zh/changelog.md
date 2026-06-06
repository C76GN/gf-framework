# 更新日志 (Changelog)

## 📝 日志条目结构标准

每次版本更新应包含以下核心模块（若无相关变动可省略该模块）：

1. **版本号与日期**：格式为 `## [主版本.次版本.修订号] - YYYY-MM-DD`
2. **版本概述**：简短描述该版本的核心目标（如：大型特性更新、紧急修复、性能重构等）。
3. **🚀 新增特性 (Added)**：新加入的类、方法、系统、扩展组件等。
4. **🔄 机制更改 (Changed)**：对现有功能逻辑的修改、内部重构、性能优化等。
5. **🐛 Bug 修复 (Fixed)**：修复的逻辑错误、内存泄漏、崩溃问题等。
6. **⚠️ 废弃与移除 (Deprecated/Removed)**：标记为废弃（将在未来移除）或本次直接移除的接口、文件。
7. **🔌 API 变动说明 (API Changes)**：详细列出函数签名改变、属性重命名等直接导致旧代码报错的改动。
8. **📘 升级指南 (Migration Guide)**：为使用旧版本框架的开发者提供 Step-by-Step 的升级建议和兼容性处理方案。
9. **📁 核心受影响文件 (Affected Files)**：列出改动最大的核心源码文件，方便开发者进行二次开发比对。

---

## 维护策略

正式文档中的更新日志只保留当前最新发布版本。发布新版本时，应将 `[未发布]` 合并为具体版本条目，并删除上一个正式版本条目；旧版本历史以 Git 历史和 GitHub Releases 为准，避免正式文档长期膨胀。

---

## [4.4.0] - 2026-06-06

**版本概述**：加强扩展发现、模块释放、资源解析、内容包声明、存储路径查询、力场采样组合和诊断上下文，修复若干 loose Variant、日志删除和 dispose 清理边界问题。

### 🚀 新增特性 (Added)

- `GFExtensionSettings` 新增 `gf/extensions/external_roots` 项目设置，以及 `get_external_extension_roots()` / `set_external_extension_roots()`，用于发现 `res://` 下 GF 仓库外的独立扩展 manifest。
- `GFModel`、`GFSystem` 与 `GFUtility` 新增 `release_dependencies()` 生命周期钩子；`GFArchitecture` 和 `GFBinding` 会在 dispose 后调用它，供模块释放缓存的外部依赖引用。
- 新增 `GFResourceResolverUtility`，用于把稳定资源键解析为资源路径或已加载 `Resource`，支持显式注册路径、provider 覆盖链、直接路径回退、诊断报告和 `GFAssetUtility` 异步加载衔接。
- 新增 `gf.content_package` 内置扩展，以及 `GFContentPackageManifest`、`GFContentPackageCatalog` 与 `GFContentPackageUtility`，用于声明内容包 manifest、诊断依赖图并把资源键同步到 `GFResourceResolverUtility`。
- 新增 `GFSchemaField` 与 `GFDictionarySchema`，用于通用 Dictionary 字段声明、默认值补齐、宽松类型转换、嵌套结构校验和 `GFValidationReport` 诊断输出。
- 新增 `GFPathTools` 与 `GFDependencyGraphTools`，用于复用纯字符串路径规范化、路径集合去重和字符串 ID 依赖图诊断，避免扩展、内容包和资源工具分叉实现同一机制。
- `GFValidationReportDictionary` 新增 `merge_report()`，用于合并多个字典报告的问题并显式复制调用方指定的统计字段。
- `GFCapabilityRecipe` 新增 `validate_recipe_report()`，用于在工具链中直接获取 `GFValidationReport` 形式的 Recipe 结构诊断。
- `GFStorageUtility` 新增 `get_storage_directory_path()`，可无副作用解析存储目录路径。
- `GFConfigTableImporter` 新增 `validate_json_record()`，用于按 `GFConfigTableSchema` 校验 JSON object 形式的单条配置、manifest 或内容元数据。
- `GFResourceRegistryTools` 新增 `build_dependency_report()`，用于生成资源依赖闭包的结构化诊断报告，包含缺失、过滤、循环和上限命中信息。
- 新增 `GFVirtualListModel`，用于大量可变尺寸列表的可见范围、累计偏移、overscan 和滚动锚点修正计算。
- 新增 `GFPolynomialMath`，用于高阶到低阶多项式系数的采样、导数、根生成和实根求解。
- `GFTouchJoystick.PositionMode` 新增 `FOLLOW`，用于触点超出摇杆半径时让摇杆中心跟随触点。
- `GFGravityProbe3D` 新增 `CombinationMode`，支持求和、最强力场和最高优先级力场组合；`GFGravityField3D` 新增 `priority` 与 `get_gravity_priority()` 供优先级采样使用。
- `GFVariantData` 新增 `diff_variant()`，用于生成纯 Variant 数据的结构化差异报告。

### 🔄 机制更改 (Changed)

- `GFConfigValidationReport` 的稳定 issue context 字段新增 `value`、`expected_value`、`actual_value`、`supported_values`、`supported_formats` 和 `supported_content_types`，便于编辑器工具给出可操作诊断。
- `GFContentPackageManifest`、`GFContentPackageCatalog` 与 `GFContentPackageUtility` 的诊断报告改用 `GFValidationReportDictionary` 通用形态，避免内容包依赖配置表专用报告语义。
- `GFExtensionSettings` 的外部扩展根目录和 `GFExtensionUsageAudit` 的扫描/忽略根目录复用 `GFPathTools`，与扩展 catalog 保持一致的路径集合规范化语义。
- `GFExtensionManifest` 读取时会裁剪标量文本字段，规范化依赖 ID、标签和扩展脚本路径列表，减少调用方重复清洗，同时保留空路径声明供校验报告。
- `GFExtensionSettings` 与扩展导出过滤插件现在会在 manifest 图无效时阻断启用扩展 manifest 查询、installer/editor 路径收集、启用扩展脚本加载和导出扩展过滤，并把问题提前报告到扩展加载或导出阶段。
- `GFExtensionSettings.get_extension_resource_path()` 与 `load_enabled_extension_script()` 现在只允许解析扩展根目录内资源，不再把 `user://`、其他扩展目录或越界路径作为扩展资源返回。
- `GFResourceResolverUtility` 的直接路径 fallback 现在默认关闭；需要把 `res://`、`uid://` 或 `user://` 直接作为资源键时，必须显式传入 `{ "allow_direct_path": true }`。
- `GFContentPackageManifest` 的资源路径边界收紧为包内相对路径或包根内 `res://` 路径；`uid://` 不再作为内容包 manifest 资源路径接受，避免 UID 指向包外资源时绕过 root 隔离。
- `tools/gf_maintenance.py release-status` 现在默认拒绝脏工作区，并会扫描 `addons/gf` 中高于当前发布版本的 `@since` 标注，避免把未发布 API 打进旧版本包。
- `GFDirectoryWatchUtility` 的监听路径、排除路径和排除子目录匹配复用 `GFPathTools`，并与资源注册表、音频扫描和内容包保持一致的纯字符串路径集合规范化语义。
- `GFConfigTableSchema` 与内置配置校验规则会在类型、集合、范围、资源路径和文本 key 错误中尽量写入实际值、期望值和支持集合/格式。
- `GFConfigRegexValidationRule` 现在会缓存当前 `pattern` 的编译结果，并在 `pattern` 改变时重新编译，减少大表批量校验时的重复正则编译成本。
- `GFCapabilityRecipe.validate_recipe()` 现在会为 entry/group 问题输出稳定 path，并报告空分组、重复分组和重复条目 warning。
- `GFStorageUtility.dispose()` 现在会清理异步队列、文件锁、迁移注册表、最近读取结果，并释放内部 helper 回链。
- `GFTouchJoystick.direction_changed` 与 `get_direction()` 现在返回已应用死区并保留模拟强度的摇杆向量；死区外会把剩余行程重映射到 0..1，而不是直接归一化。

### 🐛 Bug 修复 (Fixed)

- `GFDependencyGraphTools` 现在会对 `PackedStringArray` 形式的依赖列表执行和 `Array` 一致的空值过滤、空白裁剪和去重，避免等价依赖 ID 被误判为缺失依赖。
- `GFCapabilityUtility` 现在会校验外部实例、provider 返回实例和场景根节点脚本是否继承声明能力类型，避免错误 `as_type` 或 Recipe 声明污染能力索引。
- `GFGravityProbe3D` 的同帧采样缓存现在会把 `use_fallback_when_empty` 与 `fallback_acceleration` 纳入缓存键，避免同帧修改 fallback 配置后读到旧结果。
- `GFContentPackageUtility.rebuild_catalog()` 现在会把坏 manifest 文件追加到最终报告后重新计算 `ok`、`error_count` 和 `issue_count`，避免无效内容包 manifest 被报告为成功。
- `GFDictionarySchema.configure()` 现在会在字段列表为空时仍正确应用 `allow_extra_fields`、`coerce_values`、`fail_on_coerce_error` 和 `metadata` options。
- `GFBindableProperty.set_value()` 现在会安全处理不兼容 Variant 类型比较，避免 Object/String、Object/null、Dictionary/String 等 loose 输入触发 Godot 运行时比较错误。
- `GFLogUtility` 删除日志文件时会把 `user://` / `res://` 路径转成本地路径，并静默跳过已不存在的文件。

### 🔌 API 变动说明 (API Changes)

- 新增公开设置 `gf/extensions/external_roots`。
- 新增公开类 `GFPathTools`、`GFDependencyGraphTools`、`GFResourceResolverUtility`、`GFContentPackageManifest`、`GFContentPackageCatalog`、`GFContentPackageUtility`、`GFSchemaField`、`GFDictionarySchema`、`GFVirtualListModel` 与 `GFPolynomialMath`。
- 新增公开方法 `GFPathTools.normalize_root_paths()`、`GFExtensionSettings.get_external_extension_roots()`、`GFExtensionSettings.set_external_extension_roots()`、`GFValidationReportDictionary.merge_report()`、`GFStorageUtility.get_storage_directory_path()`、`GFConfigTableImporter.validate_json_record()`、`GFCapabilityRecipe.validate_recipe_report()`、`GFResourceRegistryTools.build_dependency_report()`、`GFVariantData.diff_variant()`、`GFModel.release_dependencies()`、`GFSystem.release_dependencies()` 与 `GFUtility.release_dependencies()`。
- `GFExtensionSettings.get_extension_resource_path()` 与 `load_enabled_extension_script()` 的路径边界收紧为扩展 root 内资源。
- `GFResourceResolverUtility.resolve()`、`resolve_path()`、`load()`、`load_async()` 和 `make_asset_group_entries()` 的 `options.allow_direct_path` 默认值从 true 调整为 false。
- `GFTouchJoystick.PositionMode` 新增枚举值 `FOLLOW`；`GFTouchJoystick` 的方向输出语义从归一化向量调整为保留模拟强度的向量。
- `GFGravityField3D` 新增公开属性 `priority` 和公开方法 `get_gravity_priority()`；`GFGravityProbe3D` 新增公开枚举 `CombinationMode` 与公开属性 `combination_mode`。

### 📘 升级指南 (Migration Guide)

- 依赖 `GFTouchJoystick.direction_changed` 出死区后固定单位方向的项目，应在消费端对非零向量调用 `normalized()`；需要模拟强度时可直接使用新向量长度或 InputMap action strength。
- 如果项目曾用 `GFExtensionSettings.get_extension_resource_path()` 或 `load_enabled_extension_script()` 加载扩展 root 外脚本，应改为项目侧显式 `ResourceLoader.load()` / `load()`，或把脚本放回对应扩展目录；扩展资源 API 不再承载任意脚本加载。
- 如果项目曾把 `res://`、`uid://` 或 `user://` 路径直接传给 `GFResourceResolverUtility` 当作资源键，应改为注册稳定资源键；仅工具链或迁移脚本确实需要路径直通时，传入 `{ "allow_direct_path": true }`。
- 如果内容包 manifest 曾用 `uid://` 声明资源路径，应改为包内相对路径或包根内 `res://` 路径；需要 UID 直通的项目应在项目侧资源解析流程显式处理，不把它写入 GF Content Package manifest。
- 如果项目曾用 `add_capability_instance()`、`add_scene_capability()`、provider 或 Recipe 把实例注册为不在其脚本继承链上的声明类型，应改为让实例脚本继承该能力基类，或按实例真实能力类型注册。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/kernel/extension/gf_extension_catalog.gd`
- `addons/gf/kernel/extension/gf_extension_settings.gd`
- `addons/gf/kernel/base/gf_model.gd`
- `addons/gf/kernel/base/gf_system.gd`
- `addons/gf/kernel/base/gf_utility.gd`
- `addons/gf/kernel/core/gf_architecture.gd`
- `addons/gf/kernel/core/gf_binding.gd`
- `addons/gf/kernel/core/gf_bindable_property.gd`
- `addons/gf/kernel/core/gf_path_tools.gd`
- `addons/gf/kernel/core/gf_dependency_graph_tools.gd`
- `addons/gf/standard/utilities/assets/gf_resource_resolver_utility.gd`
- `addons/gf/standard/utilities/assets/gf_resource_registry_tools.gd`
- `addons/gf/standard/utilities/audio/gf_audio_bank_tools.gd`
- `addons/gf/standard/utilities/io/gf_directory_watch_utility.gd`
- `addons/gf/standard/utilities/ui/gf_virtual_list_model.gd`
- `addons/gf/standard/foundation/math/gf_polynomial_math.gd`
- `addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd`
- `addons/gf/standard/foundation/variant/gf_variant_data.gd`
- `addons/gf/standard/input/touch/gf_touch_joystick.gd`
- `addons/gf/extensions/physics/nodes/gf_gravity_field_3d.gd`
- `addons/gf/extensions/physics/nodes/gf_gravity_probe_3d.gd`
- `addons/gf/standard/utilities/storage/gf_storage_utility.gd`
- `addons/gf/standard/utilities/logging/gf_log_utility.gd`
- `addons/gf/standard/utilities/config/gf_config_validation_report.gd`
- `addons/gf/standard/utilities/config/gf_config_table_importer.gd`
- `addons/gf/standard/utilities/config/gf_config_table_schema.gd`
- `addons/gf/standard/utilities/config/validation/*.gd`
- `addons/gf/standard/foundation/schema/gf_schema_field.gd`
- `addons/gf/standard/foundation/schema/gf_dictionary_schema.gd`
- `addons/gf/extensions/capability/recipes/gf_capability_recipe.gd`
- `addons/gf/extensions/content_package/gf_extension.json`
- `addons/gf/extensions/content_package/extension.gd`
- `addons/gf/extensions/content_package/resources/gf_content_package_manifest.gd`
- `addons/gf/extensions/content_package/runtime/gf_content_package_catalog.gd`
- `addons/gf/extensions/content_package/runtime/gf_content_package_utility.gd`
