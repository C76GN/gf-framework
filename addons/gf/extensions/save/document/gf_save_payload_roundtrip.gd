# Save 内部的载荷投影和稳定身份往返实现。
extends RefCounted


# --- 常量 ---

## 原生可持久化值准入。
## [br]
## @api private
const _VALUE_VALIDATOR = preload("res://addons/gf/extensions/save/core/gf_save_persisted_value_validator.gd")


# --- 框架内部方法 ---

## 验证声明图、保留路径和身份规则。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param policy: 作者政策。
## [br]
## @return 准入结果。
## [br]
## @schema return: Dictionary，含 ok、error_kind、path。
static func validate_policy(policy: GFSavePayloadPolicy) -> Dictionary:
	if policy == null or policy.schema == null:
		return _failure(&"missing_schema", "")
	if policy.max_depth < 1 or policy.max_depth > 64:
		return _failure(&"invalid_limits", "")
	if policy.max_nodes < 1 or policy.max_nodes > 100000:
		return _failure(&"invalid_limits", "")
	if policy.max_bytes < 1 or policy.max_bytes > 67108864:
		return _failure(&"invalid_limits", "")
	var policy_values: Dictionary = _admit(
		policy,
		[policy.retained_fields, policy.collections]
	)
	if not GFVariantData.get_option_bool(policy_values, "ok"):
		return _failure(&"invalid_policy_values", "")
	var state: Dictionary = {
		"ok": true,
		"nodes": {},
		"count": 0,
	}
	_collect_schema(
		policy.schema,
		"",
		[],
		state,
		policy
	)
	if not GFVariantData.get_option_bool(state, "ok"):
		return _state_failure(state)
	var wrapper: GFDictionarySchema = GFDictionarySchema.new()
	wrapper.fields = [policy.schema]
	if not wrapper.validate_definition().is_ok():
		return _failure(&"invalid_schema", "")
	var nodes: Dictionary = state["nodes"]
	for path_value: Variant in policy.retained_fields:
		if not path_value is String or not nodes.has(path_value):
			return _failure(
				&"invalid_retention_path",
				str(path_value)
			)
		var path: String = path_value
		var field: GFSchemaField = nodes[path]
		var names_value: Variant = policy.retained_fields[path]
		if field.value_type != GFSchemaField.ValueType.DICTIONARY or field.dictionary_schema == null:
			return _failure(&"retention_requires_dictionary_schema", path)
		if not names_value is PackedStringArray:
			return _failure(&"invalid_retained_fields", path)
		var names: PackedStringArray = names_value
		for field_name: String in names:
			if field_name.is_empty():
				return _failure(&"invalid_retained_field", path)
		if not _has_identity_ancestors(policy, path):
			return _failure(&"retention_requires_identity", path)
	for path_value: Variant in policy.collections:
		if not path_value is String or not nodes.has(path_value):
			return _failure(
				&"invalid_collection_path",
				str(path_value)
			)
		var path: String = path_value
		var field: GFSchemaField = nodes[path]
		if not _has_identity_ancestors(policy, path):
			return _failure(&"retention_requires_identity", path)
		if field.value_type != GFSchemaField.ValueType.ARRAY or field.array_item_schema == null:
			return _failure(&"collection_requires_array_schema", path)
		var item_schema: GFDictionarySchema = field.array_item_schema.dictionary_schema
		if field.array_item_schema.value_type != GFSchemaField.ValueType.DICTIONARY or item_schema == null:
			return _failure(&"collection_requires_record_schema", path)
		var rule_value: Variant = policy.collections[path]
		if not rule_value is Dictionary:
			return _failure(&"invalid_collection", path)
		var rule: Dictionary = rule_value
		for key: Variant in rule:
			if key not in [
				"id_field",
				"active_ids",
				"preserve_unknown",
			]:
				return _failure(&"unknown_collection_option", path)
		var id_field: StringName = GFVariantData.get_option_string_name(rule, "id_field")
		var identity: GFSchemaField = item_schema.get_field(id_field)
		if (
			identity == null
			or not identity.required
			or identity.allow_null
		):
			return _failure(&"required_identity_missing", path)
		if identity.value_type not in [
			GFSchemaField.ValueType.INT,
			GFSchemaField.ValueType.STRING,
			GFSchemaField.ValueType.STRING_NAME,
		]:
			return _failure(&"invalid_identity_type", path)
		if rule.has("preserve_unknown") and not rule["preserve_unknown"] is bool:
			return _failure(&"invalid_collection_option", path)
		if rule.has("active_ids"):
			if not rule["active_ids"] is Array:
				return _failure(&"invalid_active_ids", path)
			var seen: Dictionary = {}
			var active_ids: Array = rule["active_ids"]
			for identity_value: Variant in active_ids:
				var identity_key: String = _id_key(identity_value)
				if (
					identity_key.is_empty()
					or seen.has(identity_key)
					or not identity.validate_value(identity_value).is_ok()
				):
					return _failure(&"invalid_active_ids", path)
				seen[identity_key] = true
	return _success()


## 复用实际投影/合并的只读原生值与预算准入，不复制输入。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param policy: 已通过 validate_policy() 的政策。
## [br]
## @param payload: 保持不变的完整载荷。
## [br]
## @schema payload: Save 原生持久化值。
## [br]
## @return 与实际准入相同的预算诊断。
## [br]
## @schema return: Dictionary with ok,error_kind,path,layer,limits,observed.
static func measure_payload(policy: GFSavePayloadPolicy, payload: Variant) -> Dictionary:
	return _admit(policy, payload)


## 将已准入的完整载荷投影为已知运行数据。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param policy: 声明政策。
## [br]
## @param payload: 完整持久化数据。
## [br]
## @schema payload: 可持久化 Variant。
## [br]
## @return 投影或失败。
## [br]
## @schema return: Dictionary，含 ok、error_kind、path；成功含 projection、baseline。
static func project(policy: GFSavePayloadPolicy, payload: Variant) -> Dictionary:
	var admission: Dictionary = validate_policy(policy)
	if not GFVariantData.get_option_bool(admission, "ok"):
		return admission
	admission = _admit(policy, payload)
	if not GFVariantData.get_option_bool(admission, "ok"):
		return admission
	var state: Dictionary = _make_state(policy, {})
	var projection: Variant = _project_value(
		payload,
		policy.schema,
		"",
		state,
		policy
	)
	if not GFVariantData.get_option_bool(state, "ok"):
		return _state_failure(state)
	if not policy.schema.validate_value(GFVariantData.duplicate_variant(projection)).is_ok():
		return _failure(&"known_value_invalid", "")
	return {
		"ok": true,
		"error_kind": &"",
		"path": "",
		"projection": GFVariantData.duplicate_variant(projection),
		"baseline": GFVariantData.duplicate_variant(payload),
	}


## 合并运行候选和持久化基线；删除指令只影响保留值。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param policy: 声明政策。
## [br]
## @param projection: 当前候选。
## [br]
## @param baseline: 原完整载荷或 null。
## [br]
## @param deletions: 具体路径到删除身份/字段列表。
## [br]
## @schema projection: 可持久化 Variant。
## [br]
## @schema baseline: 可持久化 Variant。
## [br]
## @schema deletions: Dictionary[String, Array]。
## [br]
## @return 完整结果或失败。
## [br]
## @schema return: Dictionary，成功含 payload、projection、baseline；失败含 error_kind、path。
static func merge(
	policy: GFSavePayloadPolicy,
	projection: Variant,
	baseline: Variant,
	deletions: Dictionary
) -> Dictionary:
	var current: Dictionary = project(policy, projection)
	if not GFVariantData.get_option_bool(current, "ok"):
		return current
	if baseline != null:
		var previous: Dictionary = project(policy, baseline)
		if not GFVariantData.get_option_bool(previous, "ok"):
			return previous
	var admitted: Dictionary = _admit(policy, deletions)
	if not GFVariantData.get_option_bool(admitted, "ok"):
		return admitted
	for path: Variant in deletions:
		if not path is String or not deletions[path] is Array:
			return _failure(
				&"invalid_deletions",
				str(path)
			)
	var state: Dictionary = _make_state(policy, deletions)
	if not GFVariantData.get_option_bool(state, "ok"):
		return _state_failure(state)
	var payload: Variant = _merge_value(
		projection,
		baseline,
		policy.schema,
		"",
		"",
		state,
		policy
	)
	if not GFVariantData.get_option_bool(state, "ok"):
		return _state_failure(state)
	var visited: Dictionary = state["visited_deletions"]
	for path: String in deletions:
		if not visited.has(path):
			return _failure(&"unknown_deletion_path", path)
	var result: Dictionary = project(policy, payload)
	if GFVariantData.get_option_bool(result, "ok"):
		result["payload"] = payload
	return result


## 返回以稳定身份定位的具体元素路径。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param path: 集合路径。
## [br]
## @param identity: 项目身份。
## [br]
## @schema identity: int、String 或 StringName。
## [br]
## @return 转义后的具体路径，无效身份返回空。
static func item_path(path: String, identity: Variant) -> String:
	var key: String = _id_key(identity)
	return _child_path(
		path,
		"@" + key
	) if not key.is_empty() else ""


# --- 私有/辅助方法 ---

## 路径中的数组元素必须由已声明的稳定身份关联，不把普通字段前缀误当通配段。
## [br]
## @api private
static func _has_identity_ancestors(policy: GFSavePayloadPolicy, path: String) -> bool:
	var parent: String = ""
	for part: String in path.trim_prefix("/").split("/"):
		if part == "*" and not policy.collections.has(parent):
			return false
		parent += "/" + part
	return true


## 有界遍历定义图，拒绝循环与隐式类型转换。
## [br]
## @api private
static func _collect_schema(
	field: GFSchemaField,
	path: String,
	ancestors: Array[int],
	state: Dictionary,
	policy: GFSavePayloadPolicy
) -> void:
	if not GFVariantData.get_option_bool(state, "ok"):
		return
	state["count"] = GFVariantData.get_option_int(state, "count") + 1
	if (
		field == null
		or ancestors.size() > policy.max_depth
		or GFVariantData.get_option_int(state, "count") > policy.max_nodes
	):
		_fail(
			state,
			&"invalid_schema_graph",
			path
		)
		return
	if ancestors.has(field.get_instance_id()) or field.field_name == &"*":
		_fail(
			state,
			&"invalid_schema_graph",
			path
		)
		return
	var definition_values: Array = [field.default_value, field.metadata]
	if not GFVariantData.get_option_bool(
		_admit(policy, definition_values),
		"ok"
	):
		_fail(
			state,
			&"invalid_schema_values",
			path
		)
		return
	var nodes: Dictionary = state["nodes"]
	nodes[path] = field
	var active: Array[int] = ancestors.duplicate()
	active.append(field.get_instance_id())
	if field.dictionary_schema != null:
		if not GFVariantData.get_option_bool(
			_admit(policy, field.dictionary_schema.metadata),
			"ok"
		):
			_fail(
				state,
				&"invalid_schema_values",
				path
			)
			return
		if field.dictionary_schema.coerce_values:
			_fail(
				state,
				&"coercion_not_allowed",
				path
			)
			return
		for child: GFSchemaField in field.dictionary_schema.fields:
			_collect_schema(
				child,
				_child_path(
					path,
					String(child.field_name)
				) if child != null else path,
				active,
				state,
				policy
			)
	if field.array_item_schema != null:
		_collect_schema(
			field.array_item_schema,
			path + "/*",
			active,
			state,
			policy
		)


## 先检查值域，再测量有界规范字节，复制前即拒绝超额内容。
## [br]
## @api private
static func _admit(policy: GFSavePayloadPolicy, value: Variant) -> Dictionary:
	var validation: Dictionary = _VALUE_VALIDATOR.validate(
		value,
		{ "max_depth": policy.max_depth, "max_nodes": policy.max_nodes }
	)
	var result: Dictionary = {
		"ok": false,
		"error_kind": &"",
		"path": "",
		"layer": &"save_payload_policy",
		"limits": policy.get_limits(),
		"observed": { "native": validation },
	}
	if not GFVariantData.get_option_bool(validation, "ok"):
		result["error_kind"] = &"invalid_persisted_value"
		result["path"] = GFVariantData.get_option_string(validation, "path")
		return result
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		value,
		{
			"allow_floats": true,
			"max_depth": policy.max_depth,
			"max_items": policy.max_nodes,
			"max_output_bytes": policy.max_bytes,
			"max_string_length": policy.max_bytes,
		}
	)
	var observed: Dictionary = result["observed"]
	observed["canonical"] = measured
	result["ok"] = GFVariantData.get_option_bool(measured, "ok")
	if not result["ok"]:
		result["error_kind"] = &"payload_budget_exceeded"
	return result


## 编译身份与删除集合，避免每条记录线性扫描声明列表。
## [br]
## @api private
static func _make_state(policy: GFSavePayloadPolicy, deletions: Dictionary) -> Dictionary:
	var state: Dictionary = {
		"ok": true,
		"active_ids": {},
		"deletions": {},
		"visited_deletions": {},
	}
	var active_sets: Dictionary = state["active_ids"]
	for path: String in policy.collections:
		var rule: Dictionary = policy.collections[path]
		if not rule.has("active_ids"):
			continue
		var identities: Dictionary = {}
		var values: Array = rule["active_ids"]
		for identity: Variant in values:
			identities[_id_key(identity)] = true
		active_sets[path] = identities
	var deletion_sets: Dictionary = state["deletions"]
	for path: String in deletions:
		var identities: Dictionary = {}
		var values: Array = deletions[path]
		for identity: Variant in values:
			var key: String = _id_key(identity)
			if key.is_empty():
				_fail(
					state,
					&"invalid_deletion_identity",
					path
				)
				return state
			identities[key] = true
		deletion_sets[path] = identities
	return state


## 按 schema 递归投影，未知内容只做保留准入。
## [br]
## @api private
static func _project_value(
	value: Variant,
	field: GFSchemaField,
	path: String,
	state: Dictionary,
	policy: GFSavePayloadPolicy
) -> Variant:
	if not GFVariantData.get_option_bool(state, "ok"):
		return null
	if (
		value is Dictionary
		and field.value_type == GFSchemaField.ValueType.DICTIONARY
		and field.dictionary_schema != null
	):
		var input: Dictionary = value
		var output: Dictionary = {}
		for key: Variant in input:
			if not key is String and not key is StringName:
				_fail(
					state,
					&"invalid_field_name",
					path
				)
				return null
			var child: GFSchemaField = field.dictionary_schema.get_field(GFVariantData.to_string_name(key))
			if child == null:
				if not _allows_field(
					policy,
					path,
					GFVariantData.to_text(key)
				):
					_fail(
						state,
						&"unknown_field",
						_child_path(
							path,
							GFVariantData.to_text(key)
						)
					)
					return null
				continue
			output[key] = _project_value(
				input[key],
				child,
				_child_path(
					path,
					GFVariantData.to_text(key)
				),
				state,
				policy
			)
		return output
	if (
		value is Array
		and field.value_type == GFSchemaField.ValueType.ARRAY
		and field.array_item_schema != null
	):
		var input: Array = value
		var output: Array = []
		var seen: Dictionary = {}
		var rule: Dictionary = GFVariantData.get_option_dictionary(policy.collections, path)
		for item: Variant in input:
			if not rule.is_empty():
				var identity: Variant = _record_id(item, rule)
				var key: String = _id_key(identity)
				var identity_field: GFSchemaField = field.array_item_schema.dictionary_schema.get_field(GFVariantData.get_option_string_name(rule, "id_field"))
				if (
					key.is_empty()
					or seen.has(key)
					or not identity_field.validate_value(identity).is_ok()
				):
					_fail(
						state,
						&"invalid_or_duplicate_identity",
						path
					)
					return null
				seen[key] = true
				if not _is_active(
					state,
					path,
					key
				):
					if not GFVariantData.get_option_bool(rule, "preserve_unknown"):
						_fail(
							state,
							&"unknown_content",
							item_path(path, identity)
						)
						return null
					continue
			output.append(
				_project_value(
					item,
					field.array_item_schema,
					path + "/*",
					state,
					policy
				)
			)
		return output
	return GFVariantData.duplicate_variant(value)


## 合并已知当前值与政策允许的旧未知值。
## [br]
## @api private
static func _merge_value(
	current: Variant,
	previous: Variant,
	field: GFSchemaField,
	schema_path: String,
	path: String,
	state: Dictionary,
	policy: GFSavePayloadPolicy
) -> Variant:
	if (
		current is Dictionary
		and field.value_type == GFSchemaField.ValueType.DICTIONARY
		and field.dictionary_schema != null
	):
		var values: Dictionary = current
		var old: Dictionary = GFVariantData.as_dictionary(previous)
		var output: Dictionary = {}
		_mark_deletion_path(state, path)
		for key: Variant in values:
			var child: GFSchemaField = field.dictionary_schema.get_field(GFVariantData.to_string_name(key))
			if child == null:
				if not _is_deleted(
					state,
					path,
					key
				):
					output[key] = GFVariantData.duplicate_variant(values[key])
				continue
			output[key] = _merge_value(
				values[key],
				old.get(key),
				child,
				_child_path(
					schema_path,
					GFVariantData.to_text(key)
				),
				_child_path(
					path,
					GFVariantData.to_text(key)
				),
				state,
				policy
			)
		for key: Variant in old:
			if values.has(key) or field.dictionary_schema.has_field(GFVariantData.to_string_name(key)):
				continue
			if _allows_field(
				policy,
				schema_path,
				GFVariantData.to_text(key)
			) and not _is_deleted(
				state,
				path,
				key
			):
				output[key] = GFVariantData.duplicate_variant(old[key])
		return output
	if (
		current is Array
		and field.value_type == GFSchemaField.ValueType.ARRAY
		and field.array_item_schema != null
	):
		var values: Array = current
		var rule: Dictionary = GFVariantData.get_option_dictionary(policy.collections, schema_path)
		if not rule.is_empty():
			return _merge_collection(
				values,
				GFVariantData.as_array(previous),
				field.array_item_schema,
				schema_path,
				path,
				state,
				policy,
				rule
			)
		var output: Array = []
		for item: Variant in values:
			output.append(
				_merge_value(
					item,
					null,
					field.array_item_schema,
					schema_path + "/*",
					path,
					state,
					policy
				)
			)
		return output
	return GFVariantData.duplicate_variant(current)


## 用稳定身份合并元素，旧未知条目沿仍存在的后继锚点插入。
## [br]
## @api private
static func _merge_collection(
	current: Array,
	previous: Array,
	item_schema: GFSchemaField,
	schema_path: String,
	path: String,
	state: Dictionary,
	policy: GFSavePayloadPolicy,
	rule: Dictionary
) -> Array:
	_mark_deletion_path(state, path)
	var old_by_id: Dictionary = {}
	for item: Variant in previous:
		old_by_id[_id_key(_record_id(item, rule))] = item
	var current_by_id: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	for item: Variant in current:
		var identity: Variant = _record_id(item, rule)
		var key: String = _id_key(identity)
		var active: bool = _is_active(
			state,
			schema_path,
			key
		)
		if not active and _is_deleted(
			state,
			path,
			identity
		):
			continue
		current_by_id[key] = (
			_merge_value(
				item,
				old_by_id.get(key),
				item_schema,
				schema_path + "/*",
				item_path(path, identity),
				state,
				policy
			)
			if active else GFVariantData.duplicate_variant(item)
		)
		var _appended: bool = order.append(key)
	var anchors: Dictionary = {}
	var next_key: String = ""
	for index: int in range(
		previous.size() - 1,
		-1,
		-1
	):
		var item: Variant = previous[index]
		var identity: Variant = _record_id(item, rule)
		var key: String = _id_key(identity)
		if current_by_id.has(key):
			next_key = key
			continue
		if _is_active(
			state,
			schema_path,
			key
		) or _is_deleted(
			state,
			path,
			identity
		):
			continue
		var pending: Array = GFVariantData.get_option_array(anchors, next_key)
		pending.append(GFVariantData.duplicate_variant(item))
		anchors[next_key] = pending
	var output: Array = []
	for key: String in order:
		var pending: Array = GFVariantData.get_option_array(anchors, key)
		pending.reverse()
		output.append_array(pending)
		output.append(current_by_id[key])
	var tail: Array = GFVariantData.get_option_array(anchors, "")
	tail.reverse()
	output.append_array(tail)
	return output


## 查找记录的显式身份字段。
## [br]
## @api private
static func _record_id(item: Variant, rule: Dictionary) -> Variant:
	if not item is Dictionary:
		return null
	var record: Dictionary = item
	return record.get(GFVariantData.get_option_string_name(rule, "id_field"))


## 统一文本身份，同时区分整数与同字面的文本。
## [br]
## @api private
static func _id_key(value: Variant) -> String:
	if value is int:
		return "i:" + str(value)
	if value is String or value is StringName:
		var text_value: String = GFVariantData.to_text(value)
		return "s:" + text_value if not text_value.is_empty() else ""
	return ""


## 按明确清单判断未知字段能否保留。
## [br]
## @api private
static func _allows_field(
	policy: GFSavePayloadPolicy,
	path: String,
	field_name: String
) -> bool:
	var names: PackedStringArray = GFVariantData.get_option_packed_string_array(policy.retained_fields, path)
	return names.has("*") or names.has(field_name)


## 判断内容身份是否进入运行投影。
## [br]
## @api private
static func _is_active(
	state: Dictionary,
	path: String,
	key: String
) -> bool:
	var active_sets: Dictionary = state["active_ids"]
	if not active_sets.has(path):
		return true
	var identities: Dictionary = active_sets[path]
	return identities.has(key)


## 标记实际访问的可删除节点。
## [br]
## @api private
static func _mark_deletion_path(state: Dictionary, path: String) -> void:
	var visited: Dictionary = state["visited_deletions"]
	visited[path] = true


## 判断未知字段或内容身份是否被显式删除。
## [br]
## @api private
static func _is_deleted(
	state: Dictionary,
	path: String,
	identity: Variant
) -> bool:
	var sets: Dictionary = state["deletions"]
	var identities: Dictionary = GFVariantData.get_option_dictionary(sets, path)
	return identities.has(_id_key(identity))


## 拼接 JSON Pointer 字段路径。
## [br]
## @api private
static func _child_path(path: String, field_name: String) -> String:
	return path + "/" + field_name.replace("~", "~0").replace("/", "~1")


## 构造无部分载荷的失败。
## [br]
## @api private
static func _failure(kind: StringName, path: String) -> Dictionary:
	return {
		"ok": false,
		"error_kind": kind,
		"path": path,
	}


## 构造准入成功。
## [br]
## @api private
static func _success() -> Dictionary:
	return {
		"ok": true,
		"error_kind": &"",
		"path": "",
	}


## 锁存首次失败位置。
## [br]
## @api private
static func _fail(
	state: Dictionary,
	kind: StringName,
	path: String
) -> void:
	if GFVariantData.get_option_bool(state, "ok"):
		state.merge(
			_failure(kind, path),
			true
		)


## 从内部状态取出无载荷的失败结果。
## [br]
## @api private
static func _state_failure(state: Dictionary) -> Dictionary:
	return _failure(
		GFVariantData.get_option_string_name(state, "error_kind"),
		GFVariantData.get_option_string(state, "path")
	)
