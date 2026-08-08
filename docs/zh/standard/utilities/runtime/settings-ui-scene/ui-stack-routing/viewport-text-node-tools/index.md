# 视口、文本与节点树工具

本组页面说明分屏视口、屏幕/世界坐标转换、事务式表格投影、可回收虚拟列表、文本尺寸适配、富文本格式化、通用节点树操作、节点 group 查询缓存和自定义控件 Inspector 主题 override 辅助。

## 阅读入口

- [视口与坐标转换](viewport-coordinates.md)：`GFViewportUtility`、分屏视口和 2D/3D 坐标辅助。
- [表格数据视图模型](table-data-view.md)：`GFTableDataView`、类型化行谓词、`GFTableColumnDefinition` 和 `GFTableSelectionModel` 的事务式投影、提交与稳定选择。
- [文本适配与富文本](text-richtext.md)：`GFTextFitter`、`GFTextAutoFit` 和 `GFRichTextFormatter`。
- [虚拟列表布局、回收与焦点](virtual-list-model.md)：`GFVirtualListModel` 的可变尺寸窗口、`GFVirtualListBinder` 的有界 Control 回收与滚动锚定，以及 `GFVirtualListFocusModel` 的数据索引焦点。
- [通用节点树操作](node-tree-ops.md)：`GFNodeTreeOps` 的安全添加、重挂、查找、收集和释放。
- [节点 Group 查询缓存](node-group-cache.md)：`GFNodeGroupCache` 的 group 快照、SceneTree 失效和诊断。
- [主题 Override 属性列表](theme-override-property-list.md)：`GFThemeOverridePropertyList` 为自定义 Control 构建 Godot Inspector 可识别的 theme override 属性。

## 使用边界

这些工具只提供坐标转换、事务式表格投影、文本尺寸适配、富文本格式化、虚拟列表布局与有界物化机制、节点树操作、group 查询缓存和 Inspector 属性描述。具体数据与稳定 ID、领域谓词、UI 视觉、输入与可访问性、主题命名规范和节点业务语义仍由项目 UI 层决定。
