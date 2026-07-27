# 设置、UI、场景与表面查询

本组页面覆盖设置应用、UI 栈、场景切换、节点树操作、文本适配和表面材质查询等项目通用流程。

## 阅读入口

- [设置与显示应用](settings-display/index.md)：`GFSettingsUtility`、`GFDisplaySettingsUtility`、`GFControlValueAdapter` 与 `GFFormBinder`。
- [UI 栈、路由、视口与文本辅助](ui-stack-routing/index.md)：`GFUIUtility`、`GFUIRouterUtility`、`GFViewportUtility`、`GFTextFitter`、`GFTextAutoFit`、`GFRichTextFormatter` 与 `GFNodeTreeOps`。
- [场景与流程切换](scene-flow/index.md)：`GFSceneUtility`、`GFSceneTransitionConfig`、`GFScenePreloadMap` 与瞬态模块清理。
- [3D 表面材质查询](surface-query.md)：`GFSurfaceUtility` 的 face 到 surface/material 映射。
- [Shader 参数 Profile](shader-parameter-profile.md)：`GFShaderInterfaceSnapshot`、`GFShaderParameterProfile`、`GFShaderParameterUtility` 与 `GFShaderParameterBinder` 的接口快照、契约校验、参数合并、批量写入和场景绑定。

## 使用边界

- 设置工具只维护稳定键、值和应用边界；设置名称、文案、分组和业务含义由项目层决定。
- UI 工具负责栈、层级、加载和通用交互策略，不规定视觉、动画、焦点规则或页面通信协议。
- 场景工具管理资源加载、过渡、缓存和瞬态模块清理，不替代目标场景自己的初始化流程。
- 表面查询只把碰撞 face 映射到 Mesh surface 或材质，不解释脚步声、弹孔、地形标签等业务语义。
- Shader 参数工具只处理可反射 uniform 的接口快照、参数集合、校验、写入和场景绑定，不提供具体视觉风格、天气规则或 shader 算法。
