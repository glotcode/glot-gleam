import gleam/option

pub fn get(key: String) -> option.Option(String) {
  case get_item(key) {
    #(True, value) -> option.Some(value)
    #(False, _) -> option.None
  }
}

@external(javascript, "./local_storage_ffi.mjs", "getItem")
fn get_item(key: String) -> #(Bool, String)

@external(javascript, "./local_storage_ffi.mjs", "setItem")
pub fn set(key: String, value: String) -> Bool

@external(javascript, "./local_storage_ffi.mjs", "removeItem")
pub fn remove(key: String) -> Bool
