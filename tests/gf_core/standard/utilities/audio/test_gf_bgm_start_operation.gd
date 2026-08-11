# 测试 BGM 类型化启动 Operation、Result 与独立 Session Handle 契约。
extends GutTest


const _OPERATION_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/audio/gf_bgm_start_operation.gd"
)
const _RESULT_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/audio/gf_bgm_start_result.gd"
)
const _SESSION_HANDLE_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/audio/gf_bgm_session_handle.gd"
)


class DeferredAssetUtility:
	extends GFAssetUtility

	var pending: Dictionary = {}

	func load_async(
		path: String,
		on_loaded: Callable,
		_type_hint: String = "",
		_options: Dictionary = {}
	) -> void:
		pending[path] = on_loaded

	func finish(path: String, resource: Resource) -> void:
		if not pending.has(path):
			return
		var callback_value: Variant = GFVariantData.get_option_value(pending, path)
		var _erase_result: Variant = pending.erase(path)
		if callback_value is Callable:
			var callback: Callable = callback_value
			callback.call(resource)


class ImmediateAssetUtility:
	extends GFAssetUtility

	var resource: Resource

	func _init(value: Resource) -> void:
		resource = value

	func load_async(
		_path: String,
		on_loaded: Callable,
		_type_hint: String = "",
		_options: Dictionary = {}
	) -> void:
		on_loaded.call(resource)


class AssetBackedAudioUtility:
	extends GFAudioUtility

	var asset_utility: GFAssetUtility

	func _init(value: GFAssetUtility) -> void:
		asset_utility = value

	func _get_asset_util() -> GFAssetUtility:
		return asset_utility


class RecordingBgmBackend:
	extends GFAudioBackend

	var claims_bgm_paths: bool = true
	var accepts_bgm_start: bool = true
	var play_count: int = 0
	var last_path: String = ""
	var last_options: Dictionary = {}
	var bgm_playing: bool = false
	var stop_count: int = 0

	func can_handle_path(_path: String, channel: StringName, _context: Dictionary = {}) -> bool:
		return claims_bgm_paths and channel == &"bgm"

	func play_bgm_path(path: String, options: Dictionary = {}) -> bool:
		play_count += 1
		last_path = path
		last_options = options.duplicate(true)
		bgm_playing = accepts_bgm_start
		return accepts_bgm_start

	func stop_bgm(_fade_seconds: float = 0.0) -> bool:
		stop_count += 1
		bgm_playing = false
		return true

	func is_bgm_playing() -> bool:
		return bgm_playing


class ReentrantStartBackend:
	extends RecordingBgmBackend

	enum Action {
		NONE,
		CANCEL_OPERATION,
		RELEASE_OWNER,
		DISPOSE_UTILITY,
		STOP_NATURAL_DISPOSE,
		CANCEL_OPERATION_NATURAL_FINISH,
	}

	var action: Action = Action.NONE
	var request_owner: Node = null
	var action_called: bool = false
	var cancel_accepted: bool = false
	var last_pending_operation: Object = null
	var before_action_callback: Callable = Callable()

	func play_bgm_path(path: String, options: Dictionary = {}) -> bool:
		var accepted: bool = super.play_bgm_path(path, options)
		var host_value: Object = get_host()
		if host_value == null:
			return accepted
		last_pending_operation = _get_pending_operation(host_value)
		if before_action_callback.is_valid():
			var _callback_result: Variant = before_action_callback.call(
				last_pending_operation
			)
		action_called = true
		match action:
			Action.CANCEL_OPERATION:
				var operation: Object = _get_pending_operation(host_value)
				if operation != null:
					var cancel_value: Variant = operation.call(&"cancel")
					cancel_accepted = cancel_value is bool and cancel_value
			Action.RELEASE_OWNER:
				if is_instance_valid(request_owner):
					request_owner.free()
			Action.DISPOSE_UTILITY:
				host_value.call(&"dispose")
			Action.STOP_NATURAL_DISPOSE:
				host_value.call(&"stop_bgm", 0.0)
				var player_value: Variant = host_value.get("_bgm_player")
				if player_value is AudioStreamPlayer:
					var player: AudioStreamPlayer = player_value
					var _emit_result: Error = player.emit_signal(&"finished")
				host_value.call(&"dispose")
			Action.CANCEL_OPERATION_NATURAL_FINISH:
				if last_pending_operation != null:
					var cancel_value: Variant = last_pending_operation.call(&"cancel")
					cancel_accepted = cancel_value is bool and cancel_value
				var natural_player_value: Variant = host_value.get("_bgm_player")
				if natural_player_value is AudioStreamPlayer:
					var natural_player: AudioStreamPlayer = natural_player_value
					var _emit_result: Error = natural_player.emit_signal(&"finished")
		return accepted

	func _get_pending_operation(host_value: Object) -> Object:
		var pending_value: Variant = host_value.get("_bgm_pending_start_request")
		if not pending_value is Dictionary:
			return null
		var pending: Dictionary = pending_value
		var operation_value: Variant = GFVariantData.get_option_value(pending, "operation")
		if operation_value is Object:
			return operation_value
		return null


class PendingRequestLivenessBackend:
	extends RecordingBgmBackend

	enum CallbackAction {
		NONE,
		CANCEL_OPERATION,
		RELEASE_OWNER,
		CANCEL_OPERATION_AND_STOP_BGM,
		RECORD_ACTIVE_STOP_INTENT,
	}

	var callback_action: CallbackAction = CallbackAction.NONE
	var pending_operation: Object = null
	var pending_owner: Node = null
	var callback_count: int = 0
	var cancel_accepted: bool = false
	var playback_position: float = 17.25

	func is_bgm_playing() -> bool:
		var playing: bool = super.is_bgm_playing()
		_run_callback_action()
		return playing

	func pause_bgm(_fade_seconds: float = 0.0) -> bool:
		_run_callback_action()
		return true

	func set_parameter(_parameter: GFAudioParameter) -> bool:
		_run_callback_action()
		return true

	func get_bgm_playback_position() -> float:
		_run_callback_action()
		return playback_position

	func _run_callback_action() -> void:
		if callback_count > 0:
			return
		callback_count += 1
		match callback_action:
			CallbackAction.CANCEL_OPERATION:
				if pending_operation != null:
					var cancel_value: Variant = pending_operation.call(&"cancel")
					cancel_accepted = cancel_value is bool and cancel_value
			CallbackAction.RELEASE_OWNER:
				if is_instance_valid(pending_owner):
					pending_owner.free()
			CallbackAction.CANCEL_OPERATION_AND_STOP_BGM:
				if pending_operation != null:
					var cancel_value: Variant = pending_operation.call(&"cancel")
					cancel_accepted = cancel_value is bool and cancel_value
				var host_value: Object = get_host()
				if host_value != null:
					host_value.call(&"stop_bgm", 0.0)
			CallbackAction.RECORD_ACTIVE_STOP_INTENT:
				var host_value: Object = get_host()
				if host_value != null:
					var session_id: int = GFVariantData.to_int(
						host_value.get("_bgm_committed_session_id")
					)
					var _recorded: Variant = host_value.call(
						&"_record_deferred_bgm_session_terminal",
						session_id,
						GFBgmSessionHandle.EndKind.STOPPED,
						0.0
					)
					host_value.call(&"_schedule_deferred_audio_drain")


class RejectingHandoffInspectionBackend:
	extends RecordingBgmBackend

	var observed_candidate_count: int = 0
	var observed_audible_candidate: bool = false
	var observed_candidate_volume_db: float = GFAudioUtility.SILENCE_VOLUME_DB
	var reject_stop: bool = true

	func stop_bgm(_fade_seconds: float = 0.0) -> bool:
		stop_count += 1
		if not reject_stop:
			bgm_playing = false
			return true
		var host_value: Object = get_host()
		if host_value != null:
			var root_value: Variant = host_value.get("_root")
			if root_value is Node:
				var root_node: Node = root_value
				for child: Node in root_node.get_children():
					if not child is AudioStreamPlayer:
						continue
					var player: AudioStreamPlayer = child
					if player.name != &"GFBGMStandbyPlayer":
						continue
					observed_candidate_count += 1
					observed_candidate_volume_db = player.volume_db
					if (
						player.playing
						and not player.stream_paused
						and player.volume_db > GFAudioUtility.SILENCE_VOLUME_DB
					):
						observed_audible_candidate = true
		return false


class PublicationEmptyAfterBackendAcceptBackend:
	extends RecordingBgmBackend

	var invalidate_next_publication: bool = false
	var invalidated_publication_count: int = 0
	var before_invalidate_callback: Callable = Callable()

	func play_bgm_path(path: String, options: Dictionary = {}) -> bool:
		var accepted: bool = super.play_bgm_path(path, options)
		if not accepted or not invalidate_next_publication:
			return accepted
		invalidate_next_publication = false
		var host_value: Object = get_host()
		if host_value == null:
			return accepted
		var pending_value: Variant = host_value.get("_bgm_pending_start_request")
		if not pending_value is Dictionary:
			return accepted
		var pending: Dictionary = pending_value
		var operation_value: Variant = GFVariantData.get_option_value(
			pending,
			"operation"
		)
		if before_invalidate_callback.is_valid():
			var _callback_result: Variant = before_invalidate_callback.call(
				operation_value
			)
		pending["reserved_session_id"] = 0
		host_value.set("_bgm_pending_start_request", pending)
		invalidated_publication_count += 1
		return accepted


var _audio: GFAudioUtility
var _created_audio_buses: Array[String] = []
var _owned_nodes: Array[Node] = []
var _reentrant_clip: GFAudioClip = null
var _reentrant_operation: Object = null
var _freeze_before_emit_listener_called: bool = false
var _freeze_before_emit_pending_frozen: bool = false
var _cross_axis_active_session: Object = null
var _cross_axis_pending_operation: Object = null
var _cross_axis_signal_order: Array[StringName] = []
var _cross_axis_b_completed_count: int = 0
var _cross_axis_a_ended_count: int = 0
var _cross_axis_legacy_finished_count: int = 0
var _cross_axis_b_listener_saw_a_frozen: bool = false
var _cross_axis_a_listener_saw_b_frozen: bool = false
var _cross_axis_pending_connect_error: Error = OK
var _cross_axis_legacy_history_key: String = ""
var _generic_active_session: Object = null
var _generic_pending_operation: Object = null
var _generic_signal_order: Array[StringName] = []
var _generic_b_completed_count: int = 0
var _generic_a_ended_count: int = 0
var _generic_b_listener_saw_a_frozen: bool = false
var _generic_a_listener_saw_b_frozen: bool = false
var _publication_active_session: Object = null
var _publication_failed_operation: Object = null
var _publication_signal_order: Array[StringName] = []
var _publication_b_completed_count: int = 0
var _publication_a_ended_count: int = 0
var _publication_b_listener_saw_a_frozen: bool = false
var _publication_a_listener_saw_b_frozen: bool = false
var _publication_pending_connect_error: Error = OK


func before_each() -> void:
	_created_audio_buses.clear()
	_ensure_test_audio_bus(GFAudioUtility.BGM_BUS_NAME)
	_ensure_test_audio_bus(GFAudioUtility.SFX_BUS_NAME)
	_owned_nodes.clear()
	_reentrant_clip = null
	_reentrant_operation = null
	_freeze_before_emit_listener_called = false
	_freeze_before_emit_pending_frozen = false
	_cross_axis_active_session = null
	_cross_axis_pending_operation = null
	_cross_axis_signal_order.clear()
	_cross_axis_b_completed_count = 0
	_cross_axis_a_ended_count = 0
	_cross_axis_legacy_finished_count = 0
	_cross_axis_b_listener_saw_a_frozen = false
	_cross_axis_a_listener_saw_b_frozen = false
	_cross_axis_pending_connect_error = OK
	_cross_axis_legacy_history_key = ""
	_generic_active_session = null
	_generic_pending_operation = null
	_generic_signal_order.clear()
	_generic_b_completed_count = 0
	_generic_a_ended_count = 0
	_generic_b_listener_saw_a_frozen = false
	_generic_a_listener_saw_b_frozen = false
	_publication_active_session = null
	_publication_failed_operation = null
	_publication_signal_order.clear()
	_publication_b_completed_count = 0
	_publication_a_ended_count = 0
	_publication_b_listener_saw_a_frozen = false
	_publication_a_listener_saw_b_frozen = false
	_publication_pending_connect_error = OK
	_audio = GFAudioUtility.new()


func after_each() -> void:
	if _audio != null:
		_audio.dispose()
		_audio = null
	for scoped_owner: Node in _owned_nodes:
		if is_instance_valid(scoped_owner):
			scoped_owner.queue_free()
	_owned_nodes.clear()
	_remove_created_audio_buses()
	await get_tree().process_frame


func _ensure_test_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	_created_audio_buses.append(bus_name)


func _remove_created_audio_buses() -> void:
	for index: int in range(_created_audio_buses.size() - 1, -1, -1):
		var bus_index: int = AudioServer.get_bus_index(_created_audio_buses[index])
		if bus_index >= 0:
			AudioServer.remove_bus(bus_index)
	_created_audio_buses.clear()


func test_public_bgm_start_contract_is_frozen() -> void:
	_assert_method_signature(_audio, &"start_bgm", 3, 2, &"GFBgmStartOperation")
	_assert_method_signature(_audio, &"start_bgm_clip", 3, 2, &"GFBgmStartOperation")
	assert_true(
		ResourceLoader.exists(_OPERATION_SCRIPT_PATH, "Script"),
		"#88 必须提供 GFBgmStartOperation 公开句柄。"
	)
	assert_true(
		ResourceLoader.exists(_RESULT_SCRIPT_PATH, "Script"),
		"#88 必须提供 GFBgmStartResult 公开终态。"
	)
	assert_true(
		ResourceLoader.exists(_SESSION_HANDLE_SCRIPT_PATH, "Script"),
		"#88 必须提供独立于启动 Operation 的 GFBgmSessionHandle。"
	)
	assert_true(
		_global_script_class_exists(&"GFBgmStartOperation"),
		"GFBgmStartOperation 必须作为全局公开脚本类完成导入。"
	)
	assert_true(
		_global_script_class_exists(&"GFBgmStartResult"),
		"GFBgmStartResult 必须作为全局公开脚本类完成导入。"
	)
	assert_true(
		_global_script_class_exists(&"GFBgmSessionHandle"),
		"GFBgmSessionHandle 必须作为全局公开脚本类完成导入。"
	)
	if (
		not _utility_typed_methods_exist()
		or not _typed_contract_scripts_exist()
		or not _typed_contract_classes_registered()
	):
		return

	var operation_script: GDScript = _load_gdscript(_OPERATION_SCRIPT_PATH)
	var result_script: GDScript = _load_gdscript(_RESULT_SCRIPT_PATH)
	var session_script: GDScript = _load_gdscript(_SESSION_HANDLE_SCRIPT_PATH)
	assert_not_null(operation_script)
	assert_not_null(result_script)
	assert_not_null(session_script)
	if operation_script == null or result_script == null or session_script == null:
		return

	assert_eq(String(operation_script.get_global_name()), "GFBgmStartOperation")
	assert_eq(String(result_script.get_global_name()), "GFBgmStartResult")
	assert_eq(String(session_script.get_global_name()), "GFBgmSessionHandle")
	_assert_script_enum(result_script, "Status", {
		"STARTED": 0,
		"REJECTED": 1,
		"FAILED": 2,
		"SUPERSEDED": 3,
		"CANCELLED": 4,
	})
	_assert_script_enum(result_script, "BackendDisposition", {
		"NOT_ATTEMPTED": 0,
		"NOT_CLAIMED": 1,
		"REJECTED": 2,
		"STARTED": 3,
		"INVALIDATED": 4,
	})
	_assert_script_enum(session_script, "OwnerKind", {
		"NONE": 0,
		"LOCAL": 1,
		"BACKEND": 2,
	})
	_assert_script_enum(session_script, "EndKind", {
		"NONE": 0,
		"NATURAL_FINISH": 1,
		"STOPPED": 2,
		"REPLACED": 3,
		"OWNER_RELEASED": 4,
		"UTILITY_DISPOSED": 5,
		"PLAYBACK_FAILED": 6,
	})

	var operation_value: Variant = operation_script.new()
	var result_value: Variant = result_script.new()
	var session_value: Variant = session_script.new()
	assert_true(operation_value is RefCounted)
	assert_true(result_value is RefCounted)
	assert_true(session_value is RefCounted)
	if not operation_value is Object or not result_value is Object or not session_value is Object:
		return

	var operation: Object = operation_value
	var result: Object = result_value
	var session: Object = session_value
	_assert_object_surface(operation, [
		&"get_request_id",
		&"is_pending",
		&"is_completed",
		&"get_result",
		&"cancel",
	])
	assert_true(operation.has_signal(&"completed"), "Operation 必须提供 exactly-once completed(result)。")
	_assert_object_surface(result, [
		&"get_status",
		&"is_successful",
		&"get_request_id",
		&"get_reason",
		&"get_error_code",
		&"get_history_key",
		&"get_owner_kind",
		&"get_backend_disposition",
		&"used_backend_fallback",
		&"get_session_id",
		&"get_session_handle",
		&"duplicate_result",
		&"to_dict",
	])
	_assert_object_surface(session, [
		&"get_session_id",
		&"get_request_id",
		&"get_history_key",
		&"get_owner_kind",
		&"is_active",
		&"is_terminal",
		&"get_end_kind",
		&"stop",
	])
	assert_true(session.has_signal(&"ended"), "Session Handle 必须提供 exactly-once ended(handle, end_kind)。")


func test_start_result_closed_union_rejects_invalid_combinations_and_configures_once() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var request_id: int = 701
	var history_key: String = "issue88-result-union"
	var local_owner: int = _enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "LOCAL")
	var no_owner: int = _enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "NONE")
	var backend_owner: int = _enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "BACKEND")
	var started_status: int = _enum_value(_RESULT_SCRIPT_PATH, "Status", "STARTED")
	var failed_status: int = _enum_value(_RESULT_SCRIPT_PATH, "Status", "FAILED")
	var cancelled_status: int = _enum_value(_RESULT_SCRIPT_PATH, "Status", "CANCELLED")
	var not_attempted: int = _enum_value(
		_RESULT_SCRIPT_PATH,
		"BackendDisposition",
		"NOT_ATTEMPTED"
	)
	var backend_started: int = _enum_value(
		_RESULT_SCRIPT_PATH,
		"BackendDisposition",
		"STARTED"
	)
	var invalidated: int = _enum_value(
		_RESULT_SCRIPT_PATH,
		"BackendDisposition",
		"INVALIDATED"
	)
	var local_started_reason: StringName = _script_string_name_constant(
		_RESULT_SCRIPT_PATH,
		"REASON_LOCAL_STARTED"
	)
	var asset_failed_reason: StringName = _script_string_name_constant(
		_RESULT_SCRIPT_PATH,
		"REASON_ASSET_LOAD_FAILED"
	)
	var backend_changed_reason: StringName = _script_string_name_constant(
		_RESULT_SCRIPT_PATH,
		"REASON_BACKEND_CHANGED"
	)
	var local_player_rejected_reason: StringName = _script_string_name_constant(
		_RESULT_SCRIPT_PATH,
		"REASON_LOCAL_PLAYER_REJECTED"
	)
	var publication_failed_reason: StringName = _script_string_name_constant(
		_RESULT_SCRIPT_PATH,
		"REASON_SESSION_PUBLICATION_FAILED"
	)
	var session: Object = _make_configured_session(
		1701,
		request_id,
		history_key,
		"LOCAL"
	)
	if session == null:
		return

	_assert_result_configuration_rejected([
		99,
		request_id,
		local_started_reason,
		OK,
		history_key,
		local_owner,
		not_attempted,
		session,
	], "未知 status 必须拒绝。")
	_assert_result_configuration_rejected([
		started_status,
		request_id,
		&"invalid_path",
		OK,
		history_key,
		local_owner,
		not_attempted,
		session,
	], "STARTED 不得携带失败 reason。")
	_assert_result_configuration_rejected([
		started_status,
		request_id,
		local_started_reason,
		ERR_CANT_OPEN,
		history_key,
		local_owner,
		not_attempted,
		session,
	], "STARTED 必须携带 OK。")
	_assert_result_configuration_rejected([
		started_status,
		request_id,
		local_started_reason,
		OK,
		history_key,
		local_owner,
		backend_started,
		session,
	], "local-started reason 与 backend disposition 不得矛盾。")
	var mismatched_request_session: Object = _make_configured_session(
		1702,
		request_id + 1,
		history_key,
		"LOCAL"
	)
	_assert_result_configuration_rejected([
		started_status,
		request_id,
		local_started_reason,
		OK,
		history_key,
		local_owner,
		not_attempted,
		mismatched_request_session,
	], "Result 与 Session Handle 的 request identity 必须精确匹配。")
	var mismatched_history_session: Object = _make_configured_session(
		1703,
		request_id,
		"different-history",
		"LOCAL"
	)
	_assert_result_configuration_rejected([
		started_status,
		request_id,
		local_started_reason,
		OK,
		history_key,
		local_owner,
		not_attempted,
		mismatched_history_session,
	], "Result 与 Session Handle 的 history identity 必须精确匹配。")
	var mismatched_owner_session: Object = _make_configured_session(
		1704,
		request_id,
		history_key,
		"BACKEND"
	)
	_assert_result_configuration_rejected([
		started_status,
		request_id,
		local_started_reason,
		OK,
		history_key,
		local_owner,
		not_attempted,
		mismatched_owner_session,
	], "Result 与 Session Handle 的 owner identity 必须精确匹配。")
	_assert_result_configuration_rejected([
		failed_status,
		request_id,
		asset_failed_reason,
		ERR_CANT_OPEN,
		history_key,
		local_owner,
		not_attempted,
		session,
	], "非 STARTED 终态不得携带 owner 或 Session Handle。")
	_assert_result_configuration_rejected([
		failed_status,
		request_id,
		asset_failed_reason,
		ERR_CANT_OPEN,
		history_key,
		no_owner,
		backend_started,
		null,
	], "非 STARTED 终态不得声称 backend STARTED。")
	_assert_result_configuration_rejected([
		failed_status,
		request_id,
		asset_failed_reason,
		ERR_CANT_OPEN,
		history_key,
		no_owner,
		invalidated,
		null,
	], "FAILED 不得伪装为 topology-invalidated 终态。")
	_assert_result_configuration_rejected([
		failed_status,
		request_id,
		local_player_rejected_reason,
		ERR_CANT_CREATE,
		history_key,
		no_owner,
		invalidated,
		null,
	], "FAILED/ERR_CANT_CREATE/INVALIDATED 只允许 publication failure reason。")
	_assert_result_configuration_rejected([
		failed_status,
		request_id,
		publication_failed_reason,
		ERR_CANT_OPEN,
		history_key,
		no_owner,
		invalidated,
		null,
	], "session publication failure 必须携带 ERR_CANT_CREATE。")
	_assert_result_configuration_rejected([
		failed_status,
		request_id,
		publication_failed_reason,
		ERR_CANT_CREATE,
		history_key,
		no_owner,
		not_attempted,
		null,
	], "session publication failure 必须携带 INVALIDATED disposition。")
	_assert_result_configuration_rejected([
		cancelled_status,
		request_id,
		backend_changed_reason,
		ERR_SKIP,
		history_key,
		no_owner,
		not_attempted,
		null,
	], "backend_changed 必须携带 INVALIDATED disposition。")
	assert_ne(backend_owner, no_owner, "OwnerKind 枚举必须保持闭合可区分。")

	var accepted_cancelled: Object = _new_script_object(_RESULT_SCRIPT_PATH)
	assert_not_null(accepted_cancelled)
	if accepted_cancelled == null:
		return
	var accepted_arguments: Array = [
		cancelled_status,
		request_id,
		backend_changed_reason,
		ERR_SKIP,
		history_key,
		no_owner,
		invalidated,
		null,
	]
	assert_true(
		_call_bool_with_args(
			accepted_cancelled,
			&"configure_for_framework",
			accepted_arguments
		),
		"CANCELLED/backend_changed/INVALIDATED 是合法闭合终态。"
	)
	assert_false(
		_call_bool_with_args(
			accepted_cancelled,
			&"configure_for_framework",
			accepted_arguments
		),
		"Result 只能 configure 一次。"
	)
	assert_eq(_call_int(accepted_cancelled, &"get_request_id", 0), request_id)
	assert_eq(_call_int(accepted_cancelled, &"get_status", -1), cancelled_status)

	var accepted_publication_failure: Object = _new_script_object(
		_RESULT_SCRIPT_PATH
	)
	assert_not_null(accepted_publication_failure)
	if accepted_publication_failure == null:
		return
	assert_true(
		_call_bool_with_args(
			accepted_publication_failure,
			&"configure_for_framework",
			[
				failed_status,
				request_id + 1,
				publication_failed_reason,
				ERR_CANT_CREATE,
				history_key,
				no_owner,
				invalidated,
				null,
			]
		),
		"FAILED/session_publication_failed/ERR_CANT_CREATE/INVALIDATED 是合法闭合终态。"
	)
	assert_eq(
		_call_string_name(accepted_publication_failure, &"get_reason"),
		publication_failed_reason
	)
	assert_eq(
		_call_int(accepted_publication_failure, &"get_error_code", OK),
		ERR_CANT_CREATE
	)
	assert_eq(
		_call_int(accepted_publication_failure, &"get_backend_disposition", -1),
		invalidated
	)
	assert_null(_call_object(accepted_publication_failure, &"get_session_handle"))


func test_start_result_duplicate_shares_canonical_session_handle() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var request_id: int = 702
	var history_key: String = "issue88-result-duplicate"
	var session: Object = _make_configured_session(
		1705,
		request_id,
		history_key,
		"LOCAL"
	)
	var result: Object = _new_script_object(_RESULT_SCRIPT_PATH)
	assert_not_null(session)
	assert_not_null(result)
	if session == null or result == null:
		return
	assert_true(_call_bool_with_args(result, &"configure_for_framework", [
		_enum_value(_RESULT_SCRIPT_PATH, "Status", "STARTED"),
		request_id,
		_script_string_name_constant(_RESULT_SCRIPT_PATH, "REASON_LOCAL_STARTED"),
		OK,
		history_key,
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "LOCAL"),
		_enum_value(_RESULT_SCRIPT_PATH, "BackendDisposition", "NOT_ATTEMPTED"),
		session,
	]))
	var duplicated_result: Object = _call_object(result, &"duplicate_result")
	assert_not_null(duplicated_result)
	if duplicated_result == null:
		return
	assert_not_same(duplicated_result, result, "Result 标量副本必须是隔离对象。")
	assert_same(
		_call_object(duplicated_result, &"get_session_handle"),
		_call_object(result, &"get_session_handle"),
		"Result 副本必须共享唯一 canonical Session Handle capability。"
	)
	var dictionary_value: Variant = result.call(&"to_dict")
	assert_true(dictionary_value is Dictionary)
	if dictionary_value is Dictionary:
		var dictionary: Dictionary = dictionary_value
		assert_eq(dictionary.keys(), [
			"status",
			"request_id",
			"reason",
			"error_code",
			"history_key",
			"owner_kind",
			"backend_disposition",
			"used_backend_fallback",
			"session_id",
		])
		for value: Variant in dictionary.values():
			assert_false(value is Object, "Result serialization 不得泄露 capability 对象。")


func test_invalid_clip_completes_as_rejected_without_session() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())

	var operation: Object = _start_bgm_clip(null, -1.0)
	var result: Object = _assert_completed_with_status(operation, "REJECTED")
	if result == null:
		return
	assert_false(_call_bool(result, &"is_successful"))
	assert_ne(_call_int(result, &"get_error_code", OK), OK)
	assert_ne(_call_string_name(result, &"get_reason"), &"")
	assert_eq(_call_int(result, &"get_session_id", -1), 0)
	assert_null(_call_object(result, &"get_session_handle"))
	assert_eq(
		_call_int(result, &"get_owner_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "NONE")
	)
	assert_eq(
		_call_int(result, &"get_backend_disposition", -1),
		_enum_value(_RESULT_SCRIPT_PATH, "BackendDisposition", "NOT_ATTEMPTED")
	)


func test_empty_typed_path_is_rejected_without_stopping_active_session() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())
	watch_signals(_audio)
	var active_operation: Object = _start_bgm_clip(
		_make_clip("issue88-invalid-path-active"),
		0.0
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)

	var rejected_operation: Object = _start_bgm("", {})
	var rejected_result: Object = _assert_completed_with_status(
		rejected_operation,
		"REJECTED"
	)
	if rejected_result == null:
		return
	assert_eq(
		_call_string_name(rejected_result, &"get_reason"),
		_script_string_name_constant(_RESULT_SCRIPT_PATH, "REASON_INVALID_PATH")
	)
	assert_eq(_call_int(rejected_result, &"get_error_code", OK), ERR_INVALID_PARAMETER)
	assert_eq(_call_int(rejected_result, &"get_session_id", -1), 0)
	assert_null(_call_object(rejected_result, &"get_session_handle"))
	assert_true(_call_bool(active_session, &"is_active"), "typed 空路径不得复用 legacy stop 语义。")
	assert_signal_emit_count(active_session, "ended", 0)
	assert_eq(_audio.get_current_bgm_key(), "issue88-invalid-path-active")
	assert_true(_audio.is_bgm_playing())
	assert_signal_emit_count(_audio, "bgm_finished", 0)


func test_immediate_local_clip_returns_started_result_and_active_session() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())
	var clip: GFAudioClip = _make_clip("issue88-immediate-local")

	var operation: Object = _start_bgm_clip(clip, 0.0)
	var result: Object = _assert_completed_with_status(operation, "STARTED")
	if result == null:
		return
	_assert_started_result_matches_operation(operation, result, "issue88-immediate-local")
	assert_eq(
		_call_int(result, &"get_owner_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "LOCAL")
	)
	assert_eq(
		_call_int(result, &"get_backend_disposition", -1),
		_enum_value(_RESULT_SCRIPT_PATH, "BackendDisposition", "NOT_ATTEMPTED")
	)
	assert_false(_call_bool(result, &"used_backend_fallback"))


func test_started_local_session_owner_release_completes_owner_released_once() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())
	watch_signals(_audio)
	var request_owner: Node = Node.new()
	_owned_nodes.append(request_owner)
	get_tree().root.add_child(request_owner)
	var operation: Object = _start_bgm_clip(
		_make_clip("issue88-active-owner-release"),
		0.0,
		request_owner
	)
	var result: Object = _assert_completed_with_status(operation, "STARTED")
	if result == null:
		return
	var session: Object = _call_object(result, &"get_session_handle")
	assert_not_null(session)
	if session == null:
		return
	watch_signals(session)

	request_owner.free()
	await get_tree().process_frame

	assert_false(is_instance_valid(request_owner))
	assert_true(_call_bool(session, &"is_terminal"))
	assert_eq(
		_call_int(session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "OWNER_RELEASED")
	)
	assert_signal_emit_count(session, "ended", 1)
	assert_eq(_audio.get_current_bgm_key(), "")
	assert_false(_audio.is_bgm_playing())
	assert_signal_emit_count(_audio, "bgm_finished", 0)
	await get_tree().process_frame
	assert_signal_emit_count(session, "ended", 1)


func test_started_session_utility_dispose_completes_utility_disposed_once() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())
	watch_signals(_audio)
	var operation: Object = _start_bgm_clip(
		_make_clip("issue88-active-utility-dispose"),
		0.0
	)
	var result: Object = _assert_completed_with_status(operation, "STARTED")
	if result == null:
		return
	var session: Object = _call_object(result, &"get_session_handle")
	assert_not_null(session)
	if session == null:
		return
	watch_signals(session)

	_audio.dispose()

	assert_true(_call_bool(session, &"is_terminal"))
	assert_eq(
		_call_int(session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "UTILITY_DISPOSED")
	)
	assert_signal_emit_count(session, "ended", 1)
	assert_eq(_audio.get_current_bgm_key(), "")
	assert_signal_emit_count(_audio, "bgm_finished", 0)
	await get_tree().process_frame
	assert_signal_emit_count(session, "ended", 1)


func test_backend_accept_reports_started_backend_session_without_fallback() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var backend: RecordingBgmBackend = RecordingBgmBackend.new()
	await _activate_audio(GFAudioUtility.new())
	assert_true(_audio.set_audio_backend(backend))

	var operation: Object = _start_bgm(
		"event://music/issue88-backend",
		{"history_key": "issue88-backend"}
	)
	var result: Object = _assert_completed_with_status(operation, "STARTED")
	if result == null:
		return
	_assert_started_result_matches_operation(operation, result, "issue88-backend")
	assert_eq(backend.play_count, 1)
	assert_eq(backend.last_path, "event://music/issue88-backend")
	assert_eq(
		_call_int(result, &"get_owner_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "BACKEND")
	)
	assert_eq(
		_call_int(result, &"get_backend_disposition", -1),
		_enum_value(_RESULT_SCRIPT_PATH, "BackendDisposition", "STARTED")
	)
	assert_false(_call_bool(result, &"used_backend_fallback"))


func test_backend_owned_typed_session_natural_finish_completes_once() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var backend: RecordingBgmBackend = RecordingBgmBackend.new()
	await _activate_audio(GFAudioUtility.new())
	assert_true(_audio.set_audio_backend(backend))
	watch_signals(_audio)
	var operation: Object = _start_bgm(
		"event://music/issue88-backend-natural",
		{"history_key": "issue88-backend-natural"}
	)
	var result: Object = _assert_completed_with_status(operation, "STARTED")
	if result == null:
		return
	var session: Object = _call_object(result, &"get_session_handle")
	assert_not_null(session)
	if session == null:
		return
	watch_signals(session)

	backend.bgm_playing = false
	assert_false(_audio.is_bgm_playing())

	assert_true(_call_bool(session, &"is_terminal"))
	assert_eq(
		_call_int(session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "NATURAL_FINISH")
	)
	assert_signal_emit_count(session, "ended", 1)
	assert_signal_emitted_with_parameters(
		_audio,
		"bgm_finished",
		["issue88-backend-natural"]
	)
	assert_signal_emit_count(_audio, "bgm_finished", 1)
	assert_eq(_audio.get_current_bgm_key(), "")
	assert_false(_audio.is_bgm_playing())
	assert_signal_emit_count(session, "ended", 1)
	assert_signal_emit_count(_audio, "bgm_finished", 1)


func test_backend_rejection_can_fall_back_to_local_and_remains_a_started_result() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var backend: RecordingBgmBackend = RecordingBgmBackend.new()
	backend.accepts_bgm_start = false
	var immediate_asset: ImmediateAssetUtility = ImmediateAssetUtility.new(
		AudioStreamGenerator.new()
	)
	await _activate_audio(AssetBackedAudioUtility.new(immediate_asset))
	assert_true(_audio.set_audio_backend(backend))

	var operation: Object = _start_bgm(
		"event://music/issue88-fallback",
		{"history_key": "issue88-fallback"}
	)
	var result: Object = _assert_completed_with_status(operation, "STARTED")
	if result == null:
		return
	_assert_started_result_matches_operation(operation, result, "issue88-fallback")
	assert_eq(backend.play_count, 1)
	assert_eq(
		_call_int(result, &"get_owner_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "LOCAL")
	)
	assert_eq(
		_call_int(result, &"get_backend_disposition", -1),
		_enum_value(_RESULT_SCRIPT_PATH, "BackendDisposition", "REJECTED")
	)
	assert_true(_call_bool(result, &"used_backend_fallback"))


func test_backend_to_local_handoff_candidate_is_silent_before_rejected_stop() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var backend: RejectingHandoffInspectionBackend = (
		RejectingHandoffInspectionBackend.new()
	)
	var immediate_asset: ImmediateAssetUtility = ImmediateAssetUtility.new(
		AudioStreamGenerator.new()
	)
	await _activate_audio(AssetBackedAudioUtility.new(immediate_asset))
	assert_true(_audio.set_audio_backend(backend))
	var active_operation: Object = _start_bgm(
		"event://music/issue88-handoff-active",
		{"history_key": "issue88-handoff-active"}
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)

	backend.claims_bgm_paths = false
	var replacement_operation: Object = _start_bgm(
		"res://audio/issue88-handoff-local.ogg",
		{"history_key": "issue88-handoff-local"}
	)
	var replacement_result: Object = _assert_completed_with_status(
		replacement_operation,
		"FAILED"
	)
	if replacement_result == null:
		return
	assert_eq(
		_call_string_name(replacement_result, &"get_reason"),
		_script_string_name_constant(
			_RESULT_SCRIPT_PATH,
			"REASON_BACKEND_OWNER_RELEASE_FAILED"
		)
	)
	assert_eq(backend.stop_count, 1, "handoff 必须且只应尝试一次 backend stop。")
	assert_false(
		backend.observed_audible_candidate,
		"backend stop 回调可观察的本地候选必须保持静音。"
	)
	if backend.observed_candidate_count > 0:
		assert_lte(
			backend.observed_candidate_volume_db,
			GFAudioUtility.SILENCE_VOLUME_DB,
			"候选只有在 backend owner 成功释放后才可恢复目标音量。"
		)
	assert_false(_has_audible_standby_player(), "stop 拒绝后不得遗留可听候选。")
	assert_true(backend.bgm_playing, "拒绝 stop 的 backend-owned A 必须继续物理播放。")
	assert_true(_call_bool(active_session, &"is_active"))
	assert_signal_emit_count(active_session, "ended", 0)
	assert_eq(_audio.get_current_bgm_key(), "issue88-handoff-active")
	backend.reject_stop = false


func test_session_id_exhaustion_fails_before_backend_handoff_stop() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var backend: RecordingBgmBackend = RecordingBgmBackend.new()
	var immediate_asset: ImmediateAssetUtility = ImmediateAssetUtility.new(
		AudioStreamGenerator.new()
	)
	await _activate_audio(AssetBackedAudioUtility.new(immediate_asset))
	assert_true(_audio.set_audio_backend(backend))
	var active_operation: Object = _start_bgm(
		"event://music/issue88-id-exhaustion-active",
		{"history_key": "issue88-id-exhaustion-active"}
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)
	backend.claims_bgm_paths = false
	_audio._next_bgm_session_id = 9223372036854775807

	var failed_operation: Object = _start_bgm(
		"res://audio/issue88-id-exhaustion-local.ogg",
		{"history_key": "issue88-id-exhaustion-local"}
	)
	assert_push_error("[GFAudioUtility] BGM session ID 空间已耗尽。")
	var failed_result: Object = _assert_completed_with_status(failed_operation, "FAILED")
	if failed_result == null:
		return
	assert_eq(
		_call_string_name(failed_result, &"get_reason"),
		_script_string_name_constant(_RESULT_SCRIPT_PATH, "REASON_LOCAL_PLAYER_REJECTED")
	)
	assert_eq(backend.stop_count, 0, "确定无法分配 session 时不得先停止 backend-owned A。")
	assert_true(backend.bgm_playing, "ID 耗尽不得产生 backend 物理停止副作用。")
	assert_true(_call_bool(active_session, &"is_active"))
	assert_signal_emit_count(active_session, "ended", 0)
	assert_eq(_audio.get_current_bgm_key(), "issue88-id-exhaustion-active")
	assert_eq(_audio._bgm_owner, &"backend")
	assert_false(_has_audible_standby_player(), "失败候选必须完成物理清理。")


func test_backend_accepted_publication_failure_compensates_and_closes_both_axes() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var backend: PublicationEmptyAfterBackendAcceptBackend = (
		PublicationEmptyAfterBackendAcceptBackend.new()
	)
	await _activate_audio(GFAudioUtility.new())
	assert_true(_audio.set_audio_backend(backend))
	watch_signals(_audio)
	var active_operation: Object = _start_bgm(
		"event://music/issue88-publication-active",
		{"history_key": "issue88-publication-active"}
	)
	var active_result: Object = _assert_completed_with_status(
		active_operation,
		"STARTED"
	)
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)
	_publication_active_session = active_session
	assert_eq(
		active_session.connect(
			&"ended",
			Callable(self, "_on_publication_a_ended")
		),
		OK
	)
	backend.invalidate_next_publication = true
	backend.before_invalidate_callback = Callable(
		self,
		"_bind_publication_failed_operation"
	)

	var failed_operation: Object = _start_bgm(
		"event://music/issue88-publication-failed",
		{"history_key": "issue88-publication-failed"}
	)
	assert_not_null(failed_operation)
	if failed_operation == null:
		return
	assert_same(failed_operation, _publication_failed_operation)
	assert_eq(_publication_pending_connect_error, OK)
	var failed_result: Object = _assert_completed_with_status(
		failed_operation,
		"FAILED"
	)
	if failed_result == null:
		return
	assert_eq(
		_call_string_name(failed_result, &"get_reason"),
		_script_string_name_constant(
			_RESULT_SCRIPT_PATH,
			"REASON_SESSION_PUBLICATION_FAILED"
		)
	)
	assert_eq(_call_int(failed_result, &"get_error_code", OK), ERR_CANT_CREATE)
	assert_eq(
		_call_int(failed_result, &"get_backend_disposition", -1),
		_enum_value(_RESULT_SCRIPT_PATH, "BackendDisposition", "INVALIDATED")
	)
	assert_eq(
		_call_int(failed_result, &"get_owner_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "NONE")
	)
	assert_eq(_call_int(failed_result, &"get_session_id", -1), 0)
	assert_null(_call_object(failed_result, &"get_session_handle"))
	assert_eq(backend.play_count, 2, "A 与已接纳 B 必须各调用一次 backend start。")
	assert_eq(backend.invalidated_publication_count, 1)
	assert_eq(backend.stop_count, 1, "已接纳但无法发布的 B 必须补偿停止一次。")
	assert_false(backend.bgm_playing)
	assert_true(_call_bool(active_session, &"is_terminal"))
	assert_eq(
		_call_int(active_session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "PLAYBACK_FAILED")
	)
	assert_true(_publication_b_listener_saw_a_frozen)
	assert_true(_publication_a_listener_saw_b_frozen)
	assert_eq(
		_publication_signal_order,
		[&"b_completed", &"a_ended"],
		"publication failure 必须先通知 B Operation，再通知物理丢失的 A Session。"
	)
	assert_eq(_publication_b_completed_count, 1)
	assert_eq(_publication_a_ended_count, 1)
	assert_signal_emit_count(failed_operation, "completed", 1)
	assert_signal_emit_count(active_session, "ended", 1)
	assert_signal_emit_count(_audio, "bgm_finished", 0)
	assert_eq(_audio.get_current_bgm_key(), "")
	await get_tree().process_frame
	assert_eq(_publication_b_completed_count, 1)
	assert_eq(_publication_a_ended_count, 1)


func test_backend_dispatch_cancel_is_first_terminal_and_compensates_backend_start() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var backend: ReentrantStartBackend = ReentrantStartBackend.new()
	backend.action = ReentrantStartBackend.Action.CANCEL_OPERATION
	await _activate_audio(GFAudioUtility.new())
	assert_true(_audio.set_audio_backend(backend))

	var operation: Object = _start_bgm(
		"event://music/issue88-reentrant-cancel",
		{"history_key": "issue88-reentrant-cancel"}
	)
	var result: Object = _assert_completed_with_status(operation, "CANCELLED")
	if result == null:
		return
	_assert_cancelled_topology_result(result, "REASON_CALLER_CANCELLED")
	assert_true(backend.action_called)
	assert_true(backend.cancel_accepted)
	assert_eq(backend.play_count, 1)
	assert_eq(backend.stop_count, 1, "backend 已接受但 request 失效时必须补偿停止。")
	assert_false(backend.bgm_playing)
	assert_eq(_audio.get_current_bgm_key(), "")


func test_backend_dispatch_owner_release_is_terminal_and_compensates_backend_start() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var request_owner: Node = Node.new()
	_owned_nodes.append(request_owner)
	get_tree().root.add_child(request_owner)
	var backend: ReentrantStartBackend = ReentrantStartBackend.new()
	backend.action = ReentrantStartBackend.Action.RELEASE_OWNER
	backend.request_owner = request_owner
	await _activate_audio(GFAudioUtility.new())
	assert_true(_audio.set_audio_backend(backend))

	var operation: Object = _start_bgm(
		"event://music/issue88-reentrant-owner",
		{"history_key": "issue88-reentrant-owner"},
		request_owner
	)
	var result: Object = _assert_completed_with_status(operation, "CANCELLED")
	if result == null:
		return
	_assert_cancelled_topology_result(result, "REASON_OWNER_RELEASED")
	assert_true(backend.action_called)
	assert_false(is_instance_valid(request_owner))
	assert_eq(backend.stop_count, 1, "owner 释放后迟到 backend start 必须补偿停止。")
	assert_false(backend.bgm_playing)
	assert_eq(_audio.get_current_bgm_key(), "")


func test_backend_dispatch_dispose_is_terminal_and_compensates_before_teardown() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var backend: ReentrantStartBackend = ReentrantStartBackend.new()
	backend.action = ReentrantStartBackend.Action.DISPOSE_UTILITY
	await _activate_audio(GFAudioUtility.new())
	assert_true(_audio.set_audio_backend(backend))

	var operation: Object = _start_bgm(
		"event://music/issue88-reentrant-dispose",
		{"history_key": "issue88-reentrant-dispose"}
	)
	var result: Object = _assert_completed_with_status(operation, "CANCELLED")
	if result == null:
		return
	_assert_cancelled_topology_result(result, "REASON_UTILITY_DISPOSED")
	assert_true(backend.action_called)
	assert_eq(backend.stop_count, 1, "dispose intent 不能遗留 backend 已接受的幽灵播放。")
	assert_false(backend.bgm_playing)
	assert_null(_audio.get_audio_backend())
	assert_eq(_audio.get_current_bgm_key(), "")


func test_set_backend_terminates_pending_request_and_quarantines_late_asset() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	var first_backend: RecordingBgmBackend = RecordingBgmBackend.new()
	first_backend.claims_bgm_paths = false
	var replacement_backend: RecordingBgmBackend = RecordingBgmBackend.new()
	replacement_backend.claims_bgm_paths = false
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	assert_true(_audio.set_audio_backend(first_backend))
	var path: String = "res://audio/issue88-pending-set-backend.ogg"
	var operation: Object = _start_bgm(path, {"history_key": "issue88-pending-set"})
	assert_not_null(operation)
	if operation == null:
		return
	watch_signals(operation)
	assert_true(_call_bool(operation, &"is_pending"))

	assert_true(_audio.set_audio_backend(replacement_backend))
	var result: Object = _assert_completed_with_status(operation, "CANCELLED")
	if result == null:
		return
	_assert_cancelled_topology_result(result, "REASON_BACKEND_CHANGED")
	assert_signal_emit_count(operation, "completed", 1)
	asset_utility.finish(path, AudioStreamGenerator.new())
	await get_tree().process_frame
	assert_signal_emit_count(operation, "completed", 1)
	assert_eq(_audio.get_audio_backend(), replacement_backend)
	assert_eq(_audio.get_current_bgm_key(), "")


func test_clear_backend_terminates_pending_request_and_quarantines_late_asset() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	var backend: RecordingBgmBackend = RecordingBgmBackend.new()
	backend.claims_bgm_paths = false
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	assert_true(_audio.set_audio_backend(backend))
	var path: String = "res://audio/issue88-pending-clear-backend.ogg"
	var operation: Object = _start_bgm(path, {"history_key": "issue88-pending-clear"})
	assert_not_null(operation)
	if operation == null:
		return
	watch_signals(operation)
	assert_true(_call_bool(operation, &"is_pending"))

	assert_true(_audio.clear_audio_backend())
	var result: Object = _assert_completed_with_status(operation, "CANCELLED")
	if result == null:
		return
	_assert_cancelled_topology_result(result, "REASON_BACKEND_CHANGED")
	assert_signal_emit_count(operation, "completed", 1)
	asset_utility.finish(path, AudioStreamGenerator.new())
	await get_tree().process_frame
	assert_signal_emit_count(operation, "completed", 1)
	assert_null(_audio.get_audio_backend())
	assert_eq(_audio.get_current_bgm_key(), "")


func test_async_load_failure_completes_failed_exactly_once() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	var path: String = "res://audio/issue88-missing.ogg"
	var operation: Object = _start_bgm(path, {"history_key": "issue88-missing"})
	assert_not_null(operation)
	if operation == null:
		return
	watch_signals(operation)
	assert_true(_call_bool(operation, &"is_pending"))

	asset_utility.finish(path, null)
	await get_tree().process_frame
	var result: Object = _assert_completed_with_status(operation, "FAILED")
	if result == null:
		return
	assert_signal_emit_count(operation, "completed", 1)
	assert_ne(_call_string_name(result, &"get_reason"), &"")
	assert_ne(_call_int(result, &"get_error_code", OK), OK)
	assert_eq(_call_int(result, &"get_session_id", -1), 0)
	assert_null(_call_object(result, &"get_session_handle"))


func test_cancel_pending_operation_is_terminal_and_quarantines_late_load() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	var path: String = "res://audio/issue88-cancelled.ogg"
	var operation: Object = _start_bgm(path, {"history_key": "issue88-cancelled"})
	assert_not_null(operation)
	if operation == null:
		return
	watch_signals(operation)

	assert_true(_call_bool_with_args(operation, &"cancel", []))
	assert_false(_call_bool_with_args(operation, &"cancel", []), "重复 cancel 必须幂等返回 false。")
	var result: Object = _assert_completed_with_status(operation, "CANCELLED")
	assert_not_null(result)
	assert_signal_emit_count(operation, "completed", 1)
	asset_utility.finish(path, AudioStreamGenerator.new())
	await get_tree().process_frame
	assert_signal_emit_count(operation, "completed", 1)
	assert_eq(_audio.get_current_bgm_key(), "")
	assert_false(_audio.is_bgm_playing())


func test_owner_release_cancels_pending_operation_and_suppresses_late_load() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	var request_owner: Node = Node.new()
	_owned_nodes.append(request_owner)
	get_tree().root.add_child(request_owner)
	var path: String = "res://audio/issue88-owner.ogg"
	var operation: Object = _start_bgm(
		path,
		{"history_key": "issue88-owner"},
		request_owner
	)
	assert_not_null(operation)
	if operation == null:
		return
	watch_signals(operation)

	request_owner.queue_free()
	await get_tree().process_frame
	var result: Object = _assert_completed_with_status(operation, "CANCELLED")
	assert_not_null(result)
	assert_signal_emit_count(operation, "completed", 1)
	asset_utility.finish(path, AudioStreamGenerator.new())
	await get_tree().process_frame
	assert_signal_emit_count(operation, "completed", 1)
	assert_eq(_audio.get_current_bgm_key(), "")


func test_backend_query_cancel_drains_pending_request_without_asset_callback() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	var backend: PendingRequestLivenessBackend = PendingRequestLivenessBackend.new()
	assert_true(_audio.set_audio_backend(backend))
	var active_operation: Object = _start_bgm(
		"event://music/issue88-query-active",
		{"history_key": "issue88-query-active"}
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return

	backend.claims_bgm_paths = false
	var pending_path: String = "res://audio/issue88-query-pending.ogg"
	var pending_operation: Object = _start_bgm(
		pending_path,
		{"history_key": "issue88-query-pending"}
	)
	assert_not_null(pending_operation)
	if pending_operation == null:
		return
	watch_signals(pending_operation)
	assert_true(_call_bool(pending_operation, &"is_pending"))
	assert_true(asset_utility.pending.has(pending_path))
	backend.pending_operation = pending_operation
	backend.callback_action = PendingRequestLivenessBackend.CallbackAction.CANCEL_OPERATION

	assert_true(_audio.is_bgm_playing())
	assert_eq(backend.callback_count, 1)
	assert_true(backend.cancel_accepted, "backend query 回调中的 cancel intent 必须被接纳。")
	await get_tree().process_frame
	var pending_result: Object = _assert_completed_with_status(
		pending_operation,
		"CANCELLED"
	)
	if pending_result == null:
		return
	_assert_cancelled_topology_result(
		pending_result,
		"REASON_CALLER_CANCELLED",
		"NOT_CLAIMED"
	)
	assert_signal_emit_count(pending_operation, "completed", 1)
	assert_true(asset_utility.pending.has(pending_path), "终结不得依赖 asset callback。")
	assert_true(_call_bool(active_session, &"is_active"))
	assert_eq(_audio.get_current_bgm_key(), "issue88-query-active")
	await get_tree().process_frame
	assert_signal_emit_count(pending_operation, "completed", 1)


func test_backend_pause_owner_release_drains_pending_request_without_asset_callback() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	var backend: PendingRequestLivenessBackend = PendingRequestLivenessBackend.new()
	assert_true(_audio.set_audio_backend(backend))
	var active_operation: Object = _start_bgm(
		"event://music/issue88-pause-active",
		{"history_key": "issue88-pause-active"}
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return

	backend.claims_bgm_paths = false
	var request_owner: Node = Node.new()
	_owned_nodes.append(request_owner)
	get_tree().root.add_child(request_owner)
	var pending_path: String = "res://audio/issue88-pause-pending.ogg"
	var pending_operation: Object = _start_bgm(
		pending_path,
		{"history_key": "issue88-pause-pending"},
		request_owner
	)
	assert_not_null(pending_operation)
	if pending_operation == null:
		return
	watch_signals(pending_operation)
	assert_true(_call_bool(pending_operation, &"is_pending"))
	assert_true(asset_utility.pending.has(pending_path))
	backend.pending_owner = request_owner
	backend.callback_action = PendingRequestLivenessBackend.CallbackAction.RELEASE_OWNER

	var _pause_result: bool = _audio.pause_bgm(0.0)
	assert_eq(backend.callback_count, 1)
	assert_false(is_instance_valid(request_owner))
	await get_tree().process_frame
	var pending_result: Object = _assert_completed_with_status(
		pending_operation,
		"CANCELLED"
	)
	if pending_result == null:
		return
	_assert_cancelled_topology_result(
		pending_result,
		"REASON_OWNER_RELEASED",
		"NOT_CLAIMED"
	)
	assert_signal_emit_count(pending_operation, "completed", 1)
	assert_true(asset_utility.pending.has(pending_path), "终结不得依赖 asset callback。")
	assert_true(_call_bool(active_session, &"is_active"))
	assert_eq(_audio.get_current_bgm_key(), "issue88-pause-active")
	await get_tree().process_frame
	assert_signal_emit_count(pending_operation, "completed", 1)


func test_generic_backend_callback_freezes_cancel_and_stop_before_same_frame_start() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	var backend: PendingRequestLivenessBackend = PendingRequestLivenessBackend.new()
	assert_true(_audio.set_audio_backend(backend))
	var active_operation: Object = _start_bgm(
		"event://music/issue88-generic-active",
		{"history_key": "issue88-generic-active"}
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)
	_generic_active_session = active_session
	assert_eq(
		active_session.connect(&"ended", Callable(self, "_on_generic_a_ended")),
		OK
	)

	backend.claims_bgm_paths = false
	var pending_path: String = "res://audio/issue88-generic-pending.ogg"
	var pending_operation: Object = _start_bgm(
		pending_path,
		{"history_key": "issue88-generic-pending"}
	)
	assert_not_null(pending_operation)
	if pending_operation == null:
		return
	watch_signals(pending_operation)
	assert_true(_call_bool(pending_operation, &"is_pending"))
	assert_true(asset_utility.pending.has(pending_path))
	_generic_pending_operation = pending_operation
	assert_eq(
		pending_operation.connect(
			&"completed",
			Callable(self, "_on_generic_b_completed")
		),
		OK
	)
	backend.pending_operation = pending_operation
	backend.callback_action = (
		PendingRequestLivenessBackend.CallbackAction.CANCEL_OPERATION_AND_STOP_BGM
	)

	var parameter: GFAudioParameter = GFAudioParameter.new()
	parameter.parameter_id = &"issue88-generic-dispatch"
	parameter.value = 1.0
	var _parameter_result: bool = _audio.set_audio_parameter(parameter)
	assert_eq(backend.callback_count, 1)
	assert_true(backend.cancel_accepted)
	backend.claims_bgm_paths = true
	var replacement_operation: Object = _start_bgm(
		"event://music/issue88-generic-replacement",
		{"history_key": "issue88-generic-replacement"}
	)
	await get_tree().process_frame

	var pending_result: Object = _assert_completed_with_status(
		pending_operation,
		"CANCELLED"
	)
	if pending_result == null:
		return
	_assert_cancelled_topology_result(
		pending_result,
		"REASON_CALLER_CANCELLED",
		"NOT_CLAIMED"
	)
	assert_true(_call_bool(active_session, &"is_terminal"))
	assert_eq(
		_call_int(active_session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "STOPPED")
	)
	var replacement_result: Object = _assert_completed_with_status(
		replacement_operation,
		"STARTED"
	)
	if replacement_result == null:
		return
	var replacement_session: Object = _call_object(
		replacement_result,
		&"get_session_handle"
	)
	assert_not_null(replacement_session)
	if replacement_session != null:
		assert_true(_call_bool(replacement_session, &"is_active"))
	assert_true(
		_generic_b_listener_saw_a_frozen,
		"B.completed 首个用户回调必须观察到 A 已冻结为 STOPPED。"
	)
	assert_true(
		_generic_a_listener_saw_b_frozen,
		"A.ended 首个用户回调必须观察到 B 已冻结为 caller CANCELLED。"
	)
	assert_eq(_generic_b_completed_count, 1)
	assert_eq(_generic_a_ended_count, 1)
	assert_signal_emit_count(pending_operation, "completed", 1)
	assert_signal_emit_count(active_session, "ended", 1)
	assert_eq(_audio.get_current_bgm_key(), "issue88-generic-replacement")
	await get_tree().process_frame
	assert_eq(_generic_b_completed_count, 1)
	assert_eq(_generic_a_ended_count, 1)


func test_backend_query_false_drains_cancel_and_natural_before_user_signals() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	var backend: PendingRequestLivenessBackend = PendingRequestLivenessBackend.new()
	assert_true(_audio.set_audio_backend(backend))
	var active_operation: Object = _start_bgm(
		"event://music/issue88-query-natural-active",
		{"history_key": "issue88-query-natural-active"}
	)
	var active_result: Object = _assert_completed_with_status(
		active_operation,
		"STARTED"
	)
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)
	watch_signals(_audio)
	_cross_axis_active_session = active_session
	assert_eq(
		active_session.connect(&"ended", Callable(self, "_on_cross_axis_a_ended")),
		OK
	)
	assert_eq(
		_audio.bgm_finished.connect(
			Callable(self, "_on_cross_axis_legacy_finished")
		),
		OK
	)

	backend.claims_bgm_paths = false
	var pending_path: String = "res://audio/issue88-query-natural-pending.ogg"
	var pending_operation: Object = _start_bgm(
		pending_path,
		{"history_key": "issue88-query-natural-pending"}
	)
	assert_not_null(pending_operation)
	if pending_operation == null:
		return
	watch_signals(pending_operation)
	assert_true(_call_bool(pending_operation, &"is_pending"))
	assert_true(asset_utility.pending.has(pending_path))
	_bind_cross_axis_pending_operation(pending_operation)
	assert_eq(_cross_axis_pending_connect_error, OK)
	backend.pending_operation = pending_operation
	backend.callback_action = PendingRequestLivenessBackend.CallbackAction.CANCEL_OPERATION
	backend.bgm_playing = false

	assert_false(_audio.is_bgm_playing())
	assert_true(backend.cancel_accepted)
	var pending_result: Object = _call_object(pending_operation, &"get_result")
	assert_not_null(
		pending_result,
		"query 返回前 central barrier 必须已经冻结 pending B。"
	)
	if pending_result != null:
		assert_eq(
			_call_int(pending_result, &"get_status", -1),
			_enum_value(_RESULT_SCRIPT_PATH, "Status", "CANCELLED")
		)
		assert_eq(
			_call_string_name(pending_result, &"get_reason"),
			_script_string_name_constant(
				_RESULT_SCRIPT_PATH,
				"REASON_CALLER_CANCELLED"
			)
		)
	assert_true(
		_call_bool(active_session, &"is_terminal"),
		"backend query=false 返回前必须冻结 A natural terminal。"
	)
	assert_eq(
		_call_int(active_session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "NATURAL_FINISH")
	)
	assert_true(_cross_axis_b_listener_saw_a_frozen)
	assert_true(_cross_axis_a_listener_saw_b_frozen)
	assert_eq(
		_cross_axis_signal_order,
		[&"b_completed", &"a_ended", &"legacy_natural"],
		"central barrier 信号顺序必须为 B Operation、A Handle、legacy natural。"
	)
	assert_eq(_cross_axis_b_completed_count, 1)
	assert_eq(_cross_axis_a_ended_count, 1)
	assert_eq(_cross_axis_legacy_finished_count, 1)
	assert_eq(_cross_axis_legacy_history_key, "issue88-query-natural-active")
	assert_signal_emit_count(pending_operation, "completed", 1)
	assert_signal_emit_count(active_session, "ended", 1)
	assert_signal_emit_count(_audio, "bgm_finished", 1)
	await get_tree().process_frame
	assert_eq(_cross_axis_b_completed_count, 1)
	assert_eq(_cross_axis_a_ended_count, 1)
	assert_eq(_cross_axis_legacy_finished_count, 1)


func test_backend_position_revalidates_identity_after_terminal_callback() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var backend: PendingRequestLivenessBackend = PendingRequestLivenessBackend.new()
	await _activate_audio(GFAudioUtility.new())
	assert_true(_audio.set_audio_backend(backend))
	watch_signals(_audio)
	var active_operation: Object = _start_bgm(
		"event://music/issue88-position-identity",
		{"history_key": "issue88-position-identity"}
	)
	var active_result: Object = _assert_completed_with_status(
		active_operation,
		"STARTED"
	)
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)
	backend.callback_action = (
		PendingRequestLivenessBackend.CallbackAction.RECORD_ACTIVE_STOP_INTENT
	)

	var returned_position: float = _audio.get_bgm_playback_position()
	assert_eq(backend.callback_count, 1)
	assert_almost_eq(
		returned_position,
		0.0,
		0.001,
		"backend callback 终结 captured session 后不得返回旧 session 的非零 position。"
	)
	assert_true(_call_bool(active_session, &"is_terminal"))
	assert_eq(
		_call_int(active_session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "STOPPED")
	)
	assert_signal_emit_count(active_session, "ended", 1)
	assert_signal_emit_count(_audio, "bgm_finished", 0)
	assert_eq(backend.stop_count, 1)
	assert_eq(_audio.get_current_bgm_key(), "")
	await get_tree().process_frame
	assert_signal_emit_count(active_session, "ended", 1)


func test_direct_cancel_drains_prior_stop_intent_before_b_completed() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	var backend: PendingRequestLivenessBackend = PendingRequestLivenessBackend.new()
	assert_true(_audio.set_audio_backend(backend))
	watch_signals(_audio)
	var active_operation: Object = _start_bgm(
		"event://music/issue88-direct-cancel-active",
		{"history_key": "issue88-direct-cancel-active"}
	)
	var active_result: Object = _assert_completed_with_status(
		active_operation,
		"STARTED"
	)
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)
	_generic_active_session = active_session
	assert_eq(
		active_session.connect(&"ended", Callable(self, "_on_generic_a_ended")),
		OK
	)

	backend.claims_bgm_paths = false
	var pending_path: String = "res://audio/issue88-direct-cancel-pending.ogg"
	var pending_operation: Object = _start_bgm(
		pending_path,
		{"history_key": "issue88-direct-cancel-pending"}
	)
	assert_not_null(pending_operation)
	if pending_operation == null:
		return
	watch_signals(pending_operation)
	assert_true(_call_bool(pending_operation, &"is_pending"))
	assert_true(asset_utility.pending.has(pending_path))
	_generic_pending_operation = pending_operation
	assert_eq(
		pending_operation.connect(
			&"completed",
			Callable(self, "_on_generic_b_completed")
		),
		OK
	)
	backend.pending_operation = pending_operation
	backend.callback_action = (
		PendingRequestLivenessBackend.CallbackAction.RECORD_ACTIVE_STOP_INTENT
	)
	var parameter: GFAudioParameter = GFAudioParameter.new()
	parameter.parameter_id = &"issue88-direct-cancel-barrier"
	parameter.value = 1.0
	var _parameter_result: bool = _audio.set_audio_parameter(parameter)
	assert_eq(backend.callback_count, 1)

	assert_true(_call_bool(pending_operation, &"cancel"))
	var pending_result: Object = _call_object(pending_operation, &"get_result")
	assert_not_null(
		pending_result,
		"direct cancel 返回前必须通过 central barrier 冻结 B。"
	)
	if pending_result != null:
		assert_eq(
			_call_int(pending_result, &"get_status", -1),
			_enum_value(_RESULT_SCRIPT_PATH, "Status", "CANCELLED")
		)
	assert_true(
		_call_bool(active_session, &"is_terminal"),
		"B.completed 前必须提交 dispatch 内已记录的 A STOPPED。"
	)
	assert_eq(
		_call_int(active_session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "STOPPED")
	)
	assert_true(_generic_b_listener_saw_a_frozen)
	assert_true(_generic_a_listener_saw_b_frozen)
	assert_eq(
		_generic_signal_order,
		[&"b_completed", &"a_ended"],
		"central cancel barrier 必须先通知 B Operation，再通知 A Session。"
	)
	assert_eq(_generic_b_completed_count, 1)
	assert_eq(_generic_a_ended_count, 1)
	assert_signal_emit_count(pending_operation, "completed", 1)
	assert_signal_emit_count(active_session, "ended", 1)
	assert_signal_emit_count(_audio, "bgm_finished", 0)
	await get_tree().process_frame
	assert_eq(_generic_b_completed_count, 1)
	assert_eq(_generic_a_ended_count, 1)


func test_active_session_survives_failed_and_cancelled_prepare_requests() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	await _activate_audio(AssetBackedAudioUtility.new(asset_utility))
	var active_operation: Object = _start_bgm_clip(
		_make_clip("issue88-active-preserved"),
		0.0
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)

	var failed_path: String = "res://audio/issue88-prepare-failed.ogg"
	var failed_operation: Object = _start_bgm(
		failed_path,
		{"history_key": "issue88-prepare-failed"}
	)
	assert_true(_call_bool(failed_operation, &"is_pending"))
	asset_utility.finish(failed_path, null)
	await get_tree().process_frame
	var failed_result: Object = _assert_completed_with_status(failed_operation, "FAILED")
	assert_not_null(failed_result)
	assert_true(_call_bool(active_session, &"is_active"))
	assert_eq(_audio.get_current_bgm_key(), "issue88-active-preserved")
	assert_signal_emit_count(active_session, "ended", 0)

	var cancelled_path: String = "res://audio/issue88-prepare-cancelled.ogg"
	var cancelled_operation: Object = _start_bgm(
		cancelled_path,
		{"history_key": "issue88-prepare-cancelled"}
	)
	assert_true(_call_bool(cancelled_operation, &"is_pending"))
	assert_true(_call_bool_with_args(cancelled_operation, &"cancel", []))
	var cancelled_result: Object = _assert_completed_with_status(
		cancelled_operation,
		"CANCELLED"
	)
	assert_not_null(cancelled_result)
	asset_utility.finish(cancelled_path, AudioStreamGenerator.new())
	await get_tree().process_frame
	assert_true(_call_bool(active_session, &"is_active"))
	assert_eq(_audio.get_current_bgm_key(), "issue88-active-preserved")
	assert_true(_audio.is_bgm_playing())
	assert_signal_emit_count(active_session, "ended", 0)


func test_stop_ended_callback_can_start_replacement_without_old_continuation_clobber() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())
	var first_operation: Object = _start_bgm_clip(
		_make_clip("issue88-reentrant-stop-first"),
		0.0
	)
	var first_result: Object = _assert_completed_with_status(first_operation, "STARTED")
	if first_result == null:
		return
	var first_session: Object = _call_object(first_result, &"get_session_handle")
	assert_not_null(first_session)
	if first_session == null:
		return
	watch_signals(first_session)
	_reentrant_clip = _make_clip("issue88-reentrant-stop-second")
	assert_eq(
		first_session.connect(&"ended", Callable(self, "_on_reentrant_session_ended")),
		OK
	)

	assert_true(_call_bool_with_args(first_session, &"stop", [0.0]))
	assert_signal_emit_count(first_session, "ended", 1)
	assert_true(_call_bool(first_session, &"is_terminal"))
	assert_eq(
		_call_int(first_session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "STOPPED")
	)
	assert_not_null(_reentrant_operation)
	var second_result: Object = _assert_completed_with_status(_reentrant_operation, "STARTED")
	if second_result == null:
		return
	var second_session: Object = _call_object(second_result, &"get_session_handle")
	assert_not_null(second_session)
	if second_session != null:
		assert_true(_call_bool(second_session, &"is_active"))
	assert_eq(_audio.get_current_bgm_key(), "issue88-reentrant-stop-second")
	assert_true(_audio.is_bgm_playing())


func test_active_dispatch_stop_natural_and_dispose_preserve_first_terminals() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())
	watch_signals(_audio)
	var active_operation: Object = _start_bgm_clip(
		_make_clip("issue88-first-wins-active"),
		0.0
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	watch_signals(active_session)
	var backend: ReentrantStartBackend = ReentrantStartBackend.new()
	backend.action = ReentrantStartBackend.Action.STOP_NATURAL_DISPOSE
	assert_eq(
		active_session.connect(
			&"ended",
			Callable(self, "_on_first_wins_session_ended").bind(backend)
		),
		OK
	)
	assert_true(_audio.set_audio_backend(backend))

	var pending_operation: Object = _start_bgm(
		"event://music/issue88-first-wins-pending",
		{"history_key": "issue88-first-wins-pending"}
	)
	var pending_result: Object = _assert_completed_with_status(
		pending_operation,
		"CANCELLED"
	)
	if pending_result == null:
		return
	_assert_cancelled_topology_result(pending_result, "REASON_STOP_REQUESTED")
	assert_true(_freeze_before_emit_listener_called)
	assert_true(
		_freeze_before_emit_pending_frozen,
		"A.ended 首个用户回调前，pending B Operation 必须已冻结为 CANCELLED。"
	)
	assert_true(_call_bool(active_session, &"is_terminal"))
	assert_eq(
		_call_int(active_session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "STOPPED"),
		"active session 的首个 stop terminal 不得被迟到 finished/dispose 改写。"
	)
	assert_signal_emit_count(active_session, "ended", 1)
	assert_signal_emit_count(_audio, "bgm_finished", 0)
	assert_eq(backend.stop_count, 1, "pending backend start 必须且只须一次补偿停止。")
	assert_null(_audio.get_audio_backend())
	assert_eq(_audio.get_current_bgm_key(), "")


func test_backend_cancel_and_local_natural_freeze_both_axes_before_signals() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())
	var active_operation: Object = _start_bgm_clip(
		_make_clip("issue88-cross-axis-local"),
		0.0
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	_cross_axis_active_session = active_session
	assert_eq(
		active_session.connect(&"ended", Callable(self, "_on_cross_axis_a_ended")),
		OK
	)
	assert_eq(
		_audio.bgm_finished.connect(Callable(self, "_on_cross_axis_legacy_finished")),
		OK
	)

	var backend: ReentrantStartBackend = ReentrantStartBackend.new()
	backend.action = ReentrantStartBackend.Action.CANCEL_OPERATION_NATURAL_FINISH
	backend.before_action_callback = Callable(self, "_bind_cross_axis_pending_operation")
	assert_true(_audio.set_audio_backend(backend))
	var pending_operation: Object = _start_bgm(
		"event://music/issue88-cross-axis-pending",
		{"history_key": "issue88-cross-axis-pending"}
	)
	assert_not_null(pending_operation)
	if pending_operation == null:
		return
	assert_same(pending_operation, _cross_axis_pending_operation)
	assert_eq(_cross_axis_pending_connect_error, OK)
	assert_true(backend.cancel_accepted)
	var immediate_stop_accepted: bool = _call_bool_with_args(
		active_session,
		&"stop",
		[0.0]
	)
	assert_false(
		immediate_stop_accepted,
		"dispatch 中已冻结 NATURAL 后，同帧 exact stop 不得覆盖首个终态。"
	)
	await get_tree().process_frame

	var pending_result: Object = _assert_completed_with_status(
		pending_operation,
		"CANCELLED"
	)
	if pending_result == null:
		return
	_assert_cancelled_topology_result(pending_result, "REASON_CALLER_CANCELLED")
	assert_true(_call_bool(active_session, &"is_terminal"))
	assert_eq(
		_call_int(active_session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "NATURAL_FINISH")
	)
	assert_true(_cross_axis_b_listener_saw_a_frozen)
	assert_true(_cross_axis_a_listener_saw_b_frozen)
	assert_eq(
		_cross_axis_signal_order,
		[&"b_completed", &"a_ended", &"legacy_natural"],
		"用户可见信号顺序必须为 B Operation、A Handle、legacy natural。"
	)
	assert_eq(_cross_axis_b_completed_count, 1)
	assert_eq(_cross_axis_a_ended_count, 1)
	assert_eq(_cross_axis_legacy_finished_count, 1)
	assert_eq(_cross_axis_legacy_history_key, "issue88-cross-axis-local")
	await get_tree().process_frame
	assert_eq(_cross_axis_b_completed_count, 1)
	assert_eq(_cross_axis_a_ended_count, 1)
	assert_eq(_cross_axis_legacy_finished_count, 1)


func test_stop_intent_suppresses_late_finished_after_session_handle_release() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())
	watch_signals(_audio)
	var active_operation: Object = _start_bgm_clip(
		_make_clip("issue88-released-handle-active"),
		0.0
	)
	var active_result: Object = _assert_completed_with_status(active_operation, "STARTED")
	if active_result == null:
		return
	var active_session: Object = _call_object(active_result, &"get_session_handle")
	assert_not_null(active_session)
	if active_session == null:
		return
	var session_ref: WeakRef = weakref(active_session)
	active_session = null
	active_result = null
	active_operation = null
	var released_handle_value: Variant = session_ref.get_ref()
	assert_true(
		released_handle_value == null,
		"测试必须先确定性释放公开 Session Handle，命中 weak capability 缺失路径。"
	)

	var backend: ReentrantStartBackend = ReentrantStartBackend.new()
	backend.action = ReentrantStartBackend.Action.STOP_NATURAL_DISPOSE
	assert_true(_audio.set_audio_backend(backend))
	var pending_operation: Object = _start_bgm(
		"event://music/issue88-released-handle-pending",
		{"history_key": "issue88-released-handle-pending"}
	)
	var pending_result: Object = _assert_completed_with_status(
		pending_operation,
		"CANCELLED"
	)
	if pending_result == null:
		return
	_assert_cancelled_topology_result(pending_result, "REASON_STOP_REQUESTED")
	assert_true(backend.action_called)
	assert_signal_emit_count(
		_audio,
		"bgm_finished",
		0,
		"STOPPED intent 后的迟到 finished 不得因 Session Handle 已释放而伪装成自然结束。"
	)


func test_replaced_session_handle_is_exact_and_cannot_stop_replacement() -> void:
	if _skip_runtime_scenario_until_contract_exists():
		return
	await _activate_audio(GFAudioUtility.new())
	var first: Object = _start_bgm_clip(_make_clip("issue88-session-first"), 0.0)
	var first_result: Object = _assert_completed_with_status(first, "STARTED")
	if first_result == null:
		return
	var first_session: Object = _call_object(first_result, &"get_session_handle")
	assert_not_null(first_session)
	if first_session == null:
		return
	watch_signals(first_session)

	var second: Object = _start_bgm_clip(_make_clip("issue88-session-second"), 0.0)
	var second_result: Object = _assert_completed_with_status(second, "STARTED")
	if second_result == null:
		return
	var second_session: Object = _call_object(second_result, &"get_session_handle")
	assert_not_null(second_session)
	if second_session == null:
		return
	assert_true(_call_bool(first_session, &"is_terminal"))
	assert_false(_call_bool(first_session, &"is_active"))
	assert_eq(
		_call_int(first_session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "REPLACED")
	)
	assert_signal_emit_count(first_session, "ended", 1)
	assert_false(
		_call_bool_with_args(first_session, &"stop", [0.0]),
		"已替换的 stale handle 不得停止当前会话。"
	)
	assert_signal_emit_count(first_session, "ended", 1)
	assert_true(_call_bool(second_session, &"is_active"))
	assert_eq(_audio.get_current_bgm_key(), "issue88-session-second")


func test_rapid_replacement_supersedes_old_operation_and_quarantines_stale_load() -> void:
	if not _typed_contract_runtime_ready():
		assert_true(true, "公开契约缺失已由 test_public_bgm_start_contract_is_frozen 报告。")
		return

	var asset_utility: DeferredAssetUtility = DeferredAssetUtility.new()
	_audio = AssetBackedAudioUtility.new(asset_utility)
	_audio.init()
	await get_tree().process_frame
	var first_path: String = "res://audio/issue88-first.ogg"
	var second_path: String = "res://audio/issue88-second.ogg"
	var first: Object = _start_bgm(first_path, {"history_key": "issue88-first"})
	assert_not_null(first)
	if first == null:
		return
	watch_signals(first)
	assert_true(_call_bool(first, &"is_pending"), "首个异步加载必须先保持 pending。")

	var second: Object = _start_bgm(second_path, {"history_key": "issue88-second"})
	assert_not_null(second)
	if second == null:
		return
	watch_signals(second)
	assert_true(_call_bool(first, &"is_completed"), "后续 BGM 请求必须终结旧 pending 请求。")
	var first_result: Object = _get_result(first)
	assert_not_null(first_result)
	if first_result == null:
		return
	assert_eq(
		_call_int(first_result, &"get_status", -1),
		_enum_value(_RESULT_SCRIPT_PATH, "Status", "SUPERSEDED"),
		"被后续请求替代的 pending operation 必须显式终结为 SUPERSEDED。"
	)
	assert_signal_emit_count(first, "completed", 1)

	asset_utility.finish(first_path, AudioStreamGenerator.new())
	await get_tree().process_frame
	assert_signal_emit_count(first, "completed", 1, "迟到旧 load 不得重复终结旧 Operation。")
	assert_true(_call_bool(second, &"is_pending"), "迟到旧 load 不得终结或提交新请求。")
	assert_ne(_audio.get_current_bgm_key(), "issue88-first")

	asset_utility.finish(second_path, AudioStreamGenerator.new())
	await get_tree().process_frame
	assert_true(_call_bool(second, &"is_completed"))
	assert_signal_emit_count(second, "completed", 1)
	var second_result: Object = _get_result(second)
	assert_not_null(second_result)
	if second_result == null:
		return
	assert_eq(
		_call_int(second_result, &"get_status", -1),
		_enum_value(_RESULT_SCRIPT_PATH, "Status", "STARTED")
	)
	assert_eq(_audio.get_current_bgm_key(), "issue88-second")
	assert_gt(_call_int(second_result, &"get_session_id", 0), 0)
	var session_value: Variant = second_result.call(&"get_session_handle")
	assert_true(session_value is Object, "STARTED 结果必须携带独立 Session Handle。")
	if session_value is Object:
		var session: Object = session_value
		assert_true(_call_bool(session, &"is_active"))
		assert_eq(
			_call_int(session, &"get_request_id", 0),
			_call_int(second, &"get_request_id", -1)
		)


func _typed_contract_scripts_exist() -> bool:
	return (
		ResourceLoader.exists(_OPERATION_SCRIPT_PATH, "Script")
		and ResourceLoader.exists(_RESULT_SCRIPT_PATH, "Script")
		and ResourceLoader.exists(_SESSION_HANDLE_SCRIPT_PATH, "Script")
	)


func _typed_contract_runtime_ready() -> bool:
	return (
		_typed_contract_scripts_exist()
		and _typed_contract_classes_registered()
		and _utility_typed_methods_exist()
	)


func _utility_typed_methods_exist() -> bool:
	return (
		_audio != null
		and _audio.has_method(&"start_bgm")
		and _audio.has_method(&"start_bgm_clip")
	)


func _typed_contract_classes_registered() -> bool:
	return (
		_global_script_class_exists(&"GFBgmStartOperation")
		and _global_script_class_exists(&"GFBgmStartResult")
		and _global_script_class_exists(&"GFBgmSessionHandle")
	)


func _global_script_class_exists(class_name_value: StringName) -> bool:
	for class_value: Variant in ProjectSettings.get_global_class_list():
		if not class_value is Dictionary:
			continue
		var class_info: Dictionary = class_value
		if GFVariantData.get_option_string_name(class_info, "class") == class_name_value:
			return true
	return false


func _skip_runtime_scenario_until_contract_exists() -> bool:
	if _typed_contract_runtime_ready():
		return false
	assert_true(true, "公开契约缺失已由结构契约测试报告。")
	return true


func _activate_audio(replacement: GFAudioUtility) -> void:
	if _audio != null:
		_audio.dispose()
		await get_tree().process_frame
	_audio = replacement
	_audio.init()
	await get_tree().process_frame


func _make_clip(history_key: String) -> GFAudioClip:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = history_key
	clip.stream = AudioStreamGenerator.new()
	clip.bus_name = GFAudioUtility.BGM_BUS_NAME
	return clip


func _has_audible_standby_player() -> bool:
	if _audio == null:
		return false
	var root_value: Variant = _audio.get("_root")
	if not root_value is Node:
		return false
	var root_node: Node = root_value
	for child: Node in root_node.get_children():
		if not child is AudioStreamPlayer:
			continue
		var player: AudioStreamPlayer = child
		if (
			player.name == &"GFBGMStandbyPlayer"
			and player.playing
			and not player.stream_paused
			and player.volume_db > GFAudioUtility.SILENCE_VOLUME_DB
		):
			return true
	return false


func _new_script_object(path: String) -> Object:
	var script: GDScript = _load_gdscript(path)
	assert_not_null(script)
	if script == null:
		return null
	var object_value: Variant = script.new()
	assert_true(object_value is Object)
	if object_value is Object:
		return object_value
	return null


func _make_configured_session(
	session_id: int,
	request_id: int,
	history_key: String,
	owner_kind_name: String
) -> Object:
	var session: Object = _new_script_object(_SESSION_HANDLE_SCRIPT_PATH)
	if session == null:
		return null
	assert_true(_call_bool_with_args(session, &"configure_for_framework", [
		session_id,
		request_id,
		history_key,
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", owner_kind_name),
		Callable(self, "_accept_test_session_stop"),
	]))
	return session


func _assert_result_configuration_rejected(arguments: Array, message: String) -> void:
	var result: Object = _new_script_object(_RESULT_SCRIPT_PATH)
	assert_not_null(result)
	if result == null:
		return
	assert_false(
		_call_bool_with_args(result, &"configure_for_framework", arguments),
		message
	)
	assert_false(_call_bool(result, &"is_configured_for_framework"))
	assert_eq(_call_int(result, &"get_request_id", -1), 0)


func _assert_cancelled_topology_result(
	result: Object,
	reason_constant_name: String,
	disposition_constant_name: String = "INVALIDATED"
) -> void:
	assert_eq(
		_call_string_name(result, &"get_reason"),
		_script_string_name_constant(_RESULT_SCRIPT_PATH, reason_constant_name)
	)
	assert_eq(_call_int(result, &"get_error_code", OK), ERR_SKIP)
	assert_eq(
		_call_int(result, &"get_backend_disposition", -1),
		_enum_value(
			_RESULT_SCRIPT_PATH,
			"BackendDisposition",
			disposition_constant_name
		)
	)
	assert_eq(
		_call_int(result, &"get_owner_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "OwnerKind", "NONE")
	)
	assert_eq(_call_int(result, &"get_session_id", -1), 0)
	assert_null(_call_object(result, &"get_session_handle"))


func _accept_test_session_stop(_handle: Object, _fade_seconds: float) -> bool:
	return true


func _on_reentrant_session_ended(_handle: Object, _end_kind: int) -> void:
	if _audio == null or _reentrant_clip == null:
		return
	var operation_value: Variant = _audio.call(
		&"start_bgm_clip",
		_reentrant_clip,
		0.0,
		null
	)
	if operation_value is Object:
		_reentrant_operation = operation_value


func _on_first_wins_session_ended(
	_handle: Object,
	_end_kind: int,
	backend: ReentrantStartBackend
) -> void:
	_freeze_before_emit_listener_called = true
	var pending_operation: Object = backend.last_pending_operation
	if pending_operation == null:
		return
	var pending_result: Object = _call_object(pending_operation, &"get_result")
	_freeze_before_emit_pending_frozen = (
		not _call_bool(pending_operation, &"is_pending")
		and _call_bool(pending_operation, &"is_completed")
		and pending_result != null
		and _call_int(pending_result, &"get_status", -1)
		== _enum_value(_RESULT_SCRIPT_PATH, "Status", "CANCELLED")
	)


func _bind_cross_axis_pending_operation(pending_operation: Object) -> void:
	_cross_axis_pending_operation = pending_operation
	if pending_operation == null:
		_cross_axis_pending_connect_error = ERR_INVALID_PARAMETER
		return
	_cross_axis_pending_connect_error = pending_operation.connect(
		&"completed",
		Callable(self, "_on_cross_axis_b_completed")
	)


func _on_cross_axis_b_completed(_result: Object) -> void:
	_cross_axis_b_completed_count += 1
	_cross_axis_signal_order.append(&"b_completed")
	_cross_axis_b_listener_saw_a_frozen = (
		_cross_axis_active_session != null
		and _call_bool(_cross_axis_active_session, &"is_terminal")
		and _call_int(_cross_axis_active_session, &"get_end_kind", -1)
		== _enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "NATURAL_FINISH")
	)


func _on_cross_axis_a_ended(_handle: Object, end_kind: int) -> void:
	_cross_axis_a_ended_count += 1
	_cross_axis_signal_order.append(&"a_ended")
	var pending_result: Object = _call_object(
		_cross_axis_pending_operation,
		&"get_result"
	)
	_cross_axis_a_listener_saw_b_frozen = (
		end_kind == _enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "NATURAL_FINISH")
		and _cross_axis_pending_operation != null
		and not _call_bool(_cross_axis_pending_operation, &"is_pending")
		and _call_bool(_cross_axis_pending_operation, &"is_completed")
		and pending_result != null
		and _call_int(pending_result, &"get_status", -1)
		== _enum_value(_RESULT_SCRIPT_PATH, "Status", "CANCELLED")
	)


func _on_cross_axis_legacy_finished(history_key: String) -> void:
	_cross_axis_legacy_finished_count += 1
	_cross_axis_signal_order.append(&"legacy_natural")
	_cross_axis_legacy_history_key = history_key


func _on_generic_b_completed(_result: Object) -> void:
	_generic_b_completed_count += 1
	_generic_signal_order.append(&"b_completed")
	_generic_b_listener_saw_a_frozen = (
		_generic_active_session != null
		and _call_bool(_generic_active_session, &"is_terminal")
		and _call_int(_generic_active_session, &"get_end_kind", -1)
		== _enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "STOPPED")
	)


func _on_generic_a_ended(_handle: Object, end_kind: int) -> void:
	_generic_a_ended_count += 1
	_generic_signal_order.append(&"a_ended")
	var pending_result: Object = _call_object(
		_generic_pending_operation,
		&"get_result"
	)
	_generic_a_listener_saw_b_frozen = (
		end_kind == _enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "STOPPED")
		and _generic_pending_operation != null
		and not _call_bool(_generic_pending_operation, &"is_pending")
		and _call_bool(_generic_pending_operation, &"is_completed")
		and pending_result != null
		and _call_int(pending_result, &"get_status", -1)
		== _enum_value(_RESULT_SCRIPT_PATH, "Status", "CANCELLED")
		and _call_string_name(pending_result, &"get_reason")
		== _script_string_name_constant(_RESULT_SCRIPT_PATH, "REASON_CALLER_CANCELLED")
	)


func _bind_publication_failed_operation(failed_operation: Object) -> void:
	_publication_failed_operation = failed_operation
	if failed_operation == null:
		_publication_pending_connect_error = ERR_INVALID_PARAMETER
		return
	watch_signals(failed_operation)
	_publication_pending_connect_error = failed_operation.connect(
		&"completed",
		Callable(self, "_on_publication_b_completed")
	)


func _on_publication_b_completed(_result: Object) -> void:
	_publication_b_completed_count += 1
	_publication_signal_order.append(&"b_completed")
	_publication_b_listener_saw_a_frozen = (
		_publication_active_session != null
		and _call_bool(_publication_active_session, &"is_terminal")
		and _call_int(_publication_active_session, &"get_end_kind", -1)
		== _enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "PLAYBACK_FAILED")
	)


func _on_publication_a_ended(_handle: Object, end_kind: int) -> void:
	_publication_a_ended_count += 1
	_publication_signal_order.append(&"a_ended")
	var failed_result: Object = _call_object(
		_publication_failed_operation,
		&"get_result"
	)
	_publication_a_listener_saw_b_frozen = (
		end_kind == _enum_value(
			_SESSION_HANDLE_SCRIPT_PATH,
			"EndKind",
			"PLAYBACK_FAILED"
		)
		and _publication_failed_operation != null
		and not _call_bool(_publication_failed_operation, &"is_pending")
		and _call_bool(_publication_failed_operation, &"is_completed")
		and failed_result != null
		and _call_int(failed_result, &"get_status", -1)
		== _enum_value(_RESULT_SCRIPT_PATH, "Status", "FAILED")
		and _call_string_name(failed_result, &"get_reason")
		== _script_string_name_constant(
			_RESULT_SCRIPT_PATH,
			"REASON_SESSION_PUBLICATION_FAILED"
		)
	)


func _load_gdscript(path: String) -> GDScript:
	var resource_value: Resource = load(path)
	if resource_value is GDScript:
		return resource_value
	return null


func _assert_method_signature(
	target: Object,
	method_name: StringName,
	expected_argument_count: int,
	expected_default_count: int,
	expected_return_class: StringName
) -> void:
	var method_info: Dictionary = _find_method_info(target, method_name)
	assert_false(method_info.is_empty(), "缺少冻结入口：%s" % method_name)
	if method_info.is_empty():
		return
	var arguments_value: Variant = GFVariantData.get_option_value(method_info, "args")
	var defaults_value: Variant = GFVariantData.get_option_value(method_info, "default_args")
	var return_value: Variant = GFVariantData.get_option_value(method_info, "return")
	assert_true(arguments_value is Array)
	assert_true(defaults_value is Array)
	assert_true(return_value is Dictionary)
	if arguments_value is Array:
		var arguments: Array = arguments_value
		assert_eq(arguments.size(), expected_argument_count)
	if defaults_value is Array:
		var defaults: Array = defaults_value
		assert_eq(defaults.size(), expected_default_count)
	if return_value is Dictionary:
		var return_info: Dictionary = return_value
		assert_eq(
			StringName(GFVariantData.get_option_string(return_info, "class_name")),
			expected_return_class
		)


func _find_method_info(target: Object, method_name: StringName) -> Dictionary:
	if target == null:
		return {}
	for method_value: Variant in target.get_method_list():
		if not method_value is Dictionary:
			continue
		var method_info: Dictionary = method_value
		if GFVariantData.get_option_string_name(method_info, "name") == method_name:
			return method_info
	return {}


func _assert_script_enum(script: GDScript, enum_name: String, expected: Dictionary) -> void:
	var constants: Dictionary = script.get_script_constant_map()
	var enum_value: Variant = GFVariantData.get_option_value(constants, enum_name)
	assert_true(enum_value is Dictionary, "缺少冻结枚举：%s" % enum_name)
	if enum_value is Dictionary:
		var actual: Dictionary = enum_value
		assert_eq(actual, expected)


func _assert_object_surface(target: Object, method_names: Array[StringName]) -> void:
	for method_name: StringName in method_names:
		assert_true(target.has_method(method_name), "缺少冻结方法：%s" % method_name)


func _start_bgm(path: String, options: Dictionary, request_owner: Node = null) -> Object:
	var operation_value: Variant = _audio.call(&"start_bgm", path, options, request_owner)
	assert_true(operation_value is Object, "start_bgm 必须返回 GFBgmStartOperation。")
	if operation_value is Object:
		return operation_value
	return null


func _start_bgm_clip(
	clip: GFAudioClip,
	crossfade_seconds: float,
	request_owner: Node = null
) -> Object:
	var operation_value: Variant = _audio.call(
		&"start_bgm_clip",
		clip,
		crossfade_seconds,
		request_owner
	)
	assert_true(operation_value is Object, "start_bgm_clip 必须返回 GFBgmStartOperation。")
	if operation_value is Object:
		return operation_value
	return null


func _get_result(operation: Object) -> Object:
	if operation == null or not operation.has_method(&"get_result"):
		return null
	var result_value: Variant = operation.call(&"get_result")
	if result_value is Object:
		return result_value
	return null


func _assert_completed_with_status(operation: Object, status_name: String) -> Object:
	assert_not_null(operation)
	if operation == null:
		return null
	assert_false(_call_bool(operation, &"is_pending"))
	assert_true(_call_bool(operation, &"is_completed"))
	var result: Object = _get_result(operation)
	assert_not_null(result)
	if result == null:
		return null
	assert_eq(
		_call_int(result, &"get_status", -1),
		_enum_value(_RESULT_SCRIPT_PATH, "Status", status_name)
	)
	assert_eq(
		_call_int(result, &"get_request_id", 0),
		_call_int(operation, &"get_request_id", -1)
	)
	return result


func _assert_started_result_matches_operation(
	operation: Object,
	result: Object,
	expected_history_key: String
) -> void:
	assert_true(_call_bool(result, &"is_successful"))
	assert_eq(_call_int(result, &"get_error_code", -1), OK)
	assert_eq(_call_string(result, &"get_history_key"), expected_history_key)
	assert_gt(_call_int(result, &"get_session_id", 0), 0)
	var session: Object = _call_object(result, &"get_session_handle")
	assert_not_null(session)
	if session == null:
		return
	assert_eq(
		_call_int(session, &"get_session_id", 0),
		_call_int(result, &"get_session_id", -1)
	)
	assert_eq(
		_call_int(session, &"get_request_id", 0),
		_call_int(operation, &"get_request_id", -1)
	)
	assert_eq(_call_string(session, &"get_history_key"), expected_history_key)
	assert_true(_call_bool(session, &"is_active"))
	assert_false(_call_bool(session, &"is_terminal"))
	assert_eq(
		_call_int(session, &"get_end_kind", -1),
		_enum_value(_SESSION_HANDLE_SCRIPT_PATH, "EndKind", "NONE")
	)


func _call_bool(target: Object, method_name: StringName) -> bool:
	if target == null or not target.has_method(method_name):
		return false
	var value: Variant = target.call(method_name)
	return value if value is bool else false


func _call_bool_with_args(target: Object, method_name: StringName, arguments: Array) -> bool:
	if target == null or not target.has_method(method_name):
		return false
	var value: Variant = target.callv(method_name, arguments)
	return value if value is bool else false


func _call_int(target: Object, method_name: StringName, fallback: int) -> int:
	if target == null or not target.has_method(method_name):
		return fallback
	var value: Variant = target.call(method_name)
	if value is int:
		var int_value: int = value
		return int_value
	return fallback


func _call_object(target: Object, method_name: StringName) -> Object:
	if target == null or not target.has_method(method_name):
		return null
	var value: Variant = target.call(method_name)
	if value is Object:
		return value
	return null


func _call_string(target: Object, method_name: StringName) -> String:
	if target == null or not target.has_method(method_name):
		return ""
	var value: Variant = target.call(method_name)
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return ""


func _call_string_name(target: Object, method_name: StringName) -> StringName:
	return StringName(_call_string(target, method_name))


func _enum_value(path: String, enum_name: String, member_name: String) -> int:
	var script: GDScript = _load_gdscript(path)
	if script == null:
		return -1
	var enum_value: Variant = GFVariantData.get_option_value(
		script.get_script_constant_map(),
		enum_name
	)
	if not enum_value is Dictionary:
		return -1
	var values: Dictionary = enum_value
	return GFVariantData.get_option_int(values, member_name, -1)


func _script_string_name_constant(path: String, constant_name: String) -> StringName:
	var script: GDScript = _load_gdscript(path)
	if script == null:
		return &""
	var constant_value: Variant = GFVariantData.get_option_value(
		script.get_script_constant_map(),
		constant_name
	)
	if constant_value is StringName:
		var string_name_value: StringName = constant_value
		return string_name_value
	if constant_value is String:
		var string_value: String = constant_value
		return StringName(string_value)
	return &""
