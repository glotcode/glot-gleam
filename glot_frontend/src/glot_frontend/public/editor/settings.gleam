import gleam/dynamic/decode
import gleam/json

pub type KeyboardBindings {
  DefaultBindings
  EmacsBindings
  VimBindings
}

pub type EditorSettings {
  EditorSettings(keyboard_bindings: KeyboardBindings)
}

pub fn defaults() -> EditorSettings {
  EditorSettings(keyboard_bindings: DefaultBindings)
}

pub fn keyboard_bindings_to_string(bindings: KeyboardBindings) -> String {
  case bindings {
    DefaultBindings -> "default"
    EmacsBindings -> "emacs"
    VimBindings -> "vim"
  }
}

pub fn decoder() -> decode.Decoder(EditorSettings) {
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

pub fn encode(settings: EditorSettings) -> json.Json {
  let EditorSettings(keyboard_bindings:) = settings

  json.object([
    #(
      "keyboard_bindings",
      json.string(keyboard_bindings_to_string(keyboard_bindings)),
    ),
  ])
}
