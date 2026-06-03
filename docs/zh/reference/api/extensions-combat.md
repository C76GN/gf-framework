# Combat API

模块：`extensions/combat`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 2 | 14 | 14 |
| [协议与扩展点](#category-protocol) | 6 | 59 | 28 |
| [资源定义](#category-resource_definition) | 13 | 106 | 30 |
| [运行时句柄](#category-runtime_handle) | 16 | 264 | 113 |
| [值对象](#category-value_object) | 4 | 49 | 18 |
| [事件契约](#category-event_contract) | 4 | 6 | 0 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFCombatSystem`](classes/GFCombatSystem.md#gfcombatsystem) | `GFSystem` | `addons/gf/extensions/combat/core/gf_combat_system.gd` |
| [`GFSkillTargetingUtility`](classes/GFSkillTargetingUtility.md#gfskilltargetingutility) | `GFUtility` | `addons/gf/extensions/combat/skills/gf_skill_targeting_utility.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFBuff`](classes/GFBuff.md#gfbuff) | `RefCounted` | `addons/gf/extensions/combat/attributes/gf_buff.gd` |
| [`GFProjectileLifetimePolicy`](classes/GFProjectileLifetimePolicy.md#gfprojectilelifetimepolicy) | `Resource` | `addons/gf/extensions/combat/projectiles/gf_projectile_lifetime_policy.gd` |
| [`GFProjectileMotion`](classes/GFProjectileMotion.md#gfprojectilemotion) | `Resource` | `addons/gf/extensions/combat/projectiles/gf_projectile_motion.gd` |
| [`GFProjectileSpawnPattern2D`](classes/GFProjectileSpawnPattern2D.md#gfprojectilespawnpattern2d) | `Resource` | `addons/gf/extensions/combat/projectiles/gf_projectile_spawn_pattern_2d.gd` |
| [`GFProjectileSpawnPattern3D`](classes/GFProjectileSpawnPattern3D.md#gfprojectilespawnpattern3d) | `Resource` | `addons/gf/extensions/combat/projectiles/gf_projectile_spawn_pattern_3d.gd` |
| [`GFSkill`](classes/GFSkill.md#gfskill) | `RefCounted` | `addons/gf/extensions/combat/skills/gf_skill.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFCombatAction`](classes/GFCombatAction.md#gfcombataction) | `Resource` | `addons/gf/extensions/combat/actions/gf_combat_action.gd` |
| [`GFCombatActionModifier`](classes/GFCombatActionModifier.md#gfcombatactionmodifier) | `Resource` | `addons/gf/extensions/combat/actions/gf_combat_action_modifier.gd` |
| [`GFHitCollisionShapeConfig2D`](classes/GFHitCollisionShapeConfig2D.md#gfhitcollisionshapeconfig2d) | `Resource` | `addons/gf/extensions/combat/hit_detection/gf_hit_collision_shape_config_2d.gd` |
| [`GFHitCollisionShapeConfig3D`](classes/GFHitCollisionShapeConfig3D.md#gfhitcollisionshapeconfig3d) | `Resource` | `addons/gf/extensions/combat/hit_detection/gf_hit_collision_shape_config_3d.gd` |
| [`GFHomingProjectileMotion`](classes/GFHomingProjectileMotion.md#gfhomingprojectilemotion) | `GFProjectileMotion` | `addons/gf/extensions/combat/projectiles/gf_homing_projectile_motion.gd` |
| [`GFLinearProjectileMotion`](classes/GFLinearProjectileMotion.md#gflinearprojectilemotion) | `GFProjectileMotion` | `addons/gf/extensions/combat/projectiles/gf_linear_projectile_motion.gd` |
| [`GFProjectileBurstPattern2D`](classes/GFProjectileBurstPattern2D.md#gfprojectileburstpattern2d) | `GFProjectileSpawnPattern2D` | `addons/gf/extensions/combat/projectiles/gf_projectile_burst_pattern_2d.gd` |
| [`GFProjectileCatalog`](classes/GFProjectileCatalog.md#gfprojectilecatalog) | `Resource` | `addons/gf/extensions/combat/projectiles/gf_projectile_catalog.gd` |
| [`GFProjectileCatalogEntry`](classes/GFProjectileCatalogEntry.md#gfprojectilecatalogentry) | `Resource` | `addons/gf/extensions/combat/projectiles/gf_projectile_catalog_entry.gd` |
| [`GFProjectileConePattern3D`](classes/GFProjectileConePattern3D.md#gfprojectileconepattern3d) | `GFProjectileSpawnPattern3D` | `addons/gf/extensions/combat/projectiles/gf_projectile_cone_pattern_3d.gd` |
| [`GFProjectileLineSpawnPattern2D`](classes/GFProjectileLineSpawnPattern2D.md#gfprojectilelinespawnpattern2d) | `GFProjectileSpawnPattern2D` | `addons/gf/extensions/combat/projectiles/gf_projectile_line_spawn_pattern_2d.gd` |
| [`GFProjectileLineSpawnPattern3D`](classes/GFProjectileLineSpawnPattern3D.md#gfprojectilelinespawnpattern3d) | `GFProjectileSpawnPattern3D` | `addons/gf/extensions/combat/projectiles/gf_projectile_line_spawn_pattern_3d.gd` |
| [`GFSkillTargetingRule`](classes/GFSkillTargetingRule.md#gfskilltargetingrule) | `Resource` | `addons/gf/extensions/combat/skills/gf_skill_targeting_rule.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFCombatGauge`](classes/GFCombatGauge.md#gfcombatgauge) | `Node` | `addons/gf/extensions/combat/attributes/gf_combat_gauge.gd` |
| [`GFHitBox2D`](classes/GFHitBox2D.md#gfhitbox2d) | `Area2D` | `addons/gf/extensions/combat/hit_detection/gf_hit_box_2d.gd` |
| [`GFHitBox3D`](classes/GFHitBox3D.md#gfhitbox3d) | `Area3D` | `addons/gf/extensions/combat/hit_detection/gf_hit_box_3d.gd` |
| [`GFHitBoxState2D`](classes/GFHitBoxState2D.md#gfhitboxstate2d) | `Node2D` | `addons/gf/extensions/combat/hit_detection/gf_hit_box_state_2d.gd` |
| [`GFHitBoxState3D`](classes/GFHitBoxState3D.md#gfhitboxstate3d) | `Node3D` | `addons/gf/extensions/combat/hit_detection/gf_hit_box_state_3d.gd` |
| [`GFHitScan2D`](classes/GFHitScan2D.md#gfhitscan2d) | `RayCast2D` | `addons/gf/extensions/combat/hit_detection/gf_hit_scan_2d.gd` |
| [`GFHitScan3D`](classes/GFHitScan3D.md#gfhitscan3d) | `RayCast3D` | `addons/gf/extensions/combat/hit_detection/gf_hit_scan_3d.gd` |
| [`GFHurtBox2D`](classes/GFHurtBox2D.md#gfhurtbox2d) | `Area2D` | `addons/gf/extensions/combat/hit_detection/gf_hurt_box_2d.gd` |
| [`GFHurtBox3D`](classes/GFHurtBox3D.md#gfhurtbox3d) | `Area3D` | `addons/gf/extensions/combat/hit_detection/gf_hurt_box_3d.gd` |
| [`GFModifiedAttribute`](classes/GFModifiedAttribute.md#gfmodifiedattribute) | `RefCounted` | `addons/gf/extensions/combat/attributes/gf_modified_attribute.gd` |
| [`GFModifiedAttributeSet`](classes/GFModifiedAttributeSet.md#gfmodifiedattributeset) | `RefCounted` | `addons/gf/extensions/combat/attributes/gf_modified_attribute_set.gd` |
| [`GFProjectile2D`](classes/GFProjectile2D.md#gfprojectile2d) | `GFHitBox2D` | `addons/gf/extensions/combat/projectiles/gf_projectile_2d.gd` |
| [`GFProjectile3D`](classes/GFProjectile3D.md#gfprojectile3d) | `GFHitBox3D` | `addons/gf/extensions/combat/projectiles/gf_projectile_3d.gd` |
| [`GFProjectileEmitter2D`](classes/GFProjectileEmitter2D.md#gfprojectileemitter2d) | `Node2D` | `addons/gf/extensions/combat/projectiles/gf_projectile_emitter_2d.gd` |
| [`GFProjectileEmitter3D`](classes/GFProjectileEmitter3D.md#gfprojectileemitter3d) | `Node3D` | `addons/gf/extensions/combat/projectiles/gf_projectile_emitter_3d.gd` |
| [`GFTagComponent`](classes/GFTagComponent.md#gftagcomponent) | `RefCounted` | `addons/gf/extensions/combat/tags/gf_tag_component.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFCombatActionResult`](classes/GFCombatActionResult.md#gfcombatactionresult) | `RefCounted` | `addons/gf/extensions/combat/actions/gf_combat_action_result.gd` |
| [`GFCombatHitContext`](classes/GFCombatHitContext.md#gfcombathitcontext) | `RefCounted` | `addons/gf/extensions/combat/hit_detection/gf_combat_hit_context.gd` |
| [`GFModifier`](classes/GFModifier.md#gfmodifier) | `RefCounted` | `addons/gf/extensions/combat/attributes/gf_modifier.gd` |
| [`GFSkillActivationContext`](classes/GFSkillActivationContext.md#gfskillactivationcontext) | `RefCounted` | `addons/gf/extensions/combat/skills/gf_skill_activation_context.gd` |

<a id="category-event_contract"></a>

### 事件契约

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFCombatPayloads`](classes/GFCombatPayloads.md#gfcombatpayloads) | `Node` | `addons/gf/extensions/combat/core/gf_combat_payloads.gd` |
| [`GFCombatPayloads.GFBuffAppliedPayload`](classes/GFCombatPayloads.md#gfcombatpayloadsgfbuffappliedpayload) | `GFPayload` | `addons/gf/extensions/combat/core/gf_combat_payloads.gd` |
| [`GFCombatPayloads.GFBuffRefreshedPayload`](classes/GFCombatPayloads.md#gfcombatpayloadsgfbuffrefreshedpayload) | `GFPayload` | `addons/gf/extensions/combat/core/gf_combat_payloads.gd` |
| [`GFCombatPayloads.GFBuffRemovedPayload`](classes/GFCombatPayloads.md#gfcombatpayloadsgfbuffremovedpayload) | `GFPayload` | `addons/gf/extensions/combat/core/gf_combat_payloads.gd` |
