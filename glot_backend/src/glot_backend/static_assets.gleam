import gleam/dynamic/decode
import gleam/json
import gleam/result
import glot_backend/file_system

const manifest_path = "/manifest.json"

pub type Assets {
  Assets(frontend_src: String, stylesheet_href: String)
}

pub fn load(static_base_path: String) -> Result(Assets, String) {
  use entry <- result.try(read_manifest_entry(static_base_path))

  case entry.css {
    [stylesheet, ..] -> {
      Ok(Assets(
        frontend_src: "/static/" <> entry.file,
        stylesheet_href: "/static/" <> stylesheet,
      ))
    }
    [] -> Error("Vite manifest entry index.html has no CSS asset.")
  }
}

type ManifestEntry {
  ManifestEntry(file: String, css: List(String))
}

fn read_manifest_entry(
  static_base_path: String,
) -> Result(ManifestEntry, String) {
  use content <- result.try(
    file_system.read_file(static_base_path <> manifest_path)
    |> result.map_error(fn(message) {
      "Could not read Vite manifest at "
      <> static_base_path
      <> manifest_path
      <> ": "
      <> message
    }),
  )

  json.parse(content, manifest_decoder())
  |> result.map_error(fn(_) {
    "Could not decode Vite manifest at " <> static_base_path <> manifest_path
  })
}

fn manifest_decoder() -> decode.Decoder(ManifestEntry) {
  decode.field("index.html", manifest_entry_decoder(), fn(entry) {
    decode.success(entry)
  })
}

fn manifest_entry_decoder() -> decode.Decoder(ManifestEntry) {
  use file <- decode.field("file", decode.string)
  use css <- decode.field("css", decode.list(decode.string))
  decode.success(ManifestEntry(file: file, css: css))
}
