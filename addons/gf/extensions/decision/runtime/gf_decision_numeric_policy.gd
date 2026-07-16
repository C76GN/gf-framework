# Decision 扩展内部数值契约。
extends RefCounted


# --- 层内方法 ---

## 将任意评分收窄到有限的 0 到 1。
## [br]
## @api layer_internal
## [br]
## @layer extensions/decision
## [br]
## @param value: 待收窄评分。
## [br]
## @param fallback: 非有限值回退。
## [br]
## @return 有限评分。
static func normalize_score(value: float, fallback: float = 0.0) -> float:
	var safe_fallback: float = clampf(fallback, 0.0, 1.0) if is_finite(fallback) else 0.0
	return clampf(value, 0.0, 1.0) if is_finite(value) else safe_fallback


## 将权重收窄到有限非负域。
## [br]
## @api layer_internal
## [br]
## @layer extensions/decision
## [br]
## @param value: 待收窄权重。
## [br]
## @return 有限非负权重；非法值返回 0。
static func normalize_weight(value: float) -> float:
	return maxf(value, 0.0) if is_finite(value) else 0.0


## 计算对最终 0 到 1 SUM 结果等价的饱和贡献。
## [br]
## @api layer_internal
## [br]
## @layer extensions/decision
## [br]
## @param score: 已归一化评分。
## [br]
## @param weight: 已归一化权重。
## [br]
## @return 有限的 0 到 1 贡献。
static func saturating_contribution(score: float, weight: float) -> float:
	var normalized_score: float = normalize_score(score)
	var normalized_weight: float = normalize_weight(weight)
	if normalized_score <= 0.0 or normalized_weight <= 0.0:
		return 0.0
	if normalized_weight >= 1.0 / normalized_score:
		return 1.0
	return normalize_score(normalized_score * normalized_weight)


## 判断配置数值是否为有限非负权重。
## [br]
## @api layer_internal
## [br]
## @layer extensions/decision
## [br]
## @param value: 待检查值。
## [br]
## @return 合法时返回 true。
static func is_valid_weight(value: float) -> bool:
	return is_finite(value) and value >= 0.0


## 判断配置数值是否处于有限的 0 到 1。
## [br]
## @api layer_internal
## [br]
## @layer extensions/decision
## [br]
## @param value: 待检查值。
## [br]
## @return 合法时返回 true。
static func is_valid_score(value: float) -> bool:
	return is_finite(value) and value >= 0.0 and value <= 1.0
