import gleam/dynamic/decode
import gleam/json
import lustre/effect.{type Effect}

pub type KeyboardBindings {
  DefaultBindings
  EmacsBindings
  VimBindings
}

pub type EditorSettings {
  EditorSettings(keyboard_bindings: KeyboardBindings)
}

const storage_key = "glot.editor.settings"

pub fn defaults() -> EditorSettings {
  EditorSettings(keyboard_bindings: DefaultBindings)
}

pub fn load() -> EditorSettings {
  let raw = read_settings(storage_key)

  case json.parse(raw, decoder()) {
    Ok(settings) -> settings
    Error(_) -> defaults()
  }
}

pub fn save(settings: EditorSettings) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    write_settings(storage_key, settings |> encode() |> json.to_string())
  })
}

pub fn keyboard_bindings_to_string(bindings: KeyboardBindings) -> String {
  case bindings {
    DefaultBindings -> "default"
    EmacsBindings -> "emacs"
    VimBindings -> "vim"
  }
}

fn decoder() -> decode.Decoder(EditorSettings) {
  use keyboard_bindings <- decode.optional_field(
    "keyboard_bindings",
    DefaultBindings,
    keyboard_bindings_decoder(),
  )
  decode.success(EditorSettings(keyboard_bindings: keyboard_bindings))
}

fn keyboard_bindings_decoder() -> decode.Decoder(KeyboardBindings) {
  decode.then(decode.string, fn(value) {
    case value {
      "emacs" -> decode.success(EmacsBindings)
      "vim" -> decode.success(VimBindings)
      "default" -> decode.success(DefaultBindings)
      _ -> decode.failure(DefaultBindings, "KeyboardBindings")
    }
  })
}

fn encode(settings: EditorSettings) -> json.Json {
  let EditorSettings(keyboard_bindings:) = settings

  json.object([
    #(
      "keyboard_bindings",
      json.string(keyboard_bindings_to_string(keyboard_bindings)),
    ),
  ])
}

@external(javascript, "./editor_settings_ffi.mjs", "readSettings")
fn read_settings(key: String) -> String

@external(javascript, "./editor_settings_ffi.mjs", "writeSettings")
fn write_settings(key: String, value: String) -> Nil
