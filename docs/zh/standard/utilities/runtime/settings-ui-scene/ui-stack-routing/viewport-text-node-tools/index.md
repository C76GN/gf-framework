# 视口、文本与节点树工具

本组页面说明分屏视口、屏幕/世界坐标转换、文本尺寸适配、富文本格式化和通用节点树操作。

## 阅读入口

- [视口与坐标转换](viewport-coordinates.md)：`GFViewportUtility`、分屏视口和 2D/3D 坐标辅助。
- [文本适配与富文本](text-richtext.md)：`GFTextFitter`、`GFTextAutoFit` 和 `GFRichTextFormatter`。
- [虚拟列表布局模型](virtual-list-model.md)：`GFVirtualListModel` 的可变尺寸条目、可见范围、overscan 和滚动锚点修正。
- [通用节点树操作](node-tree-ops.md)：`GFNodeTreeOps` 的安全添加、重挂、查找、收集和释放。

## 使用边界

这些工具只提供坐标转换、文本尺寸适配、富文本格式化、虚拟列表布局计算和节点树操作。具体 UI 视觉、布局规范、导航状态、输入绑定、Control 物化策略和节点业务语义应由项目 UI 层决定。
