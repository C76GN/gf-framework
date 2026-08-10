extends RefCounted


static func create(target_path: String, link_path: String) -> Error:
	if target_path.is_empty() or link_path.is_empty():
		return ERR_INVALID_PARAMETER
	var link_parent: DirAccess = DirAccess.open(link_path.get_base_dir())
	if link_parent == null:
		return ERR_CANT_OPEN
	var link_error: Error = link_parent.create_link(target_path, link_path)
	if link_error == OK or OS.get_name() != "Windows":
		return link_error
	if _contains_command_shell_metacharacter(target_path) or _contains_command_shell_metacharacter(link_path):
		return ERR_INVALID_PARAMETER
	var command_output: Array = []
	var command_line: String = "mklink /J \"%s\" \"%s\"" % [link_path, target_path]
	var exit_code: int = OS.execute(
		"cmd.exe",
		PackedStringArray(["/d", "/s", "/c", command_line]),
		command_output,
		true,
		false
	)
	if exit_code == 0 and DirAccess.dir_exists_absolute(link_path):
		return OK
	return FAILED


static func _contains_command_shell_metacharacter(path: String) -> bool:
	for character: String in PackedStringArray(["\"", "\r", "\n", "%", "!"]):
		if path.contains(character):
			return true
	return false
