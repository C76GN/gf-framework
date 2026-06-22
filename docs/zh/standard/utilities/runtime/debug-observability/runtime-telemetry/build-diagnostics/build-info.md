# 构建信息快照

`GFBuildInfo` 是轻量 Resource，包含项目名、项目版本、GF 版本、构建号、提交号、分支、标签、提交数量、dirty 标记、构建时间、Godot 版本、平台和自定义 `metadata`。

`GFBuildInfo.collect()` 会从 `ProjectSettings` 与 `addons/gf/plugin.cfg` 采集当前环境。项目发布流水线可以写入 `gf/build/id`、`gf/build/commit_hash`、`gf/build/branch`、`gf/build/tag`、`gf/build/commit_count`、`gf/build/is_dirty`、`gf/build/time_utc` 与 `gf/build/metadata`，运行时再统一读取。

GF 不在运行时包或导出插件中调用 Git、Python 或 shell。需要提交号、分支、标签或流水线编号时，应由项目自己的 CI、编辑器脚本或外部构建工具采集，再调用 `GFBuildInfo.write_metadata_to_project_settings(build_data, extra_metadata, save_settings)` 写入 ProjectSettings。

启用 GF 插件后，`GFBuildInfoExportPlugin` 会注册可选导出入口；把 `gf/build/export/write_metadata` 设为 `true` 后，导出开始时会读取 `gf/build/export/build_metadata` 与 `gf/build/export/metadata`，写入构建快照并补齐导出时间，默认在导出结束后恢复旧 ProjectSettings，避免开发期配置被导出流程污染。

```gdscript
var build_info := GFBuildInfo.collect()
print(build_info.to_dict())

var build_info_utility := GFBuildInfoUtility.new()
build_info_utility.set_build_info(build_info)
print(build_info_utility.get_summary())
```

注册 `GFBuildInfoUtility` 后，`GFDiagnosticsUtility` 的 `build` 字段和 `tools.build_info` 快照会优先使用该工具中的稳定副本；未注册时诊断快照仍会采集一份当前环境信息。

构建信息只描述版本和发行上下文，不负责热更新、兼容性判断或存档迁移策略。
