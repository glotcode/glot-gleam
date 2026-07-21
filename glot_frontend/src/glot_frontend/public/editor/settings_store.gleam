import gleam/json
import gleam/option
import glot_frontend/platform/local_storage
import glot_frontend/public/editor/settings
import lustre/effect.{type Effect}

const storage_key = "glot.editor.settings"

pub fn load() -> settings.EditorSettings {
  case local_storage.get(storage_key) {
    option.Some(raw) ->
      case json.parse(raw, settings.decoder()) {
        Ok(value) -> value
        Error(_) -> settings.defaults()
      }
    option.None -> settings.defaults()
  }
}

pub fn save(value: settings.EditorSettings) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    let _ =
      local_storage.set(storage_key, value |> settings.encode |> json.to_string)
    Nil
  })
}
