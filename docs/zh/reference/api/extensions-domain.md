# Domain API

模块：`extensions/domain`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 2 | 64 | 41 |
| [资源定义](#category-resource_definition) | 8 | 96 | 44 |
| [值对象](#category-value_object) | 1 | 13 | 4 |
| [领域模型](#category-domain_model) | 7 | 122 | 96 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFLevelUtility`](classes/GFLevelUtility.md#gflevelutility) | `GFUtility` | `addons/gf/extensions/domain/level/gf_level_utility.gd` |
| [`GFQuestUtility`](classes/GFQuestUtility.md#gfquestutility) | `GFUtility` | `addons/gf/extensions/domain/quest/gf_quest_utility.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFDerivedAttributeRule`](classes/GFDerivedAttributeRule.md#gfderivedattributerule) | `Resource` | `addons/gf/extensions/domain/attributes/gf_derived_attribute_rule.gd` |
| [`GFEquipmentSlot`](classes/GFEquipmentSlot.md#gfequipmentslot) | `Resource` | `addons/gf/extensions/domain/equipment/gf_equipment_slot.gd` |
| [`GFInventoryItemDefinition`](classes/GFInventoryItemDefinition.md#gfinventoryitemdefinition) | `Resource` | `addons/gf/extensions/domain/inventory/gf_inventory_item_definition.gd` |
| [`GFInventoryItemRegistry`](classes/GFInventoryItemRegistry.md#gfinventoryitemregistry) | `Resource` | `addons/gf/extensions/domain/inventory/gf_inventory_item_registry.gd` |
| [`GFInventorySlotDefinition`](classes/GFInventorySlotDefinition.md#gfinventoryslotdefinition) | `Resource` | `addons/gf/extensions/domain/inventory/gf_inventory_slot_definition.gd` |
| [`GFLevelCatalog`](classes/GFLevelCatalog.md#gflevelcatalog) | `Resource` | `addons/gf/extensions/domain/level/gf_level_catalog.gd` |
| [`GFLevelEntry`](classes/GFLevelEntry.md#gflevelentry) | `Resource` | `addons/gf/extensions/domain/level/gf_level_entry.gd` |
| [`GFTrait`](classes/GFTrait.md#gftrait) | `Resource` | `addons/gf/extensions/domain/traits/gf_trait.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFInventoryOperationResult`](classes/GFInventoryOperationResult.md#gfinventoryoperationresult) | `RefCounted` | `addons/gf/extensions/domain/inventory/gf_inventory_operation_result.gd` |

<a id="category-domain_model"></a>

### 领域模型

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFAttributeSet`](classes/GFAttributeSet.md#gfattributeset) | `Resource` | `addons/gf/extensions/domain/attributes/gf_attribute_set.gd` |
| [`GFEquipmentSet`](classes/GFEquipmentSet.md#gfequipmentset) | `Resource` | `addons/gf/extensions/domain/equipment/gf_equipment_set.gd` |
| [`GFInventoryModel`](classes/GFInventoryModel.md#gfinventorymodel) | `GFModel` | `addons/gf/extensions/domain/inventory/gf_inventory_model.gd` |
| [`GFInventoryStack`](classes/GFInventoryStack.md#gfinventorystack) | `Resource` | `addons/gf/extensions/domain/inventory/gf_inventory_stack.gd` |
| [`GFLevelProgressModel`](classes/GFLevelProgressModel.md#gflevelprogressmodel) | `GFModel` | `addons/gf/extensions/domain/level/gf_level_progress_model.gd` |
| [`GFSlotInventoryModel`](classes/GFSlotInventoryModel.md#gfslotinventorymodel) | `GFModel` | `addons/gf/extensions/domain/inventory/gf_slot_inventory_model.gd` |
| [`GFTraitSet`](classes/GFTraitSet.md#gftraitset) | `Resource` | `addons/gf/extensions/domain/traits/gf_trait_set.gd` |
