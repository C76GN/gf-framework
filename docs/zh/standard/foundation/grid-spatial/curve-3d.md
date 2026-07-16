# 3D 曲线与折线

`GFCurve3DMath` 提供围绕 `Curve3D` 与 `PackedVector3Array` 的纯算法辅助，适合复用在车辆路径、轨道、编辑器手柄、路径预览、节点锚点、网格挤出预处理和 3D 生成工具之间的几何预处理。

## 定位

这个工具只处理 3D 路径数据本身：折线长度、按归一化比例采样、折线姿态报告、最近点投影，以及 `Curve3D` baked 路径的取点和姿态估算。它不负责 `Path3D` / `PathFollow3D` 节点生命周期、导航、交通规则、车辆动力、碰撞、绘制或网格提交。

## 常见流程

```gdscript
var points := PackedVector3Array([
	Vector3(0, 0, 0),
	Vector3(0, 0, 10),
	Vector3(10, 0, 10),
])

var length := GFCurve3DMath.get_polyline_length(points)
var point := GFCurve3DMath.sample_polyline(points, 0.75, length)
var pose := GFCurve3DMath.sample_polyline_pose(points, 0.75, false, length, Vector3.UP)
var projection := GFCurve3DMath.project_point_to_polyline(points, global_target, false, Vector3.UP)
```

`Curve3D` 可直接按 baked 长度采样：

```gdscript
var path_point := GFCurve3DMath.sample_curve(curve, 0.5)
var path_pose := GFCurve3DMath.sample_curve_pose(curve, 0.5, false, 0.25, Vector3.UP)
```

## 使用边界

`sample_polyline_pose()` 和 `project_point_to_polyline()` 返回纯数据报告，字段包括 `point`、`offset`、`ratio`、`segment_index`、`segment_ratio`、`tangent`、`normal`、`binormal` 和 `total_length`。`normal` 会优先使用 `up_hint` 在切线垂直平面上的投影；当 `up_hint` 为零或与切线平行时，函数会退回到稳定垂直方向。

`sample_curve_pose()` 基于 `Curve3D.sample_baked()` 前后取样估算切线，适合路径预览、轻量锚点、路径跟随目标和工具预处理。需要严格 Frenet frame、曲率连续性、扭转控制、闭环法线传播或网格法线写入时，应在项目工具层或专门扩展中实现。

GF 不直接提供车辆控制器或 `PathFollow3D` 替代品。项目可以用 `offset` / `ratio` 驱动自己的节点、AI、相机或生成器，也可以把 `tangent`、`normal`、`binormal` 转换成项目需要的 `Basis`；速度管理、避障、路权、碰撞体和渲染仍由项目层解释。
