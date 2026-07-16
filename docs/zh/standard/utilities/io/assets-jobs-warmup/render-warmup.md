# 渲染资源预热

这一页说明如何用 `GFRenderWarmupManifest` 和 `GFRenderWarmupUtility` 在加载阶段提前触碰材质、Mesh、Texture 或 Shader 资源。它只负责加载和触碰渲染资源 RID，不创建业务对象、不规定关卡流程，也不替项目决定预热时机。

## 清单预热

```gdscript
var manifest := GFRenderWarmupManifest.new()
manifest.manifest_id = &"battle_intro"
manifest.add_resource_path("res://characters/hero_material.tres", &"material", "Material")
manifest.add_resource_path("res://ui/battle_icons.png", &"texture", "Texture2D")

var warmup := Gf.get_utility(GFRenderWarmupUtility) as GFRenderWarmupUtility
warmup.default_entries_per_tick = 2
warmup.queue_manifest(manifest)
```

## 从场景收集

如果资源已经在场景树中，可以从节点树收集通用渲染资源：

```gdscript
var manifest := warmup.build_manifest_from_tree(get_tree().current_scene, {
	"manifest_id": &"current_scene",
	"include_meshes": true,
	"include_materials": true,
	"include_textures": true,
})
warmup.warmup_manifest_now(manifest)
```

资源来自场景文件时，也可以用 `build_manifest_from_scene()` 或 `build_manifest_from_scene_path()` 创建清单。实例化 PackedScene 可能触发项目脚本生命周期，因此默认不会扫描场景资源；只有确认场景实例化没有副作用时，才显式传入 `"allow_scene_instantiation": true`。预热执行支持 `max_seconds` 时间预算，队列和立即预热都会在预算耗尽时返回 `stopped_by_budget`。

## 使用边界

默认 `touch_mode` 只加载资源并触碰 RID。需要让材质或 Mesh 参与一次离屏渲染时，可传 `GFRenderWarmupUtility.TouchMode.TEMPORARY_RENDER_NODES`，并按需指定 `temporary_parent` 与 `temporary_viewport_size`；预热工具会创建 `SubViewport` 临时节点，下一次 `tick()` 或显式 `release_temporary_render_nodes()` 会清理它们。

`keep_resources_cached` 默认关闭，预热完成后不长期持有资源引用。项目确实需要 pin 资源时，应在调用时传 `"keep_cached": true`，并按流程设置 `"cache_group"` 与 `"max_cached_resources"`；释放时可调用 `release_cached_resources()` 清空全部缓存，或传入分组只释放指定预热流程的引用。`instantiate_packed_scenes` 也需要配合 `"allow_scene_instantiation": true` 才会生效，避免无意执行场景脚本。预热工具不保证消除所有驱动层 shader 编译成本，它提供的是一个稳定、可诊断、可分批的资源准备边界。
