# Decision API

模块：`extensions/decision`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 1 | 13 | 11 |
| [协议与扩展点](#category-protocol) | 1 | 17 | 5 |
| [资源定义](#category-resource_definition) | 2 | 32 | 19 |
| [值对象](#category-value_object) | 2 | 17 | 7 |
| [领域模型](#category-domain_model) | 2 | 32 | 20 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFDecisionUtility`](classes/GFDecisionUtility.md#gfdecisionutility) | `GFUtility` | `addons/gf/extensions/decision/runtime/gf_decision_utility.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFDecisionConsideration`](classes/GFDecisionConsideration.md#gfdecisionconsideration) | `Resource` | `addons/gf/extensions/decision/resources/gf_decision_consideration.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFDecisionOption`](classes/GFDecisionOption.md#gfdecisionoption) | `Resource` | `addons/gf/extensions/decision/resources/gf_decision_option.gd` |
| [`GFDecisionSet`](classes/GFDecisionSet.md#gfdecisionset) | `Resource` | `addons/gf/extensions/decision/resources/gf_decision_set.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFDecisionEvaluation`](classes/GFDecisionEvaluation.md#gfdecisionevaluation) | `RefCounted` | `addons/gf/extensions/decision/runtime/gf_decision_evaluation.gd` |
| [`GFDecisionScore`](classes/GFDecisionScore.md#gfdecisionscore) | `RefCounted` | `addons/gf/extensions/decision/runtime/gf_decision_score.gd` |

<a id="category-domain_model"></a>

### 领域模型

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFDecisionBlackboard`](classes/GFDecisionBlackboard.md#gfdecisionblackboard) | `RefCounted` | `addons/gf/extensions/decision/runtime/gf_decision_blackboard.gd` |
| [`GFDecisionContext`](classes/GFDecisionContext.md#gfdecisioncontext) | `RefCounted` | `addons/gf/extensions/decision/runtime/gf_decision_context.gd` |
