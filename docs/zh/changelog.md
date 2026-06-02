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

## [4.2.0] - 2026-06-02

**版本概述**：补充通用音频节拍时钟、Shader 参数动作，并为 2D 网格生成管线增加报告式执行入口，便于项目把播放时间、表现参数和数据生成流程纳入可诊断、可组合的框架能力，同时保持表现、工具链和业务语义解耦。

### 🚀 新增特性 (Added)

- 新增 `GFAudioBeatClock`，支持 BPM、每小节 beat 数、时间 offset、手动 `update()`、可选位置来源、beat / measure 边界信号、时间量化和快照查询。
- 新增 `GFShaderParameterAction` 与 `GFAction.shader_parameter()`，用于在 Action Queue 中写入或缓动 `ShaderMaterial` uniform 参数，支持外部 Tween 宿主、共享材质执行前复制，以及取消或结束时恢复初始参数值。
- `GFGridGenerationPipeline2D` 新增 `generate_with_report()` 与 `apply_to_grid_with_report()`，返回候选数量、默认填充、步骤修改数量、跳过原因、步骤前后网格大小、耗时和结果网格，便于编辑器工具链或自动化流程审计生成过程。

### 🐛 Bug 修复 (Fixed)

- 修复 `GFSignalConnection.delay()` 与 `debounce()` 共用触发序列导致连续延迟信号可能被后续触发误取消的问题，并加固防抖测试避免毫秒级计时漂移。
- 清理多处 Godot 4.6 编辑器静态类型警告，包括 `process_mode`、`mouse_filter`、`autowrap_mode`、`Signal.connect()` flags 以及 `floor` / `round` 整数转换的显式类型收窄。

### 📁 核心受影响文件 (Affected Files)

- `addons/gf/standard/utilities/audio/gf_audio_beat_clock.gd`
- `addons/gf/standard/foundation/math/gf_grid_generation_pipeline_2d.gd`
- `addons/gf/standard/utilities/signals/gf_signal_connection.gd`
- `addons/gf/extensions/action_queue/actions/gf_shader_parameter_action.gd`
- `addons/gf/extensions/action_queue/core/gf_action.gd`
- `tests/gf_core/standard/utilities/audio/test_gf_audio_beat_clock.gd`
- `tests/gf_core/standard/foundation/math/test_gf_grid_generation_pipeline_2d.gd`
- `tests/gf_core/standard/utilities/signals/test_gf_signal_utility.gd`
- `tests/gf_core/extensions/action_queue/test_gf_visual_actions.gd`
- `docs/zh/standard/utilities/runtime/audio/playback/beat-clock.md`
- `docs/zh/standard/foundation/grid-spatial/grid-2d-hex/generation-pipeline.md`
- `docs/zh/standard/utilities/runtime/time-signal-pool/signal-utility/chain-connections.md`
- `docs/zh/extensions/action-queue/interceptors-actions/action-factory.md`
