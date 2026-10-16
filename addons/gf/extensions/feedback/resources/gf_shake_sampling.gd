# Feedback 资源共享的只读波形采样核心，不持有 Resource 或调用期状态。
extends RefCounted


# --- 框架内部方法 ---

## 采样正弦三轴值，保留相位与零频率语义。
## [br]
## @api framework_internal
## [br]
## @layer extensions/feedback
## [br]
## @since unreleased
## [br]
## @param elapsed_seconds: 预设已经过时间，保留负时间和非有限值归一化约定。
## [br]
## @param frequency: 正弦频率，允许零值。
## [br]
## @param phase_offset: 以周期为单位的相位偏移。
## [br]
## @return 按现有波形合同计算的三轴偏移值。
static func sample_sine_for_framework(
	elapsed_seconds: float,
	frequency: float,
	phase_offset: float
) -> Vector3:
	var phase_cycles: float = (
		fposmod(
			_finite_float(elapsed_seconds * _finite_nonnegative(frequency)),
			1.0
		)
		+ fposmod(
			_finite_float(phase_offset),
			1.0
		)
	)
	var phase: float = phase_cycles * TAU
	return Vector3(
		sin(phase),
		sin(phase + TAU / 3.0),
		sin(phase + TAU * 2.0 / 3.0)
	)


## 按离散游标采样确定性随机三轴值。
## [br]
## @api framework_internal
## [br]
## @layer extensions/feedback
## [br]
## @since unreleased
## [br]
## @param elapsed_seconds: 预设已经过时间，保留负时间和非有限值归一化约定。
## [br]
## @param frequency: 资源频率；随机游标保留每秒至少一次的下限。
## [br]
## @param sample_seed: 同时参与轴盐值和哈希的资源种子。
## [br]
## @return 按现有波形合同计算的三轴偏移值。
static func sample_random_for_framework(
	elapsed_seconds: float,
	frequency: float,
	sample_seed: int
) -> Vector3:
	var step: int = floori(_safe_sample_cursor(elapsed_seconds, frequency))
	return Vector3(
		_hash_noise(
			step,
			sample_seed + 11,
			sample_seed
		),
		_hash_noise(
			step,
			sample_seed + 37,
			sample_seed
		),
		_hash_noise(
			step,
			sample_seed + 73,
			sample_seed
		)
	)


## 平滑插值相邻的确定性噪声三轴值。
## [br]
## @api framework_internal
## [br]
## @layer extensions/feedback
## [br]
## @since unreleased
## [br]
## @param elapsed_seconds: 预设已经过时间，保留负时间和非有限值归一化约定。
## [br]
## @param frequency: 资源频率；随机游标保留每秒至少一次的下限。
## [br]
## @param sample_seed: 同时参与轴盐值和哈希的资源种子。
## [br]
## @return 按现有波形合同计算的三轴偏移值。
static func sample_noise_for_framework(
	elapsed_seconds: float,
	frequency: float,
	sample_seed: int
) -> Vector3:
	var cursor: float = _safe_sample_cursor(
		elapsed_seconds,
		maxf(
			_finite_nonnegative(frequency),
			1.0
		)
	)
	var step: int = floori(cursor)
	var blend: float = smoothstep(
		0.0,
		1.0,
		cursor - float(step)
	)
	return Vector3(
		lerpf(
			_hash_noise(
				step,
				sample_seed + 11,
				sample_seed
			),
			_hash_noise(
				step + 1,
				sample_seed + 11,
				sample_seed
			),
			blend
		),
		lerpf(
			_hash_noise(
				step,
				sample_seed + 37,
				sample_seed
			),
			_hash_noise(
				step + 1,
				sample_seed + 37,
				sample_seed
			),
			blend
		),
		lerpf(
			_hash_noise(
				step,
				sample_seed + 73,
				sample_seed
			),
			_hash_noise(
				step + 1,
				sample_seed + 73,
				sample_seed
			),
			blend
		)
	)


## 把曲线值映射为三轴偏移，不转换调用方的进度。
## [br]
## @api framework_internal
## [br]
## @layer extensions/feedback
## [br]
## @since unreleased
## [br]
## @param progress: Preset 整体进度或 Track 局部进度。
## [br]
## @param wave_curve: 当前曲线；null 和非有限结果保留零偏移回退。
## [br]
## @return 按现有波形合同计算的三轴偏移值。
static func sample_curve_for_framework(progress: float, wave_curve: Curve) -> Vector3:
	var curve_value: float = 0.5
	if wave_curve != null:
		curve_value = _finite_float(
			wave_curve.sample_baked(progress),
			0.5
		)
	var mapped: float = clampf(
		curve_value,
		0.0,
		1.0
	) * 2.0 - 1.0
	return Vector3(
		mapped,
		mapped,
		mapped
	)


# --- 私有/辅助方法 ---

## 按既有整数运算顺序把游标、轴盐和种子映射到确定性噪声。
## [br]
## @api private
## [br]
static func _hash_noise(
	step: int,
	salt: int,
	sample_seed: int
) -> float:
	var value: int = int(step * 1103515245 + salt * 12345 + sample_seed * 2654435761)
	value = value ^ (value >> 13)
	value = value * 1274126177
	value = value ^ (value >> 16)
	var normalized: float = float(value & 0x7fffffff) / float(0x7fffffff)
	return normalized * 2.0 - 1.0


## 计算带频率下限和整数转换安全边界的采样游标。
## [br]
## @api private
static func _safe_sample_cursor(elapsed_seconds: float, sample_frequency: float) -> float:
	var cursor: float = _finite_float(elapsed_seconds) * maxf(
		_finite_nonnegative(sample_frequency),
		1.0
	)
	return clampf(
		_finite_float(cursor),
		-2147483647.0,
		2147483647.0
	)


## 将非有限输入替换为后备值，并限制结果不小于零。
## [br]
## @api private
static func _finite_nonnegative(value: float, fallback: float = 0.0) -> float:
	return maxf(
		_finite_float(value, fallback),
		0.0
	)


## 将非有限浮点输入替换为指定后备值。
## [br]
## @api private
static func _finite_float(value: float, fallback: float = 0.0) -> float:
	return value if is_finite(value) else fallback
