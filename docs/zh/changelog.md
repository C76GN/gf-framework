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

## [4.3.0] - 2026-06-03

**版本概述**：新增不依赖 LLM 的 Decision 扩展，并补充通用 Shader 参数 profile 工具、显式引用编码和存档边界文档，为 NPC、模拟系统、导演系统、视觉表现参数和持久化引用提供可组合的框架能力，同时保持业务规则、动作执行、生成式代理逻辑、项目级 SaveSystem 和具体 shader 风格在项目侧。

### 🚀 新增特性 (Added)

- 新增 `gf.decision` 内置扩展，默认随 GF 启用，并通过扩展 installer 注册 `GFDecisionUtility`。
- 新增 `GFDecisionBlackboard`、`GFDecisionContext`、`GFDecisionConsideration`、`GFDecisionOption`、`GFDecisionSet`、`GFDecisionScore` 与 `GFDecisionUtility`，支持黑板值、主体/目标读取、考虑项归一化、响应曲线、权重、候选聚合、最佳候选选择和调试快照。
- 新增 Decision 扩展文档，明确它只负责非 LLM 的候选评分与选择，不承载具体游戏业务规则或生成式 Agent。
- 新增 `GFShaderParameterProfile`、`GFShaderParameterUtility` 与 `GFShaderParameterBinder`，支持声明、复制、合并、插值、场景绑定和批量应用 `ShaderMaterial` uniform 参数，并可在写入前复制共享材质资源。
- 新增 Shader 参数 Profile 文档，明确 GF 只负责参数集合和写入流程，不提供具体 shader 效果或项目视觉规则。
- 新增 `GFVariantReferenceCodec`，支持把 Resource 路径 / UID / 类型提示和相对 root 的 NodePath 编码为显式引用标记，不做对象图序列化或全局节点扫描。
- `GFNodePropertySerializer` 复用 `GFVariantReferenceCodec`，可保存 Resource 引用以及同一 SaveGraph Scope 内的 Node 引用。
- 补充存档聚合、SaveGraph 属性序列化和模块边界文档，明确项目级 SaveSystem、业务 schema、第三方服务、任务奖励和 UI 文案不属于 GF 框架内置规则。

### ⚠️ 废弃与移除 (Deprecated/Removed)

- 移除 `GFNodePropertySerializer` 对旧 `__gf_save_property__` / `ResourcePath` 属性 payload 的读取兼容；属性引用统一使用 `GFVariantReferenceCodec` 生成的 `__gf_reference__` 标记。

### 🔌 API 变动说明 (API Changes)

- `GFNodePropertySerializer.apply()` 不再把旧 `__gf_save_property__` 字典解释为资源引用。旧 payload 会按普通 Dictionary 处理，并在写入 `TYPE_OBJECT` 属性时因类型不匹配失败。

### 📘 升级指南 (Migration Guide)

- 项目若保存过旧 `__gf_save_property__` / `ResourcePath` payload，应在项目层一次性迁移存档数据为 `__gf_reference__` 标记，或用自定义 Serializer 处理旧档转换；GF 默认属性序列化器不再保留双协议兼容。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/extensions/decision/gf_extension.json`
- `addons/gf/extensions/decision/extension.gd`
- `addons/gf/extensions/decision/runtime/gf_decision_blackboard.gd`
- `addons/gf/extensions/decision/runtime/gf_decision_context.gd`
- `addons/gf/extensions/decision/runtime/gf_decision_score.gd`
- `addons/gf/extensions/decision/runtime/gf_decision_utility.gd`
- `addons/gf/extensions/decision/resources/gf_decision_consideration.gd`
- `addons/gf/extensions/decision/resources/gf_decision_option.gd`
- `addons/gf/extensions/decision/resources/gf_decision_set.gd`
- `addons/gf/standard/foundation/variant/gf_variant_reference_codec.gd`
- `addons/gf/standard/utilities/display/gf_shader_parameter_profile.gd`
- `addons/gf/standard/utilities/display/gf_shader_parameter_utility.gd`
- `addons/gf/standard/utilities/display/gf_shader_parameter_binder.gd`
- `addons/gf/extensions/save/serializers/gf_node_property_serializer.gd`
- `addons/gf/extensions/save/graph/gf_save_graph_utility.gd`
- `tests/gf_core/standard/foundation/variant/test_gf_variant_data_and_json_codec.gd`
- `tests/gf_core/extensions/save/test_gf_node_serializers_focused.gd`
- `tests/gf_core/extensions/save/test_gf_save_graph_utility.gd`
- `tests/gf_core/extensions/decision/test_gf_decision_utility.gd`
- `tests/gf_core/standard/utilities/display/test_gf_shader_parameter_profile.gd`
- `docs/zh/extensions/decision/index.md`
- `docs/zh/standard/utilities/runtime/settings-ui-scene/shader-parameter-profile.md`
