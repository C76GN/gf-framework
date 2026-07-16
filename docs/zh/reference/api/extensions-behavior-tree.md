# Behavior Tree API

模块：`extensions/behavior_tree`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [协议与扩展点](#category-protocol) | 3 | 20 | 11 |
| [运行时句柄](#category-runtime_handle) | 1 | 6 | 4 |
| [领域模型](#category-domain_model) | 18 | 63 | 50 |

## 类

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFBehaviorTree`](classes/GFBehaviorTree.md#gfbehaviortree) | `Object` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.BTNode`](classes/GFBehaviorTree.md#gfbehaviortreebtnode) | `RefCounted` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Decorator`](classes/GFBehaviorTree.md#gfbehaviortreedecorator) | `BTNode` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |

<a id="category-runtime_handle"></a>

### 运行时句柄

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFBehaviorTree.Runner`](classes/GFBehaviorTree.md#gfbehaviortreerunner) | `RefCounted` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |

<a id="category-domain_model"></a>

### 领域模型

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFBehaviorTree.Action`](classes/GFBehaviorTree.md#gfbehaviortreeaction) | `BTNode` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.AlwaysFail`](classes/GFBehaviorTree.md#gfbehaviortreealwaysfail) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.AlwaysSucceed`](classes/GFBehaviorTree.md#gfbehaviortreealwayssucceed) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.BlackboardScope`](classes/GFBehaviorTree.md#gfbehaviortreeblackboardscope) | `RefCounted` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Condition`](classes/GFBehaviorTree.md#gfbehaviortreecondition) | `BTNode` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Cooldown`](classes/GFBehaviorTree.md#gfbehaviortreecooldown) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Inverter`](classes/GFBehaviorTree.md#gfbehaviortreeinverter) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Limit`](classes/GFBehaviorTree.md#gfbehaviortreelimit) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Parallel`](classes/GFBehaviorTree.md#gfbehaviortreeparallel) | `BTNode` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Probability`](classes/GFBehaviorTree.md#gfbehaviortreeprobability) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.RandomSelector`](classes/GFBehaviorTree.md#gfbehaviortreerandomselector) | `BTNode` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.RandomSequence`](classes/GFBehaviorTree.md#gfbehaviortreerandomsequence) | `BTNode` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Repeat`](classes/GFBehaviorTree.md#gfbehaviortreerepeat) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Selector`](classes/GFBehaviorTree.md#gfbehaviortreeselector) | `BTNode` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.Sequence`](classes/GFBehaviorTree.md#gfbehaviortreesequence) | `BTNode` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.TimeLimit`](classes/GFBehaviorTree.md#gfbehaviortreetimelimit) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.UntilFail`](classes/GFBehaviorTree.md#gfbehaviortreeuntilfail) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
| [`GFBehaviorTree.UntilSuccess`](classes/GFBehaviorTree.md#gfbehaviortreeuntilsuccess) | `Decorator` | `addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd` |
