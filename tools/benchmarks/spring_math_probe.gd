# 只记录实际执行的有限数值对照；不修改生产数学 API，不测 CPU、GPU 或分配性能。
extends SceneTree


# --- 常量 ---

## 独立闭式参照，只在本工具中使用。
## [br]
## @api private
const _ORACLE_SCRIPT = preload("res://tools/benchmarks/spring_math_oracle.gd")

## 保留 velocity 的生产步进入口；不修改其配置或非法输入策略。
## [br]
## @api private
const _SPRING_SCRIPT = preload("res://addons/gf/standard/foundation/math/gf_spring_math.gd")

## 全部数值对照在两秒内结束；目标在固定事件点改变。
## [br]
## @api private
const _SECONDS: float = 2.0

## 用于 oracle 自检的绝对误差容许值，不用于给生产近似轨迹判失败。
## [br]
## @api private
const _TOLERANCE: float = 0.000000001


# --- 私有变量 ---

## 只有显式参数才启用旧非法输入观察；不将预期诊断作为正常数值对照的一部分。
## [br]
## @api private
var _observe_invalid: bool = false


# --- Godot 回调方法 ---

func _initialize() -> void:
	_run.call_deferred()


# --- 私有/辅助方法 ---

## 运行有界自检、对照和旧输入观测，只向显式的 ignored 探针目录保存 JSON。
## [br]
## @api private
func _run() -> void:
	var output_path: String = _output_path()
	if output_path.is_empty():
		printerr("SPRING_MATH_PROBE_REJECTED: Supply one --output under res://ai_analysis/benchmarks/spring_math/ and optionally --observe-invalid.")
		quit(1)
		return
	var before: Dictionary = _source_hashes()
	var self_checks: Array[Dictionary] = _self_checks()
	var rows: Array[Dictionary] = []
	for damping: float in [0.5, 1.0, 2.0]:
		for rate: int in [20, 30, 60, 120]:
			rows.append(_compare(rate, damping, false, false))
			rows.append(_compare(rate, damping, true, false))
		rows.append(_compare(60, damping, false, true))
	var invalid_observations: Array[Dictionary] = []
	if _observe_invalid:
		invalid_observations = _invalid_observations()
	var after: Dictionary = _source_hashes()
	var issues: Array[String] = []
	for check: Dictionary in self_checks:
		if check.get("ok") != true:
			issues.append("Oracle self-check failed: %s." % _text(check.get("name")))
	for row: Dictionary in rows:
		if row.get("complete") != true:
			issues.append("A finite comparison did not produce complete finite observations.")
	if before != after:
		issues.append("Probe source changed during execution.")
	for source_key: String in ["probe", "oracle", "production"]:
		var hash_value: Variant = before.get(source_key)
		if not hash_value is String:
			issues.append("A required source content hash is unavailable.")
		else:
			var source_hash: String = hash_value
			if source_hash.length() != 64:
				issues.append("A required source content hash is unavailable.")
	var report: Dictionary = {
		"schema_version": 1, "execution_state": "executed", "ok": issues.is_empty(),
		"issues": issues, "godot_version": Engine.get_version_info(), "platform": OS.get_name(),
		"source_before": before, "source_after": after,
		"equation": "x'' + 2*zeta*omega*x' + omega^2*x = omega^2*g + response*zeta*omega*g'; omega=TAU*frequency_hz",
		"input_convention": "Production receives interval-start goal and that segment's goal velocity. The oracle integrates the same constant/linear segment; events split the interval at 0.6 and 1.4 seconds.",
		"numerical_scope": "The reference uses the continuous coefficients. Production's delta-dependent stability floor changes its effective coefficients; error includes that strategy. This is not a CPU/FPS/memory benchmark or an assertion of required accuracy.",
		"oracle_self_checks": self_checks, "comparisons": rows,
		"legacy_invalid_input_observations": invalid_observations,
	}
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("SPRING_MATH_PROBE_REJECTED: Cannot write the admitted output path.")
		quit(1)
		return
	var _store_result: Variant = file.store_string(JSON.stringify(report, "\t") + "\n")
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or not issues.is_empty():
		printerr("SPRING_MATH_PROBE_REJECTED: Output or independent self-check qualification failed.")
		quit(1)
		return
	print("SPRING_MATH_ORACLE_SELF_CHECK_EXECUTED_OK")
	print("SPRING_MATH_PROBE_EXECUTED_OK rows=%d invalid_observations=%d" % [rows.size(), invalid_observations.size()])
	quit(0)


## 验证显式唯一参数，并限制结果路径在 ignored 探针目录；不创建目录或覆盖旧结果。
## [br]
## @api private
func _output_path() -> String:
	var output: String = ""
	var output_seen: bool = false
	_observe_invalid = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--observe-invalid":
			if _observe_invalid:
				return ""
			_observe_invalid = true
		elif argument.begins_with("--output=") and not output_seen:
			output_seen = true
			output = argument.trim_prefix("--output=")
		else:
			return ""
	if output.is_empty() or output.length() > 1024 or not output.ends_with(".json"):
		return ""
	var absolute: String = ProjectSettings.globalize_path(output).simplify_path()
	var allowed: String = ProjectSettings.globalize_path("res://ai_analysis/benchmarks/spring_math/").simplify_path().trim_suffix("/") + "/"
	if not absolute.begins_with(allowed) or not DirAccess.dir_exists_absolute(absolute.get_base_dir()) or FileAccess.file_exists(absolute):
		return ""
	return absolute


## 捕获三个实际源文件的内容身份；归属和进程静止由外层监督器证明。
## [br]
## @api private
func _source_hashes() -> Dictionary:
	return {
		"probe": FileAccess.get_sha256("res://tools/benchmarks/spring_math_probe.gd"),
		"oracle": FileAccess.get_sha256("res://tools/benchmarks/spring_math_oracle.gd"),
		"production": FileAccess.get_sha256("res://addons/gf/standard/foundation/math/gf_spring_math.gd"),
	}


## 用独立已知临界解、半群组合和静止状态检查参照，不引用生产输出。
## [br]
## @api private
func _self_checks() -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	var omega: float = TAU * 2.0
	var seconds: float = 0.2
	var critical: Dictionary = _ORACLE_SCRIPT.step(0.0, 0.0, 1.0, seconds, 2.0, 1.0)
	var decay: float = exp(-omega * seconds)
	checks.append(_self_check("critical_known_unit_step", critical, 1.0 - (1.0 + omega * seconds) * decay, omega * omega * seconds * decay))
	for damping: float in [0.0, 0.5, 1.0, 2.0]:
		var stationary: Dictionary = _ORACLE_SCRIPT.step(2.0, 0.0, 2.0, 0.7, 3.0, damping)
		checks.append(_self_check("stationary_%s" % str(damping), stationary, 2.0, 0.0))
		for slope: float in [0.0, 0.6]:
			var whole: Dictionary = _ORACLE_SCRIPT.step(0.2, -0.4, 1.0, 0.48, 3.0, damping, 0.75, slope)
			var first: Dictionary = _ORACLE_SCRIPT.step(0.2, -0.4, 1.0, 0.11, 3.0, damping, 0.75, slope)
			var second: Dictionary = _ORACLE_SCRIPT.step(_number(first.get("value")), _number(first.get("velocity")), 1.0 + slope * 0.11, 0.37, 3.0, damping, 0.75, slope)
			checks.append(_self_check("partition_%s_slope_%s" % [str(damping), str(slope)], second, _number(whole.get("value")), _number(whole.get("velocity"))))
	return checks


## 记录参照和独立预期的双状态误差；只有自检精度影响探针退出状态。
## [br]
## @api private
func _self_check(check_name: String, result: Dictionary, expected_value: float, expected_velocity: float) -> Dictionary:
	var value_error: float = absf(_number(result.get("value")) - expected_value)
	var velocity_error: float = absf(_number(result.get("velocity")) - expected_velocity)
	return {"name": check_name, "ok": result.get("ok") == true and value_error <= _TOLERANCE and velocity_error <= _TOLERANCE,
		"value_error": _json_number(value_error), "velocity_error": _json_number(velocity_error)}


## 按固定时点积分相同分段输入，完整保留 value/velocity；一次大 delta 不跨越事件。
## [br]
## @api private
func _compare(rate: int, damping: float, feedforward: bool, spike: bool) -> Dictionary:
	var production_value: float = 0.0
	var production_velocity: float = 0.0
	var oracle_value: float = 0.0
	var oracle_velocity: float = 0.0
	var time: float = 0.0
	var count: int = 0
	var max_delta: float = 0.0
	var max_value_error: float = 0.0
	var max_velocity_error: float = 0.0
	var squared_value_error: float = 0.0
	var spike_applied: bool = false
	var complete: bool = true
	var response: float = 0.75 if feedforward else 0.0
	while time < _SECONDS and count < 512:
		var step_seconds: float = 1.0 / float(rate)
		if spike and not spike_applied:
			if time < 0.9:
				step_seconds = minf(step_seconds, 0.9 - time)
			else:
				step_seconds = 0.25
				spike_applied = true
		var endpoint: float = minf(time + step_seconds, _next_event(time))
		var delta: float = endpoint - time
		if delta <= 0.0:
			complete = false
			break
		var goal: PackedFloat64Array = _goal(time, feedforward)
		var production: Dictionary = _SPRING_SCRIPT.step_float(production_value, production_velocity, goal[0], delta, 3.0, damping, response, goal[1])
		var oracle: Dictionary = _ORACLE_SCRIPT.step(oracle_value, oracle_velocity, goal[0], delta, 3.0, damping, response, goal[1])
		production_value = _number(production.get("value"))
		production_velocity = _number(production.get("velocity"))
		oracle_value = _number(oracle.get("value"))
		oracle_velocity = _number(oracle.get("velocity"))
		if oracle.get("ok") != true or not is_finite(production_value) or not is_finite(production_velocity):
			complete = false
			break
		var value_error: float = absf(production_value - oracle_value)
		var velocity_error: float = absf(production_velocity - oracle_velocity)
		max_value_error = maxf(max_value_error, value_error)
		max_velocity_error = maxf(max_velocity_error, velocity_error)
		squared_value_error += value_error * value_error
		max_delta = maxf(max_delta, delta)
		time = endpoint
		count += 1
	complete = complete and time == _SECONDS and (not spike or spike_applied)
	return {"scenario": "retarget_linear_feedforward" if feedforward else "retarget_constant", "rate_hz": rate,
		"frequency_hz": 3.0, "damping_ratio": damping, "response": response,
		"goal_event_seconds": [0.6, 1.4], "duration_seconds": _SECONDS,
		"large_delta": spike, "large_delta_applied": spike_applied, "complete": complete,
		"steps": count, "max_delta_seconds": max_delta,
		"max_abs_value_error": _json_number(max_value_error), "max_abs_velocity_error": _json_number(max_velocity_error),
		"rms_value_error_per_sample": _json_number(sqrt(squared_value_error / float(maxi(count, 1)))),
		"final_production": {"value": _json_number(production_value), "velocity": _json_number(production_velocity)},
		"final_oracle": {"value": _json_number(oracle_value), "velocity": _json_number(oracle_velocity)}}


## 返回下一个确切事件端点，保证两种算法在相同目标改变时刻分段。
## [br]
## @api private
func _next_event(time: float) -> float:
	if time < 0.6:
		return 0.6
	if time < 1.4:
		return 1.4
	return _SECONDS


## 给出区间起点的目标与真实斜率；固定输入和线性输入使用相同事件点。
## [br]
## @api private
func _goal(time: float, feedforward: bool) -> PackedFloat64Array:
	var goal: float = 1.0
	var start: float = 0.0
	var slope: float = 0.6 if feedforward else 0.0
	if time >= 1.4:
		goal = 0.25
		start = 1.4
		slope = 0.2 if feedforward else 0.0
	elif time >= 0.6:
		goal = -0.5
		start = 0.6
		slope = -0.4 if feedforward else 0.0
	return PackedFloat64Array([goal + slope * (time - start), slope])


## 只观测当前生产对非法数值的真实分类，不把既存传播当作本探针 feature 失败。
## [br]
## @api private
func _invalid_observations() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var names: Array[String] = ["current_value", "velocity", "target_value", "delta_seconds", "frequency_hz", "damping_ratio", "response", "target_velocity"]
	for index: int in range(names.size()):
		for invalid: float in [NAN, INF]:
			var arguments: Array[float] = [0.0, 0.0, 1.0, 0.016, 3.0, 1.0, 0.75, 0.2]
			arguments[index] = invalid
			var result: Dictionary = _SPRING_SCRIPT.step_float(arguments[0], arguments[1], arguments[2], arguments[3], arguments[4], arguments[5], arguments[6], arguments[7])
			results.append({"input_field": names[index], "input": _json_number(invalid),
				"result_field_count": result.size(), "result_is_empty": result.is_empty(),
				"value": _observed_field(result, "value"), "velocity": _observed_field(result, "velocity")})
	return results


## 区分空结果的缺字段、真实非有限数值与未知类型，不把拒绝误报成 NaN 传播。
## [br]
## @api private
func _observed_field(result: Dictionary, field_name: String) -> Variant:
	if not result.has(field_name):
		return "missing"
	var value: Variant = result.get(field_name)
	if value is float or value is int:
		return _json_number(_number(value))
	return "unsupported_type"


## 收窄公开数值结果；不把未知类型当作零误差。
## [br]
## @api private
func _number(value: Variant) -> float:
	if value is float:
		var number: float = value
		return number
	if value is int:
		var number: int = value
		return float(number)
	return NAN


## 收窄报告中的自检名称，不对未知 Variant 执行 String 构造转换。
## [br]
## @api private
func _text(value: Variant) -> String:
	if value is String:
		var text: String = value
		return text
	return "unknown"


## JSON 不写 NaN/Infinity；非有限观测显式保存为分类字符串。
## [br]
## @api private
func _json_number(value: float) -> Variant:
	if is_nan(value):
		return "nan"
	if is_inf(value):
		return "+inf" if value > 0.0 else "-inf"
	return value
