# Removes a test-owned tree after its caller has checked the fixture root and stopped its workers.
extends RefCounted


# --- 框架内部方法 ---

static func remove_owned_tree(path: String) -> Error:
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.include_hidden = true
	for file_name: String in directory.get_files():
		var remove_file_error: Error = DirAccess.remove_absolute(path.path_join(file_name))
		if remove_file_error != OK:
			return remove_file_error
	for directory_name: String in directory.get_directories():
		var child_path: String = path.path_join(directory_name)
		var remove_directory_error: Error = (DirAccess.remove_absolute(child_path) if directory.is_link(directory_name) else remove_owned_tree(child_path))
		if remove_directory_error != OK:
			return remove_directory_error
	directory = null
	return DirAccess.remove_absolute(path)
