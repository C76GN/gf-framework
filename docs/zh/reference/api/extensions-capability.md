# Capability API

模块：`extensions/capability`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 1 | 43 | 32 |
| [协议与扩展点](#category-protocol) | 5 | 60 | 45 |
| [资源定义](#category-resource_definition) | 3 | 27 | 13 |
| [运行时句柄](#category-runtime_handle) | 2 | 18 | 13 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFCapabilityUtility`](classes/GFCapabilityUtility.md#gfcapabilityutility) | `GFUtility` | `addons/gf/extensions/capability/core/gf_capability_utility.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFCapability`](classes/GFCapability.md#gfcapability) | `RefCounted` | `addons/gf/extensions/capability/core/gf_capability.gd` |
| [`GFControlCapability`](classes/GFControlCapability.md#gfcontrolcapability) | `Control` | `addons/gf/extensions/capability/nodes/gf_control_capability.gd` |
| [`GFNode2DCapability`](classes/GFNode2DCapability.md#gfnode2dcapability) | `Node2D` | `addons/gf/extensions/capability/nodes/gf_node_2d_capability.gd` |
| [`GFNode3DCapability`](classes/GFNode3DCapability.md#gfnode3dcapability) | `Node3D` | `addons/gf/extensions/capability/nodes/gf_node_3d_capability.gd` |
| [`GFNodeCapability`](classes/GFNodeCapability.md#gfnodecapability) | `Node` | `addons/gf/extensions/capability/nodes/gf_node_capability.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFCapabilityQuery`](classes/GFCapabilityQuery.md#gfcapabilityquery) | `Resource` | `addons/gf/extensions/capability/core/gf_capability_query.gd` |
| [`GFCapabilityRecipe`](classes/GFCapabilityRecipe.md#gfcapabilityrecipe) | `Resource` | `addons/gf/extensions/capability/recipes/gf_capability_recipe.gd` |
| [`GFCapabilityRecipeEntry`](classes/GFCapabilityRecipeEntry.md#gfcapabilityrecipeentry) | `Resource` | `addons/gf/extensions/capability/recipes/gf_capability_recipe_entry.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFCapabilityContainer`](classes/GFCapabilityContainer.md#gfcapabilitycontainer) | `Node` | `addons/gf/extensions/capability/nodes/gf_capability_container.gd` |
| [`GFPropertyBagCapability`](classes/GFPropertyBagCapability.md#gfpropertybagcapability) | `GFCapability` | `addons/gf/extensions/capability/core/gf_property_bag_capability.gd` |
