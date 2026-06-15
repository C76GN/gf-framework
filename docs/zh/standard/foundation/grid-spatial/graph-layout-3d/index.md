# 图搜索、布局与 3D 网格

本组文档覆盖任意拓扑图搜索、编辑器布局建议和 3D 整数格算法。GF 负责通用路径、布局和坐标映射；节点含义、边代价、地形规则和移动系统由项目层提供。

## 阅读入口

- [任意拓扑图搜索](graph-math.md)：`GFGraphMath` 的 A*、Dijkstra 退化和可达范围。
- [编辑器图布局](graph-layout.md)：`GFGraphLayoutUtility` 的分层布局和网格布局建议。
- [2D Delaunay 与 Voronoi 图](voronoi-2d.md)：`GFVoronoi2D` 的点集三角剖分、Voronoi 顶点和开放 cell 标记。
- [3D 整数格算法](grid-3d/index.md)：`GFGrid3DMath`、`GFGridKey3D` 和 `GFGridPlaneMapper3D`。

## 使用边界

这些算法只提供路径、布局、平面点集几何和整数格坐标工具。图节点含义、边权来源、地形阻挡、单位移动、区域裁剪、编辑器交互和渲染方式应由项目层定义。
