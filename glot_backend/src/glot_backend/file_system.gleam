@external(erlang, "file_system_ffi", "is_dir")
pub fn is_dir(_path: String) -> Bool {
  panic as "not implemented"
}

@external(erlang, "file_system_ffi", "is_file")
pub fn is_file(_path: String) -> Bool {
  panic as "not implemented"
}

@external(erlang, "file_system_ffi", "list_dir")
pub fn list_dir(_path: String) -> Result(List(String), String) {
  panic as "not implemented"
}

@external(erlang, "file_system_ffi", "read_file")
pub fn read_file(_path: String) -> Result(String, String) {
  panic as "not implemented"
}

@external(erlang, "file_system_ffi", "write_file")
pub fn write_file(_path: String, _content: String) -> Result(Nil, String) {
  panic as "not implemented"
}
