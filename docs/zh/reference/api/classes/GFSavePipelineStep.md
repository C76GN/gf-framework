# GFSavePipelineStep

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/pipeline/gf_save_pipeline_step.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

存档图流程步骤基类。 用于在 GFSaveGraphUtility 的 Scope 采集/应用流程前后插入通用处理。 步骤只接收 scope、payload、context 和 result，不绑定任何业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`step_id`](#member-gfsavepipelinestep-properties-step_id) | `var step_id: StringName = &""` |
| 属性 | [`enabled`](#member-gfsavepipelinestep-properties-enabled) | `var enabled: bool = true` |

## 属性

<a id="member-gfsavepipelinestep-properties-step_id"></a>

### `step_id`

- API：`public`

```gdscript
var step_id: StringName = &""
```

步骤标识，便于调试与项目层开关。

<a id="member-gfsavepipelinestep-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该步骤。
