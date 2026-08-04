## GFTableRowPredicate: 表格结构化行过滤协议。
##
## 项目通过子类实现同步、只读、有界且无副作用的行判断。
## GFTableDataView 按注册顺序契约组合多个谓词，并把显式失败视为整次投影失败。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFTableRowPredicate
extends RefCounted


# --- 公共方法 ---

## 求值一个隔离行视图。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param row_view: 不暴露源 row 的隔离只读视图。
## [br]
## @return 类型化包含、排除或失败结果。
func evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
	return evaluate_for_framework(self, row_view)


# --- 可重写钩子 / 虚方法 ---

## 实现一次同步、只读且有界的行判断。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _row_view: 当前行的隔离只读视图。
## [br]
## @return 类型化包含、排除或失败结果。
func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
	return GFTableRowPredicateResult.failed(
		&"predicate_not_implemented",
		"Row predicate did not implement _evaluate()."
	)


# --- 框架内部方法 ---

## 通过唯一受支持扩展点执行谓词，并把结果归一为纯框架值。
##
## 静态入口不会调用候选子类可覆写的 public evaluate() 或结果 getter；
## 只有 `_evaluate()` 会进入项目代码。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param predicate: 待执行的类型化谓词。
## [br]
## @param row_view: 本次调用独占的隔离行视图。
## [br]
## @return 纯 GFTableRowPredicateResult。
static func evaluate_for_framework(
	predicate: GFTableRowPredicate,
	row_view: GFTableRowView
) -> GFTableRowPredicateResult:
	if predicate == null or not is_instance_valid(predicate):
		return GFTableRowPredicateResult.failed(
			&"invalid_predicate",
			"Row predicate instance is unavailable."
		)
	if row_view == null or not is_instance_valid(row_view):
		return GFTableRowPredicateResult.failed(
			&"invalid_row_view",
			"Row predicate received a null or unavailable row view."
		)
	var raw_result: GFTableRowPredicateResult = predicate._evaluate(row_view)
	return GFTableRowPredicateResult.snapshot_for_framework(raw_result)
