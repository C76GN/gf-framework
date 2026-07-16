# 2D 网格、生成管线与 Hex 网格

本组文档覆盖规则网格、2D 网格生成管线和六边形网格算法。GF 只提供坐标、chunk 窗口、路径、范围、候选格子和 Flow Field 原语，不定义地图、单位、地形、加载或渲染语义。

## 阅读入口

- [规则 2D 网格](grid-math.md)：`GFGridMath` 的范围、chunk 窗口、路径、迷宫拓扑、细胞自动机、连通区域后处理、连接判定和 Flow Field。
- [2D 网格变换](grid-transform.md)：`GFGridTransform2D` 的旋转、镜像和对角翻转坐标映射。
- [2D 网格生成管线](generation-pipeline.md)：`GFGridSelection2D`、`GFGridGenerationStep2D` 和 `GFGridGenerationPipeline2D`。
- [Hex 网格](hex-grid/index.md)：`GFHexGridMath` 的 cube/offset 坐标、路径、范围、视线和像素换算。

## 使用边界

这些页面只说明网格坐标、候选集合、路径、变换和生成原语。地图语义、单位占用、地形规则、TileMap 写回和渲染策略由项目层决定。
