import glot_core/page/seo
import lustre/effect.{type Effect}

pub fn apply(metadata: seo.Metadata) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    set_metadata(
      seo.title(metadata),
      seo.description(metadata),
      seo.canonical_url(metadata),
      seo.robots(metadata),
      seo.open_graph_type(metadata),
    )
  })
}

@external(javascript, "./page_metadata_ffi.mjs", "setMetadata")
fn set_metadata(
  title: String,
  description: String,
  canonical_url: String,
  robots: String,
  open_graph_type: String,
) -> Nil
