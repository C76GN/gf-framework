extends GFStorageSyncTransport


var records: Dictionary = {}
var history: Dictionary = {}
var pending: Array[Dictionary] = []
var calls: Array[StringName] = []
var held: Array[StringName] = []
var capabilities: Dictionary = {
	"read": true,
	"conditional_write": true,
	"probe": true,
}
var next_write_status: StringName = &""
var _revision: int = 0


func put(
	record_namespace: String,
	key: String,
	data: Dictionary,
	revision: String
) -> void:
	records[_key(record_namespace, key)] = { "data": data.duplicate(true), "revision": revision }


func _get_capabilities() -> Dictionary:
	return capabilities.duplicate()


func _read(request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _enqueue(&"read", request)


func _conditional_write(request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _enqueue(&"write", request)


func _probe(request: GFStorageSyncRequest) -> GFAsyncCompletion:
	return _enqueue(&"probe", request)


func execute(index: int = 0, deliver: bool = true) -> Dictionary:
	var invocation: Dictionary = pending.pop_at(index)
	var request: GFStorageSyncRequest = invocation["request"]
	var completion: GFAsyncCompletion = invocation["completion"]
	var kind: StringName = invocation["kind"]
	var reply: Dictionary = _perform(kind, request)
	if deliver:
		var _accepted: bool = completion.succeed(reply)
	return { "completion": completion, "reply": reply }


func _enqueue(kind: StringName, request: GFStorageSyncRequest) -> GFAsyncCompletion:
	calls.append(kind)
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	pending.append(
		{
			"kind": kind,
			"request": request,
			"completion": completion,
		}
	)
	if kind not in held:
		var _result: Dictionary = execute(pending.size() - 1)
	return completion


func _perform(kind: StringName, request: GFStorageSyncRequest) -> Dictionary:
	var key: String = _key(
		request.get_namespace(),
		request.get_key()
	)
	var operation_key: String = JSON.stringify([key, request.get_operation_id()])
	if kind == &"probe":
		if not history.has(operation_key):
			return _reply(request, &"unknown")
		var past: Dictionary = GFVariantData.get_option_dictionary(history, operation_key)
		if GFVariantData.get_option_dictionary(past, "candidate") != request.get_data() or past.get("expected") != request.get_expected_revision():
			return _reply(request, &"unknown")
		var past_outcome: Dictionary = GFVariantData.get_option_dictionary(past, "outcome")
		if past_outcome.get("status") == &"conflict":
			return _reply(request, &"not_committed")
		return past_outcome.duplicate(true)
	if kind == &"read":
		return _reply(
			request,
			&"read",
			GFVariantData.get_option_dictionary(records, key)
		)
	if history.has(operation_key):
		var past: Dictionary = GFVariantData.get_option_dictionary(history, operation_key)
		if GFVariantData.get_option_dictionary(past, "candidate") != request.get_data() or past.get("expected") != request.get_expected_revision():
			return _reply(request, &"unknown")
		return GFVariantData.get_option_dictionary(past, "outcome").duplicate(true)
	var current: Dictionary = GFVariantData.get_option_dictionary(records, key)
	var status: StringName = next_write_status
	next_write_status = &""
	var outcome: Dictionary
	if status == &"not_committed":
		outcome = _reply(request, status)
	elif GFVariantData.get_option_string(current, "revision") != request.get_expected_revision():
		outcome = _reply(
			request,
			&"conflict",
			current
		)
	else:
		_revision += 1
		current = { "revision": "opaque-%d" % _revision, "data": request.get_data() }
		records[key] = current
		outcome = _reply(
			request,
			&"committed",
			current
		)
	history[operation_key] = {
		"candidate": request.get_data(),
		"expected": request.get_expected_revision(),
		"outcome": outcome.duplicate(true),
	}
	return outcome


func _reply(
	request: GFStorageSyncRequest,
	status: StringName,
	record: Dictionary = {}
) -> Dictionary:
	return {
		"namespace": request.get_namespace(),
		"key": request.get_key(),
		"operation_id": request.get_operation_id(),
		"status": status,
		"exists": not record.is_empty(),
		"revision": GFVariantData.get_option_string(record, "revision"),
		"data": GFVariantData.get_option_dictionary(record, "data").duplicate(true),
	}


func _key(record_namespace: String, key: String) -> String:
	return JSON.stringify([record_namespace, key])
