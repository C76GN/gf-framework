# Foundation 网格、路径与空间索引

本组页面覆盖网格、格子选择、图搜索、寻路、TileMap 辅助、转向和空间索引等通用算法。所有能力都属于 Foundation：不注册到 `GFArchitecture`，不绑定场景树，也不解释项目业务语义。

## 阅读入口

- [2D 曲线与折线](curve-2d.md)：`GFCurve2DMath` 的折线长度、采样、简化、虚线切分和基础闭合形状生成。
- [2D 矩形打包](rect-packing-2d.md)：`GFRectPacking2D` 的固定容器、自动正方形和归一化放置结果。
- [2D Poisson-disc 采样](poisson-disc-2d.md)：`GFPoissonDisc2D` 的确定性最小间距点集生成。
- [3D 高度场与表面散布采样](heightfield-surface-scatter-3d.md)：`GFHeightfield3D` 与 `GFSurfaceScatterSampler3D` 的高度、法线和纯数据 Transform 采样报告。
- [AABB Broadphase 候选对](collision-broadphase.md)：`GFCollisionBroadphase2D/3D` 的 body、SAP、2D Quadtree 和组合候选对生成。
- [2D SAT Narrowphase 精确检测](collision-narrowphase-2d.md)：`GFCollisionNarrowphase2D` 的凸多边形、旋转盒、相切策略和最小平移向量。
- [弹簧平滑数学](spring-math.md)：`GFSpringMath` 的标量、角度、Vector2 与 Vector3 二阶弹簧步进。
- [2D 网格、生成管线与 Hex 网格](grid-2d-hex/index.md)：`GFGridMath`、`GFGridTransform2D`、`GFGridSelection2D`、`GFGridGenerationStep2D`、`GFGridGenerationPipeline2D` 与 `GFHexGridMath`。
- [图搜索、布局与 3D 网格](graph-layout-3d/index.md)：`GFGraphMath`、`GFGraphLayoutUtility`、`GFVoronoi2D`、`GFGrid3DMath`、`GFGridKey3D` 与 `GFGridPlaneMapper3D`。
- [Pattern2D 与 Steering](patterns-steering/index.md)：`GFPattern2D`、`GFSteeringAgent`、`GFSteeringMath` 和资源化 steering 组合。
- [占用、TileMap 缓存、规则表与空间哈希](occupancy-tile-spatial/index.md)：`GFGridOccupancy`、`GFTileMapCache`、`GFTileRuleSet` 与 `GFSpatialHash3D`。

## 使用边界

- Foundation 只提供纯算法、纯数据结构和通用资源，不访问运行时容器。
- 通行、代价、阵营、地形、目标选择、碰撞和渲染都由项目层回调或系统解释。
- 需要持有运行时状态、异步加载、ProjectSettings 或场景节点时，应放入 `standard/utilities`、扩展或项目代码。
